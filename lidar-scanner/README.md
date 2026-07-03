# LidarScanner — Polycam-style 3D scanning for iPhone & iPad

A native iOS app that uses the LiDAR sensor on Pro-model iPhones and iPads to
capture real-world spaces and objects as 3D models — the same core capability
as Polycam's LiDAR mode.

## Features

| Feature | How it works |
| --- | --- |
| **Live LiDAR mesh scanning** | ARKit scene reconstruction (`.meshWithClassification`) builds a triangle mesh of everything the sensor sees, visualized live over the camera feed. |
| **Room mode** | Apple RoomPlan produces a clean parametric model of a room — walls, doors, windows, and detected furniture — exported as USDZ. |
| **Measurement tool** | Tap any two points during a scan to get a real-world distance (cm/m), with markers and a connecting line rendered in AR. |
| **Multi-format export** | USDZ (AR Quick Look / Messages / Safari), OBJ (Blender, Unity, Unreal, Maya), STL (3D printing), PLY (research / point-cloud tools). |
| **Scan library** | Every scan is saved on-device with a thumbnail, capture stats, and its exported files. Interactive 3D preview via Quick Look, share any file with the system share sheet. |
| **Files app access** | Exports are stored in the app's Documents folder and are visible in the Files app (`UIFileSharingEnabled`). |

## Requirements

- **Hardware:** a LiDAR-equipped device — iPhone 12 Pro / Pro Max or later Pro models, or iPad Pro (2020) and later. The app detects support at runtime and shows an explanation on unsupported devices.
- **OS:** iOS 17.0+
- **Build:** Xcode 16 or later (the project uses buildable-folder references), a free or paid Apple Developer account for on-device signing.

> ARKit scanning does not run in the Simulator — build to a physical device.

## Getting started

1. Open `lidar-scanner/LidarScanner.xcodeproj` in Xcode.
2. Select the **LidarScanner** target → *Signing & Capabilities* → choose your team (and change the bundle identifier if needed).
3. Select your iPhone/iPad as the run destination and press **Run**.
4. On first launch, grant camera access.

## Using the app

- **Scan tab** — tap *Start Scan* and move slowly around the subject. The white wireframe overlay shows what has been captured. Use the ruler button to measure, the eye button to toggle the mesh overlay, and *Finish Scan* to name the scan and pick export formats.
- **Room tab** — RoomPlan guides you through scanning a room; tap *Done Scanning* to process, then save the parametric USDZ to the library.
- **Library tab** — browse saved scans, view them in an interactive 3D preview, share individual files, or swipe to delete.

## Architecture

```
LidarScanner/
├── LidarScannerApp.swift          App entry point
├── ContentView.swift              Tab navigation + capability gating
├── Support/DeviceSupport.swift    Runtime LiDAR / RoomPlan checks
├── Scanning/
│   ├── ScanSessionController.swift  ARKit session, live mesh, measurements
│   ├── ScanView.swift               Scan screen UI (HUD, controls)
│   ├── ExportSheet.swift            Name + format picker, export flow
│   ├── ARViewContainer.swift        SwiftUI wrapper for RealityKit ARView
│   ├── CapturedMesh.swift           ARMeshAnchor → world-space value type
│   └── MeshExporter.swift           ModelIO (OBJ/STL/PLY) + SceneKit (USDZ)
├── Rooms/
│   ├── RoomScanController.swift     RoomPlan capture session wrapper
│   └── RoomScanView.swift           Room scanning UI + save sheet
└── Library/
    ├── ScanArchiver.swift           On-disk persistence (Documents/Scans)
    ├── ScanStore.swift              Observable in-memory catalog
    ├── ScanRecord.swift             Codable scan metadata
    ├── LibraryView.swift            Saved-scan list
    ├── ScanDetailView.swift         Preview, stats, share, delete
    └── ModelPreviewView.swift       Quick Look USDZ viewer
```

**Capture pipeline:** ARKit continuously publishes `ARMeshAnchor`s while
scanning. On finish, each anchor's Metal-backed geometry buffers are copied
into plain `CapturedMesh` value types (vertices transformed to world space,
normals rotated), the session is paused, and export runs on a background task.
OBJ/STL/PLY are written through ModelIO (`MDLAsset`); USDZ is written through
SceneKit, which supports USDZ archives on iOS. Each scan is stored under
`Documents/Scans/<uuid>/` with a `metadata.json`, a thumbnail, and the
exported model files.

## Limitations & roadmap

- **No photo textures yet.** Exports are untextured geometry (like Polycam's raw LiDAR mesh view). Projecting camera frames onto the mesh for textured export is the natural next step.
- **Photogrammetry mode** (Polycam's "Photo mode") could be added with iOS 17's `ObjectCaptureSession` + `PhotogrammetrySession` for small-object capture.
- **Cloud sync / sharing links** are out of scope for this on-device v1; all data stays local.
