import Foundation
import RoomPlan
import UIKit

/// Writes scans to disk. Each scan lives in
/// Documents/Scans/<uuid>/ with its exported model files, an optional
/// thumbnail.png, and a metadata.json describing the scan.
/// All functions are thread-safe and may run off the main actor.
enum ScanArchiver {
    static let useICloudDefaultsKey = "useICloudStorage"

    static var localScansDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scans", isDirectory: true)
    }

    /// Resolved once per launch; the first access can be slow, so the app
    /// warms it on a background task at startup.
    static let ubiquityScansDirectory: URL? = FileManager.default
        .url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents", isDirectory: true)
        .appendingPathComponent("Scans", isDirectory: true)

    static var scansDirectory: URL {
        if UserDefaults.standard.bool(forKey: useICloudDefaultsKey),
           let cloud = ubiquityScansDirectory {
            return cloud
        }
        return localScansDirectory
    }

    /// Moves every scan folder between local storage and the iCloud
    /// container, returning how many were moved. Runs off the main thread.
    static func migrateScans(toICloud: Bool) throws -> Int {
        guard let cloud = ubiquityScansDirectory else {
            throw MeshExportError.writeFailed("iCloud Drive is not available. Sign in to iCloud and enable iCloud Drive for this app.")
        }
        let fileManager = FileManager.default
        let source = toICloud ? localScansDirectory : cloud
        let destination = toICloud ? cloud : localScansDirectory
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        guard let items = try? fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return 0
        }

        var moved = 0
        for item in items {
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let target = destination.appendingPathComponent(item.lastPathComponent, isDirectory: true)
            guard !fileManager.fileExists(atPath: target.path) else { continue }
            try fileManager.setUbiquitous(toICloud, itemAt: item, destinationURL: target)
            moved += 1
        }
        return moved
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

    /// The full-detail captured mesh, kept so crops and re-exports can
    /// run after capture. Only LiDAR-mode scans have one.
    static func rawMeshURL(for record: ScanRecord) -> URL {
        folderURL(for: record).appendingPathComponent("mesh.bin")
    }

    static func hasRawMesh(_ record: ScanRecord) -> Bool {
        FileManager.default.fileExists(atPath: rawMeshURL(for: record).path)
    }

    /// Saved ARKit world map, enabling scan resume with relocalization.
    static func worldMapURL(for record: ScanRecord) -> URL {
        folderURL(for: record).appendingPathComponent("worldmap.bin")
    }

    static func hasWorldMap(_ record: ScanRecord) -> Bool {
        FileManager.default.fileExists(atPath: worldMapURL(for: record).path)
    }

    static func saveThumbnail(_ image: UIImage, for record: ScanRecord) {
        if let data = image.pngData() {
            try? data.write(to: thumbnailURL(for: record))
        }
    }

    // MARK: - Persisting

    static func persistMeshes(
        _ meshes: [CapturedMesh],
        name: String,
        formats: [ExportFormat],
        quality: MeshQuality,
        thumbnail: UIImage?,
        worldMapData: Data? = nil
    ) throws -> ScanRecord {
        let rawMesh = RawMesh(merging: meshes)
        guard !rawMesh.indices.isEmpty else { throw MeshExportError.nothingToExport }

        let id = UUID()
        let folder = try createFolder(id: id)

        // Always keep the full-detail mesh; exports may be decimated.
        try rawMesh.write(to: folder.appendingPathComponent("mesh.bin"))

        if let data = thumbnail?.pngData() {
            try? data.write(to: folder.appendingPathComponent("thumbnail.png"))
        }
        if let worldMapData {
            try? worldMapData.write(to: folder.appendingPathComponent("worldmap.bin"))
        }

        var record = ScanRecord(
            id: id,
            name: name,
            createdAt: Date(),
            kind: .lidar,
            files: [],
            vertexCount: rawMesh.vertices.count,
            faceCount: rawMesh.triangleCount,
            surfaceAreaSquareMeters: rawMesh.surfaceArea(),
            volumeCubicMeters: rawMesh.approximateVolume()
        )
        record.files = try exportFiles(from: quality.apply(to: rawMesh), record: record, formats: formats)
        try writeMetadata(record, in: folder)
        return record
    }

    /// Writes the given formats from a mesh into the record's folder,
    /// overwriting files of the same format.
    static func exportFiles(
        from mesh: RawMesh,
        record: ScanRecord,
        formats: [ExportFormat]
    ) throws -> [ExportedFile] {
        let folder = folderURL(for: record)
        let baseName = sanitizedFileName(from: record.name)
        return try formats.map { format in
            let fileName = "\(baseName).\(format.fileExtension)"
            let url = folder.appendingPathComponent(fileName)
            try MeshExporter.export(mesh: mesh, format: format, to: url)
            return ExportedFile(format: format, fileName: fileName, sizeBytes: fileSize(at: url))
        }
    }

    /// Replaces same-format entries in the record's file list with the
    /// newly written ones and persists the updated metadata.
    static func mergeFiles(_ newFiles: [ExportedFile], into record: ScanRecord) throws -> ScanRecord {
        var updated = record
        for file in newFiles {
            updated.files.removeAll { $0.format == file.format }
            updated.files.append(file)
        }
        updated.files.sort { $0.fileName < $1.fileName }
        try saveMetadata(updated)
        return updated
    }

    static func saveMetadata(_ record: ScanRecord) throws {
        try writeMetadata(record, in: folderURL(for: record))
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

    /// Copies an already-built model file (e.g. a photogrammetry USDZ)
    /// into the library as a new scan.
    static func persistModelFile(at sourceURL: URL, name: String, kind: ScanRecord.Kind) throws -> ScanRecord {
        let id = UUID()
        let folder = try createFolder(id: id)
        let fileName = "\(sanitizedFileName(from: name)).\(sourceURL.pathExtension.isEmpty ? "usdz" : sourceURL.pathExtension)"
        let destination = folder.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let record = ScanRecord(
            id: id,
            name: name,
            createdAt: Date(),
            kind: kind,
            files: [ExportedFile(format: .usdz, fileName: fileName, sizeBytes: fileSize(at: destination))],
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
                // Likely an iCloud folder that hasn't downloaded yet —
                // kick off a download so it appears on a later reload.
                try? fileManager.startDownloadingUbiquitousItem(at: folder)
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
