# iOS Architecture

StillLight is now scoped as an iOS-only project.

## Stack

- SwiftUI for UI
- AVFoundation for camera preview, focus, exposure and capture
- CoreImage for the MVP film pipeline
- Photos for saving developed images
- JSON document storage for MVP photo records
- PhotosUI for imported-photo Lab
- CoreMotion for horizon level
- Metal later for realtime preview and GPU film effects

## MVP Modules

```text
SwiftUI App
-> CameraScreen
-> CameraService
-> FilmPreset / FilmLibrary
-> FilmImagePipeline
-> PhotoExporter
-> PhotoStore
-> GalleryScreen
-> ImportLabScreen
-> FilmRecommender
```

## Pipeline

```text
Captured JPEG
-> downsample with orientation transform
-> aspect-ratio crop
-> exposure correction
-> temperature / tint
-> contrast / saturation
-> tone curve
-> halation
-> vignette
-> light leak
-> luminance-aware grain
-> timestamp / paper border
-> JPEG export
-> JPEG metadata
-> Photos save
-> local PhotoRecord
```

## Near-Term iOS Roadmap

- Replace JSON store with SwiftData after the product model stabilizes
- Add LUT loading through CoreImage `CIColorCube`
- Move grain, vignette and LUT into Metal shaders for realtime preview
- Replace heuristic recommendation with Vision/CoreML scene tags
