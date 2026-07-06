import ARKit
import SwiftUI

/// Continues a previously saved scan: the stored ARWorldMap is loaded so
/// ARKit relocalizes into the original coordinate space, and on finish
/// the new geometry is merged into the scan's stored mesh.
struct ResumeScanView: View {
    let record: ScanRecord
    var onUpdated: (ScanRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = ScanSessionController()
    @State private var isStarting = true
    @State private var isFinishing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ARViewContainer(controller: controller)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                statusHUD
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .padding(10)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                Spacer()
                controls
            }
            .padding()

            if isStarting {
                ProgressView("Loading saved scan…")
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task { await start() }
        .onDisappear { controller.pauseIfScanning() }
        .interactiveDismissDisabled(isFinishing)
    }

    private var statusHUD: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Label("\(controller.meshAnchorCount)", systemImage: "square.grid.3x3.topleft.filled")
                Divider().frame(height: 14)
                Text(controller.trackingStatus)
            }
            .font(.footnote.monospacedDigit())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Text("Return to the area you scanned before so tracking can relocalize, then extend the scan.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button("Cancel", role: .cancel) {
                controller.pauseIfScanning()
                dismiss()
            }
            .buttonStyle(.bordered)
            .background(.ultraThinMaterial, in: Capsule())
            .disabled(isFinishing)

            Button {
                finish()
            } label: {
                if isFinishing {
                    ProgressView()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                } else {
                    Label("Finish & Merge", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isStarting || isFinishing || controller.meshAnchorCount == 0)
        }
    }

    private func start() async {
        let url = ScanArchiver.worldMapURL(for: record)
        do {
            let worldMap = try await Task.detached(priority: .userInitiated) { () throws -> ARWorldMap in
                let data = try Data(contentsOf: url)
                guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                    throw MeshExportError.writeFailed("The saved tracking map could not be read.")
                }
                return map
            }.value
            controller.startScan(resumingFrom: worldMap)
        } catch {
            errorMessage = "Could not load the saved session: \(error.localizedDescription)"
        }
        isStarting = false
    }

    private func finish() {
        isFinishing = true
        errorMessage = nil
        Task {
            do {
                let updated = try await controller.finishResumedScan(into: record)
                onUpdated(updated)
                isFinishing = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isFinishing = false
            }
        }
    }
}
