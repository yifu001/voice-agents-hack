# MeshNode — setup

An iPhone-only Bluetooth mesh chat app with on-device LLM (Gemma 4 E2B) and STT (Parakeet CTC 0.6B). Everything runs locally; no network after install.

The repo does **not** include the model weights (~7 GB) or the Cactus xcframework (~9 MB). You build/download those locally before opening Xcode.

## Prerequisites

- macOS with Xcode 15+ (iOS 17 SDK)
- [Homebrew](https://brew.sh)
- An Apple Developer account (free tier is fine) for signing
- ~8 GB free disk space
- For running on-device: an iPhone 12 or newer with a Lightning/USB-C cable

## One-time setup (~15–20 minutes)

### 1. Install `xcodegen`

```bash
brew install xcodegen
```

### 2. Clone this repo

```bash
git clone <this-repo-url> MeshNode
cd MeshNode
```

The paths below assume you're in the repo root.

### 3. Clone and build the Cactus engine

Cactus is a separate repo. Clone it next to this one:

```bash
cd ..
git clone https://github.com/cactus-compute/cactus
cd cactus
source ./setup
cactus build --apple
```

This builds `cactus-ios.xcframework` inside `cactus/apple/`. Takes ~1–2 minutes.

### 4. Authenticate with Cactus

You need a Cactus API key from [the dashboard](https://cactuscompute.com/dashboard/api-keys).

```bash
cactus auth
# paste your token when prompted
```

### 5. Download the two models

```bash
cactus download google/gemma-4-e2b-it           # ~5 GB download, ~6.3 GB extracted
cactus download nvidia/parakeet-ctc-0.6b        # ~700 MB
```

The weights land under `cactus/weights/`.

### 6. Wire everything into the Xcode project

From the `cactus/` directory:

```bash
# xcframework
cp -R apple/cactus-ios.xcframework ../MeshNode/ios/Vendor/

# Swift wrapper (the xcframework already ships with it, but the project expects
# it inside the target's source tree)
cp apple/Cactus.swift ../MeshNode/ios/MeshNode/LLM/

# Model weights
cp -R weights/gemma-4-e2b-it ../MeshNode/ios/MeshNode/Models/
cp -R weights/parakeet-ctc-0.6b ../MeshNode/ios/MeshNode/Models/
```

One more fix-up — the xcframework built by Cactus ships without a `Modules/module.modulemap`, which Swift needs to import it. Add it to both slices:

```bash
cd ../MeshNode/ios/Vendor/cactus-ios.xcframework
for slice in ios-arm64 ios-arm64-simulator; do
  mkdir -p "$slice/cactus.framework/Modules"
  cp ../../../../cactus/apple/module.modulemap \
     "$slice/cactus.framework/Modules/module.modulemap"
done
cd ../..
```

### 7. Generate the Xcode project

```bash
cd ios
xcodegen generate
open MeshNode.xcodeproj
```

### 8. Set your signing team

In Xcode: project navigator → `MeshNode` target → **Signing & Capabilities** → pick your Apple ID under *Team*. XcodeGen intentionally leaves this blank so signing stays personal to each contributor.

### 9. Build and run on a real iPhone

Plug in an iPhone 13 or newer, select it as the destination, press ⌘R. First install is slow (~5 minutes) because it has to transfer ~7 GB of model weights over cable. Subsequent runs are fast; Xcode only pushes what changed.

On first launch the app also copies Parakeet's weights from the read-only bundle into Application Support so Cactus can persist its compiled Core ML cache. Expect the first voice-model load to take ~10 seconds longer than subsequent launches.

## What to expect on launch

1. Pick a node identity (A / B / C / D).
2. Mesh connects to any other iPhone in range running the same app + node.
3. Gemma loads on a background thread (15–60 s on iPhone 13). The Retrieval tab's **Answer** button is disabled until it's ready.
4. Parakeet loads in parallel (~5 s). The mic icons light up when it's ready.
5. Send a message by typing or by pressing-and-holding the mic. Messages broadcast across the mesh.
6. The **Node** tab filters incoming messages per the bundled `graph.json` — some pass through verbatim, others get summarised by Gemma.
7. The **Retrieval** tab answers free-form questions about what your node has seen, with configurable context radius.

## Updating Cactus / models later

- **New Cactus engine**: re-run `cactus build --apple`, re-copy `cactus-ios.xcframework` and `Cactus.swift`, re-add the modulemap, `xcodegen generate`.
- **New model weights**: `cactus download <model>`, re-copy into `ios/MeshNode/Models/`, regenerate the project.

## Common issues

- **"Missing fmt chunk" at transcribe time**: the `AudioRecorder` writes a hand-built RIFF WAV; make sure you haven't edited `makeWAV` in `AudioRecorder.swift` without keeping the header byte-accurate.
- **"Unable to find module dependency: 'cactus'"**: the modulemap copy in step 6 didn't happen. Re-run the `for slice in …` loop.
- **Linker complains about `x86_64`**: you're on an Intel Mac, or on Apple Silicon but the simulator slice is being skipped. The project sets `EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64` specifically to avoid this on Apple Silicon; if you're on Intel, you'll need to instead rebuild Cactus with an x86_64 simulator slice (currently unsupported upstream).
- **App crashes on model load**: OOM. iPhone 13 with both models loaded is very tight; closing other apps and rebooting the phone usually helps.
- **Mic permission denied**: the first mic press triggers the system dialog. If denied, toggle it back on under iOS Settings → MeshNode → Microphone.
- **"Upgrade's application-identifier entitlement … does not match installed application's"**: the phone already has a MeshNode install signed by a different Apple Developer team, and iOS won't cross-sign an upgrade. **Delete the existing MeshNode from the phone** (long-press → Remove App → Delete App), then run from Xcode again. If multiple contributors share a phone, either use a per-contributor `PRODUCT_BUNDLE_IDENTIFIER` (e.g. `com.cactushack.MeshNode.<your-name>` — don't commit) or share the same Apple Developer team.
