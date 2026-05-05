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
        intensity: Double = 1.0,
        includeDecoration: Bool = true
    ) throws -> UIImage {
        try processWithTiming(
            photoData: photoData,
            film: film,
            aspectRatio: aspectRatio,
            date: date,
            addTimestamp: addTimestamp,
            intensity: intensity,
            includeDecoration: includeDecoration
        ).image
    }

    static func processWithTiming(
        photoData: Data,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double = 1.0,
        includeDecoration: Bool = true
    ) throws -> ProcessingResult {
        var timing = ProcessingTiming(maxInputPixelSize: processingMaxPixelSize)
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
            includeDecoration: includeDecoration,
            timing: timing
        )
    }

    static func process(
        image: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double = 1.0,
        includeDecoration: Bool = true
    ) throws -> UIImage {
        try processWithTiming(
            image: image,
            film: film,
            aspectRatio: aspectRatio,
            date: date,
            addTimestamp: addTimestamp,
            intensity: intensity,
            includeDecoration: includeDecoration
        ).image
    }

    static func processWithTiming(
        image: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double = 1.0,
        includeDecoration: Bool = true
    ) throws -> ProcessingResult {
        var timing = ProcessingTiming(maxInputPixelSize: processingMaxPixelSize)
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
            includeDecoration: includeDecoration,
            timing: timing
        )
    }

    static func decorateProcessedImage(
        _ image: UIImage,
        film: FilmPreset,
        date: Date,
        addTimestamp: Bool
    ) -> UIImage {
        decorate(
            image: image,
            film: film,
            date: date,
            addTimestamp: addTimestamp
        )
    }

    private static let processingMaxPixelSize: CGFloat = 3200

    static func processVideoFrame(
        _ image: CIImage,
        film: FilmPreset,
        intensity: Double = 0.88
    ) -> CIImage {
        let extent = image.extent
        let original = image.cropped(to: extent)
        var styledImage = applyExposure(original, ev: film.exposureBias)
        styledImage = applyTemperature(styledImage, film: film)
        styledImage = applyColorControls(styledImage, film: film)
        styledImage = applyToneCurve(styledImage, curve: film.toneCurve)
        styledImage = applyHighlightShadow(styledImage, film: film)
        styledImage = applyLocalRendering(styledImage, film: film)
        styledImage = applyFilmColorResponse(styledImage, film: film)
        styledImage = applyHalation(styledImage, amount: film.halationAmount * 0.62)
        styledImage = applyVignette(styledImage, film: film)
        styledImage = applyLightLeak(styledImage, film: film)
        return blend(original: original, styled: styledImage, intensity: intensity)
            .cropped(to: extent)
    }

    private static func processWithTiming(
        baseImage: UIImage,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        date: Date,
        addTimestamp: Bool,
        intensity: Double,
        includeDecoration: Bool,
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
            styledImage = applyLocalRendering(styledImage, film: film)
            styledImage = applyFilmColorResponse(styledImage, film: film)
            styledImage = applyHalation(styledImage, amount: film.halationAmount)
            styledImage = applyVignette(styledImage, film: film)
            styledImage = applyLightLeak(styledImage, film: film)
            let blendedImage = blend(original: original, styled: styledImage, intensity: intensity)

            guard let cgImage = context.createCGImage(blendedImage, from: blendedImage.extent) else {
                throw ImagePipelineError.cannotRenderImage
            }
            return cgImage
        } record: { timing.record($0, milliseconds: $1) }

        let grained = measureStage("grain") {
            applyFinishingTexture(to: rendered, film: film, intensity: intensity)
        } record: { timing.record($0, milliseconds: $1) }

        let finishedImage = UIImage(cgImage: grained)
        let decorated = if includeDecoration {
            measureStage("decorate") {
                decorate(
                    image: finishedImage,
                    film: film,
                    date: date,
                    addTimestamp: addTimestamp
                )
            } record: { timing.record($0, milliseconds: $1) }
        } else {
            finishedImage
        }
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

        let profile = FilmRenderingProfile.profile(for: film)
        let highlightProtection = (
            1.0
                - film.halationAmount * 0.36
                - max(0, film.brightness) * 1.45
                - profile.highlightRecovery
        ).clamped(to: 0.58...0.98)
        let shadowLift = (
            0.035
                + max(0, film.toneCurve.p0.y) * 1.55
                + max(0, 1.0 - film.contrast) * 0.16
                + profile.shadowCushion
        ).clamped(to: 0.02...0.32)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(highlightProtection, forKey: "inputHighlightAmount")
        filter.setValue(shadowLift, forKey: "inputShadowAmount")
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func applyLocalRendering(_ image: CIImage, film: FilmPreset) -> CIImage {
        let profile = FilmRenderingProfile.profile(for: film)
        let extent = image.extent
        let maxDimension = max(extent.width, extent.height)
        var rendered = image

        if profile.microContrast > 0.001 {
            let unsharp = CIFilter.unsharpMask()
            unsharp.inputImage = rendered
            unsharp.radius = Float(max(0.85, maxDimension * profile.microContrastRadius))
            unsharp.intensity = Float(profile.microContrast)
            rendered = unsharp.outputImage?.cropped(to: extent) ?? rendered
        }

        if profile.midtoneSoftness > 0.001 {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = rendered.clampedToExtent()
            blur.radius = Float(max(1.0, maxDimension * profile.softnessRadius))

            let softLayer = CIFilter.colorControls()
            softLayer.inputImage = blur.outputImage?.cropped(to: extent)
            softLayer.saturation = Float(1.0 - profile.midtoneSoftness * 0.08)
            softLayer.contrast = Float(1.0 - profile.midtoneSoftness * 0.16)
            softLayer.brightness = Float(profile.midtoneSoftness * 0.012)

            if let softened = softLayer.outputImage?.cropped(to: extent) {
                rendered = blend(original: rendered, styled: softened, intensity: profile.midtoneSoftness)
            }
        }

        return rendered.cropped(to: extent)
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

    private static func applyVignette(_ image: CIImage, film: FilmPreset) -> CIImage {
        guard film.vignetteAmount > 0 else { return image }

        let extent = image.extent
        let maxDimension = max(extent.width, extent.height)
        let profile = FilmRenderingProfile.profile(for: film)
        let vignetteProfile = FilmVignetteProfile.profile(for: film)
        let softenedAmount = film.vignetteAmount.clamped(to: 0...0.68)
        let edgeAlpha = (softenedAmount * profile.vignetteDensity * vignetteProfile.edgeDensity).clamped(to: 0...0.34)
        let center = CGPoint(
            x: extent.midX + extent.width * vignetteProfile.centerOffsetX,
            y: extent.midY + extent.height * vignetteProfile.centerOffsetY
        )

        let edgeGradient = CIFilter.radialGradient()
        edgeGradient.center = center
        edgeGradient.radius0 = Float(maxDimension * (0.50 + CGFloat(softenedAmount) * 0.11))
        edgeGradient.radius1 = Float(maxDimension * (0.98 + CGFloat(softenedAmount) * 0.08))
        edgeGradient.color0 = CIColor(red: 0.18, green: 0.145, blue: 0.105, alpha: 0.0)
        edgeGradient.color1 = CIColor(
            red: vignetteProfile.edgeRed,
            green: vignetteProfile.edgeGreen,
            blue: vignetteProfile.edgeBlue,
            alpha: edgeAlpha
        )

        let rawFalloff = edgeGradient.outputImage?.cropped(to: extent)
        let ovalFalloff = rawFalloff?
            .transformed(by: CGAffineTransform(translationX: -center.x, y: -center.y))
            .transformed(by: CGAffineTransform(scaleX: vignetteProfile.horizontalScale, y: vignetteProfile.verticalScale))
            .transformed(by: CGAffineTransform(translationX: center.x, y: center.y))
            .cropped(to: extent)

        guard let edgeFalloff = ovalFalloff ?? rawFalloff else {
            return image
        }

        let multiply = CIFilter(name: "CIMultiplyBlendMode")
        multiply?.setValue(edgeFalloff, forKey: kCIInputImageKey)
        multiply?.setValue(image, forKey: kCIInputBackgroundImageKey)
        var vignetted = multiply?.outputImage?.cropped(to: extent) ?? image

        let centerGlowAmount = (softenedAmount * profile.centerLift).clamped(to: 0...0.12)
        if centerGlowAmount > 0.001 {
            let centerGradient = CIFilter.radialGradient()
            centerGradient.center = center
            centerGradient.radius0 = Float(maxDimension * 0.10)
            centerGradient.radius1 = Float(maxDimension * vignetteProfile.centerRadius)
            centerGradient.color0 = CIColor(
                red: vignetteProfile.glowRed,
                green: vignetteProfile.glowGreen,
                blue: vignetteProfile.glowBlue,
                alpha: centerGlowAmount * vignetteProfile.centerGlow
            )
            centerGradient.color1 = CIColor(
                red: vignetteProfile.glowRed,
                green: vignetteProfile.glowGreen,
                blue: vignetteProfile.glowBlue,
                alpha: 0.0
            )

            if let glow = centerGradient.outputImage?.cropped(to: extent),
               let screen = CIFilter(name: "CIScreenBlendMode") {
                screen.setValue(glow, forKey: kCIInputImageKey)
                screen.setValue(vignetted, forKey: kCIInputBackgroundImageKey)
                vignetted = screen.outputImage?.cropped(to: extent) ?? vignetted
            }
        }

        return vignetted
    }

    private static func applyHalation(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }

        let extent = image.extent
        let maxDimension = max(extent.width, extent.height)
        guard let highPass = CIFilter(name: "CIColorControls") else {
            return image
        }
        highPass.setValue(image, forKey: kCIInputImageKey)
        highPass.setValue(0.0, forKey: kCIInputSaturationKey)
        highPass.setValue(2.2 + amount * 1.4, forKey: kCIInputContrastKey)
        highPass.setValue(-0.58, forKey: kCIInputBrightnessKey)

        guard let highMask = highPass.outputImage?.cropped(to: extent) else {
            return image
        }

        let bloom = CIFilter.bloom()
        bloom.inputImage = highMask
        bloom.intensity = Float(amount * 1.9)
        bloom.radius = Float(maxDimension * (0.014 + amount * 0.010))

        guard let bloomed = bloom.outputImage?.cropped(to: extent) else {
            return image
        }

        let warm = CIFilter.colorMatrix()
        warm.inputImage = bloomed
        warm.rVector = CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0)
        warm.gVector = CIVector(x: 0.0, y: 0.42, z: 0.0, w: 0.0)
        warm.bVector = CIVector(x: 0.0, y: 0.0, z: 0.18, w: 0.0)
        warm.aVector = CIVector(x: 0.0, y: 0.0, z: 0.0, w: CGFloat(0.32 * amount))

        guard let blend = CIFilter(name: "CIScreenBlendMode") else {
            let composite = CIFilter.sourceOverCompositing()
            composite.inputImage = warm.outputImage?.cropped(to: extent)
            composite.backgroundImage = image
            return composite.outputImage?.cropped(to: extent) ?? image
        }

        blend.setValue(warm.outputImage?.cropped(to: extent), forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    private static func applyLightLeak(_ image: CIImage, film: FilmPreset) -> CIImage {
        guard film.lightLeakAmount > 0 else { return image }

        let extent = image.extent
        let seed = stableSeed(for: film.id)
        let isLeft = seed.isMultiple(of: 2)
        let isTop = (seed / 3).isMultiple(of: 2)
        let center = CGPoint(
            x: extent.minX + extent.width * (isLeft ? 0.04 : 0.96),
            y: extent.minY + extent.height * (isTop ? 0.86 : 0.14)
        )
        let maxDimension = max(extent.width, extent.height)

        let gradient = CIFilter.radialGradient()
        gradient.center = center
        gradient.radius0 = Float(maxDimension * 0.02)
        gradient.radius1 = Float(maxDimension * (0.40 + CGFloat(seed % 18) / 100.0))
        gradient.color0 = CIColor(red: 1.0, green: 0.35, blue: 0.12, alpha: film.lightLeakAmount * 0.88)
        gradient.color1 = CIColor(red: 1.0, green: 0.76, blue: 0.18, alpha: 0.0)

        let stripe = CIFilter.linearGradient()
        let stripeX = extent.minX + extent.width * (isLeft ? 0.0 : 1.0)
        stripe.point0 = CGPoint(x: stripeX, y: extent.midY)
        stripe.point1 = CGPoint(x: stripeX + extent.width * (isLeft ? 0.28 : -0.28), y: extent.midY)
        stripe.color0 = CIColor(red: 1.0, green: 0.20, blue: 0.10, alpha: film.lightLeakAmount * 0.42)
        stripe.color1 = CIColor(red: 1.0, green: 0.74, blue: 0.22, alpha: 0.0)

        guard let leak = gradient.outputImage?.cropped(to: extent),
              let leakStripe = stripe.outputImage?.cropped(to: extent) else {
            return image
        }

        let combined = CIFilter.sourceOverCompositing()
        combined.inputImage = leakStripe
        combined.backgroundImage = leak

        guard let blend = CIFilter(name: "CIScreenBlendMode") else {
            let composite = CIFilter.sourceOverCompositing()
            composite.inputImage = combined.outputImage?.cropped(to: extent)
            composite.backgroundImage = image
            return composite.outputImage?.cropped(to: extent) ?? image
        }

        blend.setValue(combined.outputImage?.cropped(to: extent), forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    private static func applyFinishingTexture(to image: CGImage, film: FilmPreset, intensity: Double) -> CGImage {
        let finishingIntensity = intensity.clamped(to: 0...1)
        guard finishingIntensity > 0.001 else { return image }

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
            let renderingProfile = FilmRenderingProfile.profile(for: film)
            let toneSeparation = FilmToneSeparation.profile(for: film)
            let colorPolish = FilmColorPolish.profile(for: film)
            let amount = max(0.0, min(1.0, film.grainAmount * finishingIntensity))
            let isoScale = sqrt(Double(max(50, film.iso)) / 400.0).clamped(to: 0.72...1.48)
            let lumaAmplitude = amount * 17.5 * isoScale * film.grainSize.clamped(to: 0.7...1.45)
            let chromaAmplitude = film.category == .blackWhite ? 0.0 : lumaAmplitude * 0.18
            let colorWarmth = finishingWarmth(for: film) * finishingIntensity
            let appliesColorFinish = film.category != .blackWhite
            var previousRowNoise = [Double](repeating: 0, count: width)
            var currentRowNoise = [Double](repeating: 0, count: width)

            for y in 0..<height {
                currentRowNoise.withUnsafeMutableBufferPointer { rowNoise in
                    for index in rowNoise.indices {
                        rowNoise[index] = 0
                    }
                }

                for x in 0..<width {
                    let index = y * bytesPerRow + x * bytesPerPixel
                    var r = Double(pixelBuffer[index])
                    var g = Double(pixelBuffer[index + 1])
                    var b = Double(pixelBuffer[index + 2])
                    let luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                    let skinWeight = appliesColorFinish ? skinToneWeight(red: r, green: g, blue: b, luminance: luminance) : 0.0
                    let highlightWeight = smoothstep(edge0: 0.68, edge1: 0.96, x: luminance)

                    if appliesColorFinish {
                        let shadowWarmth = (1.0 - luminance).clamped(to: 0...1) * colorWarmth
                        let skinWarmth = skinWeight * colorWarmth * (1.0 - highlightWeight * 0.58)
                        let skinLuma = luminance * 255.0
                        let preservation = skinWeight * renderingProfile.skinProtection * finishingIntensity

                        r = skinLuma + (r - skinLuma) * (1.0 - preservation * 0.050)
                        g = skinLuma + (g - skinLuma) * (1.0 - preservation * 0.030)
                        b = skinLuma + (b - skinLuma) * (1.0 - preservation * 0.070)
                        r += skinWarmth * 4.2 + shadowWarmth * 1.4
                        g += skinWarmth * 1.0 + shadowWarmth * 0.45
                        b -= skinWarmth * 3.2 + shadowWarmth * 1.1

                        let highlightRecovery = highlightWeight * renderingProfile.highlightRecovery * finishingIntensity
                        if highlightRecovery > 0 {
                            let recoveredLuma = min(246.0, skinLuma + (245.0 - skinLuma) * 0.18)
                            r = r * (1.0 - highlightRecovery * 0.20) + recoveredLuma * (highlightRecovery * 0.20)
                            g = g * (1.0 - highlightRecovery * 0.18) + recoveredLuma * (highlightRecovery * 0.18)
                            b = b * (1.0 - highlightRecovery * 0.14) + recoveredLuma * (highlightRecovery * 0.14)
                        }

                        let shadowToneWeight = (1.0 - smoothstep(edge0: 0.16, edge1: 0.62, x: luminance)) * toneSeparation.intensity * finishingIntensity
                        let highlightToneWeight = highlightWeight * toneSeparation.intensity * finishingIntensity * (1.0 - skinWeight * 0.38)
                        let midtoneToneWeight = (1.0 - abs(luminance - 0.52) * 2.2).clamped(to: 0...1) * toneSeparation.intensity * finishingIntensity

                        r += shadowToneWeight * toneSeparation.shadowR
                            + highlightToneWeight * toneSeparation.highlightR
                            + midtoneToneWeight * toneSeparation.midtoneR
                        g += shadowToneWeight * toneSeparation.shadowG
                            + highlightToneWeight * toneSeparation.highlightG
                            + midtoneToneWeight * toneSeparation.midtoneG
                        b += shadowToneWeight * toneSeparation.shadowB
                            + highlightToneWeight * toneSeparation.highlightB
                            + midtoneToneWeight * toneSeparation.midtoneB

                        if colorPolish.intensity > 0 {
                            let polishIntensity = colorPolish.intensity * finishingIntensity
                            let midtonePresence = (1.0 - abs(luminance - 0.52) * 2.0).clamped(to: 0...1)
                            let deepShadow = (1.0 - smoothstep(edge0: 0.14, edge1: 0.58, x: luminance)) * (1.0 - skinWeight * 0.45)
                            let warmHighlight = highlightWeight * (1.0 - skinWeight * 0.28)
                            let skinCream = skinWeight * colorPolish.skinCream * polishIntensity * (1.0 - highlightWeight * 0.38)
                            let backgroundWarmth = midtonePresence * colorPolish.midtoneWarmth * polishIntensity * (1.0 - skinWeight * 0.72)

                            r += skinCream * 5.6 + warmHighlight * colorPolish.highlightCream * polishIntensity * 4.4 + backgroundWarmth * 2.2
                            g += skinCream * 1.4 + warmHighlight * colorPolish.highlightCream * polishIntensity * 2.1 + backgroundWarmth * 0.9
                            b -= skinCream * 4.6 + warmHighlight * colorPolish.highlightCream * polishIntensity * 3.0

                            r -= deepShadow * colorPolish.shadowCoolness * polishIntensity * 2.6
                            g += deepShadow * colorPolish.shadowCoolness * polishIntensity * 0.9
                            b += deepShadow * colorPolish.shadowCoolness * polishIntensity * 4.2

                            let greenWeight = greenSubjectWeight(red: r, green: g, blue: b, luminance: luminance)
                                * colorPolish.greenPurity
                                * polishIntensity
                                * (1.0 - skinWeight * 0.85)
                            if greenWeight > 0 {
                                let greenLuma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                                r = r * (1.0 - greenWeight * 0.050) + greenLuma * (greenWeight * 0.012)
                                g += greenWeight * 2.7
                                b += greenWeight * 1.3
                            }

                            if skinWeight > 0 {
                                let skinNeutral = (r + g * 1.18 + b * 0.72) / 2.90
                                let redRestraint = skinWeight * colorPolish.skinRedRestraint * polishIntensity
                                r = r * (1.0 - redRestraint * 0.11) + skinNeutral * (redRestraint * 0.11)
                                g = g * (1.0 - redRestraint * 0.035) + skinNeutral * (redRestraint * 0.035)
                            }
                        }

                        let redDominance = ((r - max(g, b)) / 96.0).clamped(to: 0...1)
                        if redDominance > 0 {
                            let compressedRed = r * 0.72 + g * 0.20 + b * 0.08
                            let compression = redDominance * toneSeparation.redCompression * finishingIntensity
                            r = r * (1.0 - compression) + compressedRed * compression
                        }
                    }

                    let midtoneWeight = (1.0 - abs(luminance - 0.48) * 1.65).clamped(to: 0...1)
                    let shadowWeight = (1.0 - luminance).clamped(to: 0...1)
                    let textureWeight = (0.20 + midtoneWeight * 0.48 + shadowWeight * 0.32)
                        * (1.0 - skinWeight * renderingProfile.skinTextureProtection)
                        * (1.0 - highlightWeight * renderingProfile.highlightTextureProtection)
                    let rawNoise = triangularNoise(&generator)
                    let leftNoise = x > 0 ? currentRowNoise[x - 1] : rawNoise
                    let topNoise = y > 0 ? previousRowNoise[x] : rawNoise
                    let wovenNoise = rawNoise * 0.58 + leftNoise * 0.20 + topNoise * 0.22
                    currentRowNoise[x] = wovenNoise

                    let lumaNoise = wovenNoise * lumaAmplitude * textureWeight
                    let redChroma = triangularNoise(&generator) * chromaAmplitude * textureWeight
                    let blueChroma = triangularNoise(&generator) * chromaAmplitude * textureWeight

                    pixelBuffer[index] = UInt8((r + lumaNoise + redChroma * 0.82).clamped(to: 0...255))
                    pixelBuffer[index + 1] = UInt8((g + lumaNoise - redChroma * 0.18 - blueChroma * 0.16).clamped(to: 0...255))
                    pixelBuffer[index + 2] = UInt8((b + lumaNoise + blueChroma * 0.86).clamped(to: 0...255))
                }

                swap(&previousRowNoise, &currentRowNoise)
            }

            return context.makeImage()
        }

        return output ?? image
    }

    private static func skinToneWeight(red: Double, green: Double, blue: Double, luminance: Double) -> Double {
        let normalizedRed = red / 255.0
        let normalizedGreen = green / 255.0
        let normalizedBlue = blue / 255.0
        let warmth = ((normalizedRed - normalizedBlue) / 0.32).clamped(to: 0...1)
        let redGreenBalance = (1.0 - abs((normalizedRed - normalizedGreen) - 0.075) / 0.17).clamped(to: 0...1)
        let greenBlueSeparation = ((normalizedGreen - normalizedBlue) / 0.24).clamped(to: 0...1)
        let exposureWindow = (1.0 - abs(luminance - 0.58) / 0.40).clamped(to: 0...1)
        return warmth * redGreenBalance * greenBlueSeparation * exposureWindow
    }

    private static func greenSubjectWeight(red: Double, green: Double, blue: Double, luminance: Double) -> Double {
        let normalizedRed = red / 255.0
        let normalizedGreen = green / 255.0
        let normalizedBlue = blue / 255.0
        let greenLead = ((normalizedGreen - max(normalizedRed, normalizedBlue)) / 0.16).clamped(to: 0...1)
        let notNeon = (1.0 - smoothstep(edge0: 0.72, edge1: 0.98, x: normalizedGreen)).clamped(to: 0...1)
        let exposureWindow = (1.0 - abs(luminance - 0.48) / 0.48).clamped(to: 0...1)
        return greenLead * notNeon * exposureWindow
    }

    private static func smoothstep(edge0: Double, edge1: Double, x: Double) -> Double {
        let t = ((x - edge0) / (edge1 - edge0)).clamped(to: 0...1)
        return t * t * (3.0 - 2.0 * t)
    }

    private static func finishingWarmth(for film: FilmPreset) -> Double {
        switch film.id {
        case "human-warm-400", "muse-portrait-400", "soft-portrait-400":
            return 1.0
        case "sunlit-gold-200", "t-compact-gold", "instant-square", "instant-wide", "sx-fade":
            return 0.78
        case "human-vignette-800", "m-rangefinder", "pocket-flash":
            return 0.58
        default:
            return film.temperatureShift > 120 ? 0.48 : 0.32
        }
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

    private static func stableSeed(for value: String) -> UInt64 {
        var seed: UInt64 = 14_695_981_039_346_656_037
        for scalar in value.unicodeScalars {
            seed ^= UInt64(scalar.value)
            seed = seed &* 1_099_511_628_211
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
                let frameRect = CGRect(origin: .zero, size: canvasSize)
                paperColor(for: film.borderStyle).setFill()
                context.fill(frameRect)
                drawPaperTexture(
                    film: film,
                    borderStyle: film.borderStyle,
                    in: frameRect,
                    context: context.cgContext
                )
                drawInnerPhotoShadow(
                    imageRect: CGRect(x: borderPadding, y: borderPadding, width: imageSize.width, height: imageSize.height),
                    context: context.cgContext
                )
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
            drawImperfectTimestamp(stamp, in: rect, attributes: attributes, film: film)
        }
    }

    private static func drawPaperTexture(
        film: FilmPreset,
        borderStyle: BorderStyle,
        in rect: CGRect,
        context: CGContext
    ) {
        let seed = stableSeed(for: film.id + borderStyle.rawValue)
        context.saveGState()
        context.setBlendMode(.multiply)

        UIColor.black.withAlphaComponent(0.025).setStroke()
        for index in 0..<44 {
            let x = rect.minX + rect.width * CGFloat((seed &+ UInt64(index * 37)) % 1000) / 1000.0
            let y = rect.minY + rect.height * CGFloat((seed &+ UInt64(index * 61)) % 1000) / 1000.0
            let length = rect.width * CGFloat(0.015 + Double((index % 5)) * 0.006)
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + length, y: y + CGFloat((index % 3) - 1) * 0.8))
            context.strokePath()
        }

        for index in 0..<70 {
            let x = rect.minX + rect.width * CGFloat((seed &+ UInt64(index * 53)) % 1000) / 1000.0
            let y = rect.minY + rect.height * CGFloat((seed &+ UInt64(index * 97)) % 1000) / 1000.0
            let alpha = CGFloat(0.010 + Double(index % 4) * 0.004)
            UIColor.black.withAlphaComponent(alpha).setFill()
            context.fillEllipse(in: CGRect(x: x, y: y, width: 1.0, height: 1.0))
        }

        context.restoreGState()
    }

    private static func drawInnerPhotoShadow(imageRect: CGRect, context: CGContext) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 8, color: UIColor.black.withAlphaComponent(0.22).cgColor)
        UIColor.white.setFill()
        context.fill(imageRect)
        context.restoreGState()
    }

    private static func drawImperfectTimestamp(
        _ stamp: String,
        in rect: CGRect,
        attributes: [NSAttributedString.Key: Any],
        film: FilmPreset
    ) {
        let seed = stableSeed(for: film.id + stamp)
        let ghostOffset = CGFloat(seed % 3) * 0.38 + 0.28
        var ghostAttributes = attributes
        if let color = attributes[.foregroundColor] as? UIColor {
            ghostAttributes[.foregroundColor] = color.withAlphaComponent(0.20)
        }
        stamp.draw(in: rect.offsetBy(dx: ghostOffset, dy: 0.45), withAttributes: ghostAttributes)
        stamp.draw(in: rect, withAttributes: attributes)
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

private struct FilmRenderingProfile {
    let microContrast: Double
    let microContrastRadius: CGFloat
    let midtoneSoftness: Double
    let softnessRadius: CGFloat
    let highlightRecovery: Double
    let shadowCushion: Double
    let skinProtection: Double
    let skinTextureProtection: Double
    let highlightTextureProtection: Double
    let vignetteDensity: Double
    let centerLift: Double

    static func profile(for film: FilmPreset) -> FilmRenderingProfile {
        switch film.id {
        case "human-warm-400":
            return .init(
                microContrast: 0.34,
                microContrastRadius: 0.0016,
                midtoneSoftness: 0.055,
                softnessRadius: 0.0048,
                highlightRecovery: 0.16,
                shadowCushion: 0.010,
                skinProtection: 0.82,
                skinTextureProtection: 0.34,
                highlightTextureProtection: 0.50,
                vignetteDensity: 0.42,
                centerLift: 0.095
            )
        case "human-vignette-800":
            return .init(
                microContrast: 0.42,
                microContrastRadius: 0.0019,
                midtoneSoftness: 0.035,
                softnessRadius: 0.0042,
                highlightRecovery: 0.10,
                shadowCushion: 0.006,
                skinProtection: 0.58,
                skinTextureProtection: 0.24,
                highlightTextureProtection: 0.36,
                vignetteDensity: 0.46,
                centerLift: 0.16
            )
        case "muse-portrait-400":
            return .init(
                microContrast: 0.18,
                microContrastRadius: 0.0013,
                midtoneSoftness: 0.15,
                softnessRadius: 0.0054,
                highlightRecovery: 0.23,
                shadowCushion: 0.018,
                skinProtection: 1.0,
                skinTextureProtection: 0.48,
                highlightTextureProtection: 0.66,
                vignetteDensity: 0.30,
                centerLift: 0.10
            )
        case "soft-portrait-400":
            return .init(
                microContrast: 0.22,
                microContrastRadius: 0.0014,
                midtoneSoftness: 0.11,
                softnessRadius: 0.0050,
                highlightRecovery: 0.18,
                shadowCushion: 0.014,
                skinProtection: 0.94,
                skinTextureProtection: 0.42,
                highlightTextureProtection: 0.58,
                vignetteDensity: 0.34,
                centerLift: 0.085
            )
        default:
            return .init(
                microContrast: film.category == .portrait ? 0.22 : 0.30,
                microContrastRadius: film.category == .portrait ? 0.0014 : 0.0017,
                midtoneSoftness: film.category == .portrait ? 0.10 : 0.035,
                softnessRadius: film.category == .portrait ? 0.0050 : 0.0042,
                highlightRecovery: film.category == .portrait ? 0.16 : 0.08,
                shadowCushion: film.category == .portrait ? 0.012 : 0.004,
                skinProtection: film.category == .portrait ? 0.90 : 0.60,
                skinTextureProtection: film.category == .portrait ? 0.40 : 0.22,
                highlightTextureProtection: film.category == .portrait ? 0.54 : 0.34,
                vignetteDensity: film.vignetteAmount > 0.35 ? 0.44 : 0.38,
                centerLift: film.vignetteAmount > 0.35 ? 0.13 : 0.070
            )
        }
    }
}

private struct FilmVignetteProfile {
    let edgeDensity: Double
    let horizontalScale: CGFloat
    let verticalScale: CGFloat
    let centerOffsetX: CGFloat
    let centerOffsetY: CGFloat
    let centerRadius: CGFloat
    let centerGlow: Double
    let edgeRed: CGFloat
    let edgeGreen: CGFloat
    let edgeBlue: CGFloat
    let glowRed: CGFloat
    let glowGreen: CGFloat
    let glowBlue: CGFloat

    static func profile(for film: FilmPreset) -> FilmVignetteProfile {
        switch film.id {
        case "human-warm-400":
            return .init(
                edgeDensity: 0.82,
                horizontalScale: 0.92,
                verticalScale: 1.12,
                centerOffsetX: -0.015,
                centerOffsetY: 0.018,
                centerRadius: 0.60,
                centerGlow: 1.08,
                edgeRed: 0.16, edgeGreen: 0.13, edgeBlue: 0.095,
                glowRed: 1.0, glowGreen: 0.91, glowBlue: 0.76
            )
        case "human-vignette-800":
            return .init(
                edgeDensity: 0.92,
                horizontalScale: 0.84,
                verticalScale: 1.18,
                centerOffsetX: 0.0,
                centerOffsetY: 0.025,
                centerRadius: 0.50,
                centerGlow: 1.16,
                edgeRed: 0.105, edgeGreen: 0.100, edgeBlue: 0.090,
                glowRed: 0.92, glowGreen: 0.88, glowBlue: 0.78
            )
        case "muse-portrait-400", "soft-portrait-400":
            return .init(
                edgeDensity: 0.68,
                horizontalScale: 0.94,
                verticalScale: 1.10,
                centerOffsetX: 0.0,
                centerOffsetY: 0.035,
                centerRadius: 0.66,
                centerGlow: 0.92,
                edgeRed: 0.18, edgeGreen: 0.145, edgeBlue: 0.115,
                glowRed: 1.0, glowGreen: 0.92, glowBlue: 0.82
            )
        default:
            return .init(
                edgeDensity: 1.0,
                horizontalScale: 0.90,
                verticalScale: 1.10,
                centerOffsetX: 0.0,
                centerOffsetY: 0.0,
                centerRadius: 0.54,
                centerGlow: 1.0,
                edgeRed: 0.15, edgeGreen: 0.118, edgeBlue: 0.085,
                glowRed: 1.0, glowGreen: 0.88, glowBlue: 0.70
            )
        }
    }
}

private struct FilmColorPolish {
    let intensity: Double
    let skinCream: Double
    let skinRedRestraint: Double
    let greenPurity: Double
    let shadowCoolness: Double
    let highlightCream: Double
    let midtoneWarmth: Double

    static func profile(for film: FilmPreset) -> FilmColorPolish {
        guard film.category != .blackWhite else { return .neutral }

        switch film.id {
        case "human-warm-400":
            return .init(
                intensity: 1.0,
                skinCream: 0.86,
                skinRedRestraint: 0.58,
                greenPurity: 0.52,
                shadowCoolness: 0.12,
                highlightCream: 0.72,
                midtoneWarmth: 0.56
            )
        case "human-vignette-800":
            return .init(
                intensity: 1.0,
                skinCream: 0.44,
                skinRedRestraint: 0.42,
                greenPurity: 0.28,
                shadowCoolness: 0.76,
                highlightCream: 0.34,
                midtoneWarmth: 0.18
            )
        case "muse-portrait-400":
            return .init(
                intensity: 1.0,
                skinCream: 1.0,
                skinRedRestraint: 0.76,
                greenPurity: 0.18,
                shadowCoolness: 0.08,
                highlightCream: 0.86,
                midtoneWarmth: 0.42
            )
        case "soft-portrait-400":
            return .init(
                intensity: 1.0,
                skinCream: 0.88,
                skinRedRestraint: 0.68,
                greenPurity: 0.20,
                shadowCoolness: 0.10,
                highlightCream: 0.70,
                midtoneWarmth: 0.32
            )
        default:
            return .init(
                intensity: film.category == .portrait ? 0.55 : 0.28,
                skinCream: film.category == .portrait ? 0.54 : 0.26,
                skinRedRestraint: film.category == .portrait ? 0.46 : 0.22,
                greenPurity: film.tintShift < 0 ? 0.34 : 0.16,
                shadowCoolness: film.temperatureShift < 0 ? 0.34 : 0.08,
                highlightCream: film.temperatureShift > 120 ? 0.36 : 0.16,
                midtoneWarmth: film.temperatureShift > 120 ? 0.24 : 0.08
            )
        }
    }

    static let neutral = FilmColorPolish(
        intensity: 0,
        skinCream: 0,
        skinRedRestraint: 0,
        greenPurity: 0,
        shadowCoolness: 0,
        highlightCream: 0,
        midtoneWarmth: 0
    )
}

private struct FilmToneSeparation {
    let intensity: Double
    let shadowR: Double
    let shadowG: Double
    let shadowB: Double
    let midtoneR: Double
    let midtoneG: Double
    let midtoneB: Double
    let highlightR: Double
    let highlightG: Double
    let highlightB: Double
    let redCompression: Double

    static func profile(for film: FilmPreset) -> FilmToneSeparation {
        guard film.category != .blackWhite else {
            return .neutral
        }

        switch film.id {
        case "human-warm-400":
            return .init(
                intensity: 0.72,
                shadowR: 0.4, shadowG: 1.2, shadowB: -2.2,
                midtoneR: 1.0, midtoneG: 0.5, midtoneB: -1.2,
                highlightR: 4.0, highlightG: 1.6, highlightB: -3.2,
                redCompression: 0.070
            )
        case "human-vignette-800":
            return .init(
                intensity: 0.78,
                shadowR: -2.4, shadowG: 0.7, shadowB: -3.8,
                midtoneR: 0.2, midtoneG: 0.2, midtoneB: -1.0,
                highlightR: 2.0, highlightG: 0.8, highlightB: -1.8,
                redCompression: 0.060
            )
        case "muse-portrait-400", "soft-portrait-400":
            return .init(
                intensity: 0.62,
                shadowR: 0.8, shadowG: 0.4, shadowB: -1.0,
                midtoneR: 1.2, midtoneG: 0.5, midtoneB: -1.2,
                highlightR: 3.4, highlightG: 1.4, highlightB: -2.8,
                redCompression: 0.090
            )
        case "green-street-400", "superia-green", "classic-chrome-x":
            return .init(
                intensity: 0.68,
                shadowR: -2.2, shadowG: 1.8, shadowB: -0.4,
                midtoneR: -0.4, midtoneG: 0.8, midtoneB: -0.4,
                highlightR: 1.0, highlightG: 0.4, highlightB: -1.0,
                redCompression: 0.050
            )
        case "tungsten-800":
            return .init(
                intensity: 0.82,
                shadowR: -1.4, shadowG: 0.4, shadowB: 3.4,
                midtoneR: 0.8, midtoneG: -0.2, midtoneB: 1.2,
                highlightR: 4.8, highlightG: 1.2, highlightB: -2.2,
                redCompression: 0.040
            )
        case "ccd-2003", "cyber-ccd-blue":
            return .init(
                intensity: 0.70,
                shadowR: -1.8, shadowG: 0.4, shadowB: 3.2,
                midtoneR: -0.6, midtoneG: 0.2, midtoneB: 1.4,
                highlightR: -0.4, highlightG: 0.6, highlightB: 2.4,
                redCompression: 0.030
            )
        case "instant-square", "instant-wide", "sx-fade":
            return .init(
                intensity: 0.50,
                shadowR: 1.2, shadowG: 0.8, shadowB: -1.0,
                midtoneR: 0.8, midtoneG: 0.4, midtoneB: -0.8,
                highlightR: 3.0, highlightG: 1.6, highlightB: -1.8,
                redCompression: 0.080
            )
        default:
            return .init(
                intensity: film.temperatureShift > 120 ? 0.50 : 0.42,
                shadowR: film.temperatureShift > 120 ? 0.2 : -0.8,
                shadowG: film.tintShift < 0 ? 1.0 : 0.3,
                shadowB: film.temperatureShift > 120 ? -1.4 : 0.8,
                midtoneR: film.temperatureShift > 120 ? 0.7 : -0.2,
                midtoneG: 0.2,
                midtoneB: film.temperatureShift > 120 ? -0.7 : 0.4,
                highlightR: film.temperatureShift > 120 ? 2.2 : 0.8,
                highlightG: film.temperatureShift > 120 ? 0.9 : 0.4,
                highlightB: film.temperatureShift > 120 ? -1.8 : 0.0,
                redCompression: 0.045
            )
        }
    }

    static let neutral = FilmToneSeparation(
        intensity: 0,
        shadowR: 0, shadowG: 0, shadowB: 0,
        midtoneR: 0, midtoneG: 0, midtoneB: 0,
        highlightR: 0, highlightG: 0, highlightB: 0,
        redCompression: 0
    )
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
