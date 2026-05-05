import ImageIO
import Photos
import UniformTypeIdentifiers
import UIKit

struct PhotoExportResult {
    let record: PhotoRecord
    let warningMessage: String?
}

enum PhotoExporter {
    static func export(
        processedImage: UIImage,
        originalData: Data?,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        jpegQuality: Double,
        processedFormat: ProcessedPhotoFormat,
        saveOriginalToPhotoLibrary: Bool,
        photosSaveFailedPrefix: String = "Saved to StillLight Roll. Photos save failed:"
    ) async throws -> PhotoExportResult {
        let id = UUID()
        let createdAt = Date()
        let directory = try appDirectory()
        let processedURL = directory.appendingPathComponent("\(id.uuidString)-processed.\(processedFormat.fileExtension)")
        let originalURL = originalData.map {
            directory.appendingPathComponent("\(id.uuidString)-original.\(originalFileExtension(for: $0))")
        }

        let processedData = try encodedProcessedPhotoData(
            image: processedImage,
            film: film,
            aspectRatio: aspectRatio,
            quality: jpegQuality,
            format: processedFormat
        )
        try processedData.write(to: processedURL, options: .atomic)

        if let originalData, let originalURL {
            try originalData.write(to: originalURL, options: .atomic)
        }

        let warningMessage: String?
        do {
            try await saveToPhotoLibrary(processedURL)
            if saveOriginalToPhotoLibrary, let originalURL {
                try await saveToPhotoLibrary(originalURL)
            }
            warningMessage = nil
        } catch {
            warningMessage = "\(photosSaveFailedPrefix) \(error.localizedDescription)"
        }

        let record = PhotoRecord(
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

        return PhotoExportResult(record: record, warningMessage: warningMessage)
    }

    private static func appDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("StillLight", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func encodedProcessedPhotoData(
        image: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        quality: Double,
        format: ProcessedPhotoFormat
    ) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw ExportError.cannotEncodeImage
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.cannotEncodeImage
        }

        var metadata = imageMetadata(film: film, aspectRatio: aspectRatio)
        if format == .jpegHighQuality {
            metadata[kCGImageDestinationLossyCompressionQuality] = quality
        }

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.cannotEncodeImage
        }

        return data as Data
    }

    private static func imageMetadata(film: FilmPreset, aspectRatio: CaptureAspectRatio) -> [CFString: Any] {
        [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFSoftware: "StillLight",
                kCGImagePropertyTIFFImageDescription: "StillLight \(film.name) / \(film.cameraName) / ISO \(film.iso) / \(aspectRatio.label)"
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifUserComment: "Film=\(film.name); Camera=\(film.cameraName); Category=\(film.category.rawValue); ISO=\(film.iso); Preset=\(film.id); Ratio=\(aspectRatio.label)"
            ]
        ]
    }

    private static func originalFileExtension(for data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeIdentifier = CGImageSourceGetType(source),
              let type = UTType(typeIdentifier as String),
              let preferredExtension = type.preferredFilenameExtension
        else {
            return "jpg"
        }

        return preferredExtension == "jpeg" ? "jpg" : preferredExtension
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
    case cannotCreateVideoExporter
    case photoLibraryDenied
    case photoLibrarySaveFailed
    case videoExportFailed

    var errorDescription: String? {
        switch self {
        case .cannotEncodeImage:
            return "Could not encode the processed photo."
        case .cannotCreateVideoExporter:
            return "Could not create the film video exporter."
        case .photoLibraryDenied:
            return "Photo library permission is required to save the processed image."
        case .photoLibrarySaveFailed:
            return "Could not save the processed image to Photos."
        case .videoExportFailed:
            return "Could not render the film video."
        }
    }
}
