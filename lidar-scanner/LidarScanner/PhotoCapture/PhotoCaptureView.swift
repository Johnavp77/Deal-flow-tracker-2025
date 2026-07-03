import RealityKit
import SwiftUI

struct PhotoCaptureView: View {
    @StateObject private var controller = PhotoCaptureController()
    @State private var showSaveSheet = false
    @State private var showSavedAlert = false
    @State private var savedRecord: ScanRecord?

    var body: some View {
        ZStack {
            if let session = controller.session {
                ObjectCaptureView(session: session)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    captureControls
                        .padding(.bottom, 24)
                }
            } else if case .reconstructing(let progress) = controller.phase {
                reconstructionView(progress: progress)
            } else if let modelURL = controller.completedModelURL {
                resultView(modelURL: modelURL)
            } else {
                idleOverlay
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            PhotoSaveSheet(controller: controller) { record in
                savedRecord = record
                showSavedAlert = true
            }
        }
        .alert("Model Saved", isPresented: $showSavedAlert, presenting: savedRecord) { _ in
            Button("OK") {}
        } message: { record in
            Text("\"\(record.name)\" was added to your Library.")
        }
        .onDisappear {
            controller.handleDisappear()
        }
    }

    // MARK: - Capture controls

    @ViewBuilder
    private var captureControls: some View {
        switch controller.sessionState {
        case .ready:
            VStack(spacing: 10) {
                hint("Point the camera at a small object on a flat surface")
                prominentButton("Continue", systemImage: "arrow.right.circle.fill") {
                    controller.continueToDetection()
                }
            }
        case .detecting:
            VStack(spacing: 10) {
                hint("Adjust the selection box around the object")
                prominentButton("Start Capturing", systemImage: "camera.circle.fill") {
                    controller.startCapturing()
                }
            }
        case .capturing:
            VStack(spacing: 10) {
                hint("Move slowly around the object until the ring fills")
                HStack(spacing: 14) {
                    prominentButton("Finish", systemImage: "checkmark.circle.fill") {
                        controller.finishCapture()
                    }
                    Button("Cancel", role: .destructive) {
                        controller.cancel()
                    }
                    .buttonStyle(.bordered)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
        case .finishing:
            ProgressView("Finishing capture…")
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        default:
            EmptyView()
        }
    }

    // MARK: - Reconstruction

    private func reconstructionView(progress: Double) -> some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 280)
            Text("Reconstructing 3D model… \(Int(progress * 100))%")
                .font(.headline)
            Text("Keep the app open. Photogrammetry runs entirely on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }

    // MARK: - Result

    private func resultView(modelURL: URL) -> some View {
        ZStack {
            ModelPreviewView(url: modelURL)
                .ignoresSafeArea(edges: .horizontal)
            VStack {
                Spacer()
                HStack(spacing: 14) {
                    prominentButton("Save to Library", systemImage: "square.and.arrow.down") {
                        showSaveSheet = true
                    }
                    Button("Discard", role: .destructive) {
                        controller.discardResult()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Idle

    private var idleOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color(.systemTeal).opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                Text("Photo Mode")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Capture a small object by walking around it while the app takes photos, then reconstruct a textured 3D model with on-device photogrammetry.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if case .failed(let message) = controller.phase {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 24)
                }

                prominentButton("Start Photo Capture", systemImage: "camera.fill") {
                    controller.start()
                }
            }
        }
    }

    // MARK: - Shared bits

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func prominentButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct PhotoSaveSheet: View {
    @ObservedObject var controller: PhotoCaptureController
    var onSaved: (ScanRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Model Name") {
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
                    Text("Saves the reconstructed, textured USDZ model.")
                }
            }
            .navigationTitle("Save Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = "Object \(Date.now.formatted(date: .abbreviated, time: .shortened))"
                }
            }
        }
    }

    private func save() {
        do {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let record = try controller.save(name: trimmed.isEmpty ? "Untitled Object" : trimmed)
            dismiss()
            onSaved(record)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
