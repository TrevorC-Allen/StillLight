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
    @Published var zoomState: CameraZoomState = .standard
    @Published var latestResult: CaptureResult?

    let cameraService = CameraService()
    private var recordingStartedAt: Date?
    private var recordingTimer: Timer?
    private var statusClearTask: Task<Void, Never>?

    deinit {
        recordingTimer?.invalidate()
        statusClearTask?.cancel()
    }

    func start() {
        cameraService.configure { [weak self] state in
            DispatchQueue.main.async {
                self?.permissionState = state
                if state == .authorized {
                    self?.cameraService.start()
                    self?.refreshZoomState()
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
                self?.refreshZoomState()
            }
        }
    }

    func setZoomFactor(_ displayFactor: CGFloat) {
        cameraService.setZoomDisplayFactor(displayFactor) { [weak self] state in
            DispatchQueue.main.async {
                self?.zoomState = state
            }
        }
    }

    func zoomByPinch(_ magnification: CGFloat, from startFactor: CGFloat) {
        setZoomFactor(startFactor * magnification)
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
        clearStatus()
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
        clearStatus()

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
            latestResult = CaptureResult(
                image: processedImage,
                record: exportResult.record,
                warningMessage: exportResult.warningMessage
            )
            if let warningMessage = exportResult.warningMessage {
                showTransientStatus(warningMessage, durationNanoseconds: 4_000_000_000)
            }
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
        clearStatus()
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
            if let warningMessage = exportResult.warningMessage {
                showTransientStatus(warningMessage, durationNanoseconds: 4_000_000_000)
            } else {
                showTransientStatus(successMessage)
            }
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

    private func clearStatus() {
        statusClearTask?.cancel()
        statusClearTask = nil
        statusMessage = nil
        errorMessage = nil
    }

    private func showTransientStatus(
        _ message: String,
        durationNanoseconds: UInt64 = 2_200_000_000
    ) {
        statusMessage = message
        statusClearTask?.cancel()
        statusClearTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: durationNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.statusMessage == message else { return }
                self?.statusMessage = nil
                self?.statusClearTask = nil
            }
        }
    }

    private func refreshZoomState() {
        cameraService.currentZoomState { [weak self] state in
            DispatchQueue.main.async {
                self?.zoomState = state
            }
        }
    }
}

struct CaptureResult: Identifiable {
    let id = UUID()
    let image: UIImage
    let record: PhotoRecord
    let warningMessage: String?
}
