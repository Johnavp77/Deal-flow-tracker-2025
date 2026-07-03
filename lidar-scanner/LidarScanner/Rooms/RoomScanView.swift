import RoomPlan
import SwiftUI

struct RoomScanView: View {
    @StateObject private var controller = RoomScanController()
    @State private var showSaveSheet = false
    @State private var showSavedAlert = false
    @State private var savedRecord: ScanRecord?

    var body: some View {
        ZStack {
            RoomCaptureViewContainer(controller: controller)
                .ignoresSafeArea()

            VStack {
                Spacer()
                controls
                    .padding(.bottom, 24)
            }

            if let errorMessage = controller.errorMessage {
                VStack {
                    Text(errorMessage)
                        .font(.footnote)
                        .padding(12)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                        .padding()
                    Spacer()
                }
            }
        }
        .onAppear {
            controller.start()
        }
        .onDisappear {
            controller.stop()
        }
        .sheet(isPresented: $showSaveSheet) {
            RoomSaveSheet(controller: controller) { record in
                savedRecord = record
                showSavedAlert = true
            }
        }
        .alert("Room Saved", isPresented: $showSavedAlert, presenting: savedRecord) { _ in
            Button("OK") {}
        } message: { record in
            Text("\"\(record.name)\" was added to your Library.")
        }
    }

    @ViewBuilder
    private var controls: some View {
        if controller.isScanning {
            Button {
                controller.finish()
            } label: {
                Label("Done Scanning", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        } else if controller.processedRoom != nil {
            HStack(spacing: 14) {
                Button {
                    showSaveSheet = true
                } label: {
                    Label("Save to Library", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    controller.start()
                } label: {
                    Label("Rescan", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

private struct RoomCaptureViewContainer: UIViewRepresentable {
    let controller: RoomScanController

    func makeUIView(context: Context) -> RoomCaptureView {
        controller.captureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

private struct RoomSaveSheet: View {
    @ObservedObject var controller: RoomScanController
    var onSaved: (ScanRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Room Name") {
                    TextField("Name", text: $name)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button("Save USDZ to Library") {
                        save()
                    }
                    .bold()
                } footer: {
                    Text("Exports a parametric room model — walls, doors, windows, and detected furniture — as USDZ.")
                }
            }
            .navigationTitle("Save Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = "Room \(Date.now.formatted(date: .abbreviated, time: .shortened))"
                }
            }
        }
    }

    private func save() {
        do {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let record = try controller.save(name: trimmed.isEmpty ? "Untitled Room" : trimmed)
            dismiss()
            onSaved(record)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
