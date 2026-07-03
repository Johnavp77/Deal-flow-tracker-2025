import Combine
import RoomPlan
import UIKit

/// Wraps RoomPlan's RoomCaptureView/RoomCaptureSession to produce a
/// parametric room model (walls, doors, windows, objects) exported as USDZ.
@MainActor
final class RoomScanController: NSObject, ObservableObject, RoomCaptureViewDelegate {
    let captureView: RoomCaptureView

    @Published private(set) var isScanning = false
    @Published private(set) var processedRoom: CapturedRoom?
    @Published var errorMessage: String?

    override init() {
        captureView = RoomCaptureView(frame: .zero)
        super.init()
        captureView.delegate = self
    }

    // RoomCaptureViewDelegate refines NSCoding; the delegate is never
    // actually archived, so these are inert conformances.
    init?(coder: NSCoder) {
        nil
    }

    func encode(with coder: NSCoder) {}

    // MARK: - Session control

    func start() {
        guard !isScanning, DeviceSupport.supportsRoomPlan else { return }
        processedRoom = nil
        errorMessage = nil
        var configuration = RoomCaptureSession.Configuration()
        configuration.isCoachingEnabled = true
        captureView.captureSession.run(configuration: configuration)
        isScanning = true
    }

    /// Ends the walkthrough; RoomPlan then post-processes the capture and
    /// calls back with the final CapturedRoom.
    func finish() {
        guard isScanning else { return }
        captureView.captureSession.stop()
        isScanning = false
    }

    func stop() {
        captureView.captureSession.stop(pauseARSession: true)
        isScanning = false
    }

    func save(name: String) throws -> ScanRecord {
        guard let processedRoom else { throw MeshExportError.nothingToExport }
        let record = try ScanArchiver.persistRoom(processedRoom, name: name)
        ScanStore.shared.insert(record)
        return record
    }

    // MARK: - RoomCaptureViewDelegate

    nonisolated func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (any Error)?) -> Bool {
        true
    }

    nonisolated func captureView(didPresent processedResult: CapturedRoom, error: (any Error)?) {
        let message = error?.localizedDescription
        Task { @MainActor in
            if let message {
                self.errorMessage = message
            } else {
                self.processedRoom = processedResult
            }
        }
    }
}
