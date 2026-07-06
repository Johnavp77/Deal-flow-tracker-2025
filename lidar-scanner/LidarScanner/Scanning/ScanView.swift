import SwiftUI

struct ScanView: View {
    @StateObject private var controller = ScanSessionController()
    @State private var showExportSheet = false
    @State private var showSavedAlert = false
    @State private var savedRecord: ScanRecord?

    var body: some View {
        ZStack {
            ARViewContainer(controller: controller)
                .ignoresSafeArea()

            if controller.state == .idle {
                idleOverlay
            }

            VStack {
                if controller.state == .scanning {
                    statusHUD
                }
                Spacer()
                if controller.state == .scanning {
                    scanningControls
                }
            }
            .padding()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(controller: controller) { record in
                savedRecord = record
                showSavedAlert = true
            }
        }
        .alert("Scan Saved", isPresented: $showSavedAlert, presenting: savedRecord) { _ in
            Button("OK") {}
        } message: { record in
            Text("\"\(record.name)\" was added to your Library.")
        }
        .onDisappear {
            controller.pauseIfScanning()
        }
    }

    // MARK: - Idle

    private var idleOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color(.systemIndigo).opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                Text("LiDAR 3D Scanner")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Walk around your subject slowly and keep it in frame. The LiDAR sensor builds a live 3D mesh you can export as USDZ, OBJ, STL, or PLY.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    controller.startScan()
                } label: {
                    Label("Start Scan", systemImage: "record.circle")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    // MARK: - HUD

    private var statusHUD: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Label("\(controller.meshAnchorCount)", systemImage: "square.grid.3x3.topleft.filled")
                Divider().frame(height: 14)
                Text(controller.trackingStatus)
            }
            .font(.footnote.monospacedDigit())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            if controller.measureMode {
                Picker("Tool", selection: $controller.measureTool) {
                    ForEach(ScanSessionController.MeasureTool.allCases) { tool in
                        Text(tool.displayName).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Text(measurementReadout)
                    .font(.footnote.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.yellow.opacity(0.85), in: Capsule())
                    .foregroundStyle(.black)
            }
        }
    }

    private var measurementReadout: String {
        switch controller.measureTool {
        case .distance:
            return controller.measurements.isEmpty
                ? "Tap two points on the mesh to measure"
                : controller.measurements.map(\.formatted).joined(separator: "  •  ")
        case .area:
            let count = controller.areaPoints.count
            guard count >= 3 else {
                return count == 0
                    ? "Tap the corners of a floor area"
                    : "\(count) point\(count == 1 ? "" : "s") — tap at least 3"
            }
            return String(
                format: "Area %.2f m²  •  Perimeter %.2f m",
                controller.polygonArea,
                controller.polygonPerimeter
            )
        }
    }

    // MARK: - Controls

    private var scanningControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                controlButton(
                    systemImage: controller.showMesh ? "eye" : "eye.slash",
                    active: controller.showMesh
                ) {
                    controller.showMesh.toggle()
                }
                controlButton(
                    systemImage: "ruler",
                    active: controller.measureMode
                ) {
                    controller.measureMode.toggle()
                }
                if controller.measureMode {
                    controlButton(
                        systemImage: "scope",
                        active: controller.snapToCorners
                    ) {
                        controller.snapToCorners.toggle()
                    }
                }
                if !controller.measurements.isEmpty || !controller.areaPoints.isEmpty {
                    controlButton(systemImage: "trash", active: false) {
                        controller.clearMeasurements()
                    }
                }
                controlButton(systemImage: "arrow.counterclockwise", active: false) {
                    controller.resetScan()
                }
            }

            Button {
                showExportSheet = true
            } label: {
                Label("Finish Scan", systemImage: "stop.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(controller.meshAnchorCount == 0)
        }
    }

    private func controlButton(
        systemImage: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 48, height: 48)
        }
        .background(.ultraThinMaterial, in: Circle())
        .foregroundStyle(active ? Color.yellow : Color.white)
    }
}

#Preview {
    ScanView()
}
