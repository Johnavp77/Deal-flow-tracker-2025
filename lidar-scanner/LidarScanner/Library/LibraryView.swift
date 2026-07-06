import SwiftUI

struct LibraryView: View {
    @ObservedObject private var store = ScanStore.shared
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.scans.isEmpty {
                    ContentUnavailableView(
                        "No Scans Yet",
                        systemImage: "cube.transparent",
                        description: Text("Capture a scan from the Scan or Room tab and it will show up here.")
                    )
                } else {
                    List {
                        ForEach(store.scans) { record in
                            NavigationLink(value: record) {
                                ScanRow(record: record)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: ScanRecord.self) { record in
                ScanDetailView(record: record)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .refreshable {
                store.reload()
            }
            .onAppear {
                store.reload()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            store.delete(store.scans[index])
        }
    }
}

private struct ScanRow: View {
    let record: ScanRecord

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(record.kind.displayName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                    ForEach(record.files) { file in
                        Text(file.format.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = UIImage(contentsOfFile: ScanArchiver.thumbnailURL(for: record).path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(.secondarySystemFill)
                Image(systemName: placeholderIcon)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var placeholderIcon: String {
        switch record.kind {
        case .room: return "house.fill"
        case .photo: return "camera.fill"
        case .lidar: return "cube.transparent"
        }
    }
}

#Preview {
    LibraryView()
}
