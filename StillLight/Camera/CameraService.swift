import AVFoundation
import Foundation

enum CameraPermissionState {
    case unknown
    case authorized
    case denied
    case unavailable
}

enum CameraFlashMode: String, CaseIterable {
    case off
    case on
    case auto

    var iconName: String {
        switch self {
        case .off:
            return "bolt.slash"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.a"
        }
    }

    var avMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off:
            return .off
        case .on:
            return .on
        case .auto:
            return .auto
        }
    }
}

struct CameraLensOption: Identifiable, Equatable {
    let displayFactor: CGFloat

    var id: CGFloat { displayFactor }

    var label: String {
        if displayFactor < 1 {
            return String(format: "%.1f", displayFactor)
        }
        if displayFactor.rounded() == displayFactor {
            return "\(Int(displayFactor))"
        }
        return String(format: "%.1f", displayFactor)
    }
}

struct CameraZoomState: Equatable {
    var displayFactor: CGFloat
    var minDisplayFactor: CGFloat
    var maxDisplayFactor: CGFloat
    var lensOptions: [CameraLensOption]

    static let standard = CameraZoomState(
        displayFactor: 1,
        minDisplayFactor: 1,
        maxDisplayFactor: 1,
        lensOptions: [CameraLensOption(displayFactor: 1)]
    )

    var displayFactorText: String {
        if displayFactor < 1 {
            return String(format: "%.1f", displayFactor)
        }
        if displayFactor.rounded() == displayFactor {
            return "\(Int(displayFactor))"
        }
        return String(format: "%.1f", displayFactor)
    }
}

struct CameraWhiteBalanceState: Equatable {
    static let auto = CameraWhiteBalanceState(
        kelvin: 6500,
        tint: 0,
        minKelvin: 2500,
        maxKelvin: 9000,
        isLocked: false,
        isSupported: true
    )

    var kelvin: Float
    var tint: Float
    let minKelvin: Float
    let maxKelvin: Float
    var isLocked: Bool
    var isSupported: Bool

    var kelvinText: String {
        "\(Int(kelvin.rounded()))K"
    }
}

struct CameraLongExposureRequest: Equatable {
    var duration: TimeInterval
    var frameCount: Int

    static let standard = CameraLongExposureRequest(duration: 1.2, frameCount: 4)

    var normalized: CameraLongExposureRequest {
        CameraLongExposureRequest(
            duration: duration.clamped(to: 0.3...8.0),
            frameCount: frameCount.clamped(to: 1...12)
        )
    }

    var frameInterval: TimeInterval {
        let request = normalized
        guard request.frameCount > 1 else { return 0 }
        return request.duration / TimeInterval(request.frameCount - 1)
    }
}

struct CameraLongExposureFrameProgress: Equatable {
    let capturedFrameCount: Int
    let totalFrameCount: Int

    var fractionCompleted: Double {
        guard totalFrameCount > 0 else { return 0 }
        return Double(capturedFrameCount) / Double(totalFrameCount)
    }
}

struct CameraLongExposureCapture {
    let frameData: [Data]
    let requestedDuration: TimeInterval
    let actualDuration: TimeInterval

    var isMultiFrameApproximation: Bool {
        frameData.count > 1
    }
}

final class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.stilllight.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var photoDelegate: PhotoCaptureDelegate?
    private var movieDelegate: MovieCaptureDelegate?
    private var zoomDisplayScale: CGFloat = 1
    private var preferredWhiteBalanceKelvin: Float?
    private var preferredWhiteBalanceTint: Float = 0
    private(set) var position: AVCaptureDevice.Position = .back

    func checkPermission(_ completion: @escaping (CameraPermissionState) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(.authorized)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted ? .authorized : .denied)
            }
        case .denied, .restricted:
            completion(.denied)
        @unknown default:
            completion(.denied)
        }
    }

    func configure(completion: @escaping (CameraPermissionState) -> Void) {
        checkPermission { [weak self] state in
            guard state == .authorized else {
                completion(state)
                return
            }

            self?.sessionQueue.async {
                guard let self else { return }
                do {
                    try self.configureSession(position: self.position)
                    completion(.authorized)
                } catch {
                    completion(.unavailable)
                }
            }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func switchCamera(completion: @escaping (CameraPermissionState) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.movieOutput.isRecording else {
                completion(.authorized)
                return
            }
            let newPosition: AVCaptureDevice.Position = self.position == .back ? .front : .back
            do {
                try self.configureSession(position: newPosition)
                self.position = newPosition
                completion(.authorized)
            } catch {
                completion(.unavailable)
            }
        }
    }

    func currentZoomState(completion: @escaping (CameraZoomState) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoInput?.device else {
                completion(.standard)
                return
            }
            completion(self.zoomState(for: device))
        }
    }

    func setZoomDisplayFactor(_ displayFactor: CGFloat, completion: @escaping (CameraZoomState) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoInput?.device else {
                completion(.standard)
                return
            }

            do {
                try device.lockForConfiguration()
                let rawFactor = self.rawZoomFactor(forDisplayFactor: displayFactor, device: device)
                device.videoZoomFactor = rawFactor
                device.unlockForConfiguration()
            } catch {
                completion(self.zoomState(for: device))
                return
            }

            completion(self.zoomState(for: device))
        }
    }

    func setExposureBias(_ bias: Float) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(clamped)
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    func currentWhiteBalanceState(completion: @escaping (CameraWhiteBalanceState) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoInput?.device else {
                completion(.auto)
                return
            }

            completion(self.whiteBalanceState(for: device))
        }
    }

    func setWhiteBalanceKelvin(
        _ kelvin: Float,
        tint: Float = 0,
        completion: ((CameraWhiteBalanceState) -> Void)? = nil
    ) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoInput?.device else {
                completion?(.auto)
                return
            }

            let clampedKelvin = kelvin.clamped(to: CameraWhiteBalanceState.auto.minKelvin...CameraWhiteBalanceState.auto.maxKelvin)
            self.preferredWhiteBalanceKelvin = clampedKelvin
            self.preferredWhiteBalanceTint = tint
            self.applyWhiteBalance(kelvin: clampedKelvin, tint: tint, on: device)
            completion?(self.whiteBalanceState(for: device))
        }
    }

    func resetWhiteBalanceToAuto(completion: ((CameraWhiteBalanceState) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoInput?.device else {
                completion?(.auto)
                return
            }

            self.preferredWhiteBalanceKelvin = nil
            self.preferredWhiteBalanceTint = 0

            do {
                try device.lockForConfiguration()
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                } else if device.isWhiteBalanceModeSupported(.autoWhiteBalance) {
                    device.whiteBalanceMode = .autoWhiteBalance
                }
                device.unlockForConfiguration()
            } catch {
                completion?(self.whiteBalanceState(for: device))
                return
            }

            completion?(self.whiteBalanceState(for: device))
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    func capturePhoto(flashMode: CameraFlashMode, completion: @escaping (Result<Data, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            self.configureVideoConnection(self.photoOutput.connection(with: .video))

            if self.photoOutput.supportedFlashModes.contains(flashMode.avMode) {
                settings.flashMode = flashMode.avMode
            }
            if self.photoOutput.maxPhotoQualityPrioritization.rawValue >= AVCapturePhotoOutput.QualityPrioritization.balanced.rawValue {
                settings.photoQualityPrioritization = .balanced
            }

            let delegate = PhotoCaptureDelegate { [weak self] result in
                completion(result)
                self?.photoDelegate = nil
            }
            self.photoDelegate = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func captureLongExposure(
        request: CameraLongExposureRequest,
        flashMode: CameraFlashMode,
        progress: @escaping (CameraLongExposureFrameProgress) -> Void,
        completion: @escaping (Result<CameraLongExposureCapture, Error>) -> Void
    ) {
        let safeRequest = request.normalized
        let startedAt = Date()
        var frames: [Data] = []

        func captureFrame(at index: Int) {
            guard index < safeRequest.frameCount else {
                completion(.success(CameraLongExposureCapture(
                    frameData: frames,
                    requestedDuration: safeRequest.duration,
                    actualDuration: Date().timeIntervalSince(startedAt)
                )))
                return
            }

            let delay = index == 0 ? 0 : safeRequest.frameInterval
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                let captureFlash = safeRequest.frameCount == 1 ? flashMode : .off
                self.capturePhoto(flashMode: captureFlash) { result in
                    switch result {
                    case .success(let data):
                        frames.append(data)
                        progress(CameraLongExposureFrameProgress(
                            capturedFrameCount: frames.count,
                            totalFrameCount: safeRequest.frameCount
                        ))
                        captureFrame(at: index + 1)
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }

        captureFrame(at: 0)
    }

    func startVideoRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        let startRecording = { [weak self] in
            self?.sessionQueue.async {
                guard let self, !self.movieOutput.isRecording else { return }
                do {
                    try self.configureAudioInputIfAllowed()
                    let outputURL = try self.temporaryMovieURL()
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        try FileManager.default.removeItem(at: outputURL)
                    }

                    self.configureVideoConnection(self.movieOutput.connection(with: .video), enableStabilization: true)

                    let delegate = MovieCaptureDelegate { [weak self] result in
                        completion(result)
                        self?.movieDelegate = nil
                    }
                    self.movieDelegate = delegate
                    self.movieOutput.startRecording(to: outputURL, recordingDelegate: delegate)
                } catch {
                    completion(.failure(error))
                }
            }
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                startRecording()
            }
        default:
            startRecording()
        }
    }

    func stopVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
    }

    private func configureSession(position: AVCaptureDevice.Position) throws {
        guard let device = Self.bestDevice(for: position) else {
            throw CameraError.deviceUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        let previousInput = videoInput

        session.beginConfiguration()
        session.sessionPreset = .high

        if let previousInput {
            session.removeInput(previousInput)
        }
        guard session.canAddInput(input) else {
            if let previousInput, session.canAddInput(previousInput) {
                session.addInput(previousInput)
            }
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
        videoInput = input
        zoomDisplayScale = Self.displayScale(for: device)

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        configureVideoConnection(photoOutput.connection(with: .video))
        configureVideoConnection(movieOutput.connection(with: .video), enableStabilization: true)
        setInitialZoom(on: device)
        if let preferredWhiteBalanceKelvin {
            applyWhiteBalance(kelvin: preferredWhiteBalanceKelvin, tint: preferredWhiteBalanceTint, on: device)
        }
    }

    private static func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]

        if position == .back {
            deviceTypes = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]
        } else {
            deviceTypes = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera
            ]
        }

        for deviceType in deviceTypes {
            if let device = AVCaptureDevice.default(deviceType, for: .video, position: position) {
                return device
            }
        }

        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private static func displayScale(for device: AVCaptureDevice) -> CGFloat {
        switch device.deviceType {
        case .builtInTripleCamera, .builtInDualWideCamera:
            return 2
        default:
            return 1
        }
    }

    private func setInitialZoom(on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = rawZoomFactor(forDisplayFactor: 1, device: device)
            device.unlockForConfiguration()
        } catch {
            return
        }
    }

    private func zoomState(for device: AVCaptureDevice) -> CameraZoomState {
        let minDisplayFactor = device.minAvailableVideoZoomFactor / zoomDisplayScale
        let maxDisplayFactor = min(device.maxAvailableVideoZoomFactor / zoomDisplayScale, 15)
        let currentDisplayFactor = device.videoZoomFactor / zoomDisplayScale
        let clampedDisplayFactor = currentDisplayFactor.clamped(to: minDisplayFactor...maxDisplayFactor)

        return CameraZoomState(
            displayFactor: clampedDisplayFactor,
            minDisplayFactor: minDisplayFactor,
            maxDisplayFactor: maxDisplayFactor,
            lensOptions: lensOptions(for: device, minDisplayFactor: minDisplayFactor, maxDisplayFactor: maxDisplayFactor)
        )
    }

    private func rawZoomFactor(forDisplayFactor displayFactor: CGFloat, device: AVCaptureDevice) -> CGFloat {
        let minDisplayFactor = device.minAvailableVideoZoomFactor / zoomDisplayScale
        let maxDisplayFactor = min(device.maxAvailableVideoZoomFactor / zoomDisplayScale, 15)
        let clampedDisplayFactor = displayFactor.clamped(to: minDisplayFactor...maxDisplayFactor)
        return (clampedDisplayFactor * zoomDisplayScale)
            .clamped(to: device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor)
    }

    private func lensOptions(
        for device: AVCaptureDevice,
        minDisplayFactor: CGFloat,
        maxDisplayFactor: CGFloat
    ) -> [CameraLensOption] {
        var candidates: [CGFloat] = [1]

        if minDisplayFactor < 0.95 {
            candidates.append(minDisplayFactor)
        }

        candidates.append(contentsOf: device.virtualDeviceSwitchOverVideoZoomFactors.map {
            CGFloat(truncating: $0) / zoomDisplayScale
        })

        let fallbackCandidates: [CGFloat]
        switch device.deviceType {
        case .builtInTripleCamera, .builtInDualWideCamera:
            fallbackCandidates = [0.5, 1, 2, 3, 5]
        case .builtInDualCamera:
            fallbackCandidates = [1, 2, 3]
        default:
            fallbackCandidates = [1, 2, 3]
        }
        candidates.append(contentsOf: fallbackCandidates)

        let options = Self.uniqueLensFactors(candidates)
            .filter { $0 >= minDisplayFactor - 0.01 && $0 <= maxDisplayFactor + 0.01 }
            .map(CameraLensOption.init(displayFactor:))

        if options.isEmpty {
            return [CameraLensOption(displayFactor: min(max(1, minDisplayFactor), maxDisplayFactor))]
        }

        return options
    }

    private static func uniqueLensFactors(_ factors: [CGFloat]) -> [CGFloat] {
        factors
            .filter { $0.isFinite && $0 > 0 }
            .sorted()
            .reduce(into: [CGFloat]()) { result, factor in
                guard !result.contains(where: { abs($0 - factor) < 0.04 }) else { return }
                result.append(factor)
            }
    }

    private func configureVideoConnection(
        _ connection: AVCaptureConnection?,
        enableStabilization: Bool = false
    ) {
        guard let connection else { return }

        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }

        if enableStabilization, connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .cinematic
        }
    }

    private func whiteBalanceState(for device: AVCaptureDevice) -> CameraWhiteBalanceState {
        let values = device.temperatureAndTintValues(for: device.deviceWhiteBalanceGains)
        return CameraWhiteBalanceState(
            kelvin: values.temperature.clamped(to: CameraWhiteBalanceState.auto.minKelvin...CameraWhiteBalanceState.auto.maxKelvin),
            tint: values.tint,
            minKelvin: CameraWhiteBalanceState.auto.minKelvin,
            maxKelvin: CameraWhiteBalanceState.auto.maxKelvin,
            isLocked: device.whiteBalanceMode == .locked,
            isSupported: device.isLockingWhiteBalanceWithCustomDeviceGainsSupported
        )
    }

    private func applyWhiteBalance(kelvin: Float, tint: Float, on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            guard device.isLockingWhiteBalanceWithCustomDeviceGainsSupported else {
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                return
            }

            let values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: kelvin,
                tint: tint
            )
            let gains = normalizedWhiteBalanceGains(device.deviceWhiteBalanceGains(for: values), maxGain: device.maxWhiteBalanceGain)
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        } catch {
            return
        }
    }

    private func normalizedWhiteBalanceGains(
        _ gains: AVCaptureDevice.WhiteBalanceGains,
        maxGain: Float
    ) -> AVCaptureDevice.WhiteBalanceGains {
        AVCaptureDevice.WhiteBalanceGains(
            redGain: gains.redGain.clamped(to: 1...maxGain),
            greenGain: gains.greenGain.clamped(to: 1...maxGain),
            blueGain: gains.blueGain.clamped(to: 1...maxGain)
        )
    }

    private func configureAudioInputIfAllowed() throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            return
        }
        guard audioInput == nil else { return }
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }

        let input = try AVCaptureDeviceInput(device: audioDevice)
        session.beginConfiguration()
        if session.canAddInput(input) {
            session.addInput(input)
            audioInput = input
        }
        session.commitConfiguration()
    }

    private func temporaryMovieURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StillLight", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("\(UUID().uuidString).mov")
    }
}

private enum CameraError: Error {
    case deviceUnavailable
    case cannotAddInput
}

private final class MovieCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let completion: (Result<URL, Error>) -> Void

    init(completion: @escaping (Result<URL, Error>) -> Void) {
        self.completion = completion
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error {
            let didFinish = (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
            if didFinish == true {
                completion(.success(outputFileURL))
            } else {
                completion(.failure(error))
            }
            return
        }

        completion(.success(outputFileURL))
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.deviceUnavailable))
            return
        }

        completion(.success(data))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
