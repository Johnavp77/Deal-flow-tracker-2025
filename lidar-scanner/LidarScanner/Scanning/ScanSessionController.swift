import ARKit
import Combine
import RealityKit
import UIKit

/// A completed two-point measurement taken during a scan.
struct MeasurementLine: Identifiable {
    let id = UUID()
    let start: SIMD3<Float>
    let end: SIMD3<Float>

    var distance: Float { simd_distance(start, end) }

    var formatted: String {
        distance < 1
            ? String(format: "%.1f cm", distance * 100)
            : String(format: "%.2f m", distance)
    }
}

/// Owns the ARView and AR session for LiDAR scanning: live mesh
/// visualization, tap-to-measure, and hand-off of captured mesh
/// anchors to the exporter when the user finishes a scan.
@MainActor
final class ScanSessionController: NSObject, ObservableObject {
    enum ScanState {
        case idle
        case scanning
        case finishing
    }

    let arView: ARView

    @Published private(set) var state: ScanState = .idle
    @Published private(set) var meshAnchorCount = 0
    @Published private(set) var trackingStatus = "Ready"
    @Published private(set) var measurements: [MeasurementLine] = []
    @Published var measureMode = false {
        didSet { if !measureMode { pendingPoint = nil } }
    }
    @Published var showMesh = true {
        didSet { updateMeshVisibility() }
    }

    private var pendingPoint: SIMD3<Float>?
    private var measurementAnchors: [AnchorEntity] = []
    private let coachingOverlay = ARCoachingOverlayView()
    private let keyframeCollector = KeyframeCollector()

    override init() {
        arView = ARView(frame: .zero)
        super.init()

        arView.automaticallyConfigureSession = false
        arView.session.delegate = self
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.debugOptions.insert(.showSceneUnderstanding)

        coachingOverlay.session = arView.session
        coachingOverlay.goal = .tracking
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)
        NSLayoutConstraint.activate([
            coachingOverlay.topAnchor.constraint(equalTo: arView.topAnchor),
            coachingOverlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor),
            coachingOverlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coachingOverlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    // MARK: - Session control

    func startScan() {
        guard DeviceSupport.supportsLidarScanning else { return }
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else {
            configuration.sceneReconstruction = .mesh
        }
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        clearMeasurements()
        meshAnchorCount = 0
        trackingStatus = "Initializing"
        keyframeCollector.reset()
        keyframeCollector.setCollecting(true)
        arView.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction]
        )
        state = .scanning
    }

    func resetScan() {
        guard state == .scanning else { return }
        startScan()
    }

    /// Pauses the session if the scan screen goes away mid-scan.
    func pauseIfScanning() {
        guard state == .scanning else { return }
        keyframeCollector.setCollecting(false)
        arView.session.pause()
        state = .idle
        trackingStatus = "Ready"
    }

    /// Captures the current mesh, pauses the session, and writes the
    /// selected file formats to the scan library on a background task.
    /// When captureColor is on, collected camera keyframes are projected
    /// onto the mesh to produce per-vertex colors.
    func finishScan(name: String, formats: [ExportFormat], captureColor: Bool) async throws -> ScanRecord {
        guard state == .scanning else { throw MeshExportError.nothingToExport }
        guard let frame = arView.session.currentFrame else {
            throw MeshExportError.nothingToExport
        }
        let anchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        guard !anchors.isEmpty else { throw MeshExportError.nothingToExport }

        state = .finishing
        keyframeCollector.setCollecting(false)
        let thumbnail = await snapshot()
        arView.session.pause()
        let keyframes = captureColor ? keyframeCollector.snapshot() : []

        do {
            let record = try await Task.detached(priority: .userInitiated) {
                var meshes = anchors.map(CapturedMesh.init)
                if !keyframes.isEmpty {
                    meshes = ColorProjector.colorize(meshes, with: keyframes)
                }
                return try ScanArchiver.persistMeshes(
                    meshes,
                    name: name,
                    formats: formats,
                    thumbnail: thumbnail
                )
            }.value
            ScanStore.shared.insert(record)
            state = .idle
            trackingStatus = "Ready"
            return record
        } catch {
            state = .idle
            trackingStatus = "Ready"
            throw error
        }
    }

    private func snapshot() async -> UIImage? {
        await withCheckedContinuation { continuation in
            arView.snapshot(saveToHDR: false) { image in
                continuation.resume(returning: image)
            }
        }
    }

    private func updateMeshVisibility() {
        if showMesh {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }

    // MARK: - Measurement

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard measureMode, state == .scanning else { return }
        let point = gesture.location(in: arView)
        guard let result = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any).first else {
            return
        }
        let column = result.worldTransform.columns.3
        let position = SIMD3<Float>(column.x, column.y, column.z)
        placeMarker(at: position)

        if let start = pendingPoint {
            let line = MeasurementLine(start: start, end: position)
            measurements.append(line)
            placeLine(line)
            pendingPoint = nil
        } else {
            pendingPoint = position
        }
    }

    func clearMeasurements() {
        for anchor in measurementAnchors {
            arView.scene.removeAnchor(anchor)
        }
        measurementAnchors.removeAll()
        measurements.removeAll()
        pendingPoint = nil
    }

    private func placeMarker(at position: SIMD3<Float>) {
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [UnlitMaterial(color: .systemYellow)]
        )
        let anchor = AnchorEntity(world: position)
        anchor.addChild(sphere)
        arView.scene.addAnchor(anchor)
        measurementAnchors.append(anchor)
    }

    private func placeLine(_ line: MeasurementLine) {
        let length = max(line.distance, 0.001)
        let box = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.003, 0.003, length)),
            materials: [UnlitMaterial(color: .systemYellow)]
        )
        let midpoint = (line.start + line.end) / 2
        let anchor = AnchorEntity(world: midpoint)
        anchor.addChild(box)
        box.look(at: line.end, from: midpoint, relativeTo: nil)
        arView.scene.addAnchor(anchor)
        measurementAnchors.append(anchor)
    }
}

// MARK: - ARSessionDelegate

extension ScanSessionController: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        keyframeCollector.consider(frame)
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let added = anchors.lazy.filter { $0 is ARMeshAnchor }.count
        guard added > 0 else { return }
        Task { @MainActor in
            self.meshAnchorCount += added
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removed = anchors.lazy.filter { $0 is ARMeshAnchor }.count
        guard removed > 0 else { return }
        Task { @MainActor in
            self.meshAnchorCount = max(0, self.meshAnchorCount - removed)
        }
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let status = Self.describe(camera.trackingState)
        Task { @MainActor in
            self.trackingStatus = status
        }
    }

    private nonisolated static func describe(_ trackingState: ARCamera.TrackingState) -> String {
        switch trackingState {
        case .normal:
            return "Tracking"
        case .notAvailable:
            return "Tracking unavailable"
        case .limited(.excessiveMotion):
            return "Slow down"
        case .limited(.insufficientFeatures):
            return "Point at textured surfaces"
        case .limited(.initializing):
            return "Initializing"
        case .limited(.relocalizing):
            return "Relocalizing"
        case .limited:
            return "Limited tracking"
        }
    }
}
