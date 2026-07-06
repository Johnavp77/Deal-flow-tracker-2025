# LidarScanner — Polycam-style 3D scanning for iPhone & iPad

A native iOS app that uses the LiDAR sensor on Pro-model iPhones and iPads to
capture real-world spaces and objects as 3D models — the same core capability
as Polycam's LiDAR mode.

## Features

| Feature | How it works |
| --- | --- |
| **Live LiDAR mesh scanning** | ARKit scene reconstruction (`.meshWithClassification`) builds a triangle mesh of everything the sensor sees, visualized live over the camera feed. |
| **Color capture** | Camera keyframes are collected while you scan (movement-gated, downsampled) and projected onto the mesh at export time, producing per-vertex colors in USDZ, OBJ, and PLY. |
| **Photo mode (photogrammetry)** | iOS 17 `ObjectCaptureSession` guides a photo orbit around a small object, then `PhotogrammetrySession` reconstructs a fully textured USDZ on-device — Polycam's "Photo" capture. |
| **Room mode** | Apple RoomPlan produces a clean parametric model of a room — walls, doors, windows, and detected furniture — exported as USDZ. |
| **Measurement tools** | Distance mode: tap two points for a real-world distance (cm/m). Area mode: tap the corners of a floor region for a floor-plan area and perimeter readout. Taps snap to detected mesh corners/creases (green marker = snapped); toggle with the scope button. |
| **Scan stats** | Every LiDAR scan records total surface area and approximate enclosed volume, computed from the mesh and shown in the Library. |
| **Scan resume** | Each scan saves its ARKit world map. Reopen the scan later, relocalize by pointing the device at the captured area, and keep scanning — new geometry merges into the stored mesh. Ideal for large properties. |
| **iCloud Drive backup** | Optional: move the whole scan library into the app's iCloud container (Settings gear in the Library tab) for cross-device access — no custom backend. |
| **Multi-format export** | USDZ (AR Quick Look / Messages / Safari), OBJ (Blender, Unity, Unreal, Maya), STL (3D printing), PLY (research / point-cloud tools). |
| **Crop tool** | Orbit the saved mesh in 3D and trim everything outside an adjustable crop box — remove floors, walls, and clutter after capture. |
| **Re-export & decimation** | Every LiDAR scan keeps its full-detail mesh (`mesh.bin`), so you can regenerate any format later at Full / High / Medium / Low detail. Decimation uses grid-based vertex clustering that preserves normals and colors. |
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
3. The project references `LidarScanner.entitlements` for iCloud Drive backup. Add the **iCloud** capability (CloudKit not required — just iCloud Documents) with your team, or — if you don't want iCloud / are on a free developer account — delete the `CODE_SIGN_ENTITLEMENTS` build setting; the app runs fine without it and the iCloud toggle simply reports unavailable.
4. Select your iPhone/iPad as the run destination and press **Run**.
5. On first launch, grant camera access.

## Using the app

- **Scan tab** — tap *Start Scan* and move slowly around the subject. The white wireframe overlay shows what has been captured. The ruler button opens measuring with a Distance/Area tool switch and corner snapping (scope button); the eye button toggles the mesh overlay; *Finish Scan* names the scan, picks export formats, and chooses whether to bake camera color into the mesh.
- **Room tab** — RoomPlan guides you through scanning a room; tap *Done Scanning* to process, then save the parametric USDZ to the library.
- **Photo tab** — place a small object on a flat surface, follow the guided capture ring, tap *Finish*, and wait for on-device photogrammetry to reconstruct a textured USDZ (shown on devices that support Object Capture).
- **Library tab** — browse saved scans, view them in an interactive 3D preview, share individual files, or swipe to delete. LiDAR scans also offer *Resume Scan* (relocalize and extend the capture — new geometry merges into the stored mesh), *Crop Model* (trim the mesh with a 3D crop box), and *Re-export Files* (regenerate any format at a chosen detail level) — all working from the stored full-detail mesh, no rescanning needed. The gear button opens Settings, where the library can be moved into iCloud Drive.

## Architecture

```
LidarScanner/
├── LidarScannerApp.swift          App entry point
├── ContentView.swift              Tab navigation + capability gating
├── Support/DeviceSupport.swift    Runtime LiDAR / RoomPlan checks
├── Scanning/
│   ├── ScanSessionController.swift  ARKit session, live mesh, measure tools,
│   │                                corner snapping, world-map save/resume
│   ├── ScanView.swift               Scan screen UI (HUD, controls)
│   ├── ResumeScanView.swift         Relocalize-and-extend flow for saved scans
│   ├── ExportSheet.swift            Name + format picker, export flow
│   ├── ARViewContainer.swift        SwiftUI wrapper for RealityKit ARView
│   ├── CapturedMesh.swift           ARMeshAnchor → world-space value type
│   ├── RawMesh.swift                Canonical mesh: binary IO, crop, decimation
│   ├── KeyframeCollector.swift      Color keyframes + vertex colorization
│   └── MeshExporter.swift           OBJ/PLY writers, ModelIO STL, SceneKit USDZ
├── Rooms/
│   ├── RoomScanController.swift     RoomPlan capture session wrapper
│   └── RoomScanView.swift           Room scanning UI + save sheet
├── PhotoCapture/
│   ├── PhotoCaptureController.swift ObjectCaptureSession + PhotogrammetrySession
│   └── PhotoCaptureView.swift       Guided photo capture UI + save sheet
└── Library/
    ├── ScanArchiver.swift           On-disk persistence (Documents/Scans)
    ├── ScanStore.swift              Observable in-memory catalog
    ├── ScanRecord.swift             Codable scan metadata
    ├── LibraryView.swift            Saved-scan list
    ├── ScanDetailView.swift         Preview, stats, edit, share, delete
    ├── CropView.swift               3D crop box editor (SceneKit)
    ├── ReExportSheet.swift          Regenerate files from the raw mesh
    └── ModelPreviewView.swift       Quick Look USDZ viewer
└── Settings/
    ├── StorageSettings.swift        Local ↔ iCloud Drive migration
    └── SettingsView.swift           Storage settings UI
```

**Capture pipeline:** ARKit continuously publishes `ARMeshAnchor`s while
scanning. In parallel, `KeyframeCollector` grabs a downsampled camera frame
(with its camera transform and scaled intrinsics) whenever the device has
moved or rotated enough since the last keyframe. On finish, each anchor's
Metal-backed geometry buffers are copied into plain `CapturedMesh` value
types (vertices transformed to world space, normals rotated), the session is
paused, and export runs on a background task. When color capture is enabled,
`ColorProjector` picks, for every vertex, the keyframe most directly facing
the surface and samples its color — giving vertex-colored output without a
full UV-texturing pass. OBJ and binary PLY are written directly (so colors
survive), STL goes through ModelIO, and USDZ through SceneKit. Each scan is
stored under `Documents/Scans/<uuid>/` with a `metadata.json`, a thumbnail,
the exported model files, and `mesh.bin` — the full-detail merged mesh in a
compact binary format. Crop and re-export operate on `mesh.bin`: cropping
keeps triangles fully inside the box and compacts unused vertices, then
rewrites the stored mesh and regenerates the existing export files;
re-export optionally decimates first via grid-based vertex clustering
(cell size binary-searched to hit the target vertex count, positions,
normals, and colors averaged per cell).

**Photo mode:** `ObjectCaptureSession` writes its guided capture photos to a
temporary directory; when the pass completes, `PhotogrammetrySession`
reconstructs a textured USDZ (`.reduced` detail) on-device with live progress,
and the result is copied into the same scan library.

## Limitations & roadmap

- **Vertex colors, not texture atlases.** LiDAR-mode color is per-vertex, so its resolution follows mesh density (Photo mode produces fully textured models). A UV-unwrap + texture-bake pass would be the next refinement.
- **Occlusion during colorization** is approximated with a surface-facing test rather than full visibility ray-casting, so thin geometry can pick up colors from behind in rare cases.
- **Photo mode availability** depends on `ObjectCaptureSession.isSupported` (recent Pro devices); the tab hides itself elsewhere.
- **Cloud sync / sharing links** are out of scope for this on-device app; all data stays local. Files can be shared via the share sheet or the Files app.
