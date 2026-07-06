import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = StorageSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var toggleValue = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if settings.iCloudAvailable {
                        Toggle("Store scans in iCloud Drive", isOn: $toggleValue)
                            .disabled(settings.isMigrating)
                        if settings.isMigrating {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Moving scans…")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Label {
                            Text("iCloud Drive is unavailable. Sign in to iCloud on this device and make sure the app's iCloud capability is enabled in Xcode Signing & Capabilities.")
                        } icon: {
                            Image(systemName: "icloud.slash")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("When enabled, the whole scan library — meshes, exports, and metadata — lives in this app's iCloud Drive container, so scans sync to your other devices. Existing scans are moved when you flip the switch. Scans may need a moment to download on a device that hasn't synced yet.")
                }

                if let statusMessage {
                    Section {
                        Label(statusMessage, systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(settings.isMigrating)
                }
            }
            .onAppear {
                toggleValue = settings.useICloud
            }
            .onChange(of: toggleValue) {
                applyToggle()
            }
            .interactiveDismissDisabled(settings.isMigrating)
        }
    }

    private func applyToggle() {
        guard toggleValue != settings.useICloud else { return }
        statusMessage = nil
        errorMessage = nil
        let target = toggleValue
        Task {
            do {
                let moved = try await settings.setUseICloud(target)
                statusMessage = target
                    ? "Moved \(moved) scan\(moved == 1 ? "" : "s") to iCloud Drive."
                    : "Moved \(moved) scan\(moved == 1 ? "" : "s") back to this device."
            } catch {
                errorMessage = error.localizedDescription
                toggleValue = settings.useICloud
            }
        }
    }
}

#Preview {
    SettingsView()
}
