import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit

enum FilmImagePipeline {
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
        let baseImage = try downsample(photoData: photoData, maxPixelSize: 2400)
        return try process(
            baseImage: baseImage,
            film: film,
            aspectRatio: aspectRatio,
            date: date,
            addTimestamp: addTimestamp,
            intensity: intensity
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
        try process(
            baseImage: image.normalizedForProcessing(maxPixelSize: 2400),
            film: film,
            aspectRatio: aspectRatio,
            date: date,
            addTimestamp: addTimestamp,
            intensity: intensity
        )
    }

    private static func process(
        baseImage: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double
    ) throws -> UIImage {
        guard var ciImage = CIImage(image: baseImage) else {
            throw ImagePipelineError.cannotCreateImage
        }

        ciImage = centerCrop(ciImage, aspectRatio: aspectRatio.value)
        let original = ciImage
        var styledImage = applyExposure(ciImage, ev: film.exposureBias)
        styledImage = applyTemperature(styledImage, film: film)
        styledImage = applyColorControls(styledImage, film: film)
        styledImage = applyToneCurve(styledImage, curve: film.toneCurve)
        styledImage = applyHalation(styledImage, amount: film.halationAmount)
        styledImage = applyVignette(styledImage, amount: film.vignetteAmount)
        styledImage = applyLightLeak(styledImage, film: film)
        ciImage = blend(original: original, styled: styledImage, intensity: intensity)

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImagePipelineError.cannotRenderImage
        }

        let grained = applyGrain(to: cgImage, film: film)
        let decorated = decorate(
            image: UIImage(cgImage: grained),
            film: film,
            date: date,
            addTimestamp: addTimestamp
        )
        return decorated
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

    private static func applyVignette(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = Float(amount)
        filter.radius = Float(max(image.extent.width, image.extent.height) * 0.72)
        return filter.outputImage ?? image
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

        let composite = CIFilter.sourceOverCompositing()
        composite.inputImage = leak
        composite.backgroundImage = image
        return composite.outputImage?.cropped(to: extent) ?? image
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
            var generator = LCG(seed: UInt64(width * 31 + height * 17 + film.iso))
            let amplitude = max(0.0, min(1.0, film.grainAmount)) * 34.0

            for y in stride(from: 0, to: height, by: max(1, Int(film.grainSize.rounded()))) {
                for x in stride(from: 0, to: width, by: max(1, Int(film.grainSize.rounded()))) {
                    let index = y * bytesPerRow + x * bytesPerPixel
                    let r = Double(pixelBuffer[index])
                    let g = Double(pixelBuffer[index + 1])
                    let b = Double(pixelBuffer[index + 2])
                    let luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                    let midtoneWeight = 0.35 + (1.0 - abs(luminance - 0.45) * 1.6).clamped(to: 0...1) * 0.65
                    let noise = (generator.nextDouble() - 0.5) * amplitude * midtoneWeight

                    let xEnd = min(width, x + max(1, Int(film.grainSize.rounded())))
                    let yEnd = min(height, y + max(1, Int(film.grainSize.rounded())))

                    for yy in y..<yEnd {
                        for xx in x..<xEnd {
                            let pixelIndex = yy * bytesPerRow + xx * bytesPerPixel
                            pixelBuffer[pixelIndex] = UInt8((Double(pixelBuffer[pixelIndex]) + noise).clamped(to: 0...255))
                            pixelBuffer[pixelIndex + 1] = UInt8((Double(pixelBuffer[pixelIndex + 1]) + noise).clamped(to: 0...255))
                            pixelBuffer[pixelIndex + 2] = UInt8((Double(pixelBuffer[pixelIndex + 2]) + noise).clamped(to: 0...255))
                        }
                    }
                }
            }

            return context.makeImage()
        }

        return output ?? image
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
