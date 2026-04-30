import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case chinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }
}

enum AppText {
    static func get(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .english:
            return english[key] ?? key.rawValue
        case .chinese:
            return chinese[key] ?? english[key] ?? key.rawValue
        }
    }

    enum Key: String {
        case filmRoll
        case filmRollSubtitle
        case all
        case roll
        case newRoll
        case cameraAccessNeeded
        case cameraAccessMessage
        case openSettings
        case cameraUnavailable
        case cameraUnavailableMessage
        case tryAgain
        case developing
        case developed
        case original
        case share
        case done
        case savedToPhotosAndRoll
        case lab
        case importFrame
        case importFrameSubtitle
        case importPhoto
        case strength
        case ratio
        case suggestedRoll
        case use
        case develop
        case save
        case frameLoaded
        case developedWith
        case savedToRoll
        case rollTitle
        case firstRollEmpty
        case firstRollEmptySubtitle
        case frame
        case settings
        case output
        case saveOriginalPhoto
        case addDateStamp
        case jpegQuality
        case camera
        case hapticShutter
        case gridLines
        case horizonLevel
        case defaultRatio
        case language
        case styleLibrary
        case presets
        case pipeline
        case photosSaveFailed
        case appName
    }

    private static let english: [Key: String] = [
        .filmRoll: "Film Roll",
        .filmRollSubtitle: "Choose a camera or film before shooting. Each roll defines color, contrast, grain, border, and frame label.",
        .all: "All",
        .roll: "ROLL",
        .newRoll: "NEW ROLL",
        .cameraAccessNeeded: "Camera Access Needed",
        .cameraAccessMessage: "Enable camera permission in Settings to shoot with StillLight.",
        .openSettings: "Open Settings",
        .cameraUnavailable: "Camera Unavailable",
        .cameraUnavailableMessage: "This device or simulator cannot open a live camera right now.",
        .tryAgain: "Try Again",
        .developing: "Developing",
        .developed: "Developed",
        .original: "Original",
        .share: "Share",
        .done: "Done",
        .savedToPhotosAndRoll: "Saved to Photos and StillLight Roll",
        .lab: "Lab",
        .importFrame: "Import a frame",
        .importFrameSubtitle: "Develop an existing photo with the same film pipeline.",
        .importPhoto: "Import",
        .strength: "Strength",
        .ratio: "Ratio",
        .suggestedRoll: "Suggested Roll",
        .use: "Use",
        .develop: "Develop",
        .save: "Save",
        .frameLoaded: "Frame loaded",
        .developedWith: "Developed with",
        .savedToRoll: "Saved to Photos and Roll",
        .rollTitle: "Roll",
        .firstRollEmpty: "First roll is empty",
        .firstRollEmptySubtitle: "Shoot a frame and it will appear here.",
        .frame: "Frame",
        .settings: "Settings",
        .output: "Output",
        .saveOriginalPhoto: "Save original photo",
        .addDateStamp: "Add date stamp",
        .jpegQuality: "JPEG quality",
        .camera: "Camera",
        .hapticShutter: "Haptic shutter",
        .gridLines: "Grid lines",
        .horizonLevel: "Horizon level",
        .defaultRatio: "Default ratio",
        .language: "Language",
        .styleLibrary: "Style Library",
        .presets: "Presets",
        .pipeline: "Pipeline",
        .photosSaveFailed: "Saved to StillLight Roll. Photos save failed:",
        .appName: "StillLight"
    ]

    private static let chinese: [Key: String] = [
        .filmRoll: "胶卷库",
        .filmRollSubtitle: "拍摄前选择胶卷或经典机型。每一卷都会定义色彩、反差、颗粒、边框和机型标注。",
        .all: "全部",
        .roll: "当前卷",
        .newRoll: "新胶卷",
        .cameraAccessNeeded: "需要相机权限",
        .cameraAccessMessage: "请在系统设置中允许 StillLight 使用相机。",
        .openSettings: "打开设置",
        .cameraUnavailable: "相机不可用",
        .cameraUnavailableMessage: "当前设备或模拟器暂时无法打开实时相机。",
        .tryAgain: "重试",
        .developing: "冲洗中",
        .developed: "已冲洗",
        .original: "原片",
        .share: "分享",
        .done: "完成",
        .savedToPhotosAndRoll: "已保存到照片和 StillLight 胶卷",
        .lab: "暗房",
        .importFrame: "导入一张照片",
        .importFrameSubtitle: "用同一套胶片 pipeline 冲洗已有照片。",
        .importPhoto: "导入",
        .strength: "强度",
        .ratio: "比例",
        .suggestedRoll: "推荐胶卷",
        .use: "使用",
        .develop: "冲洗",
        .save: "保存",
        .frameLoaded: "照片已载入",
        .developedWith: "已使用",
        .savedToRoll: "已保存到照片和胶卷",
        .rollTitle: "胶卷",
        .firstRollEmpty: "第一卷还是空的",
        .firstRollEmptySubtitle: "拍下一张照片后会出现在这里。",
        .frame: "相片",
        .settings: "设置",
        .output: "输出",
        .saveOriginalPhoto: "保留原片",
        .addDateStamp: "添加日期戳",
        .jpegQuality: "JPEG 质量",
        .camera: "相机",
        .hapticShutter: "快门震动",
        .gridLines: "网格线",
        .horizonLevel: "水平仪",
        .defaultRatio: "默认比例",
        .language: "语言",
        .styleLibrary: "风格库",
        .presets: "预设数量",
        .pipeline: "图像管线",
        .photosSaveFailed: "已保存到 StillLight 胶卷。系统照片保存失败：",
        .appName: "StillLight"
    ]
}
