import AVFoundation
import CoreImage
import Photos
import UIKit

struct VideoExportResult {
    let localURL: URL
    let warningMessage: String?
}

enum VideoExporter {
    static func export(
        temporaryURL: URL,
        film: FilmPreset,
        photosSaveFailedPrefix: String = "Video saved locally. Photos save failed:"
    ) async throws -> VideoExportResult {
        let id = UUID()
        let directory = try videoDirectory()
        let localURL = directory.appendingPathComponent("\(id.uuidString)-video.mov")

        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        try await renderStyledVideo(from: temporaryURL, to: localURL, film: film)
        try? FileManager.default.removeItem(at: temporaryURL)

        let warningMessage: String?
        do {
            try await saveToPhotoLibrary(localURL)
            warningMessage = nil
        } catch {
            warningMessage = "\(photosSaveFailedPrefix) \(error.localizedDescription)"
        }

        return VideoExportResult(localURL: localURL, warningMessage: warningMessage)
    }

    private static func renderStyledVideo(
        from sourceURL: URL,
        to destinationURL: URL,
        film: FilmPreset
    ) async throws {
        let asset = AVAsset(url: sourceURL)
        let videoComposition = AVVideoComposition(asset: asset) { request in
            let source = request.sourceImage.clampedToExtent()
            let styled = FilmImagePipeline.processVideoFrame(source, film: film)
                .cropped(to: request.sourceImage.extent)
            request.finish(with: styled, context: nil)
        }

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.cannotCreateVideoExporter
        }

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        let exportBox = ExportSessionBox(exportSession)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                let session = exportBox.session
                switch session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: session.error ?? ExportError.videoExportFailed)
                default:
                    continuation.resume(throwing: ExportError.videoExportFailed)
                }
            }
        }
    }

    private static func videoDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("StillLight/Videos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func saveToPhotoLibrary(_ fileURL: URL) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let authorized: Bool

        if status == .notDetermined {
            authorized = await requestAddOnlyAuthorization()
        } else {
            authorized = status == .authorized || status == .limited
        }

        guard authorized else {
            throw ExportError.photoLibraryDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: fileURL, options: nil)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ExportError.photoLibrarySaveFailed)
                }
            }
        }
    }

    private static func requestAddOnlyAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
