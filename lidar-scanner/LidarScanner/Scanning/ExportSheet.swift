import SwiftUI

struct ExportSheet: View {
    @ObservedObject var controller: ScanSessionController
    var onSaved: (ScanRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedFormats: Set<ExportFormat> = [.usdz, .obj]
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Scan Name") {
                    TextField("Name", text: $name)
                }

                Section {
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
                } header: {
                    Text("Export Formats")
                } footer: {
                    Text("Mesh chunks captured: \(controller.meshAnchorCount)")
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
                                Text("Processing mesh…")
                                    .padding(.leading, 8)
                            } else {
                                Text("Export & Save to Library")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isExporting || selectedFormats.isEmpty)
                }
            }
            .navigationTitle("Finish Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Scanning") { dismiss() }
                        .disabled(isExporting)
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = "Scan \(Date.now.formatted(date: .abbreviated, time: .shortened))"
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
        let scanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let record = try await controller.finishScan(
                    name: scanName.isEmpty ? "Untitled Scan" : scanName,
                    formats: formats
                )
                isExporting = false
                dismiss()
                onSaved(record)
            } catch {
                isExporting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
