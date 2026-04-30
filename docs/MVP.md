# StillLight MVP

StillLight is an iOS-only fast MVP for a quiet film-camera app: choose a roll, shoot, develop, save.

## MVP Scope

- AVFoundation live camera preview
- Photo capture with flash, front/back switch, exposure compensation and tap focus
- Animated focus reticle after tap focus
- Aspect-ratio frame guide, camera grid and horizon level
- Capture ratios: 3:2, 4:3, 1:1, 16:9 and Half
- Persistent current film roll with remaining-shot counter
- 8 film presets:
  - Sunlit Gold 200
  - Soft Portrait 400
  - Silver HP5
  - Green Street 400
  - Tungsten 800
  - Pocket Flash
  - CCD 2003
  - Instant Square
- CoreImage pipeline:
  - orientation-aware downsampling
  - aspect-ratio center crop
  - exposure
  - temperature/tint
  - contrast/saturation
  - tone curve
  - halation
  - vignette
  - light leak
  - CPU film grain
  - timestamp and simple paper border
- Save processed image to local StillLight Roll first, then Photos when permission allows
- Write StillLight film metadata into exported JPEG metadata
- Optional original capture retention in app documents
- Local JSON photo records
- App roll/gallery and photo detail with long-press original comparison
- Import Lab:
  - PhotosPicker image import
  - shared film pipeline processing
  - strength control
  - local smart film recommendation

## Not In MVP

- Real-time film preview
- RAW/HEIC export
- LUT authoring UI
- cloud multimodal AI
- batch import
- full roll archive/history
- cloud sync

## Run

Open `StillLight.xcodeproj` in Xcode and run the `StillLight` scheme on a real iPhone.

The iOS simulator can build the app, but it cannot provide a physical camera feed.

For the exact device checklist, run:

```sh
scripts/check_ios_device.sh
```
