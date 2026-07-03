import Foundation

struct ExportedFile: Codable, Hashable, Identifiable {
    var format: ExportFormat
    var fileName: String
    var sizeBytes: Int64

    var id: String { fileName }
}

struct ScanRecord: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case lidar
        case room
        case photo

        var displayName: String {
            switch self {
            case .lidar: return "LiDAR Mesh"
            case .room: return "Room Plan"
            case .photo: return "Photo Mode"
            }
        }
    }

    let id: UUID
    var name: String
    var createdAt: Date
    var kind: Kind
    var files: [ExportedFile]
    var vertexCount: Int
    var faceCount: Int
}
