import ARKit
import CoreGraphics
import CoreImage
import simd

/// A downsampled copy of one camera frame plus the camera geometry
/// needed to project world-space points back into the image, so mesh
/// vertices can be colorized after scanning ends.
struct ColorKeyframe: Sendable {
    let pixels: [UInt8]        // RGBA8, row 0 = top of image
    let width: Int
    let height: Int
    let worldToCamera: simd_float4x4
    let cameraPosition: SIMD3<Float>
    /// (fx, fy, cx, cy) scaled to the downsampled image size.
    let intrinsics: SIMD4<Float>

    /// Samples the image color at the projection of a world point,
    /// or nil when the point is behind the camera or outside the frame.
    func sample(worldPoint: SIMD3<Float>) -> SIMD3<UInt8>? {
        let camera = worldToCamera * SIMD4<Float>(worldPoint.x, worldPoint.y, worldPoint.z, 1)
        // ARKit camera space: +x right, +y up, -z forward.
        guard camera.z < -0.05 else { return nil }
        let u = intrinsics.z - intrinsics.x * (camera.x / camera.z)
        let v = intrinsics.w + intrinsics.y * (camera.y / camera.z)
        let x = Int(u.rounded())
        let y = Int(v.rounded())
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        let offset = (y * width + x) * 4
        return SIMD3<UInt8>(pixels[offset], pixels[offset + 1], pixels[offset + 2])
    }
}

/// Collects color keyframes during a scan. Frames are captured when the
/// camera has moved or rotated enough since the last keyframe, and are
/// downsampled on a background queue so the AR session is never blocked.
final class KeyframeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let processingQueue = DispatchQueue(label: "KeyframeCollector", qos: .utility)
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    private var keyframes: [ColorKeyframe] = []
    private var collecting = false
    private var busy = false
    private var lastTransform: simd_float4x4?
    private var lastTimestamp: TimeInterval = 0

    private let maxKeyframes = 150
    private let targetWidth = 320
    private let minInterval: TimeInterval = 0.4
    private let forcedInterval: TimeInterval = 2.0
    private let minTranslation: Float = 0.2
    private let minRotationCosine = cosf(12 * .pi / 180)

    func setCollecting(_ enabled: Bool) {
        lock.lock()
        collecting = enabled
        lock.unlock()
    }

    func reset() {
        lock.lock()
        keyframes.removeAll()
        lastTransform = nil
        lastTimestamp = 0
        lock.unlock()
    }

    func snapshot() -> [ColorKeyframe] {
        lock.lock()
        defer { lock.unlock() }
        return keyframes
    }

    /// Called from the ARSession delegate for every frame; cheap unless
    /// the frame is actually selected as a keyframe.
    func consider(_ frame: ARFrame) {
        guard case .normal = frame.camera.trackingState else { return }
        let transform = frame.camera.transform
        let timestamp = frame.timestamp

        lock.lock()
        guard collecting, !busy, keyframes.count < maxKeyframes,
              timestamp - lastTimestamp >= minInterval else {
            lock.unlock()
            return
        }
        if let last = lastTransform, timestamp - lastTimestamp < forcedInterval {
            let moved = simd_distance(
                SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z),
                SIMD3<Float>(last.columns.3.x, last.columns.3.y, last.columns.3.z)
            )
            let forwardNow = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
            let forwardLast = -SIMD3<Float>(last.columns.2.x, last.columns.2.y, last.columns.2.z)
            let rotationCosine = simd_dot(simd_normalize(forwardNow), simd_normalize(forwardLast))
            if moved < minTranslation, rotationCosine > minRotationCosine {
                lock.unlock()
                return
            }
        }
        busy = true
        lastTransform = transform
        lastTimestamp = timestamp
        lock.unlock()

        let pixelBuffer = frame.capturedImage
        let intrinsics = frame.camera.intrinsics
        let resolution = frame.camera.imageResolution

        processingQueue.async { [weak self] in
            guard let self else { return }
            let keyframe = self.makeKeyframe(
                pixelBuffer: pixelBuffer,
                cameraTransform: transform,
                intrinsics: intrinsics,
                imageResolution: resolution
            )
            self.lock.lock()
            if let keyframe, self.collecting {
                self.keyframes.append(keyframe)
            }
            self.busy = false
            self.lock.unlock()
        }
    }

    private func makeKeyframe(
        pixelBuffer: CVPixelBuffer,
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        imageResolution: CGSize
    ) -> ColorKeyframe? {
        let sourceWidth = Float(imageResolution.width)
        let sourceHeight = Float(imageResolution.height)
        guard sourceWidth > 0, sourceHeight > 0 else { return nil }

        let width = targetWidth
        let height = Int((Float(width) * sourceHeight / sourceWidth).rounded())
        let scaleX = CGFloat(width) / imageResolution.width
        let scaleY = CGFloat(height) / imageResolution.height

        let image = CIImage(cvPixelBuffer: pixelBuffer)
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        guard let cgImage = ciContext.createCGImage(image, from: bounds) else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(cgImage, in: bounds)
            return true
        }
        guard rendered else { return nil }

        let fx = intrinsics.columns.0.x * Float(scaleX)
        let fy = intrinsics.columns.1.y * Float(scaleY)
        let cx = intrinsics.columns.2.x * Float(scaleX)
        let cy = intrinsics.columns.2.y * Float(scaleY)

        return ColorKeyframe(
            pixels: pixels,
            width: width,
            height: height,
            worldToCamera: simd_inverse(cameraTransform),
            cameraPosition: SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            ),
            intrinsics: SIMD4<Float>(fx, fy, cx, cy)
        )
    }
}

/// Assigns a color to every mesh vertex by projecting it into the best
/// keyframe (the one most directly facing the surface at that point).
enum ColorProjector {
    static let fallbackColor = SIMD3<UInt8>(180, 180, 180)

    static func colorize(_ meshes: [CapturedMesh], with keyframes: [ColorKeyframe]) -> [CapturedMesh] {
        guard !keyframes.isEmpty else { return meshes }
        return meshes.map { mesh in
            var colored = mesh
            var colors = [SIMD3<UInt8>]()
            colors.reserveCapacity(mesh.vertices.count)
            for index in 0..<mesh.vertices.count {
                let point = mesh.vertices[index]
                let normal = mesh.normals[index]
                var best: SIMD3<UInt8>?
                var bestScore: Float = 0.1
                for keyframe in keyframes {
                    let toCamera = keyframe.cameraPosition - point
                    let distance = simd_length(toCamera)
                    guard distance > 0.05 else { continue }
                    let score = simd_dot(normal, toCamera / distance)
                    guard score > bestScore else { continue }
                    if let color = keyframe.sample(worldPoint: point) {
                        best = color
                        bestScore = score
                    }
                }
                colors.append(best ?? fallbackColor)
            }
            colored.colors = colors
            return colored
        }
    }
}
