import Foundation
import simd

/// Level-of-detail options applied at export time. The full-detail
/// mesh is always kept on disk so exports can be regenerated later.
enum MeshQuality: String, CaseIterable, Identifiable {
    case full
    case high
    case medium
    case low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full: return "Full"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    /// Approximate fraction of the original vertex count to keep.
    var fraction: Double {
        switch self {
        case .full: return 1
        case .high: return 0.5
        case .medium: return 0.25
        case .low: return 0.1
        }
    }

    func apply(to mesh: RawMesh) -> RawMesh {
        guard self != .full else { return mesh }
        let target = max(1_000, Int(Double(mesh.vertices.count) * fraction))
        return mesh.decimated(targetVertexCount: target)
    }
}

/// A single merged, world-space triangle mesh — the canonical form every
/// scan is stored and processed in. Persisted per scan as `mesh.bin` so
/// crops, decimation, and re-exports can run long after capture.
struct RawMesh {
    var vertices: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var colors: [SIMD3<UInt8>]?
    var indices: [UInt32]

    var triangleCount: Int { indices.count / 3 }

    init(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        colors: [SIMD3<UInt8>]?,
        indices: [UInt32]
    ) {
        self.vertices = vertices
        self.normals = normals
        self.colors = colors
        self.indices = indices
    }

    init(merging meshes: [CapturedMesh]) {
        let hasColors = meshes.contains { $0.colors != nil }
        var mergedVertices: [SIMD3<Float>] = []
        var mergedNormals: [SIMD3<Float>] = []
        var mergedColors: [SIMD3<UInt8>] = []
        var mergedIndices: [UInt32] = []

        for mesh in meshes where !mesh.indices.isEmpty {
            let base = UInt32(mergedVertices.count)
            mergedVertices.append(contentsOf: mesh.vertices)
            mergedNormals.append(contentsOf: mesh.normals)
            if hasColors {
                mergedColors.append(contentsOf: mesh.colors
                    ?? Array(repeating: ColorProjector.fallbackColor, count: mesh.vertices.count))
            }
            mergedIndices.append(contentsOf: mesh.indices.map { $0 + base })
        }

        vertices = mergedVertices
        normals = mergedNormals
        colors = hasColors ? mergedColors : nil
        indices = mergedIndices
    }

    func bounds() -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard var minBound = vertices.first else {
            return (.zero, .zero)
        }
        var maxBound = minBound
        for vertex in vertices {
            minBound = simd_min(minBound, vertex)
            maxBound = simd_max(maxBound, vertex)
        }
        return (minBound, maxBound)
    }
}

// MARK: - Binary persistence

extension RawMesh {
    private static let magic: UInt32 = 0x4C_53_4D_31 // "LSM1"
    private static let version: UInt32 = 1

    enum IOError: LocalizedError {
        case corrupt

        var errorDescription: String? {
            "The stored mesh file is missing or damaged."
        }
    }

    func write(to url: URL) throws {
        var data = Data()
        let colorBytes = colors != nil ? vertices.count * MemoryLayout<SIMD3<UInt8>>.stride : 0
        data.reserveCapacity(
            20
                + vertices.count * MemoryLayout<SIMD3<Float>>.stride * 2
                + colorBytes
                + indices.count * MemoryLayout<UInt32>.stride
        )

        func append<T>(_ value: T) {
            withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
        }
        append(Self.magic)
        append(Self.version)
        append(UInt32(colors != nil ? 1 : 0))
        append(UInt32(vertices.count))
        append(UInt32(indices.count))

        vertices.withUnsafeBytes { data.append(contentsOf: $0) }
        normals.withUnsafeBytes { data.append(contentsOf: $0) }
        if let colors {
            colors.withUnsafeBytes { data.append(contentsOf: $0) }
        }
        indices.withUnsafeBytes { data.append(contentsOf: $0) }

        try data.write(to: url, options: .atomic)
    }

    static func read(from url: URL) throws -> RawMesh {
        let data = try Data(contentsOf: url)
        var offset = 0

        func readValue<T>(_ type: T.Type) throws -> T {
            let size = MemoryLayout<T>.size
            guard offset + size <= data.count else { throw IOError.corrupt }
            defer { offset += size }
            return data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
        }

        func readArray<T>(_ type: T.Type, count: Int) throws -> [T] {
            let byteCount = MemoryLayout<T>.stride * count
            guard count >= 0, offset + byteCount <= data.count else { throw IOError.corrupt }
            defer { offset += byteCount }
            return [T](unsafeUninitializedCapacity: count) { buffer, initialized in
                _ = data.copyBytes(to: buffer, from: offset..<(offset + byteCount))
                initialized = count
            }
        }

        guard try readValue(UInt32.self) == magic,
              try readValue(UInt32.self) == version else {
            throw IOError.corrupt
        }
        let hasColors = try readValue(UInt32.self) == 1
        let vertexCount = Int(try readValue(UInt32.self))
        let indexCount = Int(try readValue(UInt32.self))

        let vertices = try readArray(SIMD3<Float>.self, count: vertexCount)
        let normals = try readArray(SIMD3<Float>.self, count: vertexCount)
        let colors = hasColors ? try readArray(SIMD3<UInt8>.self, count: vertexCount) : nil
        let indices = try readArray(UInt32.self, count: indexCount)

        guard indices.allSatisfy({ Int($0) < vertexCount }) else { throw IOError.corrupt }
        return RawMesh(vertices: vertices, normals: normals, colors: colors, indices: indices)
    }
}

// MARK: - Crop

extension RawMesh {
    /// Returns a copy containing only triangles whose vertices all lie
    /// inside the given axis-aligned box, with unused vertices compacted away.
    func cropped(minBound: SIMD3<Float>, maxBound: SIMD3<Float>) -> RawMesh {
        let lower = simd_min(minBound, maxBound)
        let upper = simd_max(minBound, maxBound)

        var inside = [Bool](repeating: false, count: vertices.count)
        for index in 0..<vertices.count {
            let v = vertices[index]
            inside[index] = v.x >= lower.x && v.x <= upper.x
                && v.y >= lower.y && v.y <= upper.y
                && v.z >= lower.z && v.z <= upper.z
        }

        var used = [Bool](repeating: false, count: vertices.count)
        var keptIndices = [UInt32]()
        keptIndices.reserveCapacity(indices.count)
        var i = 0
        while i + 2 < indices.count {
            let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
            if inside[a], inside[b], inside[c] {
                keptIndices.append(indices[i])
                keptIndices.append(indices[i + 1])
                keptIndices.append(indices[i + 2])
                used[a] = true
                used[b] = true
                used[c] = true
            }
            i += 3
        }

        var remap = [UInt32](repeating: 0, count: vertices.count)
        var newVertices = [SIMD3<Float>]()
        var newNormals = [SIMD3<Float>]()
        var newColors: [SIMD3<UInt8>]? = colors != nil ? [] : nil
        for index in 0..<vertices.count where used[index] {
            remap[index] = UInt32(newVertices.count)
            newVertices.append(vertices[index])
            newNormals.append(normals[index])
            if let colors {
                newColors?.append(colors[index])
            }
        }

        return RawMesh(
            vertices: newVertices,
            normals: newNormals,
            colors: newColors,
            indices: keptIndices.map { remap[Int($0)] }
        )
    }
}

// MARK: - Decimation (vertex clustering)

extension RawMesh {
    /// Reduces the mesh toward the target vertex count by snapping
    /// vertices to a uniform spatial grid and merging each cell.
    /// Cell size is binary-searched to approach the target.
    func decimated(targetVertexCount: Int) -> RawMesh {
        guard targetVertexCount > 0, vertices.count > targetVertexCount else { return self }
        let (minBound, maxBound) = bounds()
        let diagonal = simd_length(maxBound - minBound)
        guard diagonal > 0 else { return self }

        var fine = diagonal / 4096
        var coarse = diagonal / 4
        var chosen = coarse
        for _ in 0..<8 {
            let mid = (fine + coarse) / 2
            if clusterCount(cellSize: mid, minBound: minBound) > targetVertexCount {
                fine = mid
            } else {
                coarse = mid
                chosen = mid
            }
        }
        return clustered(cellSize: chosen, minBound: minBound)
    }

    private func cellKey(_ point: SIMD3<Float>, cellSize: Float, minBound: SIMD3<Float>) -> Int64 {
        let q = (point - minBound) / cellSize
        let limit = 1_048_575 // 2^20 - 1 per axis
        let x = Int64(max(0, min(limit, Int(q.x))))
        let y = Int64(max(0, min(limit, Int(q.y))))
        let z = Int64(max(0, min(limit, Int(q.z))))
        return x | (y << 20) | (z << 40)
    }

    private func clusterCount(cellSize: Float, minBound: SIMD3<Float>) -> Int {
        var cells = Set<Int64>()
        cells.reserveCapacity(min(vertices.count, 1 << 18))
        for vertex in vertices {
            cells.insert(cellKey(vertex, cellSize: cellSize, minBound: minBound))
        }
        return cells.count
    }

    private func clustered(cellSize: Float, minBound: SIMD3<Float>) -> RawMesh {
        let hasColors = colors != nil
        var cellToIndex = [Int64: Int]()
        cellToIndex.reserveCapacity(vertices.count / 4)
        var positionSums = [SIMD3<Float>]()
        var normalSums = [SIMD3<Float>]()
        var colorSums = [SIMD3<Float>]()
        var counts = [Int]()
        var remap = [UInt32](repeating: 0, count: vertices.count)

        for index in 0..<vertices.count {
            let key = cellKey(vertices[index], cellSize: cellSize, minBound: minBound)
            let cluster: Int
            if let existing = cellToIndex[key] {
                cluster = existing
                positionSums[cluster] += vertices[index]
                normalSums[cluster] += normals[index]
                if hasColors, let color = colors?[index] {
                    colorSums[cluster] += SIMD3<Float>(Float(color.x), Float(color.y), Float(color.z))
                }
                counts[cluster] += 1
            } else {
                cluster = positionSums.count
                cellToIndex[key] = cluster
                positionSums.append(vertices[index])
                normalSums.append(normals[index])
                if hasColors, let color = colors?[index] {
                    colorSums.append(SIMD3<Float>(Float(color.x), Float(color.y), Float(color.z)))
                }
                counts.append(1)
            }
            remap[index] = UInt32(cluster)
        }

        var newVertices = [SIMD3<Float>]()
        var newNormals = [SIMD3<Float>]()
        newVertices.reserveCapacity(positionSums.count)
        newNormals.reserveCapacity(positionSums.count)
        for cluster in 0..<positionSums.count {
            let count = Float(counts[cluster])
            newVertices.append(positionSums[cluster] / count)
            let normal = normalSums[cluster]
            let length = simd_length(normal)
            newNormals.append(length > 0 ? normal / length : SIMD3<Float>(0, 1, 0))
        }

        var newColors: [SIMD3<UInt8>]?
        if hasColors {
            newColors = (0..<colorSums.count).map { cluster in
                let averaged = colorSums[cluster] / Float(counts[cluster])
                return SIMD3<UInt8>(
                    UInt8(max(0, min(255, averaged.x.rounded()))),
                    UInt8(max(0, min(255, averaged.y.rounded()))),
                    UInt8(max(0, min(255, averaged.z.rounded())))
                )
            }
        }

        var newIndices = [UInt32]()
        newIndices.reserveCapacity(indices.count)
        var i = 0
        while i + 2 < indices.count {
            let a = remap[Int(indices[i])]
            let b = remap[Int(indices[i + 1])]
            let c = remap[Int(indices[i + 2])]
            if a != b, b != c, a != c {
                newIndices.append(a)
                newIndices.append(b)
                newIndices.append(c)
            }
            i += 3
        }

        return RawMesh(
            vertices: newVertices,
            normals: newNormals,
            colors: newColors,
            indices: newIndices
        )
    }
}
