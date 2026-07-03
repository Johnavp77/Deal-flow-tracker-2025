import SwiftUI

struct UnsupportedDeviceView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sensor.tag.radiowaves.forward")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("LiDAR Not Available")
                .font(.title2.bold())
            Text("3D scanning requires a LiDAR-equipped device:\niPhone 12 Pro or later Pro/Pro Max models,\nor iPad Pro (2020 and later).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("You can still browse previously saved scans in the Library tab.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

#Preview {
    UnsupportedDeviceView()
}
