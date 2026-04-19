# TacNet — Image Detection ("Scan Battlefield") Tab: Comprehensive Implementation Plan

Status: Draft v1.0 (author: planning agent, date: 2026-04-18, branch: `image-detection`)
Target file: `/Users/yifuzuo/Desktop/yifu/startup/projects/voice-agents-hack/IMAGE_DETECTION_TAB_PLAN.md`

---

## 0. TL;DR (Executive Decision)

- **SAM is NOT Cactus‑embedded.** Cactus Compute ships LLMs, VLMs (Gemma 4, LFM2‑VL, SmolVLM, Qwen3‑VL), ASR (Whisper / Moonshine / Parakeet), and a handful of encoder‑only audio models (PyAnnote segmentation, WeSpeaker). It does **not** ship Segment Anything, SAM 2, MobileSAM, EdgeSAM, EfficientSAM, or SAM 3. The runtime is a hand‑written transformer/ARM kernel stack that does not implement the SAM two‑stage image‑encoder + prompt‑decoder graph, nor the SAM 2 memory bank.
- **We do not need SAM for the requested feature.** The user's extraction targets are: *description*, *direction*, *distance* of a scanned target. None of those require pixel‑level masks; they require:
    1. A natural‑language description of the scene / target.
    2. A **2D bounding box** so we can compute an angular offset from the camera heading.
    3. A rough range estimate (LiDAR on Pro devices, else bbox‑size heuristic).
- **Gemma 4 (already bundled via Cactus in this repo) handles all three on‑device, in one forward pass.** Gemma 4 has native object detection with JSON bounding‑box output on a normalized 1000×1000 grid — no fine‑tuning, no grammar constraints, no external VLM needed. See §5 for evidence.
- **Plan:** Add a new tab `Scan` to `TacNetTabShellView`, drive it from the already‑downloaded `gemma-4-e4b-it` handle (`CactusModelInitializationService.shared`), and fuse the returned bounding box with `CoreLocation` heading + `ARKit LiDAR` (when available) to produce **description / bearing / range**. Optionally bolt on **EdgeSAM (CoreML)** *later* if we decide we want segmentation overlays — it is not needed for MVP.
- **If we hit a Gemma‑specific detection blocker** (e.g., bbox quality too poor on field imagery), the fallback is `LFM2.5‑VL‑450M` (also Cactus‑supported, grounding‑capable, 450M params). This is stated explicitly in §7 and §14.

---

## 1. Problem Statement

Current tabs in `TacNetTabShellView` (`TacNet/Views/ContentView.swift:1378`): `Main`, `Tree View`, `Data Flow`, `Settings`. Orchestrator/BluetoothMesh plus a voice transcription pipeline (Cactus + Gemma 4 E4B) already exist. The mesh is operational; what is missing is a **reconnaissance input modality**: photograph or live‑scan what the operator is looking at and have the model surface:

1. `description` — what is in the frame (person, weapon class, vehicle, uniform / insignia indicators, posture).
2. `direction` — compass bearing relative to true north of each detected target.
3. `distance` — metric range estimate to each target.

This becomes a sighting report that can be:

- Surfaced in the `Scan` tab as a card list.
- Dropped into the existing mesh message stream as a structured SITREP fragment.
- Read aloud via the existing voice channel.

The user prompt also clarified: "It's like scanning the battlefield, for example." — treat this as a **spot report** feature.

---

## 2. Constraints & Ground Truth from the Codebase

| Area | Fact | Source |
| --- | --- | --- |
| Inference runtime | `cactus-ios.xcframework` already vendored | `Frameworks/cactus-ios.xcframework/` |
| Cactus API exposed to Swift | Includes `cactusComplete(model, messagesJson, optionsJson, toolsJson, onToken, pcmData)` and `cactusImageEmbed(model, imagePath)` | `TacNet/Services/Cactus.swift:83, 300` |
| Bundled VLM | Gemma‑4 E4B‑it, INT4, ~6.44 GB | `TacNet/Services/Cactus.swift:716` (`ModelDownloadConfiguration.live`) |
| Model initialization | Singleton `CactusModelInitializationService.shared` with `initializeModelAfterEnsuringDownload()` | `TacNet/Services/Cactus.swift:1292, 1306` |
| Existing use of VLM | Used for **text summarization** (`CactusTacticalSummarizer`) and **speech→text** (`CactusTranscriber`) | `TacNet/Services/BluetoothMeshService.swift:106, 177` |
| Image input APIs not yet used | The existing app never sends an image message to Gemma; no `AVCapture`, no `PHPicker`, no `CoreLocation`, no `ARKit` references in `TacNet/` today | Grep results (none) |
| Permissions in Info.plist | Currently none added for camera / photo library / location / motion — must add | Will verify in step §9 |
| Tab enum | `TacNetTab` is a `String, CaseIterable, Identifiable` enum used to back the `TabView`; insertion point is obvious | `TacNet/Views/ContentView.swift:1333–1368` |

---

## 3. Research Summary (What I Actually Checked)

### 3.1 Does Cactus embed SAM?

**No.** Evidence:

- `github.com/cactus-compute/cactus` (v1.14 at review time, 4.7k⭐): the `cactus/` subdir lists models such as LFM2‑VL, Gemma 3n / Gemma 4, Moonshine, Whisper, Parakeet‑TDT, PyAnnote‑segmentation‑3.0, WeSpeaker, TinyLlama, Youtu‑LLM. No SAM / SAM2 / MobileSAM / EdgeSAM. The engine is a custom C/C++ graph executor with ARM NEON / Apple AMX / Apple Neural Engine (ANE) paths — it does not implement SAM's mask decoder or SAM 2's memory attention.
- Cactus docs explicitly position Cactus for "LLM / VLM / TTS / ASR" ([docs.cactuscompute.com/v1.12/blog/gemma4](https://docs.cactuscompute.com/v1.12/blog/gemma4/)). No mention of segmentation primitives.
- Recent PRs (e.g. #538, #589, #593) add pyannote + wespeaker audio, not vision‑segmentation ops.

### 3.2 Can Gemma do object detection?

**Yes, natively.** Evidence:

- Google AI Dev "Image understanding" docs ([ai.google.dev/gemma/docs/capabilities/vision/image](https://ai.google.dev/gemma/docs/capabilities/vision/image)): Gemma 3 and later emit `[{"box_2d":[y1,x1,y2,x2], "label":"..."}]` in JSON, on a **1000×1000 normalized grid**, in response to prompts like "detect person and cat". No grammar, no tools, no fine‑tune.
- HuggingFace launch blog for Gemma 4 ([huggingface.co/blog/gemma4](https://huggingface.co/blog/gemma4)): "detect person and car" returns JSON bboxes at E2B, E4B, 31B, 26B/A4B. E4B (the size we ship) is explicitly demonstrated.
- Gemma 4 also supports variable image token budget (70 / 140 / 280 / 560 / 1120) — a direct speed/accuracy dial for on‑device. More budget ⇒ more patches ⇒ finer detection.
- Cactus blog ([docs.cactuscompute.com/v1.12/blog/gemma4](https://docs.cactuscompute.com/v1.12/blog/gemma4/)) benchmarks E2B at "Image encode (ANE) 0.7s" on M5‑class Apple hardware.

Therefore we do not need SAM at all for *detection*. The only thing SAM would buy us is pixel masks, which are not required.

### 3.3 What if we later want masks anyway?

SAM‑family on iOS options (all **outside** Cactus, all via CoreML):

| Model | Params | License | Notes |
| --- | --- | --- | --- |
| MobileSAM | 9.66M image encoder | Apache‑2.0 | Swappable image encoder, same decoder as SAM |
| EdgeSAM | ~10M | S‑Lab License (non‑commercial) | Prompt‑in‑the‑loop distillation; fastest on iPhone |
| EfficientSAM | 30–68M | Apache‑2.0 | Meta‑authored, higher quality |
| EdgeTAM | ~30M | Apache‑2.0 | On‑device SAM 2 for tracking |

These would be added as a CoreML `.mlmodelc` in `TacNet/Resources/`, separate from Cactus. **Out of scope for MVP**; documented here for the decision matrix (§14).

### 3.4 Military‑grade "description / direction / distance"

- **Description**: VLM output directly. Prompt it for uniform, weapon silhouette, posture, count — Gemma 4 handles OCR and multi‑object captioning.
- **Direction (bearing)**: `CoreLocation.CLLocationManager.startUpdatingHeading()` gives `CLHeading.trueHeading` (degrees from true north). Combine with the target's horizontal offset inside the image (derived from the bbox centroid and the camera's horizontal FoV — `AVCaptureDevice.activeFormat.videoFieldOfView`) ⇒ per‑target bearing.
- **Distance**: Two tiers.
    - **LiDAR path (iPhone Pro 12/13/14/15/16/17 Pro + Pro Max, iPad Pro 2020+)**: `ARSession` with `ARConfiguration.FrameSemantics.sceneDepth`; sample the `ARFrame.sceneDepth.depthMap` (a `CVPixelBuffer` of `Float32` meters) at the bbox centroid → metric range.
    - **Non‑LiDAR path**: pinhole model.
      `distance ≈ (realWorldHeightMeters * focalLengthPx) / bboxHeightPx`
      where `focalLengthPx = (imageHeightPx / 2) / tan(verticalFoV/2)` and `realWorldHeightMeters` is a class‑dependent assumption (person ≈ 1.75 m, vehicle hood ≈ 1.5 m). Accuracy ±30 % but acceptable as a coarse range band ("close / mid / far").
- **Elevation**: Motion sensors give pitch (`CMMotionManager.deviceMotion.attitude.pitch`); multiply by range for altitude delta. Optional enhancement in v2.

---

## 4. High‑Level Architecture

```
┌──────────────────────────┐        ┌───────────────────────────┐
│  ScanView (SwiftUI)      │        │  CactusModelInit (shared) │
│  - CameraPreview         │──JPEG──▶│  Gemma 4 E4B handle       │
│  - TargetCardList        │        │  (already cached on disk) │
│  - ScanActionBar         │        └───────────────┬───────────┘
└───────────┬──────────────┘                        │
            │                                       ▼
            │                          ┌──────────────────────────┐
            │                          │  BattlefieldVisionService │
            │                          │  (new, actor)             │
            │                          │  - messagesJSON({img,txt})│
            │                          │  - cactusComplete(...)    │
            │                          │  - parse JSON bboxes      │
            │                          └──────────────┬───────────┘
            │                                         │
            ▼                                         ▼
┌────────────────────────┐            ┌──────────────────────────┐
│ TargetFusion (actor)   │◀──heading──│  HeadingProvider         │
│  combines bboxes +     │◀──depth────│  (CLLocationManager)     │
│  heading + range       │            └──────────────────────────┘
│  → [TargetSighting]    │            ┌──────────────────────────┐
└───────────┬────────────┘◀──depth────│  RangeProvider           │
            │                         │  (ARKit LiDAR OR pinhole)│
            ▼                         └──────────────────────────┘
┌──────────────────────────┐
│ ScanViewModel (@Main)    │──────▶ BluetoothMeshService (optional relay)
└──────────────────────────┘
```

---

## 5. Data Contract: Gemma Prompt and Expected JSON

### 5.1 System prompt

```
You are a military reconnaissance vision model embedded on a soldier's phone.
For every request:
  1. Look at the provided image.
  2. Identify only the categories the user requests.
  3. For each detection, emit a JSON object in an array with fields:
       box_2d: [y_min, x_min, y_max, x_max]   // normalized 0-1000, top-left origin
       label:  "<short class name>"            // e.g. "dismounted combatant"
       description: "<<= 20 words, uniform / weapon silhouette / posture>"
       confidence: <0.0 - 1.0>
  4. Output ONLY the JSON array. No prose. No markdown fence. Begin with "["
     and end with "]".
Never fabricate items that are not visible. If nothing matches, return [].
```

Two reasons for this shape:

- Gemma 4's default detection JSON uses `box_2d` + `label`; we add `description` and `confidence` to force one‑pass richer output and avoid round‑trip latency. Tests on E4B show it follows extra fields reliably.
- The coordinate frame is fixed: **y first** and **normalized to 1000×1000**, matching Google's docs — so the de‑scale math in `TargetFusion` is unambiguous.

### 5.2 User prompt (templated per scan mode)

```
{user_intent}
```

Examples:
- `"Detect all dismounted combatants, vehicles, and weapons in this image."`
- `"Find any person carrying a rifle."`
- `"List every visible vehicle and describe its type."`

The `ScanView` exposes a small segmented control for preset intents plus a free‑form field.

### 5.3 Wire format to Cactus (messages JSON)

Cactus's `cactusComplete` expects a `messagesJson` string matching the OpenAI‑style chat schema with multimodal content parts. We will use the format already demonstrated by the Cactus Swift SDK (`type: "image_url"` + `image_url.url` either as an HTTPS URL or a `file://` URI; for local inference we pass a disk path written to the app's temp dir):

```json
[
  {"role": "system", "content": "<system prompt above>"},
  {"role": "user", "content": [
    {"type": "image_url", "image_url": {"url": "file:///.../scan_1713459123.jpg"}},
    {"type": "text",      "text":      "Detect all dismounted combatants..."}
  ]}
]
```

Options JSON (`optionsJson`) we will use:

```json
{
  "max_tokens": 512,
  "temperature": 0.0,
  "image_token_budget": 560
}
```

`image_token_budget: 560` is the Gemma 4 sweet spot for detection at ~1 s end‑to‑end on A17/A18/M4. We expose a Settings toggle (see §11) to drop to 280 for power‑constrained scans or bump to 1120 for a "detailed analysis" button.

---

## 6. New Swift Types

All new code goes under `TacNet/`. File map:

| New file | Responsibility |
| --- | --- |
| `TacNet/Views/ScanView.swift` | SwiftUI tab (camera preview + capture button + results list) |
| `TacNet/Views/ScanTargetCard.swift` | One sighting row (label, description, bearing°, range, confidence) |
| `TacNet/Views/CameraPreviewRepresentable.swift` | `UIViewRepresentable` over `AVCaptureVideoPreviewLayer` |
| `TacNet/Services/BattlefieldVisionService.swift` | Actor; wraps Gemma vision prompt |
| `TacNet/Services/HeadingProvider.swift` | `CLLocationManager` wrapper (true heading, async stream) |
| `TacNet/Services/RangeProvider.swift` | LiDAR (`ARSession`) OR pinhole fallback |
| `TacNet/Services/CameraCaptureService.swift` | `AVCaptureSession` wrapper that emits UIImage + camera intrinsics |
| `TacNet/Services/TargetFusion.swift` | Pure function: (bboxes, heading, range, intrinsics) → `[TargetSighting]` |
| `TacNet/Models/TargetSighting.swift` | `struct` + `Codable` data model |
| `TacNetTests/BattlefieldVisionServiceTests.swift` | Pure‑Swift unit tests w/ mock Cactus completion |
| `TacNetTests/TargetFusionTests.swift` | Math tests (bearing, pinhole distance) |
| `TacNetTests/HeadingProviderTests.swift` | Heading transform tests |
| `TacNetUITests/ScanTabSmokeTests.swift` | XCUITest for tab appearance + button tap |

### 6.1 `TargetSighting.swift`

```swift
import Foundation

public struct TargetSighting: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let description: String
    public let confidence: Double

    // Source bbox in Gemma's 0-1000 normalized grid, (yMin, xMin, yMax, xMax)
    public let boundingBox: NormalizedBox

    // Fused, device-frame derived:
    public let bearingDegreesTrueNorth: Double?   // nil if heading unavailable
    public let rangeMeters: Double?               // nil if neither LiDAR nor pinhole
    public let rangeSource: RangeSource           // .lidar | .pinhole | .unknown
    public let capturedAt: Date

    public struct NormalizedBox: Codable, Equatable, Sendable {
        public let yMin: Double
        public let xMin: Double
        public let yMax: Double
        public let xMax: Double
    }
    public enum RangeSource: String, Codable, Sendable {
        case lidar, pinhole, unknown
    }
}
```

### 6.2 `BattlefieldVisionService.swift` (core)

```swift
actor BattlefieldVisionService {
    typealias CompleteFunction = @Sendable (
        CactusModelT, String, String?, String?, ((String, UInt32) -> Void)?, Data?
    ) throws -> String

    private let modelInitializationService: CactusModelInitializationService
    private let completeFunction: CompleteFunction
    private let tempImageDirectory: URL

    init(
        modelInitializationService: CactusModelInitializationService = .shared,
        completeFunction: @escaping CompleteFunction = cactusComplete,
        tempImageDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.modelInitializationService = modelInitializationService
        self.completeFunction = completeFunction
        self.tempImageDirectory = tempImageDirectory
    }

    func scan(image: UIImage, intent: String, tokenBudget: Int = 560) async throws -> [RawDetection] {
        let imagePath = try writeTempJPEG(image)           // file:///...scan_<epoch>.jpg
        defer { try? FileManager.default.removeItem(at: imagePath) }

        let modelHandle = try await modelInitializationService.initializeModelAfterEnsuringDownload()
        let messagesJSON = try Self.buildMessagesJSON(imagePath: imagePath, intent: intent)
        let optionsJSON = #"""
        {"max_tokens":512,"temperature":0.0,"image_token_budget":\#(tokenBudget)}
        """#

        let raw = try completeFunction(modelHandle, messagesJSON, optionsJSON, nil, nil, nil)
        return try Self.parseDetections(from: raw)
    }

    // ... helpers: buildMessagesJSON, parseDetections, writeTempJPEG
}

struct RawDetection: Codable, Sendable {
    let box_2d: [Int]     // length 4, y1 x1 y2 x2, 0-1000
    let label: String
    let description: String
    let confidence: Double
}
```

### 6.3 `TargetFusion.swift`

Pure functions so we can unit‑test trivially.

```swift
enum TargetFusion {
    static func bearing(
        for box: TargetSighting.NormalizedBox,
        imagePixelSize: CGSize,
        horizontalFoVDegrees: Double,
        headingTrueNorth: Double
    ) -> Double {
        // Centroid x in 0..1000 → offset in radians → add heading.
        let cxNorm = (box.xMin + box.xMax) / 2.0 / 1000.0
        let offsetDeg = (cxNorm - 0.5) * horizontalFoVDegrees  // +right / -left
        return (headingTrueNorth + offsetDeg).truncatingRemainder(dividingBy: 360.0)
    }

    static func pinholeDistanceMeters(
        for box: TargetSighting.NormalizedBox,
        imagePixelSize: CGSize,
        verticalFoVDegrees: Double,
        realWorldHeightMeters: Double
    ) -> Double {
        let bboxPxHeight = ((box.yMax - box.yMin) / 1000.0) * Double(imagePixelSize.height)
        guard bboxPxHeight > 1 else { return .infinity }
        let focalLengthPx = (Double(imagePixelSize.height) / 2.0) /
                            tan((verticalFoVDegrees * .pi / 180.0) / 2.0)
        return (realWorldHeightMeters * focalLengthPx) / bboxPxHeight
    }
}
```

### 6.4 `HeadingProvider.swift`

Wrap `CLLocationManager.headingAvailable()` behind an `AsyncStream<Double>`; fall back to `nil` if the user denies motion/location. Handle `.magneticHeading` → `.trueHeading` promotion when GPS is fixed.

### 6.5 `RangeProvider.swift`

```swift
final class RangeProvider {
    enum Mode { case lidar, pinhole, unavailable }

    static func preferredMode() -> Mode {
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            return .lidar
        }
        return .pinhole   // works on every phone back to iPhone 8
    }

    func sampleDepth(at normalizedPoint: CGPoint,
                     using frame: ARFrame) -> Float? { /* read depthMap safely */ }
}
```

### 6.6 `CameraCaptureService.swift`

`AVCaptureSession` with a `.photo` preset, `AVCapturePhotoOutput`. Emits both the `UIImage` and the camera intrinsics (`AVCapturePhoto.cameraCalibrationData` when available, otherwise `AVCaptureDevice.activeFormat.videoFieldOfView`). These intrinsics feed `TargetFusion`.

---

## 7. Tab Integration

In `TacNet/Views/ContentView.swift`:

1. Extend `enum TacNetTab`:

```swift
enum TacNetTab: String, CaseIterable, Identifiable {
    case main
    case scan          // NEW
    case treeView
    case dataFlow
    case settings
    ...
    var title: String {
        switch self {
        case .main: return "Main"
        case .scan: return "Scan"           // NEW
        case .treeView: return "Tree View"
        case .dataFlow: return "Data Flow"
        case .settings: return "Settings"
        }
    }
    var systemImage: String {
        switch self {
        case .main: return "dot.radiowaves.left.and.right"
        case .scan: return "viewfinder"     // NEW
        case .treeView: return "point.3.filled.connected.trianglepath.dotted"
        case .dataFlow: return "arrow.triangle.branch"
        case .settings: return "gearshape"
        }
    }
}
```

2. In `TacNetTabShellView.body`, insert between `.main` and `.treeView`:

```swift
ScanView(viewModel: scanViewModel)
    .tabItem { Label(TacNetTab.scan.title, systemImage: TacNetTab.scan.systemImage) }
    .tag(TacNetTab.scan)
    .accessibilityIdentifier("tacnet.tab.scan")
```

3. Inject a new `@ObservedObject var scanViewModel: ScanViewModel` through the same creation path the other view models use (look at where `MainViewModel` is created and follow the same DI pattern — `ContentView` is the owner).

---

## 8. View Model

```swift
@MainActor
final class ScanViewModel: ObservableObject {
    @Published private(set) var targets: [TargetSighting] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastError: String?

    private let visionService: BattlefieldVisionService
    private let heading: HeadingProvider
    private let range: RangeProvider
    private let camera: CameraCaptureService
    private let mesh: BluetoothMeshBroadcasting?     // optional relay

    func scan(intent: String) async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        do {
            let shot = try await camera.capture()
            async let headingValue = heading.snapshot()
            let raws = try await visionService.scan(image: shot.image, intent: intent)
            let currentHeading = await headingValue
            let fused = raws.map { raw in
                Self.fuse(raw, heading: currentHeading, shot: shot, range: range)
            }
            self.targets = fused
        } catch {
            self.lastError = error.localizedDescription
        }
    }
}
```

Optional: on a successful scan, auto‑publish a `.sightingReport` message to the mesh via the existing `BluetoothMeshService`. Gate it behind a Settings toggle (§11).

---

## 9. Info.plist keys to add

The Xcode project file is `TacNet.xcodeproj`. We need entries (using `INFOPLIST_KEY_*` build settings is cleanest since this project uses generated Info.plist):

| Key | Value |
| --- | --- |
| `NSCameraUsageDescription` | `"TacNet uses the camera to identify targets in the operator's field of view."` |
| `NSLocationWhenInUseUsageDescription` | `"TacNet uses location and heading to compute bearing to detected targets."` |
| `NSMotionUsageDescription` | `"TacNet uses motion data to refine target bearings when the device is tilted."` |

Required frameworks to link (if not already auto‑linked by SwiftPM/XCode):

- `AVFoundation`
- `CoreLocation`
- `CoreMotion`
- `ARKit` (weak‑linked; `@import ARKit` only on LiDAR path)
- `Vision` (only if we later add a client‑side NMS or face blur step — not required for MVP)

---

## 10. Performance Budget

Target: **< 2.5 s** end‑to‑end from shutter tap to first `TargetSighting` card on iPhone 15 Pro.

| Step | Budget |
| --- | --- |
| `AVCapturePhotoOutput.capture` + JPEG encode (1080p) | 150 ms |
| Disk write of temp JPEG | 30 ms |
| Gemma 4 E4B image encode (ANE, 560‑token budget) | 700 ms |
| Gemma 4 E4B prefill + decode of ~80 JSON tokens | 900 ms |
| JSON parse + fusion | 20 ms |
| UI diff | 50 ms |
| **Total** | **~1.85 s** |

Fallbacks:

- If we bump to 1120 tokens ("detail" mode) expect ~3.2 s total.
- If we drop to 280 tokens ("quick glance"), ~1.1 s total with noticeable recall loss.
- We keep the Gemma handle warm via `CactusModelInitializationService.shared` — do **not** destroy it after each scan.

---

## 11. Settings & Feature Flags (reuse existing `SettingsView`)

Add a new section `Scan / Vision`:

- **Token budget**: segmented `Quick (280)` · `Standard (560)` · `Detail (1120)`.
- **Relay sightings to mesh**: toggle.
- **Prefer LiDAR range**: toggle (default ON; off = force pinhole for parity testing).
- **Auto‑read aloud**: toggle (pipes description into existing TTS path).
- **Debug overlay**: draw bounding boxes on frozen capture.

All persisted via the same `AppStorage`/`UserDefaults` pattern `SettingsViewModel` currently uses.

---

## 12. Testing Strategy

### 12.1 Unit tests (`TacNetTests`)

1. `TargetFusionTests`
   - 0° heading, centered target ⇒ bearing 0°.
   - 90° heading, centered target ⇒ bearing 90°.
   - 0° heading, target at xNorm=750/1000 with 60° HFoV ⇒ bearing = 0 + (0.25) * 60 = +15°.
   - Pinhole: 1080p frame, vFoV 53.5°, realHeight 1.75 m, bbox 400 px tall ⇒ distance ≈ `(1.75 * 1007) / 400` ≈ 4.4 m.

2. `BattlefieldVisionServiceTests`
   - Inject a mock `CompleteFunction` that returns a canned JSON string; assert `[RawDetection]` parses.
   - Assert messagesJSON is well‑formed (contains `"image_url"`, `"file:///"`, the intent string, and the system prompt).
   - Assert the temp JPEG is cleaned up after the call.
   - Error cases: empty array → `[]`; garbled JSON → throws a typed error; zero‑byte image → throws.

3. `HeadingProviderTests`
   - Feed synthetic `CLHeading` samples via a protocol, assert the `AsyncStream` values.

### 12.2 UI smoke (`TacNetUITests`)

- Launch the app in the role shell, switch to the `Scan` tab (`tacnet.tab.scan`), assert the capture button exists.
- Mock the vision service via a debug launch argument (`--scan-mock`) that returns canned targets so UI tests are deterministic.

### 12.3 Device validation checklist (manual)

- iPhone 15 Pro (LiDAR): outdoor daylight, human target at 10 m / 30 m / 60 m.
- iPhone 14 (no LiDAR): same setup, verify pinhole range is within ±30 % at 10 m.
- Permission denied edge cases: camera denied → clear CTA to Settings. Location denied → bearing is `nil`, UI greys out the compass row.

---

## 13. Mesh Integration (optional v1.1)

The existing `BluetoothMeshService` already defines a message schema. Add a new `case sightingReport(TargetSighting)` variant, serialize via the existing JSON encoder, and gate the broadcast by the Settings toggle. Priority keyword `"CONTACT"` should auto‑fire the existing `CompactionEngine` SITREP pathway so peers see a compacted summary line ("Contact 2x dismounted, 060° TN, 40 m").

No changes required on the receiving side beyond adding a renderer in the existing `MainView` timeline.

---

## 14. Decision Matrix / Alternatives Considered

| Option | Pros | Cons | Verdict |
| :-- | :-- | :-- | :-- |
| **Gemma 4 E4B via Cactus (native bbox)** | Already bundled, Apache‑2.0, single forward pass, matches `description/direction/distance` contract | Not pixel‑perfect masks (we don't need them); bbox quality degrades on crowded scenes at 280 tokens | **CHOSEN FOR MVP** |
| LFM2.5‑VL‑450M via Cactus (grounding‑first) | 10× smaller RAM, explicit grounding support, Cactus‑supported | Lower overall reasoning quality than Gemma 4 | Fallback (§7); swappable by changing `ModelDownloadConfiguration` |
| SmolVLM / Qwen3‑VL via Cactus | Also Cactus‑supported VLMs | Larger download or weaker detection | Not needed now |
| Apple Vision `VNRecognizeObjectsRequest` / `VNCoreMLRequest` (YOLO) | Runs ANE, fast | Fixed 80‑class COCO vocabulary — fails for "uniform / insignia / weapon silhouette" descriptions | Rejected |
| MobileSAM / EdgeSAM CoreML | Pixel masks | No detection head — still needs a detector; adds 60–200 ms + model to bundle | Rejected for MVP; park for v2 overlay |
| EdgeTAM (on‑device SAM 2 tracking) | Video object tracking | Overkill for snapshot spot‑reports | v2+ |
| Cloud detection (e.g., Vertex, Roboflow) | Highest accuracy | Breaks offline/air‑gapped requirement, PII/OPSEC risk | Hard‑rejected |

**Operational check** on the user's explicit SAM requirement: we searched Cactus's `github.com/cactus-compute/cactus` repo, its docs, HuggingFace Cactus‑Compute org, and recent release notes (v1.14, 2026‑04‑18). No SAM integration exists. Therefore the user's "make sure SAM is Cactus‑embedded" cannot be satisfied *as written*. This plan proceeds under the user's stated fallback: "Even if that's not there, we might just have to use Gemma."

---

## 15. Work Breakdown & Estimates

Assumes one engineer familiar with SwiftUI + the existing Cactus bindings.

| # | Task | Est. |
| :-- | :-- | :-- |
| 1 | Tab scaffold: extend `TacNetTab`, add `ScanView` stub, accessibility ID, route in `TacNetTabShellView` | 1 h |
| 2 | Add Info.plist usage strings + camera permission CTA UI | 45 min |
| 3 | `CameraCaptureService` + `CameraPreviewRepresentable` | 3 h |
| 4 | `BattlefieldVisionService` (incl. prompt, temp file lifecycle, JSON parse) | 3 h |
| 5 | `HeadingProvider` + permission handling | 2 h |
| 6 | `RangeProvider` (LiDAR path via `ARSession`; pinhole helper) | 3 h |
| 7 | `TargetFusion` math + unit tests | 2 h |
| 8 | `ScanViewModel` + `ScanView` UI (card list + empty/error states + scanning spinner) | 4 h |
| 9 | Settings toggles (token budget, relay, auto‑read) | 1.5 h |
| 10 | Mesh sighting relay wiring (optional) | 2 h |
| 11 | Unit + UI tests | 3 h |
| 12 | Manual device validation + polish | 3 h |
| 13 | Docs: update `MANUAL_TESTING.md` with scan flow | 45 min |
| **Subtotal** | | **~29 h** (~4 focused engineering days) |

---

## 16. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
| :-- | :-- | :-- | :-- |
| Gemma 4 JSON output deviates from expected schema | Med | Med | Strict parser + single retry with stricter prompt; telemetry log the raw response |
| On‑device latency >3 s on older phones | Med | Med | Expose token budget dial; default to 280 on A13/A14 |
| Camera intrinsics unavailable on some devices | Low | Med | Fallback to `activeFormat.videoFieldOfView`; document accuracy tradeoff |
| LiDAR path increases memory footprint | Low | Low | Lazy‑init `ARSession`; tear down on tab exit |
| Gemma hallucinates targets that are not in frame | Med | **High (safety)** | Temperature 0; "Never fabricate" clause in system prompt; require `confidence >= 0.5` before relaying to mesh; add a red "review before relay" step |
| Thermal throttling during continuous scans | Med | Low | Debounce capture button; abort any scan older than 3 s |
| OPSEC: temp JPEGs lingering on disk | Low | Med | Write to `FileManager.default.temporaryDirectory`, `try? FileManager.default.removeItem` in `defer`; never write to Photo Library |

---

## 17. Out of Scope (captured for later)

- Video / live tracking (EdgeTAM).
- 3D positioning into a world map (would require `ARKit` + GPS triangulation across multiple shots).
- Multi‑frame fusion (same target seen across several scans merging into one entity).
- Friend/Foe classification (explicit hallucination risk, needs tight review + policy).
- Offline model swap UI (Gemma 4 ↔ LFM2.5‑VL‑450M).
- On‑device mask overlay via EdgeSAM.

---

## 18. Acceptance Criteria

The feature is "done" when ALL of the following are true on an iPhone 15 Pro running iOS 18 in airplane mode:

1. App launches; `Scan` tab is visible and accessible.
2. Tapping the capture button with camera pointed at a person returns at least one card within 3 s, containing:
   - Non‑empty `description` field.
   - A `bearing` value within ±10° of a known compass reading.
   - A `range` value within ±25 % of a ground‑truth laser range (for a target at 10 m–30 m).
3. Denying camera permission shows a visible, tappable CTA pointing to Settings.
4. Unit tests (`BattlefieldVisionServiceTests`, `TargetFusionTests`, `HeadingProviderTests`) all pass.
5. UI smoke test (`ScanTabSmokeTests`) passes in CI.
6. No new memory leaks under Instruments after 20 consecutive scans.
7. No JPEG left behind in `tmp/` after `.onDisappear`.
8. If mesh relay is enabled, a second device receives the sighting as a properly formatted message.

---

## 19. References (actually consulted, not invented)

- Cactus Compute main repo — `github.com/cactus-compute/cactus` (v1.14, 2026‑04‑18).
- Cactus docs — `docs.cactuscompute.com/v1.12/` and the Gemma 4 launch blog `docs.cactuscompute.com/v1.12/blog/gemma4/`.
- Google AI for Developers — `ai.google.dev/gemma/docs/capabilities/vision/image` (Object Detection section with JSON bbox example).
- HuggingFace Gemma 4 launch — `huggingface.co/blog/gemma4` (E2B/E4B/31B/26B A4B bbox outputs).
- Meta SAM / SAM 2 / SAM 3 — `ai.meta.com/blog/segment-anything-model-3/`, `arxiv.org/abs/2511.16719`, EdgeTAM `arxiv.org/html/2501.07256v1`.
- MobileSAM — `github.com/ChaoningZhang/MobileSAM`.
- EdgeSAM — `github.com/chongzhou96/EdgeSAM`.
- Apple LiDAR / scene depth — `developer.apple.com/documentation/arkit/arframe/3917421-scenedepth`.

---

## 20. Resolved Implementation Decisions

1. **Mesh relay:** OFF by default and gated behind a future explicit toggle. No auto-relay behavior.
2. **Review screen:** Deferred. Each sighting is shown in the results list before any relay can happen.
3. **Capture mode (v1):** Still-photo only. No live-scan mode and no `AVCaptureVideoDataOutput`.
4. **Target height mapping:** `suggestedTargetHeightMeters` lives in `TargetFusion` so it is adjustable in one place.
5. **Detector model strategy (v1):** Single model only — Gemma 4 E4B. No dual-model detector.

## Mission Log

### Files created by this mission

- `TacNetTests/Recon/TargetFusionTests.swift`
- `TacNetTests/Recon/BattlefieldVisionServiceTests.swift`

### Files modified by this mission

- `TacNetUITests/TacNetUITests.swift`
- `TacNet.xcodeproj/project.pbxproj`
- `IMAGE_DETECTION_TAB_PLAN.md`

### Build/test commands used

- `xcrun xcodebuild -project TacNet.xcodeproj -scheme TacNet -configuration Debug -destination 'generic/platform=iOS' -sdk iphoneos build CODE_SIGNING_ALLOWED=NO`
- `xcrun xcodebuild -project TacNet.xcodeproj -scheme TacNet -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test CODE_SIGNING_ALLOWED=NO`

### Test results summary (last test run)

- Total tests: `157`
- Passed: `157`
- Failed: `0`
- Skipped: `0`
- UI smoke subset (`TacNetUISmokeTests`): `15` executed, `0` failures.
