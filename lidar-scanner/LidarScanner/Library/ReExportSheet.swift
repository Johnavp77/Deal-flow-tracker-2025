import SwiftUI

/// Regenerates export files for a saved scan from its stored raw mesh,
/// with any format combination and detail level — no rescanning needed.
struct ReExportSheet: View {
    let record: ScanRecord
    var onUpdated: (ScanRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormats: Set<ExportFormat>
    @State private var quality: MeshQuality = .full
    @State private var isExporting = false
    @State private var errorMessage: String?

    init(record: ScanRecord, onUpdated: @escaping (ScanRecord) -> Void) {
        self.record = record
        self.onUpdated = onUpdated
        _selectedFormats = State(initialValue: Set(record.files.map(\.format)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Formats") {
                    ForEach(ExportFormat.allCases) { format in
                        Toggle(isOn: binding(for: format)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.displayName)
                                Text(format.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Picker("Mesh Detail", selection: $quality) {
                        ForEach(MeshQuality.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Mesh Detail")
                } footer: {
                    Text("Files are regenerated from the stored full-detail mesh (\(record.vertexCount.formatted()) vertices). Existing files of the same format are replaced.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        export()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                Text("Exporting…")
                                    .padding(.leading, 8)
                            } else {
                                Text("Re-export")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isExporting || selectedFormats.isEmpty)
                }
            }
            .navigationTitle("Re-export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isExporting)
                }
            }
            .interactiveDismissDisabled(isExporting)
        }
    }

    private func binding(for format: ExportFormat) -> Binding<Bool> {
        Binding(
            get: { selectedFormats.contains(format) },
            set: { isOn in
                if isOn {
                    selectedFormats.insert(format)
                } else {
                    selectedFormats.remove(format)
                }
            }
        )
    }

    private func export() {
        isExporting = true
        errorMessage = nil
        let formats = ExportFormat.allCases.filter { selectedFormats.contains($0) }
        let baseRecord = record
        let level = quality

        Task {
            do {
                let updated = try await Task.detached(priority: .userInitiated) { () throws -> ScanRecord in
                    let raw = try RawMesh.read(from: ScanArchiver.rawMeshURL(for: baseRecord))
                    let mesh = level.apply(to: raw)
                    let files = try ScanArchiver.exportFiles(from: mesh, record: baseRecord, formats: formats)
                    return try ScanArchiver.mergeFiles(files, into: baseRecord)
                }.value
                onUpdated(updated)
                isExporting = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isExporting = false
            }
        }
    }
}
