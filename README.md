# StillLight

[中文文档](README.zh-CN.md) | English

StillLight is an iOS-only film camera MVP built with SwiftUI, AVFoundation,
CoreImage and Photos. It is designed as a portfolio-grade camera product: a real
shooting loop, a Dazz-like film roll drawer, and a modular image pipeline that
can be explained and tested stage by stage.

```text
Choose a film roll
-> Shoot with the custom camera or import photos into the lab
-> Develop through the film pipeline
-> Save to the local roll and Photos
-> Review, compare and share the result
```

## Product Focus

- A quiet native camera experience: live preview, tap focus/metering, exposure
  compensation, flash, lens zoom buttons, haptics, grid, horizon and frame guide.
- A Dazz-like film library with 27 original film/camera presets rendered as
  physical objects: paper boxes, canisters, instant packs, sleeves, disposable
  cameras, half-frame tickets and camera bodies.
- Three flagship directions for the current build:
  - `Human Warm 400`: humanistic cafes, interiors and street life.
  - `Shadow Walk 800`: moody street, museum and architecture frames with heavier
    vignette and deeper blacks.
  - `Soft Muse 400`: soft portraits with warmer skin, lifted shadows and protected
    highlights.
- Real sample direction for portfolio review: shoot actual iPhone frames in cafe
  interiors, window-light portraits, evening streets, museums, architecture
  corridors, instant-style tabletops and CCD-like campus/daylight scenes. Preset
  thumbnails should communicate these moods instead of relying on numbers alone.
- Chinese documentation mode for demos and interviews: the Chinese README and
  `docs/zh-CN/` explain MVP scope, architecture, presets, performance, device
  runbook, AI recommendation and demo script in a product-facing narrative.

## Technical Highlights

StillLight is not a single-filter app. Each roll controls a deterministic film
rendering pipeline:

```text
Captured JPEG / Imported Image
-> Orientation-aware downsampling or normalization
-> 3200px high-quality processing path
-> Aspect-ratio center crop
-> Exposure, temperature, tint, contrast and saturation
-> Tone Curve
-> Highlight / shadow adjustment
-> Film Rendering Profile
-> Tone Separation and film color response
-> Highlight-masked warm halation
-> Soft radial lens falloff
-> Stable seeded light leak
-> Luminance-aware grain and finishing texture with skin protection
-> Timestamp, paper / instant / white-frame border and camera label
-> JPEG export with StillLight film metadata
```

Video exports reuse the preview-safe Core Image portion of the same film stack:
exposure, white balance, tone curve, local rendering, color response, halation,
vignette and light leak are applied through `AVVideoComposition` before the movie
is saved locally and exported to Photos.

The key portfolio talking points are:

- `Film Rendering Profile`: local micro-contrast, midtone softness, highlight
  recovery and skin-aware finishing make each roll feel rendered, not just tinted.
- `Tone Separation`: shadows, midtones and highlights are treated with different
  color and contrast behavior before grain, borders and labels are applied.
- Shared processing path: camera capture, Import Lab and video export use the
  same film response stages, so direct captures, imported photos and movies stay
  visually coherent.
- Observable performance: Import Lab reports total processing time, input/output
  pixels and stage timings for pipeline-level QA.

## MVP Scope

- AVFoundation photo capture and native video recording with audio, timer and
  film-rendered export.
- Front/back camera switch, flash off/on/auto, exposure compensation, tap
  focus/metering and animated reticle.
- Pinch zoom plus available lens buttons such as 0.5x / 1x / 3x on multi-camera
  iPhones.
- Capture ratios: 3:2, 4:3, 1:1, 16:9 and Half.
- Non-blocking capture flow: the lower-left recent-frame thumbnail updates after
  processing instead of forcing a result sheet.
- Persistent film roll counter and local JSON photo records.
- Gallery detail browsing with page swipe and a constrained long-press original
  comparison gesture that does not block horizontal paging.
- Import Lab with multi-photo selection, current/all develop, cancellable batch
  progress, failed-frame retry, current/all save and shared pipeline processing.
- Explainable local Top 3 film recommendation based on brightness, color, warmth
  and contrast.
- English / Chinese UI switch, share sheet and optional original photo retention.

## Film Library

The current library contains 27 original presets across featured, portrait, color
negative, classic camera, instant, black-and-white, digital and experimental
categories. Representative rolls include:

- Human Warm 400
- Shadow Walk 800
- Soft Muse 400
- Sunlit Gold 200
- Soft Portrait 400
- Silver HP5
- Green Street 400
- Tungsten 800
- Pocket Flash
- CCD 2003
- Instant Square
- HNCS Natural
- M Rangefinder Color
- GR Street Snap
- Medium 500C
- Instant Wide
- Half Frame Diary

See `docs/PRESETS.md` for the complete preset table, physical object mapping and
sample-shot acceptance direction.

## Acceptance Checklist

MVP acceptance:

- Build succeeds with `scripts/build_unsigned.sh`.
- On a real iPhone, camera preview opens, focus/metering/zoom/exposure controls
  respond, and capture produces a processed still.
- The selected roll changes both visual rendering and frame labeling.
- `Human Warm 400`, `Shadow Walk 800` and `Soft Muse 400` are validated on real
  cafe/interior, street/museum and portrait sample sets.
- A short video recorded with a selected roll exports with the same film color
  response and then clears its saved-to-Photos status message automatically.
- Import Lab can process multiple imported photos, cancel a batch, retry failures
  and save the selected or full set.
- Processed photos are saved locally first, then exported to Photos when
  permission allows, with StillLight metadata written to JPEG.
- Chinese documentation mode is usable from `README.zh-CN.md` and
  `docs/zh-CN/README.md`.

Next-step acceptance:

- Add real 3D LUT / `CIColorCube` assets for the three flagship rolls and compare
  them against the current procedural profiles.
- Move preview-safe tone, grain and vignette stages toward Metal for real-time
  camera preview.
- Add frame-safe grain and optional timestamp overlays to video after export
  performance is measured on a real iPhone.
- Replace the heuristic recommender with Vision/CoreML scene tags when there is a
  larger real sample set.
- Support user-generated custom rolls from 5-10 reference photos.

## Project Structure

```text
StillLight/
├── StillLight.xcodeproj
├── StillLight/
│   ├── App/              # app entry, root tab, shared state
│   ├── Camera/           # AVFoundation session, preview, camera UI
│   ├── Film/             # film presets, library and picker
│   ├── ImagePipeline/    # CoreImage + grain + timestamp + borders
│   ├── Export/           # Photos export and file writing
│   ├── Gallery/          # local roll records and photo detail
│   ├── ImportLab/        # imported-photo developing workflow
│   ├── AI/               # local film recommendation heuristics
│   ├── Settings/         # MVP settings
│   ├── UI/               # shared UI helpers
│   ├── Resources/        # asset catalog, app icon and accent color
│   └── Supporting/       # Info.plist and permissions
├── docs/
│   ├── zh-CN/
│   ├── DEVICE_RUNBOOK.md
│   ├── IOS_ARCHITECTURE.md
│   ├── MVP.md
│   └── PRESETS.md
└── scripts/
    ├── build_unsigned.sh
    ├── check_ios_device.sh
    └── run_on_iphone.sh
```

## Build

Open `StillLight.xcodeproj` with Xcode and run the `StillLight` target on a real
iPhone.

CLI compile check:

```sh
scripts/build_unsigned.sh
```

Device readiness check:

```sh
scripts/check_ios_device.sh
```

After a real iPhone is connected, trusted and signed through Xcode Accounts, run:

```sh
scripts/run_on_iphone.sh
```

See `docs/DEVICE_RUNBOOK.md` for the exact iPhone setup flow.
