import SwiftUI

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var permissionState: CameraPermissionState = .unknown
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var exposureBias: Double = 0
    @Published var flashMode: CameraFlashMode = .off
    @Published var result: CaptureResult?

    let cameraService = CameraService()

    func start() {
        cameraService.configure { [weak self] state in
            DispatchQueue.main.async {
                self?.permissionState = state
                if state == .authorized {
                    self?.cameraService.start()
                }
            }
        }
    }

    func stop() {
        cameraService.stop()
    }

    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        }
    }

    func switchCamera() {
        cameraService.switchCamera { [weak self] state in
            DispatchQueue.main.async {
                self?.permissionState = state
            }
        }
    }

    func updateExposureBias(_ value: Double) {
        exposureBias = value
        cameraService.setExposureBias(Float(value))
    }

    func focus(at point: CGPoint) {
        cameraService.focus(at: point)
    }

    func capture(appState: AppState) {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil

        if appState.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        let film = appState.selectedFilm
        let aspectRatio = appState.selectedAspectRatio
        let saveOriginal = appState.saveOriginalPhoto
        let addTimestamp = appState.addTimestamp
        let quality = appState.jpegQuality
        let flash = flashMode

        cameraService.capturePhoto(flashMode: flash) { [weak self] captureResult in
            Task { @MainActor in
                await self?.processCapture(
                    captureResult,
                    film: film,
                    aspectRatio: aspectRatio,
                    saveOriginal: saveOriginal,
                    addTimestamp: addTimestamp,
                    jpegQuality: quality,
                    photoStore: appState.photoStore
                )
            }
        }
    }

    private func processCapture(
        _ captureResult: Result<Data, Error>,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        saveOriginal: Bool,
        addTimestamp: Bool,
        jpegQuality: Double,
        photoStore: PhotoStore
    ) async {
        do {
            let data = try captureResult.get()
            let processedImage = try await Task.detached(priority: .userInitiated) {
                try FilmImagePipeline.process(
                    photoData: data,
                    film: film,
                    aspectRatio: aspectRatio,
                    date: Date(),
                    addTimestamp: addTimestamp
                )
            }.value

            let record = try await PhotoExporter.export(
                processedImage: processedImage,
                originalData: saveOriginal ? data : nil,
                film: film,
                aspectRatio: aspectRatio,
                jpegQuality: jpegQuality
            )

            photoStore.add(record)
            result = CaptureResult(image: processedImage, record: record)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}

struct CaptureResult: Identifiable {
    let id = UUID()
    let image: UIImage
    let record: PhotoRecord
}
