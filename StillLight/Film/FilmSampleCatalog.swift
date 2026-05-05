import Foundation
import ImageIO
import UIKit

enum FilmSampleRole: String, Decodable {
    case hero
    case thumb
    case micro
    case blur
}

struct FilmSampleAsset: Decodable {
    let role: FilmSampleRole
    let path: String
    let sceneSlug: String
    let aspect: String
    let dominantColor: String
}

private struct FilmSampleEntry: Decodable {
    let filmId: String
    let assets: [FilmSampleAsset]
}

private struct FilmSampleManifest: Decodable {
    let version: Int
    let samples: [FilmSampleEntry]
}

enum FilmSampleCatalog {
    static func asset(for film: FilmPreset, role: FilmSampleRole) -> FilmSampleAsset? {
        entries[film.id]?.assets.first(where: { $0.role == role })
    }

    static func image(for film: FilmPreset, role: FilmSampleRole, maxPixelSize: Int) -> UIImage? {
        guard let asset = asset(for: film, role: role) else {
            return nil
        }
        return FilmSampleImageProvider.image(relativePath: asset.path, maxPixelSize: maxPixelSize)
    }

    private static let entries: [String: FilmSampleEntry] = {
        guard let url = Bundle.main.url(forResource: "film_samples_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(FilmSampleManifest.self, from: data)
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: manifest.samples.map { ($0.filmId, $0) })
    }()
}

private enum FilmSampleImageProvider {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    static func image(relativePath: String, maxPixelSize: Int) -> UIImage? {
        let cacheKey = "\(relativePath)#\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let url = resourceURL(for: relativePath),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(160, maxPixelSize)
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: thumbnail)
        cache.setObject(image, forKey: cacheKey, cost: thumbnail.width * thumbnail.height * 4)
        return image
    }

    private static func resourceURL(for relativePath: String) -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else {
            return nil
        }

        let candidates = [
            relativePath,
            relativePath.replacingOccurrences(of: "FilmSamples/", with: ""),
            relativePath.replacingOccurrences(of: "FilmSamples/Samples/", with: "Samples/"),
            URL(fileURLWithPath: relativePath).lastPathComponent
        ]

        return candidates
            .map { resourceURL.appendingPathComponent($0) }
            .first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }
}
