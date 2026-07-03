import Combine
import Foundation

/// In-memory catalog of saved scans, backed by the folders that
/// ScanArchiver writes under Documents/Scans.
@MainActor
final class ScanStore: ObservableObject {
    static let shared = ScanStore()

    @Published private(set) var scans: [ScanRecord] = []

    private init() {
        reload()
    }

    func reload() {
        scans = ScanArchiver.loadAll()
    }

    func insert(_ record: ScanRecord) {
        scans.removeAll { $0.id == record.id }
        scans.insert(record, at: 0)
        scans.sort { $0.createdAt > $1.createdAt }
    }

    func delete(_ record: ScanRecord) {
        ScanArchiver.delete(record)
        scans.removeAll { $0.id == record.id }
    }
}
