import Foundation
import ModelIO
import SceneKit
import UIKit

enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case usdz
    case obj
    case stl
    case ply

    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }

    var summary: String {
        switch self {
        case .usdz: return "Apple AR — previews in Quick Look, Messages, Safari"
        case .obj: return "Universal — Blender, Maya, Unity, Unreal"
        case .stl: return "3D printing (geometry only)"
        case .ply: return "MeshLab / CloudCompare / research tools"
        }
    }

    var supportsVertexColors: Bool {
        switch self {
        case .usdz, .obj, .ply: return true
        case .stl: return false
        }
    }
}

enum MeshExportError: LocalizedError {
    case nothingToExport
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .nothingToExport:
            return "No mesh has been captured yet. Move the device around slowly so the LiDAR sensor can map the scene, then try again."
        case .writeFailed(let detail):
            return "Could not write the scan file: \(detail)"
        }
    }
}

/// All captured mesh chunks merged into a single vertex/index list,
/// which every export format consumes.
private struct CombinedMesh {
    var vertices: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var colors: [SIMD3<UInt8>]?
    var indices: [UInt32] = []

    var triangleCount: Int { indices.count / 3 }

    init(_ meshes: [CapturedMesh]) {
        let hasColors = meshes.contains { $0.colors != nil }
        var mergedColors: [SIMD3<UInt8>] = []
        for mesh in meshes where !mesh.indices.isEmpty {
            let base = UInt32(vertices.count)
            vertices.append(contentsOf: mesh.vertices)
            normals.append(contentsOf: mesh.normals)
            if hasColors {
                mergedColors.append(contentsOf: mesh.colors
                    ?? Array(repeating: ColorProjector.fallbackColor, count: mesh.vertices.count))
            }
            indices.append(contentsOf: mesh.indices.map { $0 + base })
        }
        colors = hasColors ? mergedColors : nil
    }
}

/// Writes captured LiDAR meshes to standard 3D file formats.
/// OBJ and PLY are written directly (so per-vertex colors survive),
/// STL goes through ModelIO, and USDZ goes through SceneKit.
enum MeshExporter {
    static func export(meshes: [CapturedMesh], format: ExportFormat, to url: URL) throws {
        let combined = CombinedMesh(meshes)
        guard !combined.indices.isEmpty else {
            throw MeshExportError.nothingToExport
        }
        switch format {
        case .usdz:
            try exportUSDZ(combined, to: url)
        case .obj:
            try exportOBJ(combined, to: url)
        case .ply:
            try exportPLY(combined, to: url)
        case .stl:
            try exportSTL(combined, to: url)
        }
    }

    // MARK: - OBJ (text, optional vertex colors as the common "v x y z r g b" extension)

    private static func exportOBJ(_ mesh: CombinedMesh, to url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: url) else {
            throw MeshExportError.writeFailed("Could not open \(url.lastPathComponent) for writing.")
        }
        defer { try? handle.close() }

        var chunk = "# Exported by LidarScanner\no scan\n"
        func flush() throws {
            guard let data = chunk.data(using: .utf8) else {
                throw MeshExportError.writeFailed("Encoding failure.")
            }
            try handle.write(contentsOf: data)
            chunk = ""
        }

        for (index, vertex) in mesh.vertices.enumerated() {
            if let colors = mesh.colors {
                let color = colors[index]
                chunk += "v \(vertex.x) \(vertex.y) \(vertex.z) \(Float(color.x) / 255) \(Float(color.y) / 255) \(Float(color.z) / 255)\n"
            } else {
                chunk += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
            }
            if chunk.utf8.count > 1_000_000 { try flush() }
        }
        for normal in mesh.normals {
            chunk += "vn \(normal.x) \(normal.y) \(normal.z)\n"
            if chunk.utf8.count > 1_000_000 { try flush() }
        }
        var i = 0
        while i + 2 < mesh.indices.count {
            let a = mesh.indices[i] + 1
            let b = mesh.indices[i + 1] + 1
            let c = mesh.indices[i + 2] + 1
            chunk += "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n"
            if chunk.utf8.count > 1_000_000 { try flush() }
            i += 3
        }
        try flush()
    }

    // MARK: - PLY (binary little-endian, vertex colors when available)

    private static func exportPLY(_ mesh: CombinedMesh, to url: URL) throws {
        let hasColors = mesh.colors != nil
        var header = """
        ply
        format binary_little_endian 1.0
        comment Exported by LidarScanner
        element vertex \(mesh.vertices.count)
        property float x
        property float y
        property float z
        property float nx
        property float ny
        property float nz

        """
        if hasColors {
            header += """
            property uchar red
            property uchar green
            property uchar blue

            """
        }
        header += """
        element face \(mesh.triangleCount)
        property list uchar uint vertex_indices
        end_header

        """

        var data = Data(header.utf8)
        let vertexStride = 24 + (hasColors ? 3 : 0)
        data.reserveCapacity(data.count + mesh.vertices.count * vertexStride + mesh.triangleCount * 13)

        for (index, vertex) in mesh.vertices.enumerated() {
            let normal = mesh.normals[index]
            withUnsafeBytes(of: vertex.x) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: vertex.y) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: vertex.z) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: normal.x) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: normal.y) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: normal.z) { data.append(contentsOf: $0) }
            if let colors = mesh.colors {
                let color = colors[index]
                data.append(contentsOf: [color.x, color.y, color.z])
            }
        }

        var i = 0
        while i + 2 < mesh.indices.count {
            data.append(3)
            withUnsafeBytes(of: mesh.indices[i]) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: mesh.indices[i + 1]) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: mesh.indices[i + 2]) { data.append(contentsOf: $0) }
            i += 3
        }

        do {
            try data.write(to: url)
        } catch {
            throw MeshExportError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - STL (ModelIO, geometry only)

    private static func exportSTL(_ mesh: CombinedMesh, to url: URL) throws {
        let allocator = MDLMeshBufferDataAllocator()
        let asset = MDLAsset(bufferAllocator: allocator)

        let vertexData = mesh.vertices.withUnsafeBytes { Data($0) }
        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)

        let indexData = mesh.indices.withUnsafeBytes { Data($0) }
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: mesh.indices.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: nil
        )

        let descriptor = MDLVertexDescriptor()
        descriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)

        let mdlMesh = MDLMesh(
            vertexBuffer: vertexBuffer,
            vertexCount: mesh.vertices.count,
            descriptor: descriptor,
            submeshes: [submesh]
        )
        asset.add(mdlMesh)

        do {
            try asset.export(to: url)
        } catch {
            throw MeshExportError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - USDZ (SceneKit, vertex colors when available)

    private static func exportUSDZ(_ mesh: CombinedMesh, to url: URL) throws {
        let vertexSource = SCNGeometrySource(vertices: mesh.vertices.map {
            SCNVector3($0.x, $0.y, $0.z)
        })
        let normalSource = SCNGeometrySource(normals: mesh.normals.map {
            SCNVector3($0.x, $0.y, $0.z)
        })
        var sources = [vertexSource, normalSource]

        if let colors = mesh.colors {
            var components = [Float]()
            components.reserveCapacity(colors.count * 3)
            for color in colors {
                components.append(Float(color.x) / 255)
                components.append(Float(color.y) / 255)
                components.append(Float(color.z) / 255)
            }
            let colorData = components.withUnsafeBytes { Data($0) }
            sources.append(SCNGeometrySource(
                data: colorData,
                semantic: .color,
                vectorCount: colors.count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<Float>.size * 3
            ))
        }

        let element = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: sources, elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor.white
        material.roughness.contents = 0.9
        material.isDoubleSided = true
        geometry.firstMaterial = material

        let scene = SCNScene()
        scene.rootNode.addChildNode(SCNNode(geometry: geometry))

        let success = scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
        guard success else {
            throw MeshExportError.writeFailed("SceneKit failed to write the USDZ archive.")
        }
    }
}
