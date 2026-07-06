import SceneKit
import SwiftUI
import simd

/// Interactive crop tool: shows the saved mesh in an orbitable 3D view
/// with a translucent crop box driven by per-axis sliders. Applying the
/// crop rewrites the stored raw mesh and regenerates the exported files.
struct CropView: View {
    let record: ScanRecord
    var onUpdated: (ScanRecord) -> Void

    @Environment(\.dismiss) private var dismiss

    private struct CropFractions: Equatable {
        var minX = 0.0, maxX = 1.0
        var minY = 0.0, maxY = 1.0
        var minZ = 0.0, maxZ = 1.0
    }

    @State private var mesh: RawMesh?
    @State private var scene: SCNScene?
    @State private var boxNode: SCNNode?
    @State private var meshBounds: (min: SIMD3<Float>, max: SIMD3<Float>) = (.zero, .zero)
    @State private var fractions = CropFractions()
    @State private var isApplying = false
    @State private var showConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                viewport
                controls
            }
            .navigationTitle("Crop Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isApplying)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { showConfirm = true }
                        .disabled(mesh == nil || isApplying)
                }
            }
            .confirmationDialog(
                "Trim everything outside the box? This permanently replaces the stored mesh and regenerates the exported files.",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Apply Crop", role: .destructive) { apply() }
            }
            .task { await load() }
            .onChange(of: fractions) { updateBox() }
            .interactiveDismissDisabled(isApplying)
        }
    }

    // MARK: - Viewport

    @ViewBuilder
    private var viewport: some View {
        ZStack {
            if let scene {
                SceneView(
                    scene: scene,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding()
            } else {
                ProgressView("Loading mesh…")
            }

            if isApplying {
                ProgressView("Cropping…")
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Sliders

    private var controls: some View {
        VStack(spacing: 10) {
            axisRow(label: "X", min: $fractions.minX, max: $fractions.maxX)
            axisRow(label: "Y", min: $fractions.minY, max: $fractions.maxY)
            axisRow(label: "Z", min: $fractions.minZ, max: $fractions.maxZ)
        }
        .padding()
        .background(.thinMaterial)
        .disabled(mesh == nil || isApplying)
    }

    private func axisRow(label: String, min: Binding<Double>, max: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.headline.monospaced())
                .frame(width: 20)
            Slider(value: min, in: 0...1)
            Slider(value: max, in: 0...1)
        }
    }

    // MARK: - Loading

    private func load() async {
        let url = ScanArchiver.rawMeshURL(for: record)
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                try RawMesh.read(from: url)
            }.value
            mesh = loaded
            meshBounds = loaded.bounds()
            buildScene(with: loaded)
            updateBox()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildScene(with mesh: RawMesh) {
        let newScene = SCNScene()
        newScene.rootNode.addChildNode(SCNNode(geometry: MeshExporter.makeGeometry(from: mesh)))

        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.18)
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        box.firstMaterial = material
        let node = SCNNode(geometry: box)
        newScene.rootNode.addChildNode(node)

        boxNode = node
        scene = newScene
    }

    private func cropBounds() -> (lower: SIMD3<Float>, upper: SIMD3<Float>) {
        let extent = meshBounds.max - meshBounds.min
        let a = meshBounds.min + extent * SIMD3<Float>(
            Float(fractions.minX), Float(fractions.minY), Float(fractions.minZ)
        )
        let b = meshBounds.min + extent * SIMD3<Float>(
            Float(fractions.maxX), Float(fractions.maxY), Float(fractions.maxZ)
        )
        return (simd_min(a, b), simd_max(a, b))
    }

    private func updateBox() {
        guard let boxNode else { return }
        let (lower, upper) = cropBounds()
        let size = simd_max(upper - lower, SIMD3<Float>(repeating: 0.005))
        let center = (lower + upper) / 2
        boxNode.position = SCNVector3(center.x, center.y, center.z)
        boxNode.scale = SCNVector3(size.x, size.y, size.z)
    }

    // MARK: - Apply

    private func apply() {
        guard let mesh else { return }
        isApplying = true
        errorMessage = nil
        let (lower, upper) = cropBounds()
        let baseRecord = record

        Task {
            do {
                let updated = try await Task.detached(priority: .userInitiated) { () throws -> ScanRecord in
                    let cropped = mesh.cropped(minBound: lower, maxBound: upper)
                    guard !cropped.indices.isEmpty else {
                        throw MeshExportError.writeFailed("The crop box contains no geometry. Enlarge it and try again.")
                    }
                    try cropped.write(to: ScanArchiver.rawMeshURL(for: baseRecord))

                    var next = baseRecord
                    next.vertexCount = cropped.vertices.count
                    next.faceCount = cropped.triangleCount
                    next.surfaceAreaSquareMeters = cropped.surfaceArea()
                    next.volumeCubicMeters = cropped.approximateVolume()
                    let formats = Array(Set(next.files.map(\.format)))
                    let files = try ScanArchiver.exportFiles(from: cropped, record: next, formats: formats)
                    return try ScanArchiver.mergeFiles(files, into: next)
                }.value
                onUpdated(updated)
                isApplying = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isApplying = false
            }
        }
    }
}
