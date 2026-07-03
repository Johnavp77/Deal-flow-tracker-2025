import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Group {
                if DeviceSupport.supportsLidarScanning {
                    ScanView()
                } else {
                    UnsupportedDeviceView()
                }
            }
            .tabItem {
                Label("Scan", systemImage: "camera.metering.matrix")
            }

            if DeviceSupport.supportsRoomPlan {
                RoomScanView()
                    .tabItem {
                        Label("Room", systemImage: "house")
                    }
            }

            if DeviceSupport.supportsObjectCapture {
                PhotoCaptureView()
                    .tabItem {
                        Label("Photo", systemImage: "camera")
                    }
            }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2")
                }
        }
    }
}

#Preview {
    ContentView()
}
