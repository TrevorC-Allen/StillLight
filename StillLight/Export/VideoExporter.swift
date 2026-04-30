import Photos
import UIKit

struct VideoExportResult {
    let localURL: URL
    let warningMessage: String?
}

enum VideoExporter {
    static func export(
        temporaryURL: URL,
        photosSaveFailedPrefix: String = "Video saved locally. Photos save failed:"
    ) async throws -> VideoExportResult {
        let id = UUID()
        let directory = try videoDirectory()
        let localURL = directory.appendingPathComponent("\(id.uuidString)-video.mov")

        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: localURL)

        let warningMessage: String?
        do {
            try await saveToPhotoLibrary(localURL)
            warningMessage = nil
        } catch {
            warningMessage = "\(photosSaveFailedPrefix) \(error.localizedDescription)"
        }

        return VideoExportResult(localURL: localURL, warningMessage: warningMessage)
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
