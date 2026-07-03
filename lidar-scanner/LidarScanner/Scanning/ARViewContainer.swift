import RealityKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    let controller: ScanSessionController

    func makeUIView(context: Context) -> ARView {
        controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
