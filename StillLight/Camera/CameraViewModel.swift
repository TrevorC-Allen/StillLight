import CoreImage
import SwiftUI
import UIKit

enum CameraCaptureMode {
    case photo
    case video
}

enum CameraCreativeCaptureMode: String, CaseIterable, Identifiable {
    case standard
    case doubleExposure
    case longExposure

    var id: String { rawValue }
}

enum CameraDoubleExposureBlendMode: String, CaseIterable, Identifiable {
    case screen
    case multiply
    case softLight

    var id: String { rawValue }
}

enum CameraDoubleExposurePhase: Equatable {
    case idle
    case waitingForSecondShot
    case processingComposite
}

struct CameraDoubleExposureState {
    var phase: CameraDoubleExposurePhase = .idle
    var blendMode: CameraDoubleExposureBlendMode = .screen
    var firstShotPreview: UIImage?
    var firstCapturedAt: Date?

    var hasBufferedFirstShot: Bool {
        firstShotPreview != nil
    }
}

enum CameraLongExposurePhase: Equatable {
    case idle
    case collectingFrames
    case processingFrames
    case completed
}

struct CameraLongExposureState {
    var phase: CameraLongExposurePhase = .idle
    var request: CameraLongExposureRequest = .standard
    var capturedFrameCount = 0
    var totalFrameCount = CameraLongExposureRequest.standard.frameCount
    var isMultiFrameApproximation = true

    var progress: Double {
        guard totalFrameCount > 0 else { return 0 }
        return Double(capturedFrameCount) / Double(totalFrameCount)
    }
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
    @Published var creativeCaptureMode: CameraCreativeCaptureMode = .standard
    @Published var doubleExposureState = CameraDoubleExposureState()
    @Published var longExposureState = CameraLongExposureState()
    @Published var whiteBalanceState: CameraWhiteBalanceState = .auto
    @Published var starburstIntensity: Double = 0

    let cameraService = CameraService()
    private var recordingStartedAt: Date?
    private var recordingTimer: Timer?
    private var statusClearTask: Task<Void, Never>?
    private var statusToken = UUID()
    private var doubleExposureBuffer: CameraDoubleExposureBuffer?

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
                    self?.refreshWhiteBalanceState()
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
        guard !isRecording, !isProcessing else { return }
        cameraService.switchCamera { [weak self] state in
            DispatchQueue.main.async {
                self?.permissionState = state
                self?.refreshZoomState()
                self?.refreshWhiteBalanceState()
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

    func updateWhiteBalanceKelvin(_ kelvin: Double) {
        var nextState = whiteBalanceState
        nextState.kelvin = Float(kelvin).clamped(to: nextState.minKelvin...nextState.maxKelvin)
        nextState.isLocked = true
        whiteBalanceState = nextState

        cameraService.setWhiteBalanceKelvin(nextState.kelvin, tint: nextState.tint) { [weak self] state in
            DispatchQueue.main.async {
                self?.whiteBalanceState = state
            }
        }
    }

    func resetWhiteBalance() {
        cameraService.resetWhiteBalanceToAuto { [weak self] state in
            DispatchQueue.main.async {
                self?.whiteBalanceState = state
            }
        }
    }

    func updateStarburstIntensity(_ value: Double) {
        starburstIntensity = value.clamped(to: 0...1)
    }

    func focus(at point: CGPoint) {
        cameraService.focus(at: point)
    }

    func setCaptureMode(_ mode: CameraCaptureMode) {
        guard !isRecording else { return }
        captureMode = mode
        clearStatus()
    }

    func setCreativeCaptureMode(_ mode: CameraCreativeCaptureMode) {
        guard !isRecording, !isProcessing else { return }
        creativeCaptureMode = mode
        clearStatus()

        if mode != .doubleExposure {
            resetDoubleExposureBuffer()
        }
    }

    func setDoubleExposureEnabled(_ isEnabled: Bool) {
        setCreativeCaptureMode(isEnabled ? .doubleExposure : .standard)
    }

    func updateDoubleExposureBlendMode(_ mode: CameraDoubleExposureBlendMode) {
        doubleExposureState.blendMode = mode
    }

    func resetDoubleExposureBuffer() {
        doubleExposureBuffer = nil
        doubleExposureState.phase = .idle
        doubleExposureState.firstShotPreview = nil
        doubleExposureState.firstCapturedAt = nil
    }

    func updateLongExposureDuration(_ duration: TimeInterval) {
        longExposureState.request = CameraLongExposureRequest(
            duration: duration,
            frameCount: longExposureState.request.frameCount
        ).normalized
        longExposureState.totalFrameCount = longExposureState.request.frameCount
    }

    func updateLongExposureFrameCount(_ frameCount: Int) {
        longExposureState.request = CameraLongExposureRequest(
            duration: longExposureState.request.duration,
            frameCount: frameCount
        ).normalized
        longExposureState.totalFrameCount = longExposureState.request.frameCount
    }

    func primaryAction(appState: AppState) {
        switch captureMode {
        case .photo:
            switch creativeCaptureMode {
            case .standard:
                capture(appState: appState)
            case .doubleExposure:
                captureDoubleExposure(appState: appState)
            case .longExposure:
                captureLongExposure(appState: appState)
            }
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
        let starburstIntensity = starburstIntensity

        cameraService.capturePhoto(flashMode: flash) { [weak self] captureResult in
            Task { @MainActor in
                await self?.processCapture(
                    captureResult,
                    film: film,
                    aspectRatio: aspectRatio,
                    saveOriginal: saveOriginal,
                    addTimestamp: addTimestamp,
                    jpegQuality: quality,
                    starburstIntensity: starburstIntensity,
                    appState: appState
                )
            }
        }
    }

    func captureDoubleExposure(appState: AppState) {
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
        let blendMode = doubleExposureState.blendMode
        let starburstIntensity = starburstIntensity

        cameraService.capturePhoto(flashMode: flash) { [weak self] captureResult in
            Task { @MainActor in
                await self?.processDoubleExposureCapture(
                    captureResult,
                    film: film,
                    aspectRatio: aspectRatio,
                    saveOriginal: saveOriginal,
                    addTimestamp: addTimestamp,
                    jpegQuality: quality,
                    blendMode: blendMode,
                    starburstIntensity: starburstIntensity,
                    appState: appState
                )
            }
        }
    }

    func captureLongExposure(appState: AppState) {
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
        let request = longExposureState.request.normalized
        let starburstIntensity = starburstIntensity

        longExposureState.phase = .collectingFrames
        longExposureState.capturedFrameCount = 0
        longExposureState.totalFrameCount = request.frameCount
        longExposureState.isMultiFrameApproximation = request.frameCount > 1

        cameraService.captureLongExposure(
            request: request,
            flashMode: flash,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.longExposureState.capturedFrameCount = progress.capturedFrameCount
                    self?.longExposureState.totalFrameCount = progress.totalFrameCount
                }
            },
            completion: { [weak self] captureResult in
                Task { @MainActor in
                    await self?.processLongExposureCapture(
                        captureResult,
                        film: film,
                        aspectRatio: aspectRatio,
                        saveOriginal: saveOriginal,
                        addTimestamp: addTimestamp,
                        jpegQuality: quality,
                        starburstIntensity: starburstIntensity,
                        appState: appState
                    )
                }
            }
        )
    }

    private func processCapture(
        _ captureResult: Result<Data, Error>,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        saveOriginal: Bool,
        addTimestamp: Bool,
        jpegQuality: Double,
        starburstIntensity: Double,
        appState: AppState
    ) async {
        do {
            let data = try captureResult.get()
            let processedImage = try await Task.detached(priority: .userInitiated) {
                let image = try FilmImagePipeline.process(
                    photoData: data,
                    film: film,
                    aspectRatio: aspectRatio,
                    date: Date(),
                    addTimestamp: addTimestamp
                )
                return try CameraCreativeImageComposer.applyStarburst(
                    to: image,
                    intensity: starburstIntensity
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

    private func processDoubleExposureCapture(
        _ captureResult: Result<Data, Error>,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        saveOriginal: Bool,
        addTimestamp: Bool,
        jpegQuality: Double,
        blendMode: CameraDoubleExposureBlendMode,
        starburstIntensity: Double,
        appState: AppState
    ) async {
        do {
            let data = try captureResult.get()
            let captureDate = Date()
            let processedImage = try await Task.detached(priority: .userInitiated) {
                try FilmImagePipeline.process(
                    photoData: data,
                    film: film,
                    aspectRatio: aspectRatio,
                    date: captureDate,
                    addTimestamp: addTimestamp
                )
            }.value

            guard let firstShot = doubleExposureBuffer else {
                doubleExposureBuffer = CameraDoubleExposureBuffer(
                    processedImage: processedImage,
                    originalData: data,
                    capturedAt: captureDate
                )
                doubleExposureState.phase = .waitingForSecondShot
                doubleExposureState.firstShotPreview = processedImage
                doubleExposureState.firstCapturedAt = captureDate
                showTransientStatus(appState.t(.doubleExposureFirstBuffered), durationNanoseconds: 4_000_000_000)
                isProcessing = false
                return
            }

            doubleExposureState.phase = .processingComposite
            let compositeImage = try await Task.detached(priority: .userInitiated) {
                let image = try CameraCreativeImageComposer.blend(
                    firstShot.processedImage,
                    processedImage,
                    mode: blendMode
                )
                return try CameraCreativeImageComposer.applyStarburst(
                    to: image,
                    intensity: starburstIntensity
                )
            }.value

            let exportResult = try await PhotoExporter.export(
                processedImage: compositeImage,
                originalData: saveOriginal ? data : nil,
                film: film,
                aspectRatio: aspectRatio,
                jpegQuality: jpegQuality,
                photosSaveFailedPrefix: appState.t(.photosSaveFailed)
            )

            appState.photoStore.add(exportResult.record)
            appState.recordShot()
            latestResult = CaptureResult(
                image: compositeImage,
                record: exportResult.record,
                warningMessage: exportResult.warningMessage
            )
            resetDoubleExposureBuffer()
            if let warningMessage = exportResult.warningMessage {
                showTransientStatus(warningMessage, durationNanoseconds: 4_000_000_000)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func processLongExposureCapture(
        _ captureResult: Result<CameraLongExposureCapture, Error>,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        saveOriginal: Bool,
        addTimestamp: Bool,
        jpegQuality: Double,
        starburstIntensity: Double,
        appState: AppState
    ) async {
        do {
            let capture = try captureResult.get()
            guard let originalData = capture.frameData.first else {
                throw ImagePipelineError.cannotCreateImage
            }

            longExposureState.phase = .processingFrames
            let processedImages = try await Task.detached(priority: .userInitiated) {
                try capture.frameData.map { data in
                    try FilmImagePipeline.process(
                        photoData: data,
                        film: film,
                        aspectRatio: aspectRatio,
                        date: Date(),
                        addTimestamp: addTimestamp
                    )
                }
            }.value
            let compositeImage = try await Task.detached(priority: .userInitiated) {
                let image = try CameraCreativeImageComposer.longExposureComposite(processedImages)
                return try CameraCreativeImageComposer.applyStarburst(
                    to: image,
                    intensity: starburstIntensity
                )
            }.value

            let exportResult = try await PhotoExporter.export(
                processedImage: compositeImage,
                originalData: saveOriginal ? originalData : nil,
                film: film,
                aspectRatio: aspectRatio,
                jpegQuality: jpegQuality,
                photosSaveFailedPrefix: appState.t(.photosSaveFailed)
            )

            appState.photoStore.add(exportResult.record)
            appState.recordShot()
            latestResult = CaptureResult(
                image: compositeImage,
                record: exportResult.record,
                warningMessage: exportResult.warningMessage
            )
            longExposureState.phase = .completed
            if let warningMessage = exportResult.warningMessage {
                showTransientStatus(warningMessage, durationNanoseconds: 4_000_000_000)
            } else if capture.isMultiFrameApproximation {
                showTransientStatus(String(format: appState.t(.longExposureFramesBlended), capture.frameData.count))
            }
        } catch {
            errorMessage = error.localizedDescription
            longExposureState.phase = .idle
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
        let film = appState.selectedFilm

        cameraService.startVideoRecording { [weak self] recordingResult in
            Task { @MainActor in
                await self?.processVideoRecording(
                    recordingResult,
                    film: film,
                    successMessage: successMessage,
                    saveFailedPrefix: saveFailedPrefix
                )
            }
        }
    }

    private func processVideoRecording(
        _ recordingResult: Result<URL, Error>,
        film: FilmPreset,
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
                film: film,
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
        statusToken = UUID()
        statusMessage = nil
        errorMessage = nil
    }

    private func showTransientStatus(
        _ message: String,
        durationNanoseconds: UInt64 = 2_200_000_000
    ) {
        let token = UUID()
        statusToken = token
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
                guard self?.statusToken == token else { return }
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

    private func refreshWhiteBalanceState() {
        cameraService.currentWhiteBalanceState { [weak self] state in
            DispatchQueue.main.async {
                self?.whiteBalanceState = state
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

private struct CameraDoubleExposureBuffer {
    let processedImage: UIImage
    let originalData: Data
    let capturedAt: Date
}

private enum CameraCreativeImageComposer {
    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any
    ])

    static func blend(
        _ firstImage: UIImage,
        _ secondImage: UIImage,
        mode: CameraDoubleExposureBlendMode
    ) throws -> UIImage {
        guard let first = CIImage(image: firstImage),
              let second = CIImage(image: secondImage) else {
            throw ImagePipelineError.cannotCreateImage
        }

        let extent = first.extent
        let preparedSecond = fit(second, to: extent)
        let blended = applyBlend(
            foreground: preparedSecond,
            background: first.cropped(to: extent),
            mode: mode
        ).cropped(to: extent)

        return try render(blended, scale: firstImage.scale)
    }

    static func longExposureComposite(_ images: [UIImage]) throws -> UIImage {
        guard let firstImage = images.first,
              let first = CIImage(image: firstImage) else {
            throw ImagePipelineError.cannotCreateImage
        }

        let extent = first.extent
        let composed = try images.dropFirst().reduce(first.cropped(to: extent)) { partial, image in
            guard let next = CIImage(image: image) else {
                throw ImagePipelineError.cannotCreateImage
            }
            let preparedNext = fit(next, to: extent)
            return applyBlend(
                foreground: preparedNext,
                background: partial,
                mode: .screen
            ).cropped(to: extent)
        }

        return try render(composed, scale: firstImage.scale)
    }

    static func applyStarburst(to image: UIImage, intensity: Double) throws -> UIImage {
        let amount = intensity.clamped(to: 0...1)
        guard amount > 0.01 else { return image }

        let points = highlightPoints(in: image, maxPoints: Int(2 + amount * 5))
        guard !points.isEmpty else { return image }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: image.size)
            image.draw(in: rect)

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.setBlendMode(.screen)
            points.enumerated().forEach { index, point in
                drawStar(
                    at: point,
                    index: index,
                    intensity: amount,
                    imageSize: image.size,
                    context: cgContext
                )
            }
            cgContext.restoreGState()
        }
    }

    private static func fit(_ image: CIImage, to targetExtent: CGRect) -> CIImage {
        let scaleX = targetExtent.width / max(image.extent.width, 1)
        let scaleY = targetExtent.height / max(image.extent.height, 1)
        return image
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: targetExtent)
    }

    private static func applyBlend(
        foreground: CIImage,
        background: CIImage,
        mode: CameraDoubleExposureBlendMode
    ) -> CIImage {
        let filterName: String
        switch mode {
        case .screen:
            filterName = "CIScreenBlendMode"
        case .multiply:
            filterName = "CIMultiplyBlendMode"
        case .softLight:
            filterName = "CISoftLightBlendMode"
        }

        guard let filter = CIFilter(name: filterName) else {
            return foreground
        }
        filter.setValue(foreground, forKey: kCIInputImageKey)
        filter.setValue(background, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage ?? foreground
    }

    private static func highlightPoints(in image: UIImage, maxPoints: Int) -> [CGPoint] {
        guard let cgImage = image.cgImage else { return [] }

        let sampleWidth = 36
        let sampleHeight = 36
        let bytesPerRow = sampleWidth * 4
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        pixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: sampleWidth,
                    height: sampleHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else {
                return
            }

            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        }

        var candidates: [(point: CGPoint, luminance: Double)] = []
        for y in 1..<(sampleHeight - 1) {
            for x in 1..<(sampleWidth - 1) {
                let offset = y * bytesPerRow + x * 4
                let red = Double(pixels[offset])
                let green = Double(pixels[offset + 1])
                let blue = Double(pixels[offset + 2])
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                guard luminance > 188 else { continue }

                let normalizedPoint = CGPoint(
                    x: (CGFloat(x) + 0.5) / CGFloat(sampleWidth) * image.size.width,
                    y: (CGFloat(sampleHeight - y) + 0.5) / CGFloat(sampleHeight) * image.size.height
                )
                candidates.append((normalizedPoint, luminance))
            }
        }

        let minimumDistance = min(image.size.width, image.size.height) * 0.16
        var selected: [CGPoint] = []
        for candidate in candidates.sorted(by: { $0.luminance > $1.luminance }) {
            guard selected.allSatisfy({ distance($0, candidate.point) > minimumDistance }) else {
                continue
            }
            selected.append(candidate.point)
            if selected.count >= maxPoints {
                break
            }
        }
        return selected
    }

    private static func drawStar(
        at point: CGPoint,
        index: Int,
        intensity: Double,
        imageSize: CGSize,
        context: CGContext
    ) {
        let shortSide = min(imageSize.width, imageSize.height)
        let baseLength = shortSide * CGFloat(0.055 + 0.060 * intensity)
        let baseAlpha = CGFloat(0.18 + 0.34 * intensity)
        let rotation = CGFloat(index % 3) * .pi / 12
        let angles: [CGFloat] = [0, .pi / 4, .pi / 2, .pi * 3 / 4]

        for (rayIndex, angle) in angles.enumerated() {
            let rayScale: CGFloat = rayIndex.isMultiple(of: 2) ? 1.0 : 0.58
            let length = baseLength * rayScale
            let lineWidth = max(1.0, shortSide * CGFloat(0.0014 + 0.0014 * intensity))
            let alpha = baseAlpha * (rayIndex.isMultiple(of: 2) ? 1.0 : 0.62)
            let adjustedAngle = angle + rotation
            let dx = cos(adjustedAngle) * length
            let dy = sin(adjustedAngle) * length

            context.setStrokeColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: point.x - dx, y: point.y - dy))
            context.addLine(to: CGPoint(x: point.x + dx, y: point.y + dy))
            context.strokePath()
        }

        let glowRadius = max(2, shortSide * CGFloat(0.010 + 0.012 * intensity))
        context.setFillColor(UIColor.white.withAlphaComponent(baseAlpha * 0.35).cgColor)
        context.fillEllipse(in: CGRect(
            x: point.x - glowRadius / 2,
            y: point.y - glowRadius / 2,
            width: glowRadius,
            height: glowRadius
        ))
    }

    private static func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    private static func render(_ image: CIImage, scale: CGFloat) throws -> UIImage {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw ImagePipelineError.cannotRenderImage
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
