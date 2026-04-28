import UIKit

struct FilmRecommendation {
    let film: FilmPreset
    let reason: String
    let metrics: ImageMetrics
}

struct ImageMetrics {
    let brightness: Double
    let saturation: Double
    let warmth: Double
    let contrast: Double

    var summary: String {
        "B \(Int(brightness * 100)) / S \(Int(saturation * 100)) / C \(Int(contrast * 100))"
    }
}

enum FilmRecommender {
    static func recommend(image: UIImage, presets: [FilmPreset]) -> FilmRecommendation? {
        guard let metrics = ImageMetricsAnalyzer.analyze(image: image) else {
            return nil
        }

        let filmId: String
        let reason: String

        if metrics.brightness < 0.30 {
            filmId = "tungsten-800"
            reason = "Low light with room for warm highlight bloom."
        } else if metrics.saturation < 0.16 && metrics.contrast > 0.18 {
            filmId = "silver-hp5"
            reason = "Low color and clear contrast suit a monochrome documentary roll."
        } else if metrics.brightness > 0.70 && metrics.saturation < 0.30 {
            filmId = "soft-portrait-400"
            reason = "Bright, gentle color works well with soft highlights."
        } else if metrics.warmth < -0.06 {
            filmId = "green-street-400"
            reason = "Cool tones can lean into a cyan-green street palette."
        } else if metrics.saturation > 0.46 && metrics.contrast > 0.23 {
            filmId = "pocket-flash"
            reason = "High color and punchy contrast can carry a casual flash look."
        } else if metrics.brightness > 0.62 && metrics.warmth > 0.05 {
            filmId = "sunlit-gold-200"
            reason = "Warm daylight is a natural fit for a gold color negative roll."
        } else {
            filmId = "sunlit-gold-200"
            reason = "Balanced light and color call for the most forgiving everyday roll."
        }

        guard let film = presets.first(where: { $0.id == filmId }) ?? presets.first else {
            return nil
        }

        return FilmRecommendation(film: film, reason: reason, metrics: metrics)
    }
}

private enum ImageMetricsAnalyzer {
    static func analyze(image: UIImage) -> ImageMetrics? {
        let sampleSize = CGSize(width: 48, height: 48)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: sampleSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: sampleSize))
        }

        guard let cgImage = rendered.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let pixelCount = width * height
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminances: [Double] = []
        luminances.reserveCapacity(pixelCount)
        var brightnessSum = 0.0
        var saturationSum = 0.0
        var warmthSum = 0.0

        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = Double(pixels[index]) / 255.0
            let g = Double(pixels[index + 1]) / 255.0
            let b = Double(pixels[index + 2]) / 255.0
            let maxChannel = max(r, g, b)
            let minChannel = min(r, g, b)
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b

            luminances.append(luminance)
            brightnessSum += luminance
            saturationSum += maxChannel == 0 ? 0 : (maxChannel - minChannel) / maxChannel
            warmthSum += r - b
        }

        let count = Double(max(pixelCount, 1))
        let brightness = brightnessSum / count
        let saturation = saturationSum / count
        let warmth = warmthSum / count
        let contrast = luminances.reduce(0.0) { partial, value in
            partial + abs(value - brightness)
        } / count

        return ImageMetrics(
            brightness: brightness,
            saturation: saturation,
            warmth: warmth,
            contrast: contrast
        )
    }
}
