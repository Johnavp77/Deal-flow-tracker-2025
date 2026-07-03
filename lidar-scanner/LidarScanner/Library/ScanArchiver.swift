import Foundation
import RoomPlan
import UIKit

/// Writes scans to disk. Each scan lives in
/// Documents/Scans/<uuid>/ with its exported model files, an optional
/// thumbnail.png, and a metadata.json describing the scan.
/// All functions are thread-safe and may run off the main actor.
enum ScanArchiver {
    static var scansDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scans", isDirectory: true)
    }

    static func folderURL(for record: ScanRecord) -> URL {
        scansDirectory.appendingPathComponent(record.id.uuidString, isDirectory: true)
    }

    static func fileURL(for record: ScanRecord, file: ExportedFile) -> URL {
        folderURL(for: record).appendingPathComponent(file.fileName)
    }

    static func thumbnailURL(for record: ScanRecord) -> URL {
        folderURL(for: record).appendingPathComponent("thumbnail.png")
    }

    // MARK: - Persisting

    static func persistMeshes(
        _ meshes: [CapturedMesh],
        name: String,
        formats: [ExportFormat],
        thumbnail: UIImage?
    ) throws -> ScanRecord {
        let id = UUID()
        let folder = try createFolder(id: id)
        let baseName = sanitizedFileName(from: name)

        var files: [ExportedFile] = []
        for format in formats {
            let fileName = "\(baseName).\(format.fileExtension)"
            let url = folder.appendingPathComponent(fileName)
            try MeshExporter.export(meshes: meshes, format: format, to: url)
            files.append(ExportedFile(format: format, fileName: fileName, sizeBytes: fileSize(at: url)))
        }

        if let data = thumbnail?.pngData() {
            try? data.write(to: folder.appendingPathComponent("thumbnail.png"))
        }

        let record = ScanRecord(
            id: id,
            name: name,
            createdAt: Date(),
            kind: .lidar,
            files: files,
            vertexCount: meshes.reduce(0) { $0 + $1.vertices.count },
            faceCount: meshes.reduce(0) { $0 + $1.triangleCount }
        )
        try writeMetadata(record, in: folder)
        return record
    }

    static func persistRoom(_ room: CapturedRoom, name: String) throws -> ScanRecord {
        let id = UUID()
        let folder = try createFolder(id: id)
        let baseName = sanitizedFileName(from: name)

        let fileName = "\(baseName).usdz"
        let url = folder.appendingPathComponent(fileName)
        try room.export(to: url, exportOptions: .parametric)

        let record = ScanRecord(
            id: id,
            name: name,
            createdAt: Date(),
            kind: .room,
            files: [ExportedFile(format: .usdz, fileName: fileName, sizeBytes: fileSize(at: url))],
            vertexCount: 0,
            faceCount: 0
        )
        try writeMetadata(record, in: folder)
        return record
    }

    static func delete(_ record: ScanRecord) {
        try? FileManager.default.removeItem(at: folderURL(for: record))
    }

    // MARK: - Loading

    static func loadAll() -> [ScanRecord] {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: scansDirectory, withIntermediateDirectories: true)
        guard let folders = try? fileManager.contentsOfDirectory(
            at: scansDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        var records: [ScanRecord] = []
        for folder in folders {
            let metadataURL = folder.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataURL),
                  let record = try? JSONDecoder().decode(ScanRecord.self, from: data) else {
                continue
            }
            records.append(record)
        }
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Helpers

    private static func createFolder(id: UUID) throws -> URL {
        let folder = scansDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func writeMetadata(_ record: ScanRecord, in folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(record)
        try data.write(to: folder.appendingPathComponent("metadata.json"))
    }

    private static func sanitizedFileName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Scan" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return base
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? Int64) ?? 0
    }
}
