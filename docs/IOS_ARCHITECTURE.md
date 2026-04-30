# iOS Architecture

StillLight is now scoped as an iOS-only project.

## Stack

- SwiftUI for UI
- AVFoundation for camera preview, focus, exposure, photo capture, movie recording and virtual-device zoom
- CoreImage for the MVP film pipeline
- Photos for saving developed images
- JSON document storage for MVP photo records and current film roll state
- PhotosUI for multi-photo Import Lab selection
- CoreMotion for horizon level
- Lightweight in-app English / Chinese text table for fast portfolio iteration
- Metal later for realtime preview and GPU film effects

## MVP Modules

```text
SwiftUI App
-> CameraScreen
-> CameraService
-> VideoExporter
-> FilmPreset / FilmLibrary / FilmRollStore
-> AppLanguage / AppText
-> FilmImagePipeline
-> PhotoExporter
-> PhotoStore
-> GalleryScreen
-> ImportLabScreen
-> FilmRecommender
```

## Camera Capture

```text
AVCaptureSession
-> best available camera device: triple / dual-wide / dual / wide fallback
-> AVCaptureVideoPreviewLayer
-> tap focus and exposure
-> pinch zoom plus 0.5x / 1x / 3x style lens controls when available
-> AVCapturePhotoOutput
-> non-blocking recent-frame thumbnail
-> FilmImagePipeline
-> PhotoExporter
```

## Import Lab

```text
PhotosPicker multi-selection
-> downsampled in-memory LabFrame queue
-> per-frame local film recommendation
-> selected-frame preview and horizontal queue
-> develop current frame or all frames through FilmImagePipeline
-> save current frame or all developed frames through PhotoExporter
-> PhotoStore records and best-effort Photos save
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
-> timestamp / instant, paper or white-frame border
-> camera/model frame label
-> JPEG export
-> JPEG metadata
-> local PhotoRecord
-> best-effort Photos save
```

## Video MVP

```text
AVCaptureMovieFileOutput
-> temporary .mov recording
-> local Documents/StillLight/Videos copy
-> best-effort Photos video save
```

The current video MVP records native camera video with audio. Film-processed video is intentionally deferred until the realtime Metal path exists.

## Near-Term iOS Roadmap

- Replace JSON store with SwiftData after the product model stabilizes
- Add LUT loading through CoreImage `CIColorCube`
- Move grain, vignette and LUT into Metal shaders for realtime preview
- Replace heuristic recommendation with Vision/CoreML scene tags
