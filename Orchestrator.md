# Orchestrator: Recon (Battlefield Scan) Tab — Mission Build Spec

> Single-mission spec for building out the new **Recon** tab in TacNet. This file is the **source of truth** the mission-mode agent will consume. Everything below is scoped to a single mission with deterministic acceptance criteria.

---

## 0. Mission Statement (one sentence)

Ship a fully on-device battlefield-scan tab in the TacNet iPhone app that uses the already-bundled Cactus xcframework + Gemma 4 E4B model to detect targets in a still photo and return, for each target, a **description**, a **true-north bearing**, and a **metric distance** — with zero network calls after install.

---

## 1. Non-Negotiable Constraints

1. **100 % on-device.** No network, no cloud, no remote model. Re-use `CactusModelInitializationService.shared` — do **not** load a second model handle.
2. **Swift-only.** No Python, no Node, no new native C/C++.
3. **No new third-party SPM dependencies.** Only Apple frameworks + the vendored Cactus xcframework already in `Frameworks/cactus-ios.xcframework`.
4. **Must build clean** for:
   - `-destination 'generic/platform=iOS'` (arm64 device)
   - `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (arm64 simulator)
   The x86_64 simulator slice is permitted to stay red because Cactus doesn't ship x86_64 — this is pre-existing and out of scope.
5. **All 14 pre-existing UI smoke tests must still pass** on iPhone 17 Pro simulator.
6. **Branch**: work happens on `image-detection` branch. Do **not** merge to `main`.
7. **No emojis** anywhere in source, tests, docs, or commits.

---

## 2. What Already Exists in the Branch

The previous implementation pass already landed in `image-detection` (unstaged / untracked). Re-use — do **not** re-author — these files:

| Path                                                      | Purpose                                                               |
| --------------------------------------------------------- | --------------------------------------------------------------------- |
| `TacNet/Models/TargetSighting.swift`                      | `TargetSighting`, `NormalizedBox` (Gemma 0–1000 grid), `RawDetection` |
| `TacNet/Services/TargetFusion.swift`                      | Pure math: bearing, pinhole distance, class → real-world height       |
| `TacNet/Services/BattlefieldVisionService.swift`          | `actor` wrapping `cactusComplete`; `ReconScanMode`; JSON parsing       |
| `TacNet/Services/HeadingProvider.swift`                   | `CLLocationManager` true-north heading                                |
| `TacNet/Services/RangeProvider.swift`                     | `ARSession.sceneDepth` LiDAR sampling                                 |
| `TacNet/Services/CameraCaptureService.swift`              | `AVCaptureSession .photo` + FoV metadata                              |
| `TacNet/Views/CameraPreviewRepresentable.swift`           | `AVCaptureVideoPreviewLayer` in SwiftUI                               |
| `TacNet/ViewModels/ReconViewModel.swift`                  | `@MainActor` VM: scan pipeline, intent presets, mode, status          |
| `TacNet/Views/ReconView.swift`                            | Tab UI: viewfinder, bbox overlay, presets, sighting rows              |

And these files were **modified** to wire the tab in:

- `TacNet/Views/ContentView.swift` — added `.recon` case + `TacNetTabShellView` + `AppNetworkCoordinator.reconViewModel`
- `TacNet/Resources/Info.plist` — added `NSCameraUsageDescription`, `NSMotionUsageDescription`, updated location string
- `TacNet/Utilities/FrameworkImportsProbe.swift` — added `import ARKit` + `_ = ARSession.self`
- `TacNet.xcodeproj/project.pbxproj` — added ARKit + 10 Swift files to groups, sources build phase, frameworks build phase

**Do not revert any of these files. Start from this state.**

---

## 3. What the Mission Must Deliver

The mission has **five tracks**. Each track is independently mergeable but all must ship.

### Track A — Unit Tests for Fusion + Vision (required)

Create the following test files under `TacNetTests/`:

1. `TacNetTests/Recon/TargetFusionTests.swift`
2. `TacNetTests/Recon/BattlefieldVisionServiceTests.swift`

Required coverage:

#### `TargetFusionTests`

- `testBearingAtCenter_returnsHeading` — centroid at x=500 with hFoV=68, heading=90 → bearing == 90 (±0.01).
- `testBearingAtLeftEdge_subtractsHalfFoV` — centroid at x=0 with hFoV=68, heading=0 → bearing == 326 (±0.5, wraps below 0).
- `testBearingAtRightEdge_addsHalfFoV` — centroid at x=1000 with hFoV=68, heading=0 → bearing == 34 (±0.5).
- `testBearingWrapsAt360` — heading=350 + offset=20 → normalized to 10.
- `testBearingReturnsNil_whenHeadingNil`.
- `testPinholeDistance_knownGeometry` — 1.75 m target, 4032×3024 image, vFoV=51, box height 20 % of frame → ~7.9 m (±5 %).
- `testPinholeDistance_returnsNil_onDegenerateBox` — box with height 0.
- `testSuggestedHeight_coversCanonicalLabels` — `person` → 1.75, `truck` → 2.5, `drone` → 0.4, `car` → 1.5, unknown label → `nil`.
- `testFuse_preferLidar_overPinhole` — when `lidarRangeMeters != nil`, `rangeSource == .lidar`.
- `testFuse_rejectsInvalidBox` — box with `xMax <= xMin` → returns `nil`.

#### `BattlefieldVisionServiceTests`

- `testBuildMessagesJSON_containsSystemPromptAndImagePath`
- `testBuildMessagesJSON_includesCactusNativeImagesField` — asserts the user message has `images: ["<path>"]`.
- `testBuildOptionsJSON_tokenBudget_matchesMode` — quick/standard/detail → 280/560/1120.
- `testParseDetections_happyPath` — array of two detections decodes cleanly.
- `testParseDetections_stripsMarkdownFence` — `\`\`\`json\n[...]\n\`\`\`` decodes.
- `testParseDetections_returnsEmptyForEmptyArray`.
- `testParseDetections_returnsEmptyForNonJSON` — "no targets visible." → `[]`.
- `testParseDetections_filtersOutBadBoxLengths` — detections with `box_2d.count != 4` dropped.
- `testScan_invokesInjectedCompleteFunctionOnce` — using a synchronous stub completion closure (do **not** call the real Cactus model in unit tests).

Use the existing `completeFunction:` injection point on `BattlefieldVisionService.init` to stub the model.

Register both test files in `project.pbxproj` under the `TacNetTests` target's Sources build phase (new PBXBuildFile + PBXFileReference IDs are already reserved: `F1A1001400000000000001B4`, `F1A1001500000000000001B5`, `F1A1001600000000000001B6`, `F1A1001700000000000001B7`).

### Track B — UI Smoke Test for Recon Tab (required)

Add to `TacNetUITests/TacNetUITests.swift` (extend the existing `TacNetUISmokeTests` class, do not create a new test file):

- `testReconTabAppearsAndRendersEmptyState` — from the post-onboarding tab shell, tap the **Recon** tab item, assert `tacnet.recon.root` exists, assert `tacnet.recon.emptyState` is visible, assert the scan button (`tacnet.recon.scanButton`) exists. Must not require granting camera permission.
- Update the existing `testMainTreeDataFlowSettingsTabsRenderAndSwitch` to iterate over the new 5-tab layout (recon between main and treeView).

### Track C — Documentation & Handoff (required)

1. Update `IMAGE_DETECTION_TAB_PLAN.md` section 20 by replacing open questions with the actual implementation choices that landed:
   - Mesh relay: **off by default**, gated behind a future explicit toggle. No auto-relay.
   - Review screen: deferred; each sighting is shown in the results list before any relay is possible.
   - Still-photo only for v1 (no live-scan, no AVCaptureVideoDataOutput).
   - `suggestedTargetHeightMeters` table lives in `TargetFusion`; adjustable in one place.
   - Single model (Gemma 4 E4B). No dual-model detector.
2. Append a **“Mission Log”** section to `IMAGE_DETECTION_TAB_PLAN.md` listing every file created/modified and the build/test commands that verified them.

Do **not** touch `README.md`, `DECISIONS.md`, `SETUP_LOG.md`, or `MANUAL_TESTING.md`.

### Track D — Pinhole Fallback Sanity Check (required)

Author a runnable XCTest sanity assertion inside `TargetFusionTests`:

- Given a synthetic `RawDetection` with `label: "person"`, box `[400, 450, 900, 550]` (box height 50% of frame), image size 4032×3024, vFoV 51°, heading 0, **no** LiDAR → expected range ~3.3 m (±10 %), `rangeSource == .pinhole`, bearing ~0° (±1°).

This locks the fallback math against regressions.

### Track E — Commit & PR Hygiene (required)

1. Single commit per track, `git add -p`-style, **no mass adds**. Use Conventional Commits:
   - `feat(recon): add unit tests for TargetFusion`
   - `feat(recon): add unit tests for BattlefieldVisionService`
   - `test(ui): verify recon tab renders empty state`
   - `docs(recon): resolve open questions + mission log`
2. Run `git status` and `git diff --cached` **before every commit** and paste the summary in the commit body.
3. Include this footer on every commit:
   ```
   Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>
   ```
4. **Do not push.** The user will push manually.

---

## 4. Out of Scope (explicit)

The following are **explicitly deferred** — do not implement them in this mission:

- Mesh relay of sightings (no changes to `BluetoothMeshService`).
- Live / video-rate detection (no `AVCaptureVideoDataOutput` or per-frame inference).
- Review & confirm screen before a sighting is logged.
- SAM / MobileSAM / SAM 3 integration (Cactus doesn't ship segmentation).
- CoreML fallback detector.
- Persisting sightings to disk or SwiftData.
- Voice readout of sightings (no AVSpeechSynthesizer work).
- Settings UI for the Recon tab.
- x86_64 simulator link fix — the Cactus xcframework just doesn't ship that slice.

---

## 5. Interfaces the Mission Agent May Rely On

```swift
// Already-built Cactus entry point (Services/Cactus.swift)
public func cactusComplete(
    _ model: CactusModelT,
    _ messagesJson: String,
    _ optionsJson: String?,
    _ toolsJson: String?,
    _ onToken: ((String, UInt32) -> Void)?,
    _ pcmData: Data?
) throws -> String

// Already-built service handle (Services/Cactus.swift)
public actor CactusModelInitializationService {
    public static let shared: CactusModelInitializationService
    public func initializeModelAfterEnsuringDownload(progressHandler: ...) async throws -> CactusModelT
}

// Recon vision actor (Services/BattlefieldVisionService.swift)
public actor BattlefieldVisionService {
    public init(
        modelInitializationService: CactusModelInitializationService = .shared,
        completeFunction: @escaping CompleteFunction = { ... },
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        jpegQuality: CGFloat = 0.85
    )
    public func scan(image: UIImage, intent: String, mode: ReconScanMode) async throws -> [RawDetection]
    // static helpers (internal) for tests:
    static let systemPrompt: String
    static func buildMessagesJSON(intent: String, imageURL: URL) throws -> String
    static func buildOptionsJSON(mode: ReconScanMode) -> String
    static func parseDetections(from response: String) throws -> [RawDetection]
}
```

When testing `BattlefieldVisionService`, stub the `completeFunction` closure — the Cactus model must **not** be loaded in unit tests.

---

## 6. Exact Build & Test Commands (agent must use these)

```bash
# Device build (must be green):
xcrun xcodebuild \
  -project TacNet.xcodeproj \
  -scheme TacNet \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -sdk iphoneos \
  build \
  CODE_SIGNING_ALLOWED=NO

# Simulator build + test (must be green):
xcrun xcodebuild \
  -project TacNet.xcodeproj \
  -scheme TacNet \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test \
  CODE_SIGNING_ALLOWED=NO
```

If the simulator refuses to launch the app with `Application failed preflight checks / Busy`, it means another xcodebuild instance is running — **kill it and retry once**, don't start hacking.

---

## 7. Acceptance Criteria (machine-checkable)

A mission run is **DONE** iff **all of** the following are true:

1. `git status` shows clean tree on `image-detection` except for the new test files and doc edits this mission created.
2. `xcodebuild build` succeeds for both `iphoneos` and `iPhone 17 Pro` simulator destinations.
3. `xcodebuild test` on `iPhone 17 Pro` reports:
   - **All previous 14 UI smoke tests passing.**
   - **All new `TargetFusionTests` passing (≥ 11 tests).**
   - **All new `BattlefieldVisionServiceTests` passing (≥ 9 tests).**
   - **New `testReconTabAppearsAndRendersEmptyState` UI test passing.**
4. The 3 or 4 Conventional-Commit commits described in Track E exist in `git log --oneline -10` with the correct footer.
5. No changes outside:
   - `TacNetTests/Recon/**`
   - `TacNetUITests/**`
   - `IMAGE_DETECTION_TAB_PLAN.md`
   - `Orchestrator.md` (this file; no changes expected)
   - `TacNet.xcodeproj/project.pbxproj` (only to register new test files)

If any of the above fails, the mission agent **must self-heal** (fix + re-run) before returning control. Don't hand back a red tree.

---

## 8. Risks & Mitigations

| Risk                                                                            | Mitigation                                                                                   |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Cactus model loads in unit tests and blows the 6.44 GB download                 | Always inject a stub `completeFunction`; never touch `.shared` in `setUp`.                   |
| ARKit session fails on non-LiDAR devices                                        | Already handled: `RangeProvider.mode == .unavailable` → `TargetFusion` falls back to pinhole. |
| Flaky UI test because camera permission sheet appears                           | New UI test runs on the empty-state branch before ever tapping scan.                         |
| `project.pbxproj` merge conflicts                                               | Use reserved IDs from section 3 Track A; do not renumber existing entries.                   |
| Gemma emits prose before the JSON array                                         | `parseDetections` locates the outermost `[` and `]` and slices between them.                  |

---

## 9. Hand-off Checklist (mission agent must produce)

At mission end, produce a single markdown report containing:

1. Files added (path + SHA after commit).
2. Files modified (path + diff line count).
3. Build command outputs (last 20 lines each).
4. Test count summary: `<suite>: <passed>/<total>`.
5. Any deferred TODO items with rationale.

Send this report back to the orchestrator. The user will review it before pushing.

---

## 10. One-Line Summary for the Mission Agent

> **Add unit + UI tests for the Recon tab that already exists on `image-detection`, update `IMAGE_DETECTION_TAB_PLAN.md` open questions, register new test files in `project.pbxproj`, and prove everything stays green on iPhone 17 Pro simulator. No new features, no pushes, no scope creep.**
