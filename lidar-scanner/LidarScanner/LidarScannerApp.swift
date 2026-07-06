import SwiftUI

@main
struct LidarScannerApp: App {
    init() {
        // Resolving the iCloud container can be slow on first access;
        // warm it off the main thread so scansDirectory never stalls UI.
        Task.detached(priority: .utility) {
            _ = ScanArchiver.ubiquityScansDirectory
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
