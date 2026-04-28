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
│   ├── Resources/        # asset catalog placeholder
│   └── Supporting/       # Info.plist and permissions
└── docs/
    └── MVP.md
```

## Build

Open `StillLight.xcodeproj` with Xcode and run the `StillLight` target on a real iPhone.

CLI compile check used:

```sh
xcodebuild -project StillLight.xcodeproj \
  -target StillLight \
  -configuration Debug \
  -sdk iphoneos26.4 \
  build CODE_SIGNING_ALLOWED=NO
```

The app compiles with the installed iOS SDK. The local machine currently has no available simulator runtime, so simulator launching may require installing one from Xcode settings.

## Next Steps

- Add a real app icon and enable the asset catalog in the build phase
- Add long-press original/processed comparison in Lab
- Add batch import queue
- Move LUT, grain and vignette into Metal for realtime preview
- Replace local smart recommendation with Vision/CoreML scene tags later
