import SwiftUI

struct ScanDetailView: View {
    @State private var record: ScanRecord

    @ObservedObject private var store = ScanStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showCrop = false
    @State private var showReExport = false
    @State private var showResume = false

    init(record: ScanRecord) {
        _record = State(initialValue: record)
    }

    private var hasRawMesh: Bool {
        ScanArchiver.hasRawMesh(record)
    }

    private var canResume: Bool {
        hasRawMesh && ScanArchiver.hasWorldMap(record) && DeviceSupport.supportsLidarScanning
    }

    private var previewURL: URL? {
        guard let usdz = record.files.first(where: { $0.format == .usdz }) else { return nil }
        let url = ScanArchiver.fileURL(for: record, file: usdz)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var body: some View {
        List {
            if let previewURL {
                Section {
                    ModelPreviewView(url: previewURL)
                        .id(record)
                        .frame(height: 380)
                        .listRowInsets(EdgeInsets())
                }
            }

            if hasRawMesh {
                Section("Edit") {
                    if canResume {
                        Button {
                            showResume = true
                        } label: {
                            Label("Resume Scan", systemImage: "arrow.triangle.2.circlepath.camera")
                        }
                    }
                    Button {
                        showCrop = true
                    } label: {
                        Label("Crop Model", systemImage: "crop")
                    }
                    Button {
                        showReExport = true
                    } label: {
                        Label("Re-export Files", systemImage: "square.and.arrow.up.on.square")
                    }
                }
            }

            Section("Details") {
                LabeledContent("Type", value: record.kind.displayName)
                LabeledContent("Captured", value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
                if record.vertexCount > 0 {
                    LabeledContent("Vertices", value: record.vertexCount.formatted())
                    LabeledContent("Triangles", value: record.faceCount.formatted())
                }
                if let area = record.surfaceAreaSquareMeters, area > 0 {
                    LabeledContent("Surface Area", value: String(format: "%.2f m²", area))
                }
                if let volume = record.volumeCubicMeters, volume > 0 {
                    LabeledContent(
                        "Volume (approx.)",
                        value: volume < 1
                            ? String(format: "%.3f m³", volume)
                            : String(format: "%.2f m³", volume)
                    )
                }
            }

            Section("Files") {
                ForEach(record.files) { file in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(file.sizeBytes, format: .byteCount(style: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ShareLink(item: ScanArchiver.fileURL(for: record, file: file)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }

            Section {
                Button("Delete Scan", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(record.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCrop) {
            CropView(record: record) { updated in
                record = updated
                store.insert(updated)
            }
        }
        .sheet(isPresented: $showReExport) {
            ReExportSheet(record: record) { updated in
                record = updated
                store.insert(updated)
            }
        }
        .fullScreenCover(isPresented: $showResume) {
            ResumeScanView(record: record) { updated in
                record = updated
            }
        }
        .confirmationDialog(
            "Delete this scan and all of its exported files?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.delete(record)
                dismiss()
            }
        }
    }
}
