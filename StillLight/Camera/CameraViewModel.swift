import SwiftUI

enum CameraCaptureMode {
    case photo
    case video
}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var permissionState: CameraPermissionState = .unknown
    @Published var isProcessing = false
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var exposureBias: Double = 0
    @Published var flashMode: CameraFlashMode = .off
    @Published var captureMode: CameraCaptureMode = .photo
    @Published var result: CaptureResult?

    let cameraService = CameraService()
    private var recordingStartedAt: Date?
    private var recordingTimer: Timer?

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
        if isRecording {
            cameraService.stopVideoRecording()
            stopRecordingTimer()
            isRecording = false
        }
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
        guard !isRecording else { return }
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

    func setCaptureMode(_ mode: CameraCaptureMode) {
        guard !isRecording else { return }
        captureMode = mode
        statusMessage = nil
        errorMessage = nil
    }

    func primaryAction(appState: AppState) {
        switch captureMode {
        case .photo:
            capture(appState: appState)
        case .video:
            toggleVideoRecording(appState: appState)
        }
    }

    func capture(appState: AppState) {
        guard !isProcessing, !isRecording else { return }
        isProcessing = true
        errorMessage = nil
        statusMessage = nil

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
                    appState: appState
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
        appState: AppState
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

            let exportResult = try await PhotoExporter.export(
                processedImage: processedImage,
                originalData: saveOriginal ? data : nil,
                film: film,
                aspectRatio: aspectRatio,
                jpegQuality: jpegQuality,
                photosSaveFailedPrefix: appState.t(.photosSaveFailed)
            )

            appState.photoStore.add(exportResult.record)
            appState.recordShot()
            result = CaptureResult(
                image: processedImage,
                record: exportResult.record,
                warningMessage: exportResult.warningMessage
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func toggleVideoRecording(appState: AppState) {
        if isRecording {
            cameraService.stopVideoRecording()
            if appState.enableHaptics {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            return
        }

        guard !isProcessing else { return }
        isRecording = true
        errorMessage = nil
        statusMessage = nil
        recordingDuration = 0
        recordingStartedAt = Date()
        startRecordingTimer()

        if appState.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        let saveFailedPrefix = appState.t(.videoSaveFailed)
        let successMessage = appState.t(.videoSaved)

        cameraService.startVideoRecording { [weak self] recordingResult in
            Task { @MainActor in
                await self?.processVideoRecording(
                    recordingResult,
                    successMessage: successMessage,
                    saveFailedPrefix: saveFailedPrefix
                )
            }
        }
    }

    private func processVideoRecording(
        _ recordingResult: Result<URL, Error>,
        successMessage: String,
        saveFailedPrefix: String
    ) async {
        stopRecordingTimer()
        isRecording = false

        do {
            let temporaryURL = try recordingResult.get()
            isProcessing = true
            let exportResult = try await VideoExporter.export(
                temporaryURL: temporaryURL,
                photosSaveFailedPrefix: saveFailedPrefix
            )
            statusMessage = exportResult.warningMessage ?? successMessage
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recordingStartedAt = self.recordingStartedAt else { return }
                self.recordingDuration = Date().timeIntervalSince(recordingStartedAt)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartedAt = nil
    }
}

struct CaptureResult: Identifiable {
    let id = UUID()
    let image: UIImage
    let record: PhotoRecord
    let warningMessage: String?
}
