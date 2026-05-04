import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let canvas = CGFloat(side)
let masterOutputPath = CommandLine.arguments.dropFirst().first
    ?? "StillLight/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let iconOutputDirectory = CommandLine.arguments.dropFirst().dropFirst().first
    ?? "StillLight/Resources/AppIcons"

func cgColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func hex(_ value: UInt32, alpha: CGFloat = 1) -> CGColor {
    let red = CGFloat((value >> 16) & 0xff) / 255
    let green = CGFloat((value >> 8) & 0xff) / 255
    let blue = CGFloat(value & 0xff) / 255
    return cgColor(red, green, blue, alpha)
}

func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: x, y: y)
}

func drawLinearGradient(
    in context: CGContext,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!
    context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func drawRadialGradient(
    in context: CGContext,
    colors: [CGColor],
    locations: [CGFloat],
    center: CGPoint,
    startRadius: CGFloat,
    endRadius: CGFloat
) {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: startRadius,
        endCenter: center,
        endRadius: endRadius,
        options: [.drawsAfterEndLocation]
    )
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func regularPolygon(center: CGPoint, radius: CGFloat, sides: Int, rotation: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for index in 0..<sides {
        let angle = rotation + CGFloat(index) * 2 * .pi / CGFloat(sides)
        let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        index == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bytesPerPixel = 4
let bytesPerRow = side * bytesPerPixel
var pixels = [UInt8](repeating: 0, count: side * bytesPerRow)

guard let context = CGContext(
    data: &pixels,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create bitmap context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.interpolationQuality = .high
context.translateBy(x: 0, y: canvas)
context.scaleBy(x: 1, y: -1)

let fullRect = CGRect(x: 0, y: 0, width: canvas, height: canvas)

drawLinearGradient(
    in: context,
    colors: [hex(0x040507), hex(0x111820), hex(0x050608)],
    locations: [0, 0.52, 1],
    start: point(0, 0),
    end: point(canvas, canvas)
)
drawRadialGradient(
    in: context,
    colors: [hex(0x6fd6ff, alpha: 0.36), hex(0x2a7d9b, alpha: 0.13), hex(0x000000, alpha: 0)],
    locations: [0, 0.34, 1],
    center: point(590, 415),
    startRadius: 0,
    endRadius: 690
)
drawRadialGradient(
    in: context,
    colors: [hex(0xffc56a, alpha: 0.16), hex(0x000000, alpha: 0)],
    locations: [0, 1],
    center: point(246, 246),
    startRadius: 0,
    endRadius: 480
)

var seed: UInt64 = 0x51544c49474854
func random01() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((seed >> 40) & 0xffffff) / CGFloat(0xffffff)
}

for _ in 0..<4200 {
    let x = random01() * canvas
    let y = random01() * canvas
    let value = random01()
    let alpha: CGFloat = 0.018 + random01() * 0.035
    context.setFillColor(value > 0.54 ? cgColor(1, 1, 1, alpha) : cgColor(0, 0, 0, alpha))
    context.fill(CGRect(x: x, y: y, width: 1 + random01() * 1.2, height: 1 + random01() * 1.2))
}

let bodyRect = CGRect(x: 150, y: 150, width: 724, height: 724)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: 34), blur: 64, color: cgColor(0, 0, 0, 0.64))
context.addPath(roundedRect(bodyRect, radius: 198))
context.clip()
drawLinearGradient(
    in: context,
    colors: [hex(0x1f2730), hex(0x090c10), hex(0x27313a)],
    locations: [0, 0.56, 1],
    start: point(bodyRect.minX, bodyRect.minY),
    end: point(bodyRect.maxX, bodyRect.maxY)
)
drawRadialGradient(
    in: context,
    colors: [hex(0xffffff, alpha: 0.15), hex(0xffffff, alpha: 0.03), hex(0x000000, alpha: 0)],
    locations: [0, 0.45, 1],
    center: point(330, 250),
    startRadius: 0,
    endRadius: 530
)
context.restoreGState()

context.addPath(roundedRect(bodyRect.insetBy(dx: 10, dy: 10), radius: 188))
context.setStrokeColor(hex(0xcbd2d7, alpha: 0.38))
context.setLineWidth(2.5)
context.strokePath()

context.addPath(roundedRect(bodyRect.insetBy(dx: 42, dy: 42), radius: 154))
context.setStrokeColor(hex(0x0d1115, alpha: 0.76))
context.setLineWidth(18)
context.strokePath()

let gate = CGRect(x: 238, y: 300, width: 548, height: 424)
context.saveGState()
context.addPath(roundedRect(gate, radius: 108))
context.clip()
drawLinearGradient(
    in: context,
    colors: [hex(0x07090d), hex(0x171e25), hex(0x020304)],
    locations: [0, 0.48, 1],
    start: point(gate.minX, gate.minY),
    end: point(gate.maxX, gate.maxY)
)
drawRadialGradient(
    in: context,
    colors: [hex(0x89e7ff, alpha: 0.21), hex(0x0a3a4b, alpha: 0.08), hex(0x000000, alpha: 0)],
    locations: [0, 0.4, 1],
    center: point(566, 454),
    startRadius: 0,
    endRadius: 410
)
context.restoreGState()

context.addPath(roundedRect(gate, radius: 108))
context.setStrokeColor(hex(0xe8ecef, alpha: 0.34))
context.setLineWidth(4)
context.strokePath()

let center = point(512, 512)
for (radius, lineWidth, color) in [
    (CGFloat(226), CGFloat(3), hex(0xdce5ea, alpha: 0.24)),
    (CGFloat(184), CGFloat(14), hex(0x111820, alpha: 0.85)),
    (CGFloat(170), CGFloat(2), hex(0x78daf6, alpha: 0.34)),
    (CGFloat(112), CGFloat(2.5), hex(0xf5f7f8, alpha: 0.25))
] {
    context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    context.setStrokeColor(color)
    context.setLineWidth(lineWidth)
    context.strokePath()
}

context.saveGState()
context.addEllipse(in: CGRect(x: center.x - 154, y: center.y - 154, width: 308, height: 308))
context.clip()
drawRadialGradient(
    in: context,
    colors: [hex(0x9ef4ff, alpha: 0.53), hex(0x23566c, alpha: 0.26), hex(0x02080c, alpha: 0.95)],
    locations: [0, 0.32, 1],
    center: point(462, 454),
    startRadius: 0,
    endRadius: 218
)
for i in 0..<6 {
    let angle = -CGFloat.pi / 6 + CGFloat(i) * CGFloat.pi / 3
    let path = CGMutablePath()
    path.move(to: center)
    path.addArc(center: center, radius: 146, startAngle: angle, endAngle: angle + .pi / 3.2, clockwise: false)
    path.closeSubpath()
    context.addPath(path)
    context.setFillColor(i.isMultiple(of: 2) ? hex(0x020305, alpha: 0.36) : hex(0xffffff, alpha: 0.035))
    context.fillPath()
}
context.restoreGState()

context.addPath(regularPolygon(center: center, radius: 74, sides: 6, rotation: .pi / 6))
context.setFillColor(hex(0x020407, alpha: 0.72))
context.fillPath()
context.addPath(regularPolygon(center: center, radius: 74, sides: 6, rotation: .pi / 6))
context.setStrokeColor(hex(0xaef1ff, alpha: 0.26))
context.setLineWidth(2)
context.strokePath()

context.saveGState()
context.addEllipse(in: CGRect(x: center.x - 190, y: center.y - 190, width: 380, height: 380))
context.clip()
context.translateBy(x: center.x, y: center.y)
context.rotate(by: -0.58)
let slit = CGRect(x: -292, y: -32, width: 584, height: 64)
context.addPath(roundedRect(slit, radius: 32))
context.clip()
drawLinearGradient(
    in: context,
    colors: [hex(0xffffff, alpha: 0), hex(0xf4fbff, alpha: 0.72), hex(0x71e9ff, alpha: 0.16), hex(0xffffff, alpha: 0)],
    locations: [0, 0.44, 0.63, 1],
    start: point(slit.minX, slit.midY),
    end: point(slit.maxX, slit.midY)
)
context.restoreGState()

for (radius, start, end, alpha, width) in [
    (CGFloat(204), CGFloat(-0.04), CGFloat(1.22), CGFloat(0.55), CGFloat(7)),
    (CGFloat(248), CGFloat(3.55), CGFloat(4.84), CGFloat(0.30), CGFloat(4)),
    (CGFloat(132), CGFloat(4.62), CGFloat(5.82), CGFloat(0.48), CGFloat(3))
] {
    context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    context.setStrokeColor(hex(0xaaf4ff, alpha: alpha))
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.strokePath()
}

let notch = CGRect(x: 424, y: 188, width: 176, height: 24)
context.addPath(roundedRect(notch, radius: 12))
context.setFillColor(hex(0xe5eaee, alpha: 0.58))
context.fillPath()

let dotRect = CGRect(x: 698, y: 220, width: 44, height: 44)
context.addEllipse(in: dotRect)
context.setFillColor(hex(0xf0c078, alpha: 0.66))
context.fillPath()
context.addEllipse(in: dotRect.insetBy(dx: 10, dy: 10))
context.setFillColor(hex(0xfff0c0, alpha: 0.72))
context.fillPath()

drawRadialGradient(
    in: context,
    colors: [hex(0x000000, alpha: 0), hex(0x000000, alpha: 0.42)],
    locations: [0.62, 1],
    center: center,
    startRadius: 120,
    endRadius: 724
)

guard let cgImage = context.makeImage() else {
    fatalError("Could not create image")
}

func makeOpaqueImage(from image: CGImage, width: Int, height: Int) -> CGImage {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var outputPixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue

    guard let outputContext = CGContext(
        data: &outputPixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Could not create opaque bitmap context")
    }

    outputContext.interpolationQuality = .high
    outputContext.setFillColor(hex(0x050608))
    outputContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
    outputContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let outputImage = outputContext.makeImage() else {
        fatalError("Could not create opaque image")
    }
    return outputImage
}

func writePNG(_ image: CGImage, to path: String) {
    let outputURL = URL(fileURLWithPath: path)
    do {
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch {
        fatalError("Could not create output directory for \(path): \(error)")
    }

    guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create image destination")
    }

    let properties: [CFString: Any] = [
        kCGImagePropertyPNGDictionary: [
            kCGImagePropertyPNGInterlaceType: 0
        ]
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    if !CGImageDestinationFinalize(destination) {
        fatalError("Could not write \(path)")
    }
}

let appIcons: [(filename: String, pixels: Int)] = [
    ("AppIcon20x20@2x.png", 40),
    ("AppIcon20x20@3x.png", 60),
    ("AppIcon29x29@2x.png", 58),
    ("AppIcon29x29@3x.png", 87),
    ("AppIcon40x40@2x.png", 80),
    ("AppIcon40x40@3x.png", 120),
    ("AppIcon60x60@2x.png", 120),
    ("AppIcon60x60@3x.png", 180)
]

let opaqueMaster = makeOpaqueImage(from: cgImage, width: side, height: side)
writePNG(opaqueMaster, to: masterOutputPath)

for icon in appIcons {
    let resized = makeOpaqueImage(from: opaqueMaster, width: icon.pixels, height: icon.pixels)
    writePNG(resized, to: "\(iconOutputDirectory)/\(icon.filename)")
}

print(masterOutputPath)
print(iconOutputDirectory)
