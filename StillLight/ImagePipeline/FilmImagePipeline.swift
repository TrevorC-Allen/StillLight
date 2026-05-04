import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit

enum FilmImagePipeline {
    struct ProcessingResult {
        let image: UIImage
        let timing: ProcessingTiming
    }

    struct ProcessingTiming {
        struct Stage {
            let name: String
            let milliseconds: Double
        }

        let maxInputPixelSize: CGFloat
        private(set) var inputPixelSize: CGSize = .zero
        private(set) var croppedPixelSize: CGSize = .zero
        private(set) var outputPixelSize: CGSize = .zero
        private(set) var stages: [Stage] = []

        var totalMilliseconds: Double {
            stages.reduce(0) { $0 + $1.milliseconds }
        }

        mutating func record(_ name: String, milliseconds: Double) {
            stages.append(Stage(name: name, milliseconds: milliseconds))
        }

        mutating func setInputPixelSize(_ size: CGSize) {
            inputPixelSize = size
        }

        mutating func setCroppedPixelSize(_ size: CGSize) {
            croppedPixelSize = size
        }

        mutating func setOutputPixelSize(_ size: CGSize) {
            outputPixelSize = size
        }
    }

    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any
    ])

    static func process(
        photoData: Data,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double = 1.0
    ) throws -> UIImage {
        try processWithTiming(
            photoData: photoData,
            film: film,
            aspectRatio: aspectRatio,
            date: date,
            addTimestamp: addTimestamp,
            intensity: intensity
        ).image
    }

    static func processWithTiming(
        photoData: Data,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double = 1.0
    ) throws -> ProcessingResult {
        var timing = ProcessingTiming(maxInputPixelSize: 2400)
        let baseImage = try measureStage("downsample") {
            try downsample(photoData: photoData, maxPixelSize: timing.maxInputPixelSize)
        } record: { timing.record($0, milliseconds: $1) }

        return try processWithTiming(
            baseImage: baseImage,
            film: film,
            aspectRatio: aspectRatio,
            date: date,
            addTimestamp: addTimestamp,
            intensity: intensity,
            timing: timing
        )
    }

    static func process(
        image: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double = 1.0
    ) throws -> UIImage {
        try processWithTiming(
            image: image,
            film: film,
            aspectRatio: aspectRatio,
            date: date,
            addTimestamp: addTimestamp,
            intensity: intensity
        ).image
    }

    static func processWithTiming(
        image: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double = 1.0
    ) throws -> ProcessingResult {
        var timing = ProcessingTiming(maxInputPixelSize: 2400)
        let baseImage = measureStage("normalize") {
            image.normalizedForProcessing(maxPixelSize: timing.maxInputPixelSize)
        } record: { timing.record($0, milliseconds: $1) }

        return try processWithTiming(
            baseImage: baseImage,
            film: film,
            aspectRatio: aspectRatio,
            date: date,
            addTimestamp: addTimestamp,
            intensity: intensity,
            timing: timing
        )
    }

    private static func processWithTiming(
        baseImage: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double,
        timing: ProcessingTiming
    ) throws -> ProcessingResult {
        var timing = timing
        timing.setInputPixelSize(baseImage.pixelSize)

        guard var ciImage = CIImage(image: baseImage) else {
            throw ImagePipelineError.cannotCreateImage
        }

        ciImage = measureStage("crop") {
            centerCrop(ciImage, aspectRatio: aspectRatio.value)
        } record: { timing.record($0, milliseconds: $1) }
        timing.setCroppedPixelSize(ciImage.extent.size)

        let rendered = try measureStage("coreImageRender") {
            let original = ciImage
            var styledImage = applyExposure(ciImage, ev: film.exposureBias)
            styledImage = applyTemperature(styledImage, film: film)
            styledImage = applyColorControls(styledImage, film: film)
            styledImage = applyToneCurve(styledImage, curve: film.toneCurve)
            styledImage = applyHighlightShadow(styledImage, film: film)
            styledImage = applyFilmColorResponse(styledImage, film: film)
            styledImage = applyHalation(styledImage, amount: film.halationAmount)
            styledImage = applyVignette(styledImage, amount: film.vignetteAmount)
            styledImage = applyLightLeak(styledImage, film: film)
            let blendedImage = blend(original: original, styled: styledImage, intensity: intensity)

            guard let cgImage = context.createCGImage(blendedImage, from: blendedImage.extent) else {
                throw ImagePipelineError.cannotRenderImage
            }
            return cgImage
        } record: { timing.record($0, milliseconds: $1) }

        let grained = measureStage("grain") {
            applyGrain(to: rendered, film: film)
        } record: { timing.record($0, milliseconds: $1) }

        let decorated = measureStage("decorate") {
            decorate(
                image: UIImage(cgImage: grained),
                film: film,
                date: date,
                addTimestamp: addTimestamp
            )
        } record: { timing.record($0, milliseconds: $1) }
        timing.setOutputPixelSize(decorated.pixelSize)

        return ProcessingResult(image: decorated, timing: timing)
    }

    private static func measureStage<Result>(
        _ name: String,
        operation: () throws -> Result,
        record: (String, Double) -> Void
    ) rethrows -> Result {
        let clock = ContinuousClock()
        let start = clock.now
        let result = try operation()
        let duration = start.duration(to: clock.now)
        record(name, duration.milliseconds)
        return result
    }

    private static func downsample(photoData: Data, maxPixelSize: CGFloat) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(photoData as CFData, nil) else {
            throw ImagePipelineError.cannotCreateImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImagePipelineError.cannotCreateImage
        }

        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }

    private static func centerCrop(_ image: CIImage, aspectRatio: CGFloat) -> CIImage {
        let extent = image.extent
        let currentRatio = extent.width / extent.height
        var crop = extent

        if currentRatio > aspectRatio {
            let width = extent.height * aspectRatio
            crop.origin.x += (extent.width - width) / 2
            crop.size.width = width
        } else if currentRatio < aspectRatio {
            let height = extent.width / aspectRatio
            crop.origin.y += (extent.height - height) / 2
            crop.size.height = height
        }

        return image
            .cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.origin.x, y: -crop.origin.y))
    }

    private static func applyExposure(_ image: CIImage, ev: Double) -> CIImage {
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = Float(ev)
        return filter.outputImage ?? image
    }

    private static func blend(original: CIImage, styled: CIImage, intensity: Double) -> CIImage {
        let clampedIntensity = Float(intensity.clamped(to: 0...1))
        guard clampedIntensity < 0.999 else { return styled }
        guard clampedIntensity > 0.001 else { return original }

        let filter = CIFilter.dissolveTransition()
        filter.inputImage = original
        filter.targetImage = styled
        filter.time = clampedIntensity
        return filter.outputImage?.cropped(to: original.extent) ?? styled
    }

    private static func applyTemperature(_ image: CIImage, film: FilmPreset) -> CIImage {
        guard film.temperatureShift != 0 || film.tintShift != 0 else {
            return image
        }

        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: 6500, y: 0)
        filter.targetNeutral = CIVector(x: 6500 + film.temperatureShift, y: film.tintShift)
        return filter.outputImage ?? image
    }

    private static func applyColorControls(_ image: CIImage, film: FilmPreset) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = Float(film.contrast)
        filter.brightness = Float(film.brightness)
        filter.saturation = Float(film.saturation)
        return filter.outputImage ?? image
    }

    private static func applyToneCurve(_ image: CIImage, curve: ToneCurvePreset) -> CIImage {
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        filter.point0 = curve.p0.cgPoint
        filter.point1 = curve.p1.cgPoint
        filter.point2 = curve.p2.cgPoint
        filter.point3 = curve.p3.cgPoint
        filter.point4 = curve.p4.cgPoint
        return filter.outputImage ?? image
    }

    private static func applyHighlightShadow(_ image: CIImage, film: FilmPreset) -> CIImage {
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else {
            return image
        }

        let highlightProtection = (1.0 - film.halationAmount * 0.44 - max(0, film.brightness) * 1.8).clamped(to: 0.68...0.98)
        let shadowLift = (0.04 + max(0, film.toneCurve.p0.y) * 1.8 + max(0, 1.0 - film.contrast) * 0.18).clamped(to: 0.02...0.28)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(highlightProtection, forKey: "inputHighlightAmount")
        filter.setValue(shadowLift, forKey: "inputShadowAmount")
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func applyFilmColorResponse(_ image: CIImage, film: FilmPreset) -> CIImage {
        let response = FilmColorResponse.response(for: film)
        guard !response.isIdentity else { return image }

        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = CIVector(x: response.rr, y: response.rg, z: response.rb, w: 0)
        filter.gVector = CIVector(x: response.gr, y: response.gg, z: response.gb, w: 0)
        filter.bVector = CIVector(x: response.br, y: response.bg, z: response.bb, w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = CIVector(x: response.biasR, y: response.biasG, z: response.biasB, w: 0)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func applyVignette(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }

        let extent = image.extent
        guard let filter = CIFilter(name: "CIVignetteEffect") else {
            return image
        }

        let maxDimension = max(extent.width, extent.height)
        let softenedAmount = min(0.62, amount)
        let radius = maxDimension * (0.72 - CGFloat(softenedAmount) * 0.12)
        let intensity = softenedAmount * 0.95

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: extent.midX, y: extent.midY), forKey: kCIInputCenterKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        return filter.outputImage?.cropped(to: extent) ?? image
    }

    private static func applyHalation(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }

        let bloom = CIFilter.bloom()
        bloom.inputImage = image
        bloom.intensity = Float(amount * 1.35)
        bloom.radius = Float(max(image.extent.width, image.extent.height) * 0.018)

        guard let bloomed = bloom.outputImage?.cropped(to: image.extent) else {
            return image
        }

        let warm = CIFilter.colorMatrix()
        warm.inputImage = bloomed
        warm.rVector = CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0)
        warm.gVector = CIVector(x: 0.0, y: 0.42, z: 0.0, w: 0.0)
        warm.bVector = CIVector(x: 0.0, y: 0.0, z: 0.18, w: 0.0)
        warm.aVector = CIVector(x: 0.0, y: 0.0, z: 0.0, w: CGFloat(0.26 * amount))

        let composite = CIFilter.sourceOverCompositing()
        composite.inputImage = warm.outputImage?.cropped(to: image.extent)
        composite.backgroundImage = image
        return composite.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func applyLightLeak(_ image: CIImage, film: FilmPreset) -> CIImage {
        guard film.lightLeakAmount > 0 else { return image }

        let extent = image.extent
        let seed = abs(film.id.hashValue)
        let isLeft = seed.isMultiple(of: 2)
        let isTop = (seed / 3).isMultiple(of: 2)
        let center = CGPoint(
            x: extent.minX + extent.width * (isLeft ? 0.06 : 0.94),
            y: extent.minY + extent.height * (isTop ? 0.88 : 0.12)
        )

        let gradient = CIFilter.radialGradient()
        gradient.center = center
        gradient.radius0 = Float(max(extent.width, extent.height) * 0.03)
        gradient.radius1 = Float(max(extent.width, extent.height) * 0.56)
        gradient.color0 = CIColor(red: 1.0, green: 0.42, blue: 0.12, alpha: film.lightLeakAmount)
        gradient.color1 = CIColor(red: 1.0, green: 0.76, blue: 0.18, alpha: 0.0)

        guard let leak = gradient.outputImage?.cropped(to: extent) else {
            return image
        }

        guard let blend = CIFilter(name: "CIScreenBlendMode") else {
            let composite = CIFilter.sourceOverCompositing()
            composite.inputImage = leak
            composite.backgroundImage = image
            return composite.outputImage?.cropped(to: extent) ?? image
        }

        blend.setValue(leak, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    private static func applyGrain(to image: CGImage, film: FilmPreset) -> CGImage {
        guard film.grainAmount > 0 else { return image }

        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let pixelCount = height * bytesPerRow
        var pixels = [UInt8](repeating: 0, count: pixelCount)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        let output: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return image
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

            let pixelBuffer = baseAddress.bindMemory(to: UInt8.self, capacity: pixelCount)
            var generator = LCG(seed: grainSeed(width: width, height: height, film: film))
            let amount = max(0.0, min(1.0, film.grainAmount))
            let isoScale = sqrt(Double(max(50, film.iso)) / 400.0).clamped(to: 0.72...1.48)
            let lumaAmplitude = amount * 21.0 * isoScale * film.grainSize.clamped(to: 0.7...1.45)
            let chromaAmplitude = film.category == .blackWhite ? 0.0 : lumaAmplitude * 0.28

            for y in 0..<height {
                for x in 0..<width {
                    let index = y * bytesPerRow + x * bytesPerPixel
                    let r = Double(pixelBuffer[index])
                    let g = Double(pixelBuffer[index + 1])
                    let b = Double(pixelBuffer[index + 2])
                    let luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                    let midtoneWeight = (1.0 - abs(luminance - 0.48) * 1.65).clamped(to: 0...1)
                    let shadowWeight = (1.0 - luminance).clamped(to: 0...1)
                    let weight = 0.22 + midtoneWeight * 0.52 + shadowWeight * 0.26
                    let lumaNoise = triangularNoise(&generator) * lumaAmplitude * weight
                    let redChroma = triangularNoise(&generator) * chromaAmplitude * weight
                    let blueChroma = triangularNoise(&generator) * chromaAmplitude * weight

                    pixelBuffer[index] = UInt8((r + lumaNoise + redChroma * 0.82).clamped(to: 0...255))
                    pixelBuffer[index + 1] = UInt8((g + lumaNoise - redChroma * 0.18 - blueChroma * 0.16).clamped(to: 0...255))
                    pixelBuffer[index + 2] = UInt8((b + lumaNoise + blueChroma * 0.86).clamped(to: 0...255))
                }
            }

            return context.makeImage()
        }

        return output ?? image
    }

    private static func triangularNoise(_ generator: inout LCG) -> Double {
        generator.nextDouble() - generator.nextDouble()
    }

    private static func grainSeed(width: Int, height: Int, film: FilmPreset) -> UInt64 {
        var seed = UInt64(width * 31 + height * 17 + film.iso * 13)
        for scalar in film.id.unicodeScalars {
            seed = seed &* 1_099_511_628_211 &+ UInt64(scalar.value)
        }
        return seed
    }

    private static func decorate(
        image: UIImage,
        film: FilmPreset,
        date: Date,
        addTimestamp: Bool
    ) -> UIImage {
        let imageSize = image.size
        let borderPadding: CGFloat
        let bottomPadding: CGFloat

        switch film.borderStyle {
        case .none:
            borderPadding = 0
            bottomPadding = 0
        case .whiteFrame:
            borderPadding = max(22, imageSize.width * 0.045)
            bottomPadding = max(54, imageSize.width * 0.075)
        case .paper:
            borderPadding = max(18, imageSize.width * 0.035)
            bottomPadding = max(48, imageSize.width * 0.068)
        case .instant:
            borderPadding = max(28, imageSize.width * 0.055)
            bottomPadding = max(88, imageSize.width * 0.19)
        }

        let canvasSize = CGSize(
            width: imageSize.width + borderPadding * 2,
            height: imageSize.height + borderPadding + bottomPadding
        )

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { context in
            if film.borderStyle == .none {
                image.draw(in: CGRect(origin: .zero, size: imageSize))
            } else {
                paperColor(for: film.borderStyle).setFill()
                context.fill(CGRect(origin: .zero, size: canvasSize))
                image.draw(in: CGRect(x: borderPadding, y: borderPadding, width: imageSize.width, height: imageSize.height))
                drawFrameLabel(
                    film: film,
                    canvasSize: canvasSize,
                    borderPadding: borderPadding,
                    bottomPadding: bottomPadding
                )
            }

            guard addTimestamp else { return }
            let stamp = makeTimestamp(date)
            let color = UIColor(hex: film.timestampColorHex) ?? UIColor(red: 0.88, green: 0.64, blue: 0.30, alpha: 0.92)
            let fontSize = max(16, canvasSize.width * 0.032)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: color.withAlphaComponent(0.92),
                .kern: 1.2
            ]
            let textSize = stamp.size(withAttributes: attributes)
            let inset = max(18, canvasSize.width * 0.035)
            let rect = CGRect(
                x: canvasSize.width - textSize.width - inset,
                y: canvasSize.height - textSize.height - max(14, inset * 0.72),
                width: textSize.width,
                height: textSize.height
            )
            stamp.draw(in: rect, withAttributes: attributes)
        }
    }

    private static func paperColor(for borderStyle: BorderStyle) -> UIColor {
        switch borderStyle {
        case .none:
            return .clear
        case .paper:
            return UIColor(red: 0.93, green: 0.90, blue: 0.84, alpha: 1)
        case .instant:
            return UIColor(red: 0.955, green: 0.94, blue: 0.89, alpha: 1)
        case .whiteFrame:
            return UIColor(red: 0.965, green: 0.955, blue: 0.925, alpha: 1)
        }
    }

    private static func drawFrameLabel(
        film: FilmPreset,
        canvasSize: CGSize,
        borderPadding: CGFloat,
        bottomPadding: CGFloat
    ) {
        guard film.borderStyle != .none else { return }

        let primaryColor = UIColor(red: 0.13, green: 0.12, blue: 0.10, alpha: 0.72)
        let secondaryColor = UIColor(red: 0.13, green: 0.12, blue: 0.10, alpha: 0.42)
        let fontSize = max(13, min(24, canvasSize.width * 0.022))
        let smallFontSize = max(10, fontSize * 0.72)
        let y = canvasSize.height - bottomPadding + max(12, bottomPadding * 0.28)
        let leftX = max(16, borderPadding)
        let availableWidth = canvasSize.width - leftX * 2

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: primaryColor,
            .kern: 0.6
        ]
        let subAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: smallFontSize, weight: .medium),
            .foregroundColor: secondaryColor,
            .kern: 0.5
        ]

        let cameraText = film.cameraName.uppercased()
        cameraText.draw(
            in: CGRect(x: leftX, y: y, width: availableWidth * 0.62, height: fontSize * 1.4),
            withAttributes: labelAttributes
        )

        let rollText = "STILLLIGHT  \(film.shortName.uppercased())"
        rollText.draw(
            in: CGRect(x: leftX, y: y + fontSize * 1.22, width: availableWidth * 0.70, height: smallFontSize * 1.5),
            withAttributes: subAttributes
        )

        let cameraMark = "ISO \(film.iso)"
        let markSize = cameraMark.size(withAttributes: subAttributes)
        cameraMark.draw(
            in: CGRect(x: canvasSize.width - leftX - markSize.width, y: y, width: markSize.width, height: smallFontSize * 1.5),
            withAttributes: subAttributes
        )
    }

    private static func makeTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy MM dd"
        return formatter.string(from: date)
    }
}

enum ImagePipelineError: LocalizedError {
    case cannotCreateImage
    case cannotRenderImage

    var errorDescription: String? {
        switch self {
        case .cannotCreateImage:
            return "Could not read the captured photo."
        case .cannotRenderImage:
            return "Could not render the film simulation."
        }
    }
}

private struct FilmColorResponse {
    let rr: CGFloat
    let rg: CGFloat
    let rb: CGFloat
    let gr: CGFloat
    let gg: CGFloat
    let gb: CGFloat
    let br: CGFloat
    let bg: CGFloat
    let bb: CGFloat
    let biasR: CGFloat
    let biasG: CGFloat
    let biasB: CGFloat

    var isIdentity: Bool {
        rr == 1 && rg == 0 && rb == 0
            && gr == 0 && gg == 1 && gb == 0
            && br == 0 && bg == 0 && bb == 1
            && biasR == 0 && biasG == 0 && biasB == 0
    }

    static let identity = FilmColorResponse(
        rr: 1, rg: 0, rb: 0,
        gr: 0, gg: 1, gb: 0,
        br: 0, bg: 0, bb: 1,
        biasR: 0, biasG: 0, biasB: 0
    )

    static func response(for film: FilmPreset) -> FilmColorResponse {
        switch film.id {
        case "human-warm-400":
            return .init(rr: 1.025, rg: 0.014, rb: -0.010, gr: 0.006, gg: 1.006, gb: 0.000, br: -0.010, bg: 0.006, bb: 0.970, biasR: 0.010, biasG: 0.004, biasB: -0.006)
        case "human-vignette-800":
            return .init(rr: 1.012, rg: 0.010, rb: -0.012, gr: 0.004, gg: 1.000, gb: 0.004, br: -0.015, bg: 0.010, bb: 0.955, biasR: -0.003, biasG: -0.001, biasB: -0.010)
        case "muse-portrait-400", "soft-portrait-400":
            return .init(rr: 1.026, rg: 0.010, rb: -0.006, gr: 0.006, gg: 1.000, gb: 0.000, br: -0.006, bg: 0.006, bb: 0.974, biasR: 0.012, biasG: 0.006, biasB: -0.004)
        case "sunlit-gold-200", "t-compact-gold":
            return .init(rr: 1.032, rg: 0.014, rb: -0.018, gr: 0.012, gg: 1.006, gb: -0.006, br: -0.016, bg: 0.004, bb: 0.952, biasR: 0.014, biasG: 0.008, biasB: -0.010)
        case "green-street-400", "superia-green":
            return .init(rr: 0.990, rg: 0.008, rb: -0.006, gr: 0.004, gg: 1.030, gb: -0.004, br: -0.012, bg: 0.018, bb: 0.970, biasR: -0.004, biasG: 0.010, biasB: -0.006)
        case "tungsten-800":
            return .init(rr: 1.020, rg: 0.006, rb: 0.006, gr: -0.004, gg: 0.985, gb: 0.008, br: -0.006, bg: 0.014, bb: 1.038, biasR: 0.010, biasG: -0.004, biasB: 0.012)
        case "hncs-natural", "medium-500c":
            return .init(rr: 1.006, rg: 0.004, rb: -0.004, gr: 0.002, gg: 1.004, gb: 0.000, br: -0.004, bg: 0.004, bb: 0.994, biasR: 0.002, biasG: 0.002, biasB: -0.002)
        case "m-rangefinder":
            return .init(rr: 1.035, rg: 0.006, rb: -0.010, gr: 0.004, gg: 0.996, gb: 0.000, br: -0.014, bg: 0.006, bb: 0.960, biasR: 0.006, biasG: 0.001, biasB: -0.008)
        case "gr-street-snap", "classic-chrome-x":
            return .init(rr: 0.976, rg: 0.010, rb: 0.000, gr: 0.000, gg: 1.000, gb: 0.010, br: -0.004, bg: 0.014, bb: 1.012, biasR: -0.006, biasG: -0.002, biasB: 0.004)
        case "ccd-2003", "cyber-ccd-blue":
            return .init(rr: 0.984, rg: 0.000, rb: 0.016, gr: -0.004, gg: 0.998, gb: 0.012, br: -0.006, bg: 0.010, bb: 1.045, biasR: -0.006, biasG: 0.000, biasB: 0.014)
        case "instant-square", "instant-wide", "sx-fade":
            return .init(rr: 1.020, rg: 0.010, rb: -0.006, gr: 0.006, gg: 1.000, gb: 0.000, br: -0.010, bg: 0.004, bb: 0.978, biasR: 0.012, biasG: 0.006, biasB: -0.004)
        case "holga-120-dream", "lca-vivid":
            return .init(rr: 1.032, rg: 0.008, rb: -0.008, gr: 0.002, gg: 1.020, gb: -0.004, br: -0.012, bg: 0.004, bb: 0.972, biasR: 0.012, biasG: 0.004, biasB: -0.006)
        case "silver-hp5", "tri-x-street", "noir-soft":
            return .identity
        default:
            return .init(rr: 1.012, rg: 0.006, rb: -0.006, gr: 0.004, gg: 1.002, gb: 0.000, br: -0.008, bg: 0.004, bb: 0.982, biasR: 0.004, biasG: 0.002, biasB: -0.004)
        }
    }
}

private struct LCG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x1234ABCD : seed
    }

    mutating func nextDouble() -> Double {
        state = 2862933555777941757 &* state &+ 3037000493
        return Double((state >> 33) & 0xFFFF_FFFF) / Double(UInt32.max)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Duration {
    var milliseconds: Double {
        let durationComponents = components
        return Double(durationComponents.seconds) * 1_000 + Double(durationComponents.attoseconds) / 1_000_000_000_000_000
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return nil
        }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

private extension UIImage {
    var pixelSize: CGSize {
        if let cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    func normalizedForProcessing(maxPixelSize: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        let scaleRatio = min(1.0, maxPixelSize / longestSide)
        let outputSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }
}
