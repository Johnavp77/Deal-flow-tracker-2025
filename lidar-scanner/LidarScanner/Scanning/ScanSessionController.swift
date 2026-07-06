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

    enum MeasureTool: String, CaseIterable, Identifiable {
        case distance
        case area

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .distance: return "Distance"
            case .area: return "Area"
            }
        }
    }

    let arView: ARView

    @Published private(set) var state: ScanState = .idle
    @Published private(set) var meshAnchorCount = 0
    @Published private(set) var trackingStatus = "Ready"
    @Published private(set) var measurements: [MeasurementLine] = []
    @Published private(set) var areaPoints: [SIMD3<Float>] = []
    @Published var measureTool: MeasureTool = .distance
    @Published var snapToCorners = true
    @Published var measureMode = false {
        didSet { if !measureMode { pendingPoint = nil } }
    }
    @Published var showMesh = true {
        didSet { updateMeshVisibility() }
    }

    /// Horizontal (floor-plan) area of the tapped polygon, in m².
    var polygonArea: Float {
        guard areaPoints.count >= 3 else { return 0 }
        var sum: Float = 0
        for index in 0..<areaPoints.count {
            let a = areaPoints[index]
            let b = areaPoints[(index + 1) % areaPoints.count]
            sum += a.x * b.z - b.x * a.z
        }
        return abs(sum) / 2
    }

    /// Closed-loop perimeter of the tapped polygon, in meters.
    var polygonPerimeter: Float {
        guard areaPoints.count >= 2 else { return 0 }
        var total: Float = 0
        for index in 0..<areaPoints.count {
            total += simd_distance(areaPoints[index], areaPoints[(index + 1) % areaPoints.count])
        }
        return total
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

    /// Starts a fresh scan, or continues a saved one when a world map
    /// is supplied — ARKit relocalizes against it so new geometry lands
    /// in the same coordinate space as the original capture.
    func startScan(resumingFrom worldMap: ARWorldMap? = nil) {
        guard DeviceSupport.supportsLidarScanning else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.initialWorldMap = worldMap
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
    /// onto the mesh to produce per-vertex colors. Quality controls
    /// decimation of the exported files; the raw mesh is kept at full detail.
    func finishScan(
        name: String,
        formats: [ExportFormat],
        captureColor: Bool,
        quality: MeshQuality
    ) async throws -> ScanRecord {
        guard state == .scanning else { throw MeshExportError.nothingToExport }
        guard let frame = arView.session.currentFrame else {
            throw MeshExportError.nothingToExport
        }
        let anchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        guard !anchors.isEmpty else { throw MeshExportError.nothingToExport }

        state = .finishing
        keyframeCollector.setCollecting(false)
        let thumbnail = await snapshot()
        let worldMap = await currentWorldMap()
        arView.session.pause()
        let keyframes = captureColor ? keyframeCollector.snapshot() : []

        do {
            let record = try await Task.detached(priority: .userInitiated) {
                var meshes = anchors.map(CapturedMesh.init)
                if !keyframes.isEmpty {
                    meshes = ColorProjector.colorize(meshes, with: keyframes)
                }
                let worldMapData = worldMap.flatMap {
                    try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
                }
                return try ScanArchiver.persistMeshes(
                    meshes,
                    name: name,
                    formats: formats,
                    quality: quality,
                    thumbnail: thumbnail,
                    worldMapData: worldMapData
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

    /// Finishes a resumed scan: the newly captured mesh is merged into
    /// the record's stored mesh, its export files are regenerated, and
    /// the saved world map is refreshed for the next resume.
    func finishResumedScan(into record: ScanRecord) async throws -> ScanRecord {
        guard state == .scanning else { throw MeshExportError.nothingToExport }
        guard let frame = arView.session.currentFrame else {
            throw MeshExportError.nothingToExport
        }
        let anchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        guard !anchors.isEmpty else { throw MeshExportError.nothingToExport }

        state = .finishing
        keyframeCollector.setCollecting(false)
        let thumbnail = await snapshot()
        let worldMap = await currentWorldMap()
        arView.session.pause()
        let keyframes = keyframeCollector.snapshot()

        do {
            let updated = try await Task.detached(priority: .userInitiated) { () throws -> ScanRecord in
                var meshes = anchors.map(CapturedMesh.init)
                if !keyframes.isEmpty {
                    meshes = ColorProjector.colorize(meshes, with: keyframes)
                }
                let newMesh = RawMesh(merging: meshes)
                let existing = try RawMesh.read(from: ScanArchiver.rawMeshURL(for: record))
                let merged = RawMesh.merged(existing, newMesh)
                try merged.write(to: ScanArchiver.rawMeshURL(for: record))

                if let worldMap,
                   let data = try? NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true) {
                    try? data.write(to: ScanArchiver.worldMapURL(for: record))
                }
                if let thumbnail {
                    ScanArchiver.saveThumbnail(thumbnail, for: record)
                }

                var next = record
                next.vertexCount = merged.vertices.count
                next.faceCount = merged.triangleCount
                next.surfaceAreaSquareMeters = merged.surfaceArea()
                next.volumeCubicMeters = merged.approximateVolume()
                let formats = next.files.isEmpty ? [.usdz] : Array(Set(next.files.map(\.format)))
                let files = try ScanArchiver.exportFiles(from: merged, record: next, formats: formats)
                return try ScanArchiver.mergeFiles(files, into: next)
            }.value
            ScanStore.shared.insert(updated)
            state = .idle
            trackingStatus = "Ready"
            return updated
        } catch {
            state = .idle
            trackingStatus = "Ready"
            throw error
        }
    }

    private func currentWorldMap() async -> ARWorldMap? {
        await withCheckedContinuation { continuation in
            arView.session.getCurrentWorldMap { map, _ in
                continuation.resume(returning: map)
            }
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
        let raw = SIMD3<Float>(column.x, column.y, column.z)
        let (position, snapped) = snappedPosition(from: raw)
        placeMarker(at: position, color: snapped ? .systemGreen : .systemYellow)

        switch measureTool {
        case .distance:
            if let start = pendingPoint {
                let line = MeasurementLine(start: start, end: position)
                measurements.append(line)
                placeLine(line)
                pendingPoint = nil
            } else {
                pendingPoint = position
            }
        case .area:
            if let previous = areaPoints.last {
                placeLine(MeasurementLine(start: previous, end: position))
            }
            areaPoints.append(position)
        }
    }

    /// Pulls a tapped point onto the nearest sharp crease or corner of
    /// the reconstructed mesh: candidate vertices near the tap whose
    /// neighborhood normals diverge strongly mark an edge; the closest
    /// strong crease wins. Falls back to the raw raycast hit.
    private func snappedPosition(from raw: SIMD3<Float>) -> (SIMD3<Float>, Bool) {
        guard snapToCorners, let frame = arView.session.currentFrame else { return (raw, false) }
        let searchRadius: Float = 0.12
        let neighborRadiusSquared: Float = 0.05 * 0.05

        struct Candidate {
            let position: SIMD3<Float>
            let normal: SIMD3<Float>
        }
        var candidates: [Candidate] = []

        for case let anchor as ARMeshAnchor in frame.anchors {
            let origin = anchor.transform.columns.3
            guard simd_distance(SIMD3<Float>(origin.x, origin.y, origin.z), raw) < 2.5 else { continue }
            let geometry = anchor.geometry
            let transform = anchor.transform
            let rotation = simd_float3x3(
                SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
                SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
                SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
            )
            for index in 0..<geometry.vertices.count {
                let local = geometry.vertexPosition(at: index)
                let world4 = transform * SIMD4<Float>(local.x, local.y, local.z, 1)
                let world = SIMD3<Float>(world4.x, world4.y, world4.z)
                guard simd_distance_squared(world, raw) < searchRadius * searchRadius else { continue }
                candidates.append(Candidate(
                    position: world,
                    normal: simd_normalize(rotation * geometry.vertexNormal(at: index))
                ))
            }
        }
        guard candidates.count > 3 else { return (raw, false) }

        var best: (position: SIMD3<Float>, score: Float, distance: Float)?
        for candidate in candidates {
            var divergence: Float = 0
            for other in candidates {
                let separation = simd_distance_squared(candidate.position, other.position)
                guard separation > 0, separation < neighborRadiusSquared else { continue }
                divergence = max(divergence, 1 - simd_dot(candidate.normal, other.normal))
            }
            // 1 - cos(60°) = 0.5: require a pronounced crease.
            guard divergence > 0.5 else { continue }
            let distance = simd_distance(candidate.position, raw)
            if let current = best {
                let clearlySharper = divergence > current.score + 0.15
                let similarButCloser = abs(divergence - current.score) <= 0.15 && distance < current.distance
                if clearlySharper || similarButCloser {
                    best = (candidate.position, divergence, distance)
                }
            } else {
                best = (candidate.position, divergence, distance)
            }
        }
        if let best {
            return (best.position, true)
        }
        return (raw, false)
    }

    func clearMeasurements() {
        for anchor in measurementAnchors {
            arView.scene.removeAnchor(anchor)
        }
        measurementAnchors.removeAll()
        measurements.removeAll()
        areaPoints.removeAll()
        pendingPoint = nil
    }

    private func placeMarker(at position: SIMD3<Float>, color: UIColor) {
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [UnlitMaterial(color: color)]
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
