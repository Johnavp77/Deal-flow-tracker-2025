import ARKit
import simd

/// A plain, world-space copy of one ARMeshAnchor's geometry.
/// Extracting into value types up front lets export run off the main
/// thread after the AR session has been paused.
struct CapturedMesh {
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let indices: [UInt32]
    /// Per-vertex RGB, filled in by ColorProjector when color capture is on.
    var colors: [SIMD3<UInt8>]?

    var triangleCount: Int { indices.count / 3 }

    init(anchor: ARMeshAnchor) {
        let geometry = anchor.geometry
        let transform = anchor.transform
        // Rotation-only part of the anchor transform, for normals.
        let rotation = simd_float3x3(
            SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )

        let vertexCount = geometry.vertices.count
        var worldVertices = [SIMD3<Float>]()
        var worldNormals = [SIMD3<Float>]()
        worldVertices.reserveCapacity(vertexCount)
        worldNormals.reserveCapacity(vertexCount)

        for index in 0..<vertexCount {
            let local = geometry.vertexPosition(at: index)
            let world = transform * SIMD4<Float>(local.x, local.y, local.z, 1)
            worldVertices.append(SIMD3<Float>(world.x, world.y, world.z))

            let normal = geometry.vertexNormal(at: index)
            worldNormals.append(simd_normalize(rotation * normal))
        }

        let faces = geometry.faces
        let indexCount = faces.count * faces.indexCountPerPrimitive
        var faceIndices = [UInt32]()
        if faces.bytesPerIndex == MemoryLayout<UInt32>.size {
            let pointer = faces.buffer.contents().bindMemory(to: UInt32.self, capacity: indexCount)
            faceIndices = Array(UnsafeBufferPointer(start: pointer, count: indexCount))
        } else if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
            let pointer = faces.buffer.contents().bindMemory(to: UInt16.self, capacity: indexCount)
            faceIndices = UnsafeBufferPointer(start: pointer, count: indexCount).map(UInt32.init)
        }

        vertices = worldVertices
        normals = worldNormals
        indices = faceIndices
    }
}

private extension ARMeshGeometry {
    func vertexPosition(at index: Int) -> SIMD3<Float> {
        let source = vertices
        let pointer = source.buffer.contents()
            .advanced(by: source.offset + index * source.stride)
            .assumingMemoryBound(to: Float.self)
        return SIMD3<Float>(pointer[0], pointer[1], pointer[2])
    }

    func vertexNormal(at index: Int) -> SIMD3<Float> {
        let source = normals
        let pointer = source.buffer.contents()
            .advanced(by: source.offset + index * source.stride)
            .assumingMemoryBound(to: Float.self)
        return SIMD3<Float>(pointer[0], pointer[1], pointer[2])
    }
}
