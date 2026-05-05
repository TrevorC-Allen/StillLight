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
        case favorites
        case favoriteFilm
        case unfavoriteFilm
        case favoriteEmptyTitle
        case favoriteEmptySubtitle
        case selectedFilm
        case addFavorite
        case removeFavorite
        case favoritesEmpty
        case favoritesEmptySubtitle
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
        case selectedFrames
        case framesLoaded
        case developingFrame
        case developingFrameProgress
        case batchDevelopCancelled
        case batchDevelopedFrames
        case developCurrent
        case developAll
        case cancelDevelop
        case saveCurrent
        case saveAll
        case savingFrame
        case savedFrames
        case processingTiming
        case inputPixels
        case outputPixels
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
        case pipelineValue
        case filmVideoPipeline
        case docsMode
        case docsModeValue
        case photosSaveFailed
        case photoMode
        case videoMode
        case recording
        case videoSaved
        case videoSaveFailed
        case appName
    }

    private static let english: [Key: String] = [
        .filmRoll: "Film Drawer",
        .filmRollSubtitle: "Load a roll before shooting. Color, grain, frame, and camera label travel together.",
        .all: "All",
        .favorites: "Favorites",
        .favoriteFilm: "Add to Favorites",
        .unfavoriteFilm: "Remove from Favorites",
        .favoriteEmptyTitle: "No favorites yet",
        .favoriteEmptySubtitle: "Pin any roll and it will stay close at hand.",
        .selectedFilm: "Selected",
        .addFavorite: "Add Favorite",
        .removeFavorite: "Remove Favorite",
        .favoritesEmpty: "No favorite frames",
        .favoritesEmptySubtitle: "Mark frames with the heart button and they will appear here.",
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
        .importFrame: "Import frames",
        .importFrameSubtitle: "Select one or more photos and develop them with the same film pipeline.",
        .importPhoto: "Import Photos",
        .selectedFrames: "%d frames selected",
        .framesLoaded: "%d frames loaded",
        .developingFrame: "Developing %d/%d",
        .developingFrameProgress: "Developing %d/%d · %d done · %d failed",
        .batchDevelopCancelled: "Stopped after %d/%d · %d done · %d failed",
        .batchDevelopedFrames: "Developed %d/%d · %d failed",
        .developCurrent: "Develop Current",
        .developAll: "Develop All",
        .cancelDevelop: "Cancel Developing",
        .saveCurrent: "Save Current",
        .saveAll: "Save All",
        .savingFrame: "Saving %d/%d",
        .savedFrames: "Saved %d frames",
        .processingTiming: "Processing Timing",
        .inputPixels: "Input",
        .outputPixels: "Output",
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
        .pipelineValue: "CoreImage + grain + frames",
        .filmVideoPipeline: "Photo and video share film rendering",
        .docsMode: "Docs Mode",
        .docsModeValue: "English + Chinese runbooks",
        .photosSaveFailed: "Saved to StillLight Roll. Photos save failed:",
        .photoMode: "Photo",
        .videoMode: "Video",
        .recording: "REC",
        .videoSaved: "Video saved to Photos",
        .videoSaveFailed: "Video saved locally. Photos save failed:",
        .appName: "StillLight"
    ]

    private static let chinese: [Key: String] = [
        .filmRoll: "胶卷抽屉",
        .filmRollSubtitle: "选择一卷装入相机。色彩、颗粒、边框和机型标注会一起生效。",
        .all: "全部",
        .favorites: "收藏",
        .favoriteFilm: "加入收藏",
        .unfavoriteFilm: "取消收藏",
        .favoriteEmptyTitle: "还没有收藏",
        .favoriteEmptySubtitle: "收藏任意胶卷后，它会固定在这里。",
        .selectedFilm: "已选",
        .addFavorite: "加入收藏",
        .removeFavorite: "取消收藏",
        .favoritesEmpty: "还没有收藏相片",
        .favoritesEmptySubtitle: "在相片详情里点亮爱心后，会出现在这里。",
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
        .importFrame: "导入照片",
        .importFrameSubtitle: "一次选择一组照片，用同一套胶片管线冲洗。",
        .importPhoto: "选择照片",
        .selectedFrames: "已选择 %d 张",
        .framesLoaded: "已载入 %d 张照片",
        .developingFrame: "冲洗中 %d/%d",
        .developingFrameProgress: "冲洗中 %d/%d · 成功 %d · 失败 %d",
        .batchDevelopCancelled: "已停止 %d/%d · 成功 %d · 失败 %d",
        .batchDevelopedFrames: "已冲洗 %d/%d · 失败 %d",
        .developCurrent: "冲洗当前",
        .developAll: "冲洗全部",
        .cancelDevelop: "取消冲洗",
        .saveCurrent: "保存当前",
        .saveAll: "保存全部",
        .savingFrame: "保存中 %d/%d",
        .savedFrames: "已保存 %d 张",
        .processingTiming: "处理耗时",
        .inputPixels: "输入",
        .outputPixels: "输出",
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
        .pipelineValue: "CoreImage + 颗粒 + 边框",
        .filmVideoPipeline: "照片和录像共用胶片渲染",
        .docsMode: "文档模式",
        .docsModeValue: "英文 + 中文运行手册",
        .photosSaveFailed: "已保存到 StillLight 胶卷。系统照片保存失败：",
        .photoMode: "拍照",
        .videoMode: "录像",
        .recording: "录制中",
        .videoSaved: "视频已保存到照片",
        .videoSaveFailed: "视频已保存在本地。系统照片保存失败：",
        .appName: "StillLight"
    ]
}
