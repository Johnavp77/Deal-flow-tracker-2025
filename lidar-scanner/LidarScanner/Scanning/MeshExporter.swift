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
        case .stl: return "3D printing"
        case .ply: return "Point-cloud / research tools"
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

/// Writes captured LiDAR meshes to standard 3D file formats.
/// OBJ / STL / PLY go through ModelIO; USDZ goes through SceneKit,
/// which supports USDZ archive export on iOS.
enum MeshExporter {
    static func export(meshes: [CapturedMesh], format: ExportFormat, to url: URL) throws {
        guard !meshes.isEmpty, meshes.contains(where: { !$0.indices.isEmpty }) else {
            throw MeshExportError.nothingToExport
        }
        switch format {
        case .usdz:
            try exportUSDZ(meshes: meshes, to: url)
        case .obj, .stl, .ply:
            try exportWithModelIO(meshes: meshes, to: url)
        }
    }

    // MARK: - ModelIO (OBJ / STL / PLY)

    private static func exportWithModelIO(meshes: [CapturedMesh], to url: URL) throws {
        let allocator = MDLMeshBufferDataAllocator()
        let asset = MDLAsset(bufferAllocator: allocator)

        for mesh in meshes where !mesh.indices.isEmpty {
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
        }

        do {
            try asset.export(to: url)
        } catch {
            throw MeshExportError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - SceneKit (USDZ)

    private static func exportUSDZ(meshes: [CapturedMesh], to url: URL) throws {
        let scene = SCNScene()
        for mesh in meshes where !mesh.indices.isEmpty {
            let vertexSource = SCNGeometrySource(vertices: mesh.vertices.map {
                SCNVector3($0.x, $0.y, $0.z)
            })
            let normalSource = SCNGeometrySource(normals: mesh.normals.map {
                SCNVector3($0.x, $0.y, $0.z)
            })
            let element = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
            let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])

            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = UIColor(white: 0.78, alpha: 1)
            material.roughness.contents = 0.9
            material.isDoubleSided = true
            geometry.firstMaterial = material

            scene.rootNode.addChildNode(SCNNode(geometry: geometry))
        }

        let success = scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
        guard success else {
            throw MeshExportError.writeFailed("SceneKit failed to write the USDZ archive.")
        }
    }
}
