import UIKit

struct FilmRecommendation {
    let film: FilmPreset
    let reason: String
    let localizedReason: String
    let metrics: ImageMetrics

    func displayReason(language: AppLanguage) -> String {
        language == .chinese ? localizedReason : reason
    }
}

struct FilmRecommendationOption {
    let preset: FilmPreset
    let score: Double
    let reason: String
    let localizedReason: String
    let metrics: ImageMetrics
    let metricSummary: RecommendationMetricSummary

    func displayReason(language: AppLanguage) -> String {
        language == .chinese ? localizedReason : reason
    }
}

struct RecommendationMetricSummary {
    let brightness: String
    let saturation: String
    let warmth: String
    let contrast: String
    let compact: String

    init(metrics: ImageMetrics) {
        let brightnessValue = Int(metrics.brightness * 100)
        let saturationValue = Int(metrics.saturation * 100)
        let warmthValue = Int(metrics.warmth * 100)
        let contrastValue = Int(metrics.contrast * 100)

        brightness = "Brightness \(brightnessValue)"
        saturation = "Saturation \(saturationValue)"
        warmth = "Warmth \(warmthValue)"
        contrast = "Contrast \(contrastValue)"
        compact = "B \(brightnessValue) / S \(saturationValue) / W \(warmthValue) / C \(contrastValue)"
    }
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
        guard let option = recommendations(image: image, presets: presets).first else {
            return nil
        }

        return FilmRecommendation(
            film: option.preset,
            reason: option.reason,
            localizedReason: option.localizedReason,
            metrics: option.metrics
        )
    }

    static func recommendations(image: UIImage, presets: [FilmPreset], limit: Int = 3) -> [FilmRecommendationOption] {
        guard let metrics = ImageMetricsAnalyzer.analyze(image: image) else {
            return []
        }

        let metricSummary = RecommendationMetricSummary(metrics: metrics)
        let presetByID = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0) })
        var options = recommendationRules.compactMap { rule -> FilmRecommendationOption? in
            guard let preset = presetByID[rule.filmId] else {
                return nil
            }

            return FilmRecommendationOption(
                preset: preset,
                score: rule.score(metrics),
                reason: rule.reason,
                localizedReason: rule.localizedReason,
                metrics: metrics,
                metricSummary: metricSummary
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.preset.name < rhs.preset.name
            }
            return lhs.score > rhs.score
        }

        let usedPresetIDs = Set(options.map(\.preset.id))
        let fallbackOptions = presets
            .filter { !usedPresetIDs.contains($0.id) }
            .map { preset in
                FilmRecommendationOption(
                    preset: preset,
                    score: 0.40,
                    reason: "Included as a neutral fallback because it is available in the local film library.",
                    localizedReason: "作为本地胶卷库里的中性候选补足推荐列表。",
                    metrics: metrics,
                    metricSummary: metricSummary
                )
            }

        options.append(contentsOf: fallbackOptions)
        return Array(options.prefix(max(limit, 0)))
    }
}

private struct FilmRecommendationRule {
    let filmId: String
    let reason: String
    let localizedReason: String
    let score: (ImageMetrics) -> Double
}

private let recommendationRules: [FilmRecommendationRule] = [
    FilmRecommendationRule(
        filmId: "human-vignette-800",
        reason: "Low light and strong contrast can use a moodier vignette roll to pull the eye inward.",
        localizedReason: "低光和强反差适合街影卷，把视线往画面中心收。",
        score: { metrics in
            0.55
                + 0.30 * highScore(0.30 - metrics.brightness, range: 0.30)
                + 0.15 * highScore(metrics.contrast - 0.18, range: 0.18)
        }
    ),
    FilmRecommendationRule(
        filmId: "tungsten-800",
        reason: "Low light with room for warm highlight bloom.",
        localizedReason: "低光场景适合保留暖色高光和轻微泛光。",
        score: { metrics in
            0.48
                + 0.35 * highScore(0.30 - metrics.brightness, range: 0.30)
                + 0.10 * highScore(metrics.warmth, range: 0.16)
        }
    ),
    FilmRecommendationRule(
        filmId: "silver-hp5",
        reason: "Low color and clear contrast suit a monochrome documentary roll.",
        localizedReason: "低饱和但反差清晰，适合黑白纪实胶卷。",
        score: { metrics in
            0.48
                + 0.30 * highScore(0.16 - metrics.saturation, range: 0.16)
                + 0.18 * highScore(metrics.contrast - 0.18, range: 0.18)
        }
    ),
    FilmRecommendationRule(
        filmId: "muse-portrait-400",
        reason: "Bright, gentle color works well with a soft portrait roll and protected highlights.",
        localizedReason: "明亮柔和的色彩适合柔光人像卷，让高光更稳、肤色更软。",
        score: { metrics in
            0.48
                + 0.28 * highScore(metrics.brightness - 0.70, range: 0.30)
                + 0.16 * highScore(0.30 - metrics.saturation, range: 0.30)
        }
    ),
    FilmRecommendationRule(
        filmId: "green-street-400",
        reason: "Cool tones can lean into a cyan-green street palette.",
        localizedReason: "偏冷画面可以强化青绿色街拍氛围。",
        score: { metrics in
            0.47
                + 0.36 * highScore(-0.06 - metrics.warmth, range: 0.20)
                + 0.08 * highScore(metrics.contrast - 0.16, range: 0.18)
        }
    ),
    FilmRecommendationRule(
        filmId: "pocket-flash",
        reason: "High color and punchy contrast can carry a casual flash look.",
        localizedReason: "高饱和和强反差适合一次性闪光机感。",
        score: { metrics in
            0.47
                + 0.24 * highScore(metrics.saturation - 0.46, range: 0.35)
                + 0.22 * highScore(metrics.contrast - 0.23, range: 0.18)
        }
    ),
    FilmRecommendationRule(
        filmId: "sunlit-gold-200",
        reason: "Warm daylight is a natural fit for a gold color negative roll.",
        localizedReason: "暖色日光适合宽容、明快的金色彩负。",
        score: { metrics in
            0.47
                + 0.24 * highScore(metrics.brightness - 0.62, range: 0.38)
                + 0.20 * highScore(metrics.warmth - 0.05, range: 0.20)
        }
    ),
    FilmRecommendationRule(
        filmId: "human-warm-400",
        reason: "Balanced light and color suit the featured humanistic warm roll.",
        localizedReason: "光线和色彩比较均衡，适合主推的人文暖调卷。",
        score: { metrics in
            0.52
                + 0.16 * closenessScore(metrics.brightness, target: 0.52, range: 0.42)
                + 0.14 * closenessScore(metrics.saturation, target: 0.28, range: 0.32)
                + 0.08 * closenessScore(metrics.warmth, target: 0.03, range: 0.18)
        }
    )
]

private func highScore(_ value: Double, range: Double) -> Double {
    guard range > 0 else { return 0 }
    return min(max(value / range, 0), 1)
}

private func closenessScore(_ value: Double, target: Double, range: Double) -> Double {
    guard range > 0 else { return 0 }
    return min(max(1 - abs(value - target) / range, 0), 1)
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
