import Foundation

struct FilmCameraProfile: Identifiable, Codable, Hashable {
    let id: String
    let modelName: String
    let localizedModelName: String
    let englishDisplayName: String
    let chineseDisplayName: String
    let category: CameraModelCategory
    let lensAndEra: String
    let localizedLensAndEra: String
    let markerIconName: String
    let bodyStyle: CameraBodyStyle
    let defaultAccessoryCapabilities: [CameraAccessoryCapability]

    func displayName(language: AppLanguage) -> String {
        language == .chinese ? chineseDisplayName : englishDisplayName
    }

    func displayModelName(language: AppLanguage) -> String {
        language == .chinese ? localizedModelName : modelName
    }

    func displayLensAndEra(language: AppLanguage) -> String {
        language == .chinese ? localizedLensAndEra : lensAndEra
    }

    func accessoryLabels(language: AppLanguage) -> [String] {
        defaultAccessoryCapabilities.map { $0.title(language: language) }
    }
}

enum CameraModelCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case compact35
    case rangefinder
    case slr
    case mediumFormat
    case instant
    case disposable
    case toyCamera
    case cinema
    case ccdCompact
    case halfFrame

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.compact35, .chinese):
            return "35mm 袖珍机"
        case (.rangefinder, .chinese):
            return "旁轴"
        case (.slr, .chinese):
            return "单反"
        case (.mediumFormat, .chinese):
            return "中画幅"
        case (.instant, .chinese):
            return "即影相机"
        case (.disposable, .chinese):
            return "一次性相机"
        case (.toyCamera, .chinese):
            return "玩具相机"
        case (.cinema, .chinese):
            return "电影机"
        case (.ccdCompact, .chinese):
            return "CCD 卡片机"
        case (.halfFrame, .chinese):
            return "半格相机"
        case (.compact35, _):
            return "35mm Compact"
        case (.rangefinder, _):
            return "Rangefinder"
        case (.slr, _):
            return "SLR"
        case (.mediumFormat, _):
            return "Medium Format"
        case (.instant, _):
            return "Instant Camera"
        case (.disposable, _):
            return "Disposable Camera"
        case (.toyCamera, _):
            return "Toy Camera"
        case (.cinema, _):
            return "Cinema Camera"
        case (.ccdCompact, _):
            return "CCD Compact"
        case (.halfFrame, _):
            return "Half Frame"
        }
    }
}

enum CameraBodyStyle: String, CaseIterable, Identifiable, Codable, Hashable {
    case brassRangefinder
    case blackPocketCompact
    case leatheretteSLR
    case studioPortraitSLR
    case daylightPointAndShoot
    case foldingInstant
    case wideInstantPlastic
    case squareInstantBox
    case disposableFlashShell
    case earlyCCDCard
    case blueCCDCard
    case hSystemBack
    case waistLevelMedium
    case plasticToy120
    case lomoCompact
    case halfFrameDiary
    case tungstenCinemaRig
    case noirCinemaBody

    var id: String { rawValue }
}

enum CameraAccessoryCapability: String, CaseIterable, Identifiable, Codable, Hashable {
    case doubleExposure
    case longExposure
    case starFilter
    case flash
    case colorTemperature
    case video
    case dateStamp
    case selfTimer
    case macro
    case squareFrame
    case halfFrame
    case wideFrame

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.doubleExposure, .chinese):
            return "双曝"
        case (.longExposure, .chinese):
            return "长曝"
        case (.starFilter, .chinese):
            return "星芒"
        case (.flash, .chinese):
            return "闪光"
        case (.colorTemperature, .chinese):
            return "色温"
        case (.video, .chinese):
            return "录像"
        case (.dateStamp, .chinese):
            return "日期戳"
        case (.selfTimer, .chinese):
            return "自拍"
        case (.macro, .chinese):
            return "微距"
        case (.squareFrame, .chinese):
            return "方构图"
        case (.halfFrame, .chinese):
            return "半格"
        case (.wideFrame, .chinese):
            return "宽幅"
        case (.doubleExposure, _):
            return "Double Exposure"
        case (.longExposure, _):
            return "Long Exposure"
        case (.starFilter, _):
            return "Star Filter"
        case (.flash, _):
            return "Flash"
        case (.colorTemperature, _):
            return "Color Temperature"
        case (.video, _):
            return "Video"
        case (.dateStamp, _):
            return "Date Stamp"
        case (.selfTimer, _):
            return "Self Timer"
        case (.macro, _):
            return "Macro"
        case (.squareFrame, _):
            return "Square Frame"
        case (.halfFrame, _):
            return "Half Frame"
        case (.wideFrame, _):
            return "Wide Frame"
        }
    }
}

enum FilmCameraProfileCatalog {
    static let profilesByFilmId: [String: FilmCameraProfile] = [
        "human-warm-400": .profile(
            id: "human-warm-400",
            modelName: "Observer 35 Compact",
            localizedModelName: "Observer 35 袖珍机",
            englishDisplayName: "Observer 35",
            chineseDisplayName: "街头观察机",
            category: .compact35,
            lensAndEra: "38mm f/2.8 pocket lens, late 1980s",
            localizedLensAndEra: "38mm f/2.8 袖珍镜头，1980 年代末",
            markerIconName: "camera.aperture",
            bodyStyle: .blackPocketCompact,
            defaultAccessoryCapabilities: [.flash, .dateStamp, .colorTemperature]
        ),
        "human-vignette-800": .profile(
            id: "human-vignette-800",
            modelName: "Low-Light 35",
            localizedModelName: "低照度 35",
            englishDisplayName: "Low-Light 35",
            chineseDisplayName: "暗廊低照度",
            category: .compact35,
            lensAndEra: "35mm f/2 fast compact, early 1990s",
            localizedLensAndEra: "35mm f/2 高速袖珍镜头，1990 年代初",
            markerIconName: "moon",
            bodyStyle: .blackPocketCompact,
            defaultAccessoryCapabilities: [.longExposure, .flash, .dateStamp]
        ),
        "muse-portrait-400": .profile(
            id: "muse-portrait-400",
            modelName: "85mm Portrait SLR",
            localizedModelName: "85mm 肖像单反",
            englishDisplayName: "Atelier 85",
            chineseDisplayName: "柔光肖像单反",
            category: .slr,
            lensAndEra: "85mm f/1.8 portrait prime, 1970s",
            localizedLensAndEra: "85mm f/1.8 肖像定焦，1970 年代",
            markerIconName: "person.crop.rectangle",
            bodyStyle: .studioPortraitSLR,
            defaultAccessoryCapabilities: [.selfTimer, .colorTemperature, .doubleExposure]
        ),
        "sunlit-gold-200": .profile(
            id: "sunlit-gold-200",
            modelName: "35mm Daylight Compact",
            localizedModelName: "35mm 日光袖珍机",
            englishDisplayName: "Daylight 35",
            chineseDisplayName: "晴日便携机",
            category: .compact35,
            lensAndEra: "35mm f/3.5 travel lens, 1990s",
            localizedLensAndEra: "35mm f/3.5 旅行镜头，1990 年代",
            markerIconName: "sun.max",
            bodyStyle: .daylightPointAndShoot,
            defaultAccessoryCapabilities: [.flash, .dateStamp, .selfTimer]
        ),
        "soft-portrait-400": .profile(
            id: "soft-portrait-400",
            modelName: "Portrait Rangefinder 50",
            localizedModelName: "50mm 人像旁轴",
            englishDisplayName: "Porcelain RF 50",
            chineseDisplayName: "瓷白旁轴 50",
            category: .rangefinder,
            lensAndEra: "50mm f/2 coated rangefinder lens, 1960s",
            localizedLensAndEra: "50mm f/2 镀膜旁轴镜头，1960 年代",
            markerIconName: "viewfinder",
            bodyStyle: .brassRangefinder,
            defaultAccessoryCapabilities: [.doubleExposure, .selfTimer, .colorTemperature]
        ),
        "silver-hp5": .profile(
            id: "silver-hp5",
            modelName: "Documentary SLR",
            localizedModelName: "纪实单反",
            englishDisplayName: "Silver Press SLR",
            chineseDisplayName: "银盐纪实单反",
            category: .slr,
            lensAndEra: "50mm f/1.8 press lens, 1970s",
            localizedLensAndEra: "50mm f/1.8 纪实镜头，1970 年代",
            markerIconName: "circle.lefthalf.filled",
            bodyStyle: .leatheretteSLR,
            defaultAccessoryCapabilities: [.doubleExposure, .dateStamp]
        ),
        "green-street-400": .profile(
            id: "green-street-400",
            modelName: "Street 35",
            localizedModelName: "街拍 35",
            englishDisplayName: "Transit 35",
            chineseDisplayName: "青绿街拍机",
            category: .compact35,
            lensAndEra: "40mm f/2.8 zone-focus lens, 1980s",
            localizedLensAndEra: "40mm f/2.8 估焦镜头，1980 年代",
            markerIconName: "tram",
            bodyStyle: .blackPocketCompact,
            defaultAccessoryCapabilities: [.flash, .dateStamp, .doubleExposure]
        ),
        "tungsten-800": .profile(
            id: "tungsten-800",
            modelName: "Super 35 Tungsten",
            localizedModelName: "Super 35 钨丝机",
            englishDisplayName: "Tungsten Super 35",
            chineseDisplayName: "钨丝电影机",
            category: .cinema,
            lensAndEra: "Super 35 cinema gate, 1980s tungsten stage",
            localizedLensAndEra: "Super 35 电影画幅，1980 年代钨丝灯片场",
            markerIconName: "movieclapper",
            bodyStyle: .tungstenCinemaRig,
            defaultAccessoryCapabilities: [.video, .longExposure, .starFilter, .colorTemperature]
        ),
        "pocket-flash": .profile(
            id: "pocket-flash",
            modelName: "27-Shot Flash Compact",
            localizedModelName: "27 张闪光袖珍机",
            englishDisplayName: "27-Shot Flash",
            chineseDisplayName: "口袋闪光机",
            category: .disposable,
            lensAndEra: "31mm fixed-focus plastic lens, 1990s",
            localizedLensAndEra: "31mm 固定焦点塑料镜头，1990 年代",
            markerIconName: "bolt.fill",
            bodyStyle: .disposableFlashShell,
            defaultAccessoryCapabilities: [.flash, .dateStamp]
        ),
        "ccd-2003": .profile(
            id: "ccd-2003",
            modelName: "3MP CCD Compact",
            localizedModelName: "300 万像素 CCD",
            englishDisplayName: "CCD 3MP",
            chineseDisplayName: "三百万像素卡片机",
            category: .ccdCompact,
            lensAndEra: "3x zoom CCD module, 2003",
            localizedLensAndEra: "3 倍变焦 CCD 模组，2003 年",
            markerIconName: "memorychip",
            bodyStyle: .earlyCCDCard,
            defaultAccessoryCapabilities: [.flash, .dateStamp, .video]
        ),
        "instant-square": .profile(
            id: "instant-square",
            modelName: "Square Instant 640",
            localizedModelName: "方片即影 640",
            englishDisplayName: "Square 640",
            chineseDisplayName: "方片即影机",
            category: .instant,
            lensAndEra: "116mm equivalent instant lens, late 1970s",
            localizedLensAndEra: "等效 116mm 即影镜头，1970 年代末",
            markerIconName: "square",
            bodyStyle: .squareInstantBox,
            defaultAccessoryCapabilities: [.flash, .squareFrame, .selfTimer]
        ),
        "hncs-natural": .profile(
            id: "hncs-natural",
            modelName: "H-System Digital Back",
            localizedModelName: "H 系统数码后背",
            englishDisplayName: "H Natural Back",
            chineseDisplayName: "H 系统自然色",
            category: .mediumFormat,
            lensAndEra: "80mm medium-format lens with digital back, 2000s",
            localizedLensAndEra: "80mm 中画幅镜头配数码后背，2000 年代",
            markerIconName: "camera.metering.matrix",
            bodyStyle: .hSystemBack,
            defaultAccessoryCapabilities: [.colorTemperature, .macro, .selfTimer]
        ),
        "m-rangefinder": .profile(
            id: "m-rangefinder",
            modelName: "M Rangefinder",
            localizedModelName: "M 旁轴",
            englishDisplayName: "M Street RF",
            chineseDisplayName: "M 街头旁轴",
            category: .rangefinder,
            lensAndEra: "35mm f/2 rangefinder lens, 1960s",
            localizedLensAndEra: "35mm f/2 旁轴镜头，1960 年代",
            markerIconName: "viewfinder.rectangular",
            bodyStyle: .brassRangefinder,
            defaultAccessoryCapabilities: [.doubleExposure, .selfTimer]
        ),
        "t-compact-gold": .profile(
            id: "t-compact-gold",
            modelName: "T Compact",
            localizedModelName: "T 袖珍机",
            englishDisplayName: "T Gold Compact",
            chineseDisplayName: "T 金调袖珍机",
            category: .compact35,
            lensAndEra: "38mm coated compact lens, 1990s",
            localizedLensAndEra: "38mm 镀膜袖珍镜头，1990 年代",
            markerIconName: "camera.fill",
            bodyStyle: .daylightPointAndShoot,
            defaultAccessoryCapabilities: [.flash, .dateStamp, .selfTimer]
        ),
        "gr-street-snap": .profile(
            id: "gr-street-snap",
            modelName: "GR Pocket",
            localizedModelName: "GR 街拍机",
            englishDisplayName: "GR Snap Pocket",
            chineseDisplayName: "GR 快拍口袋机",
            category: .compact35,
            lensAndEra: "28mm f/2.8 snap lens, late 1990s",
            localizedLensAndEra: "28mm f/2.8 快拍镜头，1990 年代末",
            markerIconName: "scope",
            bodyStyle: .blackPocketCompact,
            defaultAccessoryCapabilities: [.dateStamp, .colorTemperature]
        ),
        "classic-chrome-x": .profile(
            id: "classic-chrome-x",
            modelName: "X100 Classic",
            localizedModelName: "X100 经典",
            englishDisplayName: "Classic X100",
            chineseDisplayName: "经典铬色 X100",
            category: .compact35,
            lensAndEra: "23mm f/2 hybrid-viewfinder lens, 2010s",
            localizedLensAndEra: "23mm f/2 混合取景镜头，2010 年代",
            markerIconName: "rectangle.on.rectangle",
            bodyStyle: .brassRangefinder,
            defaultAccessoryCapabilities: [.colorTemperature, .video, .flash]
        ),
        "medium-500c": .profile(
            id: "medium-500c",
            modelName: "500C Medium",
            localizedModelName: "500C 中画幅",
            englishDisplayName: "500C Waist-Level",
            chineseDisplayName: "500C 腰平中画幅",
            category: .mediumFormat,
            lensAndEra: "80mm waist-level medium-format lens, 1960s",
            localizedLensAndEra: "80mm 腰平中画幅镜头，1960 年代",
            markerIconName: "square.stack.3d.down.right",
            bodyStyle: .waistLevelMedium,
            defaultAccessoryCapabilities: [.squareFrame, .selfTimer, .doubleExposure]
        ),
        "holga-120-dream": .profile(
            id: "holga-120-dream",
            modelName: "Toy 120",
            localizedModelName: "120 玩具机",
            englishDisplayName: "Dream 120",
            chineseDisplayName: "120 梦境玩具机",
            category: .toyCamera,
            lensAndEra: "60mm plastic meniscus lens, 1980s",
            localizedLensAndEra: "60mm 塑料弯月镜头，1980 年代",
            markerIconName: "circle.dotted",
            bodyStyle: .plasticToy120,
            defaultAccessoryCapabilities: [.doubleExposure, .longExposure, .flash]
        ),
        "lca-vivid": .profile(
            id: "lca-vivid",
            modelName: "LC-A Compact",
            localizedModelName: "LC-A 袖珍机",
            englishDisplayName: "LC-A Vivid",
            chineseDisplayName: "LC-A 鲜艳袖珍机",
            category: .compact35,
            lensAndEra: "32mm f/2.8 zone-focus lens, 1980s",
            localizedLensAndEra: "32mm f/2.8 估焦镜头，1980 年代",
            markerIconName: "camera.filters",
            bodyStyle: .lomoCompact,
            defaultAccessoryCapabilities: [.flash, .doubleExposure, .longExposure]
        ),
        "instant-wide": .profile(
            id: "instant-wide",
            modelName: "Wide Instant 210",
            localizedModelName: "Wide 210 即影机",
            englishDisplayName: "Wide 210",
            chineseDisplayName: "宽幅即影 210",
            category: .instant,
            lensAndEra: "95mm wide instant lens, 2000s",
            localizedLensAndEra: "95mm 宽幅即影镜头，2000 年代",
            markerIconName: "rectangle",
            bodyStyle: .wideInstantPlastic,
            defaultAccessoryCapabilities: [.flash, .wideFrame, .selfTimer]
        ),
        "sx-fade": .profile(
            id: "sx-fade",
            modelName: "Folding SX Instant",
            localizedModelName: "SX 折叠即影机",
            englishDisplayName: "Folding SX",
            chineseDisplayName: "SX 折叠即影机",
            category: .instant,
            lensAndEra: "folding instant lens, 1970s",
            localizedLensAndEra: "折叠式即影镜头，1970 年代",
            markerIconName: "rectangle.portrait.on.rectangle.portrait",
            bodyStyle: .foldingInstant,
            defaultAccessoryCapabilities: [.flash, .squareFrame, .longExposure]
        ),
        "half-frame-diary": .profile(
            id: "half-frame-diary",
            modelName: "Half Frame",
            localizedModelName: "半格相机",
            englishDisplayName: "Diary Half",
            chineseDisplayName: "日记半格机",
            category: .halfFrame,
            lensAndEra: "28mm half-frame lens, 1960s",
            localizedLensAndEra: "28mm 半格镜头，1960 年代",
            markerIconName: "rectangle.split.2x1",
            bodyStyle: .halfFrameDiary,
            defaultAccessoryCapabilities: [.halfFrame, .dateStamp, .selfTimer]
        ),
        "ektar-vivid-100": .profile(
            id: "ektar-vivid-100",
            modelName: "Daylight Negative",
            localizedModelName: "日光彩负",
            englishDisplayName: "Vivid Daylight 100",
            chineseDisplayName: "鲜彩日光机",
            category: .compact35,
            lensAndEra: "45mm f/2.8 daylight prime, 1970s",
            localizedLensAndEra: "45mm f/2.8 日光定焦，1970 年代",
            markerIconName: "sun.horizon",
            bodyStyle: .daylightPointAndShoot,
            defaultAccessoryCapabilities: [.colorTemperature, .starFilter, .selfTimer]
        ),
        "tri-x-street": .profile(
            id: "tri-x-street",
            modelName: "Street SLR",
            localizedModelName: "街头单反",
            englishDisplayName: "Tri-X Press SLR",
            chineseDisplayName: "Tri-X 街头单反",
            category: .slr,
            lensAndEra: "35mm f/2 press prime, 1960s",
            localizedLensAndEra: "35mm f/2 纪实定焦，1960 年代",
            markerIconName: "circle.lefthalf.filled.inverse",
            bodyStyle: .leatheretteSLR,
            defaultAccessoryCapabilities: [.doubleExposure, .dateStamp]
        ),
        "cyber-ccd-blue": .profile(
            id: "cyber-ccd-blue",
            modelName: "Night CCD Compact",
            localizedModelName: "夜拍 CCD 袖珍机",
            englishDisplayName: "Blue Night CCD",
            chineseDisplayName: "蓝白夜拍 CCD",
            category: .ccdCompact,
            lensAndEra: "5MP CCD zoom module, 2006",
            localizedLensAndEra: "500 万像素 CCD 变焦模组，2006 年",
            markerIconName: "flashlight.on.fill",
            bodyStyle: .blueCCDCard,
            defaultAccessoryCapabilities: [.flash, .video, .dateStamp]
        ),
        "superia-green": .profile(
            id: "superia-green",
            modelName: "Consumer 35",
            localizedModelName: "家用 35mm",
            englishDisplayName: "Family 35 Green",
            chineseDisplayName: "家用绿调 35",
            category: .compact35,
            lensAndEra: "35mm autofocus lens, late 1990s",
            localizedLensAndEra: "35mm 自动对焦镜头，1990 年代末",
            markerIconName: "leaf",
            bodyStyle: .daylightPointAndShoot,
            defaultAccessoryCapabilities: [.flash, .dateStamp, .selfTimer]
        ),
        "noir-soft": .profile(
            id: "noir-soft",
            modelName: "Noir Cine 35",
            localizedModelName: "Noir Cine 35",
            englishDisplayName: "Noir Cine 35",
            chineseDisplayName: "黑白夜景电影机",
            category: .cinema,
            lensAndEra: "35mm pushed-cinema gate, 1970s",
            localizedLensAndEra: "35mm 增感电影画幅，1970 年代",
            markerIconName: "theatermasks",
            bodyStyle: .noirCinemaBody,
            defaultAccessoryCapabilities: [.longExposure, .starFilter, .doubleExposure]
        )
    ]

    static func profile(for film: FilmPreset) -> FilmCameraProfile {
        profilesByFilmId[film.id] ?? fallbackProfile(for: film)
    }

    static func missingProfileIds(in presets: [FilmPreset]) -> Set<String> {
        Set(presets.map(\.id)).subtracting(profilesByFilmId.keys)
    }

    private static func fallbackProfile(for film: FilmPreset) -> FilmCameraProfile {
        .profile(
            id: film.id,
            modelName: film.cameraName,
            localizedModelName: film.localizedCameraName ?? film.cameraName,
            englishDisplayName: film.shortName,
            chineseDisplayName: film.localizedShortName ?? film.shortName,
            category: .compact35,
            lensAndEra: "StillLight default lens",
            localizedLensAndEra: "StillLight 默认镜头",
            markerIconName: "camera",
            bodyStyle: .blackPocketCompact,
            defaultAccessoryCapabilities: [.flash, .colorTemperature]
        )
    }
}

extension FilmPreset {
    var cameraProfile: FilmCameraProfile {
        FilmCameraProfileCatalog.profile(for: self)
    }
}

private extension FilmCameraProfile {
    static func profile(
        id: String,
        modelName: String,
        localizedModelName: String,
        englishDisplayName: String,
        chineseDisplayName: String,
        category: CameraModelCategory,
        lensAndEra: String,
        localizedLensAndEra: String,
        markerIconName: String,
        bodyStyle: CameraBodyStyle,
        defaultAccessoryCapabilities: [CameraAccessoryCapability]
    ) -> FilmCameraProfile {
        FilmCameraProfile(
            id: id,
            modelName: modelName,
            localizedModelName: localizedModelName,
            englishDisplayName: englishDisplayName,
            chineseDisplayName: chineseDisplayName,
            category: category,
            lensAndEra: lensAndEra,
            localizedLensAndEra: localizedLensAndEra,
            markerIconName: markerIconName,
            bodyStyle: bodyStyle,
            defaultAccessoryCapabilities: defaultAccessoryCapabilities
        )
    }
}
