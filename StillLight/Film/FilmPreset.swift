import CoreGraphics
import Foundation

struct FilmPreset: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let localizedName: String?
    let localizedShortName: String?
    let iso: Int
    let cameraName: String
    let localizedCameraName: String?
    let category: FilmCategory
    let description: String
    let localizedDescription: String?
    let suitableScenes: [String]
    let localizedSuitableScenes: [String]
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

    init(
        id: String,
        name: String,
        shortName: String,
        iso: Int,
        description: String,
        suitableScenes: [String],
        exposureBias: Double,
        temperatureShift: Double,
        tintShift: Double,
        contrast: Double,
        brightness: Double,
        saturation: Double,
        toneCurve: ToneCurvePreset,
        grainAmount: Double,
        grainSize: Double,
        vignetteAmount: Double,
        halationAmount: Double,
        lightLeakAmount: Double,
        timestampColorHex: String,
        borderStyle: BorderStyle,
        localizedName: String? = nil,
        localizedShortName: String? = nil,
        cameraName: String = "StillLight Camera",
        localizedCameraName: String? = nil,
        category: FilmCategory = .negative,
        localizedDescription: String? = nil,
        localizedSuitableScenes: [String] = []
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.localizedName = localizedName
        self.localizedShortName = localizedShortName
        self.iso = iso
        self.cameraName = cameraName
        self.localizedCameraName = localizedCameraName
        self.category = category
        self.description = description
        self.localizedDescription = localizedDescription
        self.suitableScenes = suitableScenes
        self.localizedSuitableScenes = localizedSuitableScenes
        self.exposureBias = exposureBias
        self.temperatureShift = temperatureShift
        self.tintShift = tintShift
        self.contrast = contrast
        self.brightness = brightness
        self.saturation = saturation
        self.toneCurve = toneCurve
        self.grainAmount = grainAmount
        self.grainSize = grainSize
        self.vignetteAmount = vignetteAmount
        self.halationAmount = halationAmount
        self.lightLeakAmount = lightLeakAmount
        self.timestampColorHex = timestampColorHex
        self.borderStyle = borderStyle
    }

    var metadataLine: String {
        "ISO \(iso) - \(suitableScenes.joined(separator: " / "))"
    }

    func displayName(language: AppLanguage) -> String {
        language == .chinese ? (localizedName ?? name) : name
    }

    func displayShortName(language: AppLanguage) -> String {
        language == .chinese ? (localizedShortName ?? shortName) : shortName
    }

    func displayCameraName(language: AppLanguage) -> String {
        language == .chinese ? (localizedCameraName ?? cameraName) : cameraName
    }

    func displayDescription(language: AppLanguage) -> String {
        language == .chinese ? (localizedDescription ?? description) : description
    }

    func displayMetadataLine(language: AppLanguage) -> String {
        let scenes = language == .chinese && !localizedSuitableScenes.isEmpty ? localizedSuitableScenes : suitableScenes
        return "ISO \(iso) - \(scenes.joined(separator: " / "))"
    }

    var frameLabel: String {
        "\(cameraName) / \(shortName)"
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
    case whiteFrame
}

enum FilmCategory: String, CaseIterable, Identifiable, Codable {
    case negative
    case camera
    case instant
    case blackWhite
    case digital
    case experimental

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.negative, .chinese):
            return "彩负"
        case (.camera, .chinese):
            return "经典机型"
        case (.instant, .chinese):
            return "拍立得"
        case (.blackWhite, .chinese):
            return "黑白"
        case (.digital, .chinese):
            return "数码复古"
        case (.experimental, .chinese):
            return "实验"
        case (.negative, _):
            return "Negative"
        case (.camera, _):
            return "Camera"
        case (.instant, _):
            return "Instant"
        case (.blackWhite, _):
            return "B&W"
        case (.digital, _):
            return "Digital"
        case (.experimental, _):
            return "Experimental"
        }
    }
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
