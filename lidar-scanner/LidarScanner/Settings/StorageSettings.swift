import Combine
import Foundation

/// Controls where the scan library lives: on-device Documents or the
/// app's iCloud Drive container. Switching migrates existing scans.
@MainActor
final class StorageSettings: ObservableObject {
    static let shared = StorageSettings()

    @Published private(set) var useICloud: Bool
    @Published private(set) var isMigrating = false

    var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
            && ScanArchiver.ubiquityScansDirectory != nil
    }

    private init() {
        useICloud = UserDefaults.standard.bool(forKey: ScanArchiver.useICloudDefaultsKey)
    }

    /// Moves all scans to the requested location and flips the setting.
    /// Returns the number of scan folders moved.
    @discardableResult
    func setUseICloud(_ enabled: Bool) async throws -> Int {
        guard enabled != useICloud else { return 0 }
        isMigrating = true
        defer { isMigrating = false }

        let moved = try await Task.detached(priority: .userInitiated) {
            try ScanArchiver.migrateScans(toICloud: enabled)
        }.value

        UserDefaults.standard.set(enabled, forKey: ScanArchiver.useICloudDefaultsKey)
        useICloud = enabled
        ScanStore.shared.reload()
        return moved
    }
}
