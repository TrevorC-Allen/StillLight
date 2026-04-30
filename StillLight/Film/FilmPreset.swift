import CoreGraphics
import Foundation

struct FilmPreset: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let iso: Int
    let description: String
    let suitableScenes: [String]
    let exposureBias: Double
    let temperatureShift: Double
    let tintShift: Double
    let contrast: Double
    let brightness: Double
    let saturation: Double
    let toneCurve: ToneCurvePreset
    let grainAmount: Double
    let grainSize: Double
    let vignetteAmount: Double
    let halationAmount: Double
    let lightLeakAmount: Double
    let timestampColorHex: String
    let borderStyle: BorderStyle

    var metadataLine: String {
        "ISO \(iso) - \(suitableScenes.joined(separator: " / "))"
    }

    var defaultShotCount: Int {
        switch id {
        case "instant-square":
            return 10
        case "pocket-flash":
            return 27
        case "ccd-2003":
            return 99
        default:
            return 36
        }
    }
}

struct ToneCurvePreset: Codable, Hashable {
    let p0: CurvePoint
    let p1: CurvePoint
    let p2: CurvePoint
    let p3: CurvePoint
    let p4: CurvePoint
}

struct CurvePoint: Codable, Hashable {
    let x: Double
    let y: Double

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

enum BorderStyle: String, Codable, Hashable {
    case none
    case paper
    case instant
}

enum CaptureAspectRatio: String, CaseIterable, Identifiable, Codable {
    case ratio3x2
    case ratio4x3
    case square
    case ratio16x9
    case halfFrame

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ratio3x2:
            return "3:2"
        case .ratio4x3:
            return "4:3"
        case .square:
            return "1:1"
        case .ratio16x9:
            return "16:9"
        case .halfFrame:
            return "Half"
        }
    }

    var value: CGFloat {
        switch self {
        case .ratio3x2:
            return 3.0 / 2.0
        case .ratio4x3:
            return 4.0 / 3.0
        case .square:
            return 1.0
        case .ratio16x9:
            return 16.0 / 9.0
        case .halfFrame:
            return 3.0 / 4.0
        }
    }
}
