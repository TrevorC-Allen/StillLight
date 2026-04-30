# StillLight

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
- Front/back camera switch
- Flash mode: off / on / auto
- Exposure compensation
- Tap to focus and meter
- Grid lines and horizon level
- Haptic shutter feedback
- Aspect ratios: 3:2, 4:3, 1:1
- 8 film presets:
  - Sunlit Gold 200
  - Soft Portrait 400
  - Silver HP5
  - Green Street 400
  - Tungsten 800
  - Pocket Flash
  - CCD 2003
  - Instant Square
- Film simulation pipeline:
  - orientation-aware downsampling
  - center crop
  - exposure correction
  - temperature and tint shift
  - contrast and saturation
  - tone curve
  - halation
  - vignette
  - light leak
  - luminance-aware grain
  - timestamp
  - simple paper border
- Processed photo export to Photos
- Film metadata written into exported JPEG metadata
- Optional original photo retention
- Local JSON photo records
- Roll gallery and photo detail
- Import Lab with PhotosPicker, strength control and shared pipeline processing
- Local smart film recommendation based on image brightness, color, warmth and contrast
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

- Add long-press original/processed comparison in Lab
- Add batch import queue
- Enable the prepared app icon asset catalog after the local Xcode install has an iOS simulator runtime
- Move LUT, grain and vignette into Metal for realtime preview
- Replace local smart recommendation with Vision/CoreML scene tags later
