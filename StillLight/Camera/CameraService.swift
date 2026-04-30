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

final class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.stilllight.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var photoDelegate: PhotoCaptureDelegate?
    private var movieDelegate: MovieCaptureDelegate?
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

                    if let connection = self.movieOutput.connection(with: .video) {
                        if #available(iOS 17.0, *) {
                            if connection.isVideoRotationAngleSupported(90) {
                                connection.videoRotationAngle = 90
                            }
                        } else if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                        if connection.isVideoMirroringSupported {
                            connection.isVideoMirrored = self.position == .front
                        }
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .cinematic
                        }
                    }

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
        session.beginConfiguration()
        session.sessionPreset = .high

        if let videoInput {
            session.removeInput(videoInput)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            session.commitConfiguration()
            throw CameraError.deviceUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
        videoInput = input

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
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
