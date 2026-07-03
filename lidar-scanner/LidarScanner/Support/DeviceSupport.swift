import ARKit
import RealityKit
import RoomPlan

/// Runtime capability checks. LiDAR scene reconstruction is available on
/// iPhone 12 Pro and later Pro models, and on iPad Pro (2020) and later.
enum DeviceSupport {
    /// True when the device has a LiDAR sensor capable of ARKit scene reconstruction.
    static var supportsLidarScanning: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    /// True when RoomPlan's parametric room capture is available.
    static var supportsRoomPlan: Bool {
        RoomCaptureSession.isSupported
    }

    /// True when guided object capture (photogrammetry photo mode) is available.
    @MainActor
    static var supportsObjectCapture: Bool {
        ObjectCaptureSession.isSupported
    }
}
