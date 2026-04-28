import ImageIO
import Photos
import UniformTypeIdentifiers
import UIKit

enum PhotoExporter {
    static func export(
        processedImage: UIImage,
        originalData: Data?,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        jpegQuality: Double
    ) async throws -> PhotoRecord {
        let id = UUID()
        let createdAt = Date()
        let directory = try appDirectory()
        let processedURL = directory.appendingPathComponent("\(id.uuidString)-processed.jpg")
        let originalURL = originalData == nil ? nil : directory.appendingPathComponent("\(id.uuidString)-original.jpg")

        let jpegData = try encodedJPEGData(
            image: processedImage,
            film: film,
            aspectRatio: aspectRatio,
            quality: jpegQuality
        )
        try jpegData.write(to: processedURL, options: .atomic)

        if let originalData, let originalURL {
            try originalData.write(to: originalURL, options: .atomic)
        }

        try await saveToPhotoLibrary(processedURL)

        return PhotoRecord(
            id: id,
            originalPath: originalURL?.path,
            processedPath: processedURL.path,
            filmPresetId: film.id,
            filmName: film.name,
            aspectRatio: aspectRatio.label,
            capturedAt: createdAt,
            width: Int(processedImage.size.width),
            height: Int(processedImage.size.height),
            isFavorite: false
        )
    }

    private static func appDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("StillLight", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func encodedJPEGData(
        image: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        quality: Double
    ) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw ExportError.cannotEncodeImage
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.cannotEncodeImage
        }

        let metadata: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFSoftware: "StillLight",
                kCGImagePropertyTIFFImageDescription: "StillLight \(film.name) / ISO \(film.iso) / \(aspectRatio.label)"
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifUserComment: "Film=\(film.name); ISO=\(film.iso); Preset=\(film.id); Ratio=\(aspectRatio.label)"
            ]
        ]

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.cannotEncodeImage
        }

        return data as Data
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
                request.addResource(with: .photo, fileURL: fileURL, options: nil)
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

enum ExportError: LocalizedError {
    case cannotEncodeImage
    case photoLibraryDenied
    case photoLibrarySaveFailed

    var errorDescription: String? {
        switch self {
        case .cannotEncodeImage:
            return "Could not encode the processed photo."
        case .photoLibraryDenied:
            return "Photo library permission is required to save the processed image."
        case .photoLibrarySaveFailed:
            return "Could not save the processed image to Photos."
        }
    }
}
