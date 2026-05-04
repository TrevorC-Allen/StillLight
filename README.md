# StillLight

[中文文档](README.zh-CN.md) | English

StillLight is an iOS-only quiet film-camera MVP built with SwiftUI, AVFoundation and CoreImage.

The first version focuses on one complete loop:

```text
Choose a film roll
-> Shoot with a custom camera
-> Develop through a modular image pipeline
-> Save to Photos
-> Keep a local roll record
```

## MVP Features

- Live camera preview with AVFoundation
- Photo capture
- Native video recording with audio, recording timer and Photos export
- Front/back camera switch
- Flash mode: off / on / auto
- Exposure compensation
- Tap to focus and meter with animated focus reticle
- Native-like zoom with pinch gesture and available lens buttons such as 0.5x / 1x / 3x on multi-camera iPhones
- Non-blocking capture flow: processed shots update the lower-left recent-frame thumbnail instead of opening an automatic result sheet
- Aspect-ratio frame guide, grid lines and horizon level
- Haptic shutter feedback
- Aspect ratios: 3:2, 4:3, 1:1, 16:9, Half
- Lightweight film roll counter with persistent remaining shots
- Mechanical-style exposure counter in the film drawer
- Dazz-like style library with 27 switchable film/camera presets across featured, portrait, color negative, classic camera, instant, black-and-white, digital and experimental categories
- Tuned scene-first presets for the current product direction: Human Warm 400, Shadow Walk 800 and Soft Muse 400
- HNCS-inspired natural color, compact rangefinder, GR-style street, 500C medium-format, half-frame diary, CCD and instant looks
- Dazz-inspired physical film drawer with individually drawn film boxes, canisters, instant packs, paper sleeves, disposable cameras, half-frame tickets and camera bodies
- Per-roll miniature sample scenes embedded in film objects, so rolls communicate a visual mood instead of only numbers and icons
- Deterministic paper wear, package speckles, contact shadows, shelf depth and layered lens glass drawn in SwiftUI
- White-frame and instant/paper border output with the selected camera/model label burned into the exported image
- English / Chinese UI switch in Settings
- 27 film presets, including:
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
- Film simulation pipeline:
  - orientation-aware downsampling
  - high-quality 3200px processing path
  - center crop
  - exposure correction
  - temperature and tint shift
  - contrast and saturation
  - tone curve
  - highlight/shadow adjustment
  - film rendering profiles for local micro-contrast, midtone softness and highlight recovery
  - film-specific color response matrix
  - highlight-masked warm halation
  - soft radial lens falloff
  - stable seeded light leaks
  - luminance-aware finishing texture with skin protection
  - imperfect timestamp rendering
  - textured instant, paper and white-frame borders
  - camera/model frame label
- Processed photo export to local Roll first, then Photos when permission allows
- Film metadata written into exported JPEG metadata
- Optional original photo retention
- Local JSON photo records
- Roll gallery with page swipe detail browsing and long-press original comparison
- Import Lab with multi-photo PhotosPicker selection, current/all developing, cancellable batch progress, failed-frame retry, current/all save and shared pipeline processing
- Import Lab preview supports horizontal swiping across selected imported frames
- Import Lab processing timing summary with total milliseconds, input/output pixels and pipeline stage timings
- Explainable local smart film recommendation with Top 3 candidates based on brightness, color, warmth and contrast
- Share sheet

## Project Structure

```text
StillLight/
├── StillLight.xcodeproj
├── StillLight/
│   ├── App/              # app entry, root tab, shared state
│   ├── Camera/           # AVFoundation session, preview, camera UI
│   ├── Film/             # film presets and picker
│   ├── ImagePipeline/    # CoreImage + grain + timestamp processing
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

Open `StillLight.xcodeproj` with Xcode and run the `StillLight` target on a real iPhone.

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

## Next Steps

- Add real 3D LUT / CIColorCube assets for the flagship rolls
- Move preview-safe tone, grain and vignette stages into Metal for realtime camera preview
- Apply film processing to video export and eventually live recording
- Replace local smart recommendation with Vision/CoreML scene tags later
- Add user-generated custom rolls from a small reference photo set
