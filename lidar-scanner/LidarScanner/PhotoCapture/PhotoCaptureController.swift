import Combine
import Foundation
import RealityKit

/// Drives Polycam-style "Photo mode": a guided ObjectCaptureSession takes
/// a ring of photos around a small object, then PhotogrammetrySession
/// reconstructs them into a textured USDZ model on-device.
@MainActor
final class PhotoCaptureController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case capturing
        case reconstructing(Double)
        case failed(String)
    }

    @Published private(set) var session: ObjectCaptureSession?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var sessionState: ObjectCaptureSession.CaptureState = .initializing
    /// Finished USDZ waiting for the user to name and save it.
    @Published private(set) var completedModelURL: URL?

    private var captureRoot: URL?
    private var imagesDirectory: URL?
    private var stateTask: Task<Void, Never>?

    // MARK: - Capture

    func start() {
        guard session == nil, ObjectCaptureSession.isSupported else { return }
        discardResult()

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ObjectCapture-\(UUID().uuidString)", isDirectory: true)
        let images = root.appendingPathComponent("Images", isDirectory: true)
        let checkpoints = root.appendingPathComponent("Checkpoints", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: checkpoints, withIntermediateDirectories: true)
        } catch {
            phase = .failed("Could not prepare capture storage: \(error.localizedDescription)")
            return
        }
        captureRoot = root
        imagesDirectory = images

        let session = ObjectCaptureSession()
        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = checkpoints
        session.start(imagesDirectory: images, configuration: configuration)
        self.session = session
        phase = .capturing

        stateTask = Task { [weak self] in
            for await state in session.stateUpdates {
                guard let self else { return }
                self.sessionState = state
                switch state {
                case .completed:
                    self.teardownSession()
                    await self.reconstruct()
                case .failed(let error):
                    self.phase = .failed(error.localizedDescription)
                    self.teardownSession()
                    self.cleanupCaptureFiles()
                default:
                    break
                }
            }
        }
    }

    func continueToDetection() {
        _ = session?.startDetecting()
    }

    func startCapturing() {
        session?.startCapturing()
    }

    func finishCapture() {
        session?.finish()
    }

    func cancel() {
        session?.cancel()
        teardownSession()
        cleanupCaptureFiles()
        phase = .idle
    }

    /// Cancels an in-flight capture when the screen goes away, but lets
    /// reconstruction keep running.
    func handleDisappear() {
        if session != nil {
            cancel()
        }
    }

    // MARK: - Reconstruction

    private func reconstruct() async {
        guard let imagesDirectory else { return }
        guard PhotogrammetrySession.isSupported else {
            phase = .failed("On-device 3D reconstruction is not supported on this device.")
            cleanupCaptureFiles()
            return
        }

        phase = .reconstructing(0)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoModel-\(UUID().uuidString).usdz")

        do {
            let configuration = PhotogrammetrySession.Configuration()
            let photogrammetry = try PhotogrammetrySession(
                input: imagesDirectory,
                configuration: configuration
            )
            try photogrammetry.process(requests: [.modelFile(url: outputURL, detail: .reduced)])

            for try await output in photogrammetry.outputs {
                switch output {
                case .requestProgress(_, let fractionComplete):
                    phase = .reconstructing(fractionComplete)
                case .requestError(_, let error):
                    throw error
                case .processingComplete:
                    completedModelURL = outputURL
                    phase = .idle
                default:
                    break
                }
            }
        } catch {
            phase = .failed("Reconstruction failed: \(error.localizedDescription)")
        }
        cleanupCaptureFiles()
    }

    // MARK: - Saving

    func save(name: String) throws -> ScanRecord {
        guard let completedModelURL else { throw MeshExportError.nothingToExport }
        let record = try ScanArchiver.persistModelFile(
            at: completedModelURL,
            name: name,
            kind: .photo
        )
        ScanStore.shared.insert(record)
        try? FileManager.default.removeItem(at: completedModelURL)
        self.completedModelURL = nil
        return record
    }

    func discardResult() {
        if let completedModelURL {
            try? FileManager.default.removeItem(at: completedModelURL)
        }
        completedModelURL = nil
        if case .failed = phase {
            phase = .idle
        }
    }

    // MARK: - Helpers

    private func teardownSession() {
        stateTask?.cancel()
        stateTask = nil
        session = nil
    }

    private func cleanupCaptureFiles() {
        if let captureRoot {
            try? FileManager.default.removeItem(at: captureRoot)
        }
        captureRoot = nil
        imagesDirectory = nil
    }
}
