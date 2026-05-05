import SwiftUI
import UIKit

struct FilmPickerSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: FilmCategory?
    @State private var focusedFilmId: String?

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    categoryPicker

                    if filteredPresets.isEmpty, selectedCategory == .favorites {
                        favoriteEmptyState
                    } else if let focusedFilm {
                        FilmPickerHero(
                            film: focusedFilm,
                            isLoaded: focusedFilm.id == appState.selectedFilm.id,
                            currentRoll: focusedFilm.id == appState.currentRoll.filmPresetId ? appState.currentRoll : nil,
                            language: appState.language
                        )

                        FilmObjectShelf(
                            films: filteredPresets,
                            focusedFilmId: focusedFilm.id,
                            selectedFilmId: appState.selectedFilm.id,
                            favoriteIds: appState.favoriteFilmIds,
                            language: appState.language
                        ) { film in
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                focusedFilmId = film.id
                            }
                        }

                        FilmSelectionDetailPanel(
                            film: focusedFilm,
                            isLoaded: focusedFilm.id == appState.selectedFilm.id,
                            isFavorite: appState.isFavorite(focusedFilm),
                            currentRoll: focusedFilm.id == appState.currentRoll.filmPresetId ? appState.currentRoll : nil,
                            language: appState.language,
                            favoriteAction: {
                                appState.toggleFavorite(focusedFilm)
                            },
                            loadAction: {
                                if focusedFilm.id == appState.selectedFilm.id {
                                    dismiss()
                                } else {
                                    appState.selectFilm(focusedFilm)
                                    dismiss()
                                }
                            }
                        )
                    }
                }
                .padding(18)
            }
        }
        .onAppear {
            ensureFocusedFilm()
        }
        .onChange(of: selectedCategory) { _, _ in
            ensureFocusedFilm()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.t(.filmRoll))
                .font(.title2.weight(.semibold))
                .foregroundStyle(StillLightTheme.text)
            Text(appState.t(.filmRollSubtitle))
                .font(.subheadline)
                .foregroundStyle(StillLightTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: appState.t(.all),
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(FilmCategory.allCases) { category in
                    CategoryChip(
                        title: category.title(language: appState.language),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private var filteredPresets: [FilmPreset] {
        guard let selectedCategory else {
            return appState.filmLibrary.presets
        }
        return appState.filmLibrary.presets(matching: selectedCategory, favoriteIds: appState.favoriteFilmIds)
    }

    private var focusedFilm: FilmPreset? {
        if let focusedFilmId,
           let focused = filteredPresets.first(where: { $0.id == focusedFilmId }) {
            return focused
        }
        if let selected = filteredPresets.first(where: { $0.id == appState.selectedFilm.id }) {
            return selected
        }
        return filteredPresets.first
    }

    private func ensureFocusedFilm() {
        guard !filteredPresets.isEmpty else {
            focusedFilmId = nil
            return
        }
        if let focusedFilmId,
           filteredPresets.contains(where: { $0.id == focusedFilmId }) {
            return
        }
        focusedFilmId = filteredPresets.first(where: { $0.id == appState.selectedFilm.id })?.id ?? filteredPresets[0].id
    }

    private var favoriteEmptyState: some View {
        VStack(spacing: 12) {
            EmptyShelfMark()
                .frame(width: 96, height: 62)
            Text(appState.t(.favoriteEmptyTitle))
                .font(.headline)
                .foregroundStyle(StillLightTheme.text)
            Text(appState.t(.favoriteEmptySubtitle))
                .font(.subheadline)
                .foregroundStyle(StillLightTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .stillLightPanel()
    }
}

private struct FilmPickerHero: View {
    let film: FilmPreset
    let isLoaded: Bool
    let currentRoll: FilmRoll?
    let language: AppLanguage

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            StillLightTheme.panelElevated.opacity(0.88),
                            StillLightTheme.panel.opacity(0.72),
                            StillLightTheme.background.opacity(0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            shelfGlow
            heroStage

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isLoaded ? loadedText : drawerText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(0.9)
                            .foregroundStyle(style.accent.opacity(0.86))
                        Text(film.displayName(language: language))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(StillLightTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }

                    Spacer()

                    ExposureCounter(film: film, currentRoll: currentRoll, language: language)
                }

                ZStack(alignment: .bottomTrailing) {
                    CameraModelPlate(film: film)
                        .frame(height: 142)
                        .padding(.trailing, 22)
                        .offset(y: 2)

                    FilmPhysicalPackageView(film: film, scale: .hero)
                        .shadow(color: style.accent.opacity(0.18), radius: 18, x: -8, y: 8)
                        .shadow(color: .black.opacity(0.36), radius: 20, x: 0, y: 18)
                        .offset(x: 2, y: 8)
                }
                .frame(maxWidth: .infinity)

                Text(film.displayCameraName(language: language))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(StillLightTheme.secondaryText)
                    .lineLimit(1)
            }
            .padding(18)

            if isLoaded {
                LoadedSeal(language: language)
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 292)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(StillLightTheme.text.opacity(0.06), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.055))
                .frame(height: 1)
                .padding(.horizontal, 1)
        }
    }

    private var shelfGlow: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            style.accent.opacity(0.16),
                            StillLightTheme.background.opacity(0.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: 92)
        }
    }

    private var heroStage: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottomTrailing) {
                Capsule()
                    .fill(.black.opacity(0.26))
                    .frame(width: 218, height: 28)
                    .blur(radius: 13)
                    .offset(x: 10, y: 5)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                style.paper.opacity(0.12),
                                style.accent.opacity(0.07),
                                .clear
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(height: 54)
            }
        }
        .allowsHitTesting(false)
    }

    private var loadedText: String {
        language == .chinese ? "已装入" : "LOADED"
    }

    private var drawerText: String {
        language == .chinese ? "胶卷抽屉" : "FILM DRAWER"
    }
}

private struct FilmObjectShelf: View {
    let films: [FilmPreset]
    let focusedFilmId: String
    let selectedFilmId: String
    let favoriteIds: Set<String>
    let language: AppLanguage
    let focusAction: (FilmPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(language == .chinese ? "选择一卷" : "Choose a roll")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(StillLightTheme.secondaryText.opacity(0.72))

                Rectangle()
                    .fill(StillLightTheme.secondaryText.opacity(0.14))
                    .frame(height: 1)
            }

            ZStack(alignment: .bottom) {
                shelfSurface
                shelfBackRail

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: 16) {
                        ForEach(films) { film in
                            FilmObjectCard(
                                film: film,
                                isFocused: film.id == focusedFilmId,
                                isLoaded: film.id == selectedFilmId,
                                isFavorite: favoriteIds.contains(film.id),
                                language: language
                            ) {
                                focusAction(film)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 24)
                    .padding(.bottom, 14)
                }
            }
            .frame(height: 206)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var shelfSurface: some View {
        VStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(StillLightTheme.text.opacity(0.08))
                .frame(height: 1)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            StillLightTheme.panelElevated.opacity(0.92),
                            StillLightTheme.panel.opacity(0.48),
                            StillLightTheme.background.opacity(0.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: 72)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.white.opacity(0.045))
                        .frame(height: 1)
                }
        }
    }

    private var shelfBackRail: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            StillLightTheme.panel.opacity(0.20),
                            StillLightTheme.panelElevated.opacity(0.30),
                            StillLightTheme.panel.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 82)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(StillLightTheme.text.opacity(0.055))
                        .frame(height: 1)
                }
                .overlay {
                    HStack(spacing: 22) {
                        ForEach(0..<8, id: \.self) { _ in
                            Rectangle()
                                .fill(StillLightTheme.text.opacity(0.025))
                                .frame(width: 1)
                        }
                    }
                }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

private struct FilmObjectCard: View {
    let film: FilmPreset
    let isFocused: Bool
    let isLoaded: Bool
    let isFavorite: Bool
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottom) {
                    cardPlinth
                        .offset(y: isFocused ? 5 : 8)

                    ZStack(alignment: .topTrailing) {
                        FilmPhysicalPackageView(film: film, scale: .shelf)
                            .shadow(color: FilmCoverStyle.style(for: film).accent.opacity(isFocused ? 0.18 : 0.08), radius: isFocused ? 12 : 7, x: -5, y: 5)
                            .shadow(color: .black.opacity(isFocused ? 0.38 : 0.24), radius: isFocused ? 18 : 11, x: 0, y: isFocused ? 13 : 8)

                        if isLoaded {
                            LoadedTab(language: language)
                                .offset(x: 5, y: 7)
                        } else if isFavorite {
                            FavoritePin()
                                .offset(x: 2, y: 4)
                        }
                    }
                    .scaleEffect(isFocused ? 1.08 : 0.94)
                    .rotationEffect(.degrees(isFocused ? -1 : 0.8))
                    .offset(y: isFocused ? -12 : 0)
                }
                .frame(width: 124, height: 132)

                Text(film.displayShortName(language: language))
                    .font(.system(size: 12, weight: isFocused ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isFocused ? StillLightTheme.text : StillLightTheme.secondaryText)
                    .lineLimit(1)
                    .frame(width: 118)

                Rectangle()
                    .fill(isFocused ? FilmCoverStyle.style(for: film).accent.opacity(0.88) : .clear)
                    .frame(width: 36, height: 2)
            }
            .frame(width: 124)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isFocused)
        .accessibilityLabel(film.displayName(language: language))
    }

    private var cardPlinth: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(isFocused ? 0.24 : 0.15))
                .frame(width: isFocused ? 98 : 82, height: isFocused ? 18 : 13)
                .blur(radius: isFocused ? 8 : 6)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            StillLightTheme.panelElevated.opacity(isFocused ? 0.58 : 0.30),
                            StillLightTheme.panel.opacity(isFocused ? 0.16 : 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: isFocused ? 106 : 86, height: isFocused ? 8 : 5)
                .offset(y: -1)
        }
        .allowsHitTesting(false)
    }
}

private struct FilmSelectionDetailPanel: View {
    let film: FilmPreset
    let isLoaded: Bool
    let isFavorite: Bool
    let currentRoll: FilmRoll?
    let language: AppLanguage
    let favoriteAction: () -> Void
    let loadAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(film.displayName(language: language))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(StillLightTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(film.displayDescription(language: language))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(StillLightTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("ISO \(film.iso)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(StillLightTheme.text)
                    Text(exposureText)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(StillLightTheme.secondaryText.opacity(0.82))
                }
            }

            sceneTags
            FilmDetailPreviewStrip(film: film, language: language)

            HStack(spacing: 10) {
                FilmMiniStat(title: language == .chinese ? "颗粒" : "Grain", value: normalized(film.grainAmount, upperBound: 0.46), accent: style.accent)
                FilmMiniStat(title: language == .chinese ? "反差" : "Contrast", value: normalized(film.contrast - 0.86, upperBound: 0.34), accent: style.accent)
                FilmMiniStat(title: language == .chinese ? "暖度" : "Warmth", value: normalized(film.temperatureShift + 700, upperBound: 1200), accent: style.accent)
            }

            HStack(spacing: 10) {
                Button(action: favoriteAction) {
                    Text(isFavorite ? favoriteOnText : favoriteOffText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isFavorite ? StillLightTheme.background : StillLightTheme.text)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(isFavorite ? style.accent : StillLightTheme.panelElevated.opacity(0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: loadAction) {
                    Text(loadButtonText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(StillLightTheme.background)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(StillLightTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(StillLightTheme.panel.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(StillLightTheme.text.opacity(0.06), lineWidth: 1)
        }
    }

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    private var sceneTags: some View {
        let scenes = language == .chinese && !film.localizedSuitableScenes.isEmpty
            ? film.localizedSuitableScenes
            : film.suitableScenes

        return HStack(spacing: 7) {
            ForEach(Array(scenes.prefix(3)), id: \.self) { scene in
                Text(scene)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(StillLightTheme.text.opacity(0.86))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(style.accent.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    private var exposureText: String {
        if let currentRoll {
            return language == .chinese ? "剩余 \(currentRoll.remainingShots) 张" : "\(currentRoll.remainingShots) LEFT"
        }
        switch film.category {
        case .instant:
            return "10 SHOTS"
        case .digital:
            return "99 FILES"
        default:
            return "\(film.defaultShotCount) EXP"
        }
    }

    private var loadButtonText: String {
        if isLoaded {
            return language == .chinese ? "继续拍" : "Keep Shooting"
        }
        return language == .chinese ? "装入相机" : "Load Camera"
    }

    private var favoriteOnText: String {
        language == .chinese ? "已收藏" : "Pinned"
    }

    private var favoriteOffText: String {
        language == .chinese ? "收藏" : "Pin"
    }

    private func normalized(_ value: Double, upperBound: Double) -> Double {
        min(1.0, Swift.max(0.0, value / upperBound))
    }
}

private struct FilmDetailPreviewStrip: View {
    let film: FilmPreset
    let language: AppLanguage

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    var body: some View {
        HStack(spacing: 10) {
            FilmSampleSceneView(film: film, style: style)
                .frame(width: 76, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(toneTitle)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(style.accent.opacity(0.90))
                    .lineLimit(1)

                Text(textureLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(StillLightTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(style.swatches[index].opacity(0.86))
                        .frame(width: 22, height: 8)
                }
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [
                    StillLightTheme.panelElevated.opacity(0.54),
                    style.accent.opacity(0.08)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StillLightTheme.text.opacity(0.055), lineWidth: 1)
        }
    }

    private var toneTitle: String {
        language == .chinese ? "样张预览" : "PROOF"
    }

    private var textureLine: String {
        let scenes = language == .chinese && !film.localizedSuitableScenes.isEmpty
            ? film.localizedSuitableScenes
            : film.suitableScenes
        let sceneText = scenes.prefix(2).joined(separator: " / ")
        if sceneText.isEmpty {
            return film.displayCameraName(language: language)
        }
        return sceneText
    }
}

private struct FilmMiniStat: View {
    let title: String
    let value: Double
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(StillLightTheme.secondaryText.opacity(0.8))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(StillLightTheme.panelElevated.opacity(0.84))
                    Capsule()
                        .fill(accent.opacity(0.82))
                        .frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(StillLightTheme.panelElevated.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum FilmPackageScale {
    case hero
    case shelf

    var size: CGSize {
        switch self {
        case .hero:
            return CGSize(width: 112, height: 144)
        case .shelf:
            return CGSize(width: 88, height: 112)
        }
    }
}

private enum FilmPackageKind {
    case paperBox
    case canister
    case instantPack
    case cameraBody
    case paperSleeve
    case disposable
    case halfFrameTicket

    static func kind(for film: FilmPreset) -> FilmPackageKind {
        switch film.id {
        case "pocket-flash":
            return .disposable
        case "half-frame-diary":
            return .halfFrameTicket
        case "holga-120-dream", "lca-vivid":
            return .paperSleeve
        default:
            switch film.category {
            case .blackWhite:
                return .canister
            case .instant:
                return .instantPack
            case .camera, .digital:
                return .cameraBody
            case .experimental:
                return .paperSleeve
            default:
                return .paperBox
            }
        }
    }
}

private enum FilmCoverComposition {
    case warmCafePacket
    case vignetteEnvelope
    case musePolaroids
    case sunlitProofs
    case softPortraitCard
    case silverArchive
    case greenTransit
    case tungstenNightSleeve
    case pocketFlashWrap
    case ccdMemory
    case instantSquareStack
    case naturalRollBand
    case rangefinderPlate
    case compactGold
    case grContact
    case chromeRecipe
    case mediumTwinSlide
    case holgaVellum
    case lcaDiagonal
    case instantWidePrint
    case sxFlowerFade
    case halfFrameDiary
    case ektarSlides
    case triXArchive
    case cyberCcd
    case superiaPacket
    case noirWindow
    case archiveDefault

    static func composition(for film: FilmPreset) -> FilmCoverComposition {
        switch film.id {
        case "human-warm-400":
            return .warmCafePacket
        case "human-vignette-800":
            return .vignetteEnvelope
        case "muse-portrait-400":
            return .musePolaroids
        case "sunlit-gold-200":
            return .sunlitProofs
        case "soft-portrait-400":
            return .softPortraitCard
        case "silver-hp5":
            return .silverArchive
        case "green-street-400":
            return .greenTransit
        case "tungsten-800":
            return .tungstenNightSleeve
        case "pocket-flash":
            return .pocketFlashWrap
        case "ccd-2003":
            return .ccdMemory
        case "instant-square":
            return .instantSquareStack
        case "hncs-natural":
            return .naturalRollBand
        case "m-rangefinder":
            return .rangefinderPlate
        case "t-compact-gold":
            return .compactGold
        case "gr-street-snap":
            return .grContact
        case "classic-chrome-x":
            return .chromeRecipe
        case "medium-500c":
            return .mediumTwinSlide
        case "holga-120-dream":
            return .holgaVellum
        case "lca-vivid":
            return .lcaDiagonal
        case "instant-wide":
            return .instantWidePrint
        case "sx-fade":
            return .sxFlowerFade
        case "half-frame-diary":
            return .halfFrameDiary
        case "ektar-vivid-100":
            return .ektarSlides
        case "tri-x-street":
            return .triXArchive
        case "cyber-ccd-blue":
            return .cyberCcd
        case "superia-green":
            return .superiaPacket
        case "noir-soft":
            return .noirWindow
        default:
            return .archiveDefault
        }
    }
}

private struct FilmIdentityArtworkView: View {
    let film: FilmPreset
    let style: FilmCoverStyle

    private var composition: FilmCoverComposition {
        FilmCoverComposition.composition(for: film)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                paperBase(width: width, height: height)
                compositionArtwork(width: width, height: height)
                printFinish(width: width, height: height)
            }
            .clipShape(RoundedRectangle(cornerRadius: min(width, height) * 0.075, style: .continuous))
        }
    }

    private func paperBase(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    style.paper.opacity(0.98),
                    style.wash[0].opacity(0.46),
                    style.wash[2].opacity(0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<8, id: \.self) { index in
                Rectangle()
                    .fill((index.isMultiple(of: 2) ? style.ink : style.paper).opacity(0.045))
                    .frame(width: width * CGFloat(0.22 + Double(seed(index, salt: 7) % 24) / 100.0), height: 1)
                    .rotationEffect(.degrees(Double(seed(index, salt: 13) % 22) - 11))
                    .offset(
                        x: offset(index, salt: 19, length: width * 0.84),
                        y: offset(index, salt: 29, length: height * 0.84)
                    )
            }
        }
    }

    @ViewBuilder
    private func compositionArtwork(width: CGFloat, height: CGFloat) -> some View {
        switch composition {
        case .warmCafePacket:
            ZStack {
                diagonalBand(color: style.wash[0], width: width, height: height, angle: -16, y: -0.25, thickness: 0.24)
                proofStrip(count: 3, width: width, height: height)
                    .frame(width: width * 0.34, height: height * 0.86)
                    .offset(x: -width * 0.26, y: height * 0.02)
                receiptLabel(width: width, height: height, title: "CN", subtitle: "WARM")
                    .offset(x: width * 0.18, y: height * 0.18)
                cafeStamp(width: width, height: height)
                    .offset(x: width * 0.22, y: -height * 0.25)
            }
        case .vignetteEnvelope:
            ZStack {
                envelopeFlap(width: width, height: height)
                Circle()
                    .fill(style.accent.opacity(0.64))
                    .frame(width: width * 0.22, height: width * 0.22)
                    .blur(radius: 1.4)
                    .offset(x: width * 0.22, y: -height * 0.26)
                proofStrip(count: 2, width: width, height: height)
                    .frame(width: width * 0.70, height: height * 0.32)
                    .rotationEffect(.degrees(-8))
                    .offset(y: height * 0.08)
                tape(width: width, height: height, color: style.paper, angle: 8)
                    .offset(x: -width * 0.22, y: -height * 0.18)
            }
        case .musePolaroids:
            ZStack {
                instantPrint(width: width, height: height, rotation: -8)
                    .frame(width: width * 0.50, height: height * 0.66)
                    .offset(x: -width * 0.12, y: height * 0.02)
                instantPrint(width: width, height: height, rotation: 6)
                    .frame(width: width * 0.46, height: height * 0.60)
                    .offset(x: width * 0.18, y: -height * 0.06)
                tape(width: width, height: height, color: style.accent, angle: -12)
                    .offset(x: width * 0.06, y: -height * 0.34)
            }
        case .sunlitProofs:
            ZStack {
                Circle()
                    .fill(style.accent.opacity(0.78))
                    .frame(width: width * 0.23, height: width * 0.23)
                    .offset(x: width * 0.25, y: -height * 0.32)
                contactGrid(columns: 2, rows: 3, width: width, height: height)
                    .padding(.horizontal, width * 0.13)
                    .padding(.vertical, height * 0.12)
                registrationTicks(width: width, height: height)
            }
        case .softPortraitCard:
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                    .fill(style.paper.opacity(0.54))
                    .padding(width * 0.12)
                    .overlay(photoCorners(width: width, height: height))
                FilmSampleSceneView(film: film, style: style)
                    .padding(.horizontal, width * 0.23)
                    .padding(.vertical, height * 0.22)
                    .opacity(0.74)
                Capsule()
                    .fill(style.accent.opacity(0.66))
                    .frame(width: width * 0.44, height: height * 0.045)
                    .offset(y: height * 0.30)
            }
        case .silverArchive:
            ZStack {
                archiveSleeve(width: width, height: height)
                proofStrip(count: 4, width: width, height: height)
                    .frame(width: width * 0.82, height: height * 0.30)
                    .rotationEffect(.degrees(-3))
                receiptLabel(width: width, height: height, title: "B&W", subtitle: "SILVER")
                    .offset(y: height * 0.28)
            }
        case .greenTransit:
            ZStack {
                contactGrid(columns: 2, rows: 2, width: width, height: height)
                    .padding(.horizontal, width * 0.17)
                    .padding(.top, height * 0.14)
                    .padding(.bottom, height * 0.30)
                transitPunches(width: width, height: height)
                Rectangle()
                    .fill(style.accent.opacity(0.78))
                    .frame(width: width * 0.16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        case .tungstenNightSleeve:
            ZStack {
                Rectangle().fill(style.ink.opacity(0.52))
                diagonalBand(color: style.accent, width: width, height: height, angle: -20, y: -0.20, thickness: 0.12)
                proofStrip(count: 3, width: width, height: height)
                    .frame(width: width * 0.76, height: height * 0.26)
                    .rotationEffect(.degrees(7))
                    .offset(y: height * 0.18)
                neonPips(width: width, height: height)
            }
        case .pocketFlashWrap:
            ZStack {
                diagonalBand(color: style.accent, width: width, height: height, angle: -14, y: 0.28, thickness: 0.22)
                compactCameraGlyph(width: width, height: height)
                    .frame(width: width * 0.72, height: height * 0.46)
                    .offset(y: -height * 0.10)
                burstSeal(width: width, height: height)
                    .offset(x: width * 0.25, y: height * 0.24)
            }
        case .ccdMemory:
            ZStack {
                memoryCard(width: width, height: height)
                    .frame(width: width * 0.64, height: height * 0.68)
                    .rotationEffect(.degrees(-3))
                lcdScreen(width: width, height: height)
                    .frame(width: width * 0.48, height: height * 0.26)
                    .offset(x: width * 0.18, y: -height * 0.20)
            }
        case .instantSquareStack:
            ZStack {
                instantPrint(width: width, height: height, rotation: 4)
                    .frame(width: width * 0.62, height: height * 0.76)
                    .offset(x: width * 0.06, y: height * 0.04)
                instantPrint(width: width, height: height, rotation: -7)
                    .frame(width: width * 0.56, height: height * 0.70)
                    .offset(x: -width * 0.12, y: -height * 0.04)
            }
        case .naturalRollBand:
            ZStack {
                landscapeBand(width: width, height: height)
                rollSeal(width: width, height: height)
                    .offset(x: -width * 0.25, y: -height * 0.26)
                receiptLabel(width: width, height: height, title: "120", subtitle: "FIELD")
                    .offset(x: width * 0.18, y: height * 0.22)
            }
        case .rangefinderPlate:
            ZStack {
                leatherPanel(width: width, height: height)
                rangefinderGlyph(width: width, height: height)
                    .frame(width: width * 0.74, height: height * 0.42)
                    .offset(y: -height * 0.04)
                Rectangle()
                    .fill(style.accent.opacity(0.78))
                    .frame(width: width * 0.56, height: 2)
                    .offset(y: height * 0.29)
            }
        case .compactGold:
            ZStack {
                diagonalBand(color: style.wash[0], width: width, height: height, angle: -10, y: -0.22, thickness: 0.22)
                compactCameraGlyph(width: width, height: height)
                    .frame(width: width * 0.70, height: height * 0.44)
                    .offset(y: -height * 0.04)
                proofStrip(count: 2, width: width, height: height)
                    .frame(width: width * 0.62, height: height * 0.18)
                    .offset(y: height * 0.30)
            }
        case .grContact:
            ZStack {
                Rectangle().fill(style.ink.opacity(0.38))
                contactGrid(columns: 3, rows: 2, width: width, height: height)
                    .padding(.horizontal, width * 0.10)
                    .padding(.vertical, height * 0.18)
                tape(width: width, height: height, color: style.paper, angle: -6)
                    .offset(x: -width * 0.24, y: -height * 0.33)
            }
        case .chromeRecipe:
            ZStack {
                recipeTabs(width: width, height: height)
                FilmSampleSceneView(film: film, style: style)
                    .padding(.horizontal, width * 0.22)
                    .padding(.vertical, height * 0.24)
                    .opacity(0.62)
                swatchStack(width: width, height: height)
                    .offset(x: width * 0.28, y: height * 0.28)
            }
        case .mediumTwinSlide:
            ZStack {
                twinSlides(width: width, height: height)
                rollSeal(width: width, height: height)
                    .offset(x: width * 0.25, y: -height * 0.28)
            }
        case .holgaVellum:
            ZStack {
                Circle()
                    .fill(style.accent.opacity(0.40))
                    .frame(width: width * 0.72, height: width * 0.72)
                    .blur(radius: 5)
                    .offset(x: width * 0.20, y: -height * 0.26)
                proofStrip(count: 3, width: width, height: height)
                    .frame(width: width * 0.82, height: height * 0.28)
                    .rotationEffect(.degrees(-9))
                vellumSheet(width: width, height: height)
            }
        case .lcaDiagonal:
            ZStack {
                diagonalBand(color: style.wash[0], width: width, height: height, angle: -24, y: -0.22, thickness: 0.24)
                diagonalBand(color: style.wash[1], width: width, height: height, angle: -24, y: 0.06, thickness: 0.20)
                diagonalBand(color: style.accent, width: width, height: height, angle: -24, y: 0.30, thickness: 0.12)
                instantPrint(width: width, height: height, rotation: 8)
                    .frame(width: width * 0.42, height: height * 0.54)
                    .offset(x: width * 0.18, y: -height * 0.02)
            }
        case .instantWidePrint:
            ZStack {
                wideInstant(width: width, height: height)
                    .frame(width: width * 0.80, height: height * 0.62)
                    .rotationEffect(.degrees(-3))
                tape(width: width, height: height, color: style.accent, angle: 7)
                    .offset(x: width * 0.22, y: -height * 0.32)
            }
        case .sxFlowerFade:
            ZStack {
                instantPrint(width: width, height: height, rotation: -4)
                    .frame(width: width * 0.60, height: height * 0.74)
                flowerCluster(width: width, height: height)
                    .offset(x: width * 0.20, y: height * 0.22)
                fadeWash(width: width, height: height)
            }
        case .halfFrameDiary:
            ZStack {
                HStack(spacing: width * 0.045) {
                    FilmSampleSceneView(film: film, style: style)
                    FilmSampleSceneView(film: film, style: style)
                        .opacity(0.78)
                }
                .padding(.horizontal, width * 0.13)
                .padding(.top, height * 0.14)
                .padding(.bottom, height * 0.28)
                diaryBinding(width: width, height: height)
            }
        case .ektarSlides:
            ZStack {
                slideMount(width: width, height: height, rotation: -8)
                    .frame(width: width * 0.48, height: height * 0.54)
                    .offset(x: -width * 0.16, y: -height * 0.06)
                slideMount(width: width, height: height, rotation: 7)
                    .frame(width: width * 0.48, height: height * 0.54)
                    .offset(x: width * 0.17, y: height * 0.08)
                swatchStack(width: width, height: height)
                    .offset(y: -height * 0.34)
            }
        case .triXArchive:
            ZStack {
                archiveSleeve(width: width, height: height)
                proofStrip(count: 5, width: width, height: height)
                    .frame(width: width * 0.86, height: height * 0.26)
                    .offset(y: -height * 0.04)
                registrationTicks(width: width, height: height)
            }
        case .cyberCcd:
            ZStack {
                lcdScreen(width: width, height: height)
                    .frame(width: width * 0.68, height: height * 0.42)
                    .rotationEffect(.degrees(4))
                    .offset(y: -height * 0.09)
                memoryCard(width: width, height: height)
                    .frame(width: width * 0.42, height: height * 0.46)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -width * 0.24, y: height * 0.22)
            }
        case .superiaPacket:
            ZStack {
                Rectangle()
                    .fill(style.wash[0].opacity(0.78))
                    .frame(height: height * 0.30)
                    .frame(maxHeight: .infinity, alignment: .top)
                Rectangle()
                    .fill(style.wash[1].opacity(0.74))
                    .frame(height: height * 0.34)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                wideInstant(width: width, height: height)
                    .frame(width: width * 0.64, height: height * 0.42)
                    .offset(y: height * 0.06)
                rollSeal(width: width, height: height)
                    .offset(x: width * 0.25, y: -height * 0.29)
            }
        case .noirWindow:
            ZStack {
                Rectangle().fill(style.ink.opacity(0.72))
                RoundedRectangle(cornerRadius: width * 0.025, style: .continuous)
                    .fill(style.paper.opacity(0.72))
                    .frame(width: width * 0.30, height: height * 0.66)
                    .offset(x: -width * 0.24, y: -height * 0.08)
                    .blur(radius: 0.7)
                instantPrint(width: width, height: height, rotation: 5)
                    .frame(width: width * 0.44, height: height * 0.58)
                    .offset(x: width * 0.16, y: height * 0.08)
            }
        case .archiveDefault:
            ZStack {
                contactGrid(columns: 2, rows: 2, width: width, height: height)
                    .padding(width * 0.16)
                receiptLabel(width: width, height: height, title: "SL", subtitle: "ROLL")
                    .offset(y: height * 0.28)
            }
        }
    }

    private func printFinish(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [.white.opacity(0.16), .clear, style.ink.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<14, id: \.self) { index in
                Circle()
                    .fill(style.ink.opacity(index.isMultiple(of: 4) ? 0.055 : 0.026))
                    .frame(width: CGFloat(1 + seed(index, salt: 47) % 3))
                    .offset(
                        x: offset(index, salt: 61, length: width * 0.92),
                        y: offset(index, salt: 73, length: height * 0.92)
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func contactGrid(columns: Int, rows: Int, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: height * 0.035) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: width * 0.035) {
                    ForEach(0..<columns, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: width * 0.02, style: .continuous)
                            .fill(style.ink.opacity(0.62))
                            .overlay {
                                FilmSampleSceneView(film: film, style: style)
                                    .padding(width * 0.018)
                                    .opacity(0.72)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: width * 0.016, style: .continuous)
                                    .stroke(style.paper.opacity(0.20), lineWidth: 1)
                            }
                    }
                }
            }
        }
        .padding(width * 0.035)
        .background(style.ink.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: width * 0.035, style: .continuous))
    }

    private func proofStrip(count: Int, width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.03) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: width * 0.018, style: .continuous)
                    .fill(style.swatches[index % style.swatches.count].opacity(0.72))
                    .overlay {
                        FilmSampleSceneView(film: film, style: style)
                            .padding(width * 0.014)
                            .opacity(index.isMultiple(of: 2) ? 0.68 : 0.52)
                    }
            }
        }
        .padding(.horizontal, width * 0.08)
        .padding(.vertical, height * 0.18)
        .background(style.ink.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: width * 0.025, style: .continuous))
        .overlay(alignment: .top) {
            sprocketRow(width: width, height: height)
                .padding(.top, height * 0.045)
        }
        .overlay(alignment: .bottom) {
            sprocketRow(width: width, height: height)
                .padding(.bottom, height * 0.045)
        }
    }

    private func sprocketRow(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.035) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(style.paper.opacity(0.55))
                    .frame(width: width * 0.028, height: height * 0.025)
            }
        }
    }

    private func instantPrint(width: CGFloat, height: CGFloat, rotation: Double) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                .fill(style.paper.opacity(0.95))
                .shadow(color: style.ink.opacity(0.12), radius: 3, x: 0, y: 2)
            FilmSampleSceneView(film: film, style: style)
                .padding(.horizontal, width * 0.10)
                .padding(.top, height * 0.10)
                .padding(.bottom, height * 0.30)
            Rectangle()
                .fill(style.ink.opacity(0.16))
                .frame(height: 1)
                .padding(.horizontal, width * 0.16)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, height * 0.17)
        }
        .rotationEffect(.degrees(rotation))
    }

    private func wideInstant(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: width * 0.035, style: .continuous)
                .fill(style.paper.opacity(0.96))
            FilmSampleSceneView(film: film, style: style)
                .padding(.horizontal, width * 0.08)
                .padding(.top, height * 0.12)
                .padding(.bottom, height * 0.26)
        }
    }

    private func receiptLabel(width: CGFloat, height: CGFloat, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: height * 0.020) {
            Text(title)
                .font(.system(size: width * 0.078, weight: .black, design: .monospaced))
                .tracking(0.3)
            Text(subtitle)
                .font(.system(size: width * 0.050, weight: .bold, design: .monospaced))
                .tracking(0.4)
            HStack(spacing: width * 0.026) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(style.swatches[index].opacity(0.80))
                        .frame(width: width * 0.13, height: 2)
                }
            }
        }
        .foregroundStyle(style.ink.opacity(0.72))
        .padding(.horizontal, width * 0.07)
        .padding(.vertical, height * 0.055)
        .background(style.paper.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: width * 0.025, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: width * 0.025, style: .continuous)
                .stroke(style.ink.opacity(0.12), lineWidth: 1)
        }
    }

    private func diagonalBand(color: Color, width: CGFloat, height: CGFloat, angle: Double, y: CGFloat, thickness: CGFloat) -> some View {
        Rectangle()
            .fill(color.opacity(0.78))
            .frame(width: width * 1.35, height: height * thickness)
            .rotationEffect(.degrees(angle))
            .offset(y: height * y)
    }

    private func tape(width: CGFloat, height: CGFloat, color: Color, angle: Double) -> some View {
        RoundedRectangle(cornerRadius: width * 0.018, style: .continuous)
            .fill(color.opacity(0.68))
            .frame(width: width * 0.38, height: height * 0.075)
            .overlay {
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.horizontal, width * 0.05)
            }
            .rotationEffect(.degrees(angle))
    }

    private func cafeStamp(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(style.ink.opacity(0.32), lineWidth: 1)
                .frame(width: width * 0.24, height: width * 0.24)
            Capsule()
                .fill(style.ink.opacity(0.28))
                .frame(width: width * 0.12, height: height * 0.030)
                .offset(y: height * 0.035)
            RoundedRectangle(cornerRadius: width * 0.020, style: .continuous)
                .fill(style.paper.opacity(0.58))
                .frame(width: width * 0.10, height: height * 0.070)
                .offset(y: -height * 0.025)
        }
    }

    private func envelopeFlap(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: height * 0.20))
                path.addLine(to: CGPoint(x: width * 0.50, y: height * 0.58))
                path.addLine(to: CGPoint(x: width, y: height * 0.20))
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(style.paper.opacity(0.22))
            Rectangle()
                .fill(style.ink.opacity(0.12))
                .frame(height: 1)
                .rotationEffect(.degrees(24))
                .offset(x: -width * 0.24, y: height * 0.06)
            Rectangle()
                .fill(style.ink.opacity(0.12))
                .frame(height: 1)
                .rotationEffect(.degrees(-24))
                .offset(x: width * 0.24, y: height * 0.06)
        }
    }

    private func archiveSleeve(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.030, style: .continuous)
                .fill(style.paper.opacity(0.46))
                .padding(width * 0.07)
            Rectangle()
                .fill(style.ink.opacity(0.11))
                .frame(height: 1)
                .offset(y: -height * 0.25)
            HStack(spacing: width * 0.035) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(style.ink.opacity(0.18))
                        .frame(width: width * 0.030, height: width * 0.030)
                }
            }
            .offset(y: -height * 0.36)
        }
    }

    private func photoCorners(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .trim(from: 0, to: 0.50)
                    .stroke(style.ink.opacity(0.22), lineWidth: 1)
                    .frame(width: width * 0.13, height: width * 0.13)
                    .rotationEffect(.degrees(Double(index) * 90))
                    .offset(
                        x: width * CGFloat(index == 0 || index == 3 ? -0.32 : 0.32),
                        y: height * CGFloat(index < 2 ? -0.34 : 0.34)
                    )
            }
        }
    }

    private func transitPunches(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.05) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill((index.isMultiple(of: 2) ? style.ink : style.paper).opacity(0.22))
                    .frame(width: width * 0.040, height: width * 0.040)
            }
        }
        .offset(y: height * 0.36)
    }

    private func registrationTicks(width: CGFloat, height: CGFloat) -> some View {
        VStack {
            HStack {
                tickMark(width: width, height: height)
                Spacer()
                tickMark(width: width, height: height)
                    .rotationEffect(.degrees(90))
            }
            Spacer()
            HStack {
                tickMark(width: width, height: height)
                    .rotationEffect(.degrees(-90))
                Spacer()
                tickMark(width: width, height: height)
                    .rotationEffect(.degrees(180))
            }
        }
        .padding(width * 0.08)
    }

    private func tickMark(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(style.ink.opacity(0.22)).frame(width: width * 0.10, height: 1)
            Rectangle().fill(style.ink.opacity(0.22)).frame(width: 1, height: height * 0.045)
        }
    }

    private func neonPips(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.045) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(style.swatches[index].opacity(0.78))
                    .frame(width: width * 0.055, height: width * 0.055)
                    .blur(radius: index == 1 ? 1.2 : 0)
            }
        }
        .offset(x: width * 0.19, y: -height * 0.34)
    }

    private func burstSeal(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(style.paper.opacity(0.78))
                .frame(width: width * 0.22, height: width * 0.22)
            ForEach(0..<8, id: \.self) { index in
                Rectangle()
                    .fill(style.ink.opacity(0.24))
                    .frame(width: 1, height: height * 0.060)
                    .offset(y: -height * 0.085)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
    }

    private func compactCameraGlyph(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.060, style: .continuous)
                .fill(style.ink.opacity(0.78))
            RoundedRectangle(cornerRadius: width * 0.028, style: .continuous)
                .fill(style.paper.opacity(0.58))
                .frame(width: width * 0.22, height: height * 0.22)
                .offset(x: -width * 0.26, y: -height * 0.18)
            Circle()
                .fill(style.paper.opacity(0.84))
                .frame(width: height * 0.46, height: height * 0.46)
                .overlay {
                    Circle()
                        .fill(style.ink.opacity(0.72))
                        .padding(height * 0.10)
                }
                .offset(x: width * 0.12, y: height * 0.06)
            Capsule()
                .fill(style.accent.opacity(0.70))
                .frame(width: width * 0.24, height: height * 0.040)
                .offset(x: width * 0.22, y: -height * 0.28)
        }
    }

    private func memoryCard(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: width * 0.050, style: .continuous)
                .fill(style.ink.opacity(0.74))
            Rectangle()
                .fill(style.paper.opacity(0.78))
                .frame(height: height * 0.22)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, width * 0.14)
                .padding(.top, height * 0.10)
            HStack(spacing: width * 0.035) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(style.accent.opacity(0.64))
                        .frame(width: width * 0.075, height: height * 0.20)
                }
            }
            .offset(y: height * 0.58)
        }
    }

    private func lcdScreen(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.045, style: .continuous)
            .fill(style.ink.opacity(0.66))
            .overlay {
                FilmSampleSceneView(film: film, style: style)
                    .padding(width * 0.040)
                    .opacity(0.66)
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: width * 0.018) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(style.paper.opacity(0.44))
                            .frame(width: width * 0.025, height: width * 0.025)
                    }
                }
                .padding(width * 0.06)
            }
    }

    private func landscapeBand(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(style.accent.opacity(0.58))
                .frame(width: width * 0.22, height: width * 0.22)
                .offset(x: width * 0.20, y: -height * 0.56)
            Path { path in
                path.move(to: CGPoint(x: 0, y: height * 0.66))
                path.addCurve(
                    to: CGPoint(x: width, y: height * 0.60),
                    control1: CGPoint(x: width * 0.28, y: height * 0.44),
                    control2: CGPoint(x: width * 0.60, y: height * 0.78)
                )
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(style.swatches[1].opacity(0.62))
            Path { path in
                path.move(to: CGPoint(x: 0, y: height * 0.78))
                path.addCurve(
                    to: CGPoint(x: width, y: height * 0.72),
                    control1: CGPoint(x: width * 0.20, y: height * 0.62),
                    control2: CGPoint(x: width * 0.76, y: height * 0.88)
                )
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(style.swatches[2].opacity(0.58))
        }
    }

    private func rollSeal(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(style.ink.opacity(0.24), lineWidth: 1)
                .frame(width: width * 0.19, height: width * 0.19)
            Circle()
                .fill(style.accent.opacity(0.62))
                .frame(width: width * 0.10, height: width * 0.10)
        }
    }

    private func leatherPanel(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.035, style: .continuous)
            .fill(style.ink.opacity(0.52))
            .padding(.horizontal, width * 0.10)
            .padding(.vertical, height * 0.18)
            .overlay {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(style.paper.opacity(0.07))
                        .frame(height: 1)
                        .offset(y: height * CGFloat(Double(index) * 0.10 - 0.22))
                }
            }
    }

    private func rangefinderGlyph(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.045, style: .continuous)
                .fill(style.paper.opacity(0.58))
            Circle()
                .fill(style.ink.opacity(0.74))
                .frame(width: height * 0.40, height: height * 0.40)
                .overlay {
                    Circle()
                        .stroke(style.paper.opacity(0.70), lineWidth: 2)
                        .padding(height * 0.06)
                }
                .offset(x: width * 0.16)
            RoundedRectangle(cornerRadius: width * 0.020, style: .continuous)
                .fill(style.ink.opacity(0.42))
                .frame(width: width * 0.18, height: height * 0.20)
                .offset(x: -width * 0.26, y: -height * 0.12)
        }
    }

    private func recipeTabs(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(style.swatches[index].opacity(0.62))
            }
        }
        .overlay(alignment: .leading) {
            VStack(spacing: height * 0.035) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(style.paper.opacity(0.60))
                        .frame(width: width * CGFloat(0.16 + Double(index) * 0.05), height: 2)
                }
            }
            .padding(.leading, width * 0.10)
        }
    }

    private func swatchStack(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: height * 0.018) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(style.swatches[index].opacity(0.88))
                    .frame(width: width * CGFloat(0.16 + Double(index) * 0.035), height: height * 0.032)
            }
        }
    }

    private func twinSlides(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.08) {
            slideMount(width: width, height: height, rotation: -4)
            slideMount(width: width, height: height, rotation: 5)
        }
        .padding(.horizontal, width * 0.10)
        .padding(.vertical, height * 0.18)
    }

    private func slideMount(width: CGFloat, height: CGFloat, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: width * 0.030, style: .continuous)
            .fill(style.paper.opacity(0.92))
            .overlay {
                FilmSampleSceneView(film: film, style: style)
                    .padding(width * 0.070)
                    .opacity(0.72)
            }
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.020, style: .continuous)
                    .stroke(style.ink.opacity(0.13), lineWidth: 1)
                    .padding(width * 0.035)
            }
            .rotationEffect(.degrees(rotation))
    }

    private func vellumSheet(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.030, style: .continuous)
            .fill(style.paper.opacity(0.34))
            .background(.ultraThinMaterial.opacity(0.20))
            .padding(.horizontal, width * 0.12)
            .padding(.vertical, height * 0.14)
            .overlay {
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 1)
                    .offset(y: -height * 0.20)
            }
    }

    private func flowerCluster(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.035) {
            ForEach(0..<3, id: \.self) { index in
                ZStack {
                    ForEach(0..<4, id: \.self) { petal in
                        Circle()
                            .fill(style.wash[petal % style.wash.count].opacity(0.72))
                            .frame(width: width * 0.065, height: width * 0.065)
                            .offset(
                                x: width * CGFloat([0.035, -0.035, 0.0, 0.0][petal]),
                                y: height * CGFloat([0.0, 0.0, 0.025, -0.025][petal])
                            )
                    }
                    Circle()
                        .fill(style.accent.opacity(0.85))
                        .frame(width: width * 0.036, height: width * 0.036)
                }
                .offset(y: height * CGFloat(index == 1 ? -0.04 : 0.0))
            }
        }
    }

    private func fadeWash(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            colors: [style.paper.opacity(0.24), .clear, style.accent.opacity(0.18)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func diaryBinding(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(style.ink.opacity(0.14))
                .frame(width: 1)
            VStack(spacing: height * 0.08) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(style.paper.opacity(0.52))
                        .frame(width: width * 0.030, height: width * 0.030)
                }
            }
            .offset(y: -height * 0.02)
        }
    }

    private func seed(_ index: Int, salt: UInt64) -> Int {
        var value: UInt64 = 14_695_981_039_346_656_037 &+ salt
        for scalar in film.id.unicodeScalars {
            value ^= UInt64(scalar.value)
            value = value &* 1_099_511_628_211
        }
        value ^= UInt64(index + 1) &* 16_777_619
        return Int(value % 10_000)
    }

    private func offset(_ index: Int, salt: UInt64, length: CGFloat) -> CGFloat {
        let normalized = CGFloat(seed(index, salt: salt)) / 10_000.0
        return normalized * length - length / 2
    }
}

private struct FilmPhysicalPackageView: View {
    let film: FilmPreset
    let scale: FilmPackageScale

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    private var size: CGSize {
        scale.size
    }

    private var isHeroScale: Bool {
        switch scale {
        case .hero:
            return true
        case .shelf:
            return false
        }
    }

    private var exposureMicroLabel: String {
        switch film.category {
        case .instant:
            return "pack"
        case .digital:
            return "ccd"
        default:
            return "\(film.defaultShotCount) exp"
        }
    }

    var body: some View {
        ZStack {
            objectAmbientShadow

            Group {
                switch FilmPackageKind.kind(for: film) {
                case .paperBox:
                    paperBox
                case .canister:
                    canister
                case .instantPack:
                    instantPack
                case .cameraBody:
                    cameraBody
                case .paperSleeve:
                    paperSleeve
                case .disposable:
                    disposable
                case .halfFrameTicket:
                    halfFrameTicket
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var paperBox: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            style.paper.opacity(1.0),
                            style.paper.opacity(0.92),
                            style.ink.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            boxWrapperArtwork
            .padding(size.width * 0.055)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            boxSidePanel
            boxTopLip

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [style.ink.opacity(0.18), style.ink.opacity(0.02)],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                )
                .frame(width: size.width * 0.13)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, size.width * 0.055)

            packageMotif
                .frame(width: size.width * 0.58, height: size.height * 0.38)
                .padding(.leading, size.width * 0.13)
                .padding(.top, size.height * 0.28)

            VStack(alignment: .leading, spacing: size.height * 0.022) {
                Text("STILL LIGHT")
                    .font(.system(size: size.width * 0.054, weight: .bold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(style.ink.opacity(0.55))

                Text(style.label)
                    .font(.system(size: size.width * 0.112, weight: .black, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(style.ink.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)

                Spacer()

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Rectangle()
                            .fill(style.swatches[index].opacity(0.90))
                            .frame(width: size.width * 0.16, height: 3)
                    }
                }

                HStack {
                    Text("ISO \(film.iso)")
                    Spacer()
                    Text(exposureMicroLabel)
                }
                .font(.system(size: size.width * 0.071, weight: .bold, design: .monospaced))
                .foregroundStyle(style.ink.opacity(0.76))
            }
            .padding(size.width * 0.12)

            boxFoldLines
            productionTicks
            paperTexture
            packageWear
            packageGloss(cornerRadius: 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(packageStroke(cornerRadius: 8))
        .overlay(packageInsetStroke(cornerRadius: 6).padding(size.width * 0.055))
        .shadow(color: style.ink.opacity(0.18), radius: isHeroScale ? 11 : 7, x: 0, y: isHeroScale ? 8 : 5)
    }

    @ViewBuilder
    private var boxWrapperArtwork: some View {
        switch style.kind {
        case .filmStrip:
            VStack(spacing: 0) {
                Rectangle().fill(style.wash[0].opacity(0.86)).frame(height: size.height * 0.21)
                Rectangle().fill(style.paper.opacity(0.92))
                negativeStrip
                    .frame(height: size.height * 0.25)
                    .padding(.horizontal, size.width * 0.10)
                    .padding(.vertical, size.height * 0.035)
                    .background(style.wash[1].opacity(0.48))
                Rectangle().fill(style.wash[2].opacity(0.78)).frame(height: size.height * 0.15)
            }
        case .contactSheet:
            ZStack {
                style.paper.opacity(0.96)
                VStack(spacing: size.height * 0.035) {
                    Rectangle().fill(style.wash[0].opacity(0.82)).frame(height: size.height * 0.17)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: size.width * 0.035), count: 2), spacing: size.width * 0.035) {
                        ForEach(0..<4, id: \.self) { index in
                            FilmSampleSceneView(film: film, style: style)
                                .opacity(index == 3 ? 0.62 : 0.88)
                        }
                    }
                    .padding(.horizontal, size.width * 0.12)
                    .padding(.bottom, size.height * 0.12)
                }
            }
        case .darkroomCard:
            ZStack {
                style.ink.opacity(0.92)
                FilmSampleSceneView(film: film, style: style)
                    .padding(.horizontal, size.width * 0.16)
                    .padding(.vertical, size.height * 0.20)
                    .opacity(0.86)
                Rectangle()
                    .fill(style.accent.opacity(0.72))
                    .frame(width: size.width * 0.62, height: 2)
                    .offset(y: size.height * 0.24)
            }
        case .colorRecipe:
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(style.swatches[index].opacity(index == 0 ? 0.82 : 0.72))
                }
                FilmSampleSceneView(film: film, style: style)
                    .frame(height: size.height * 0.34)
            }
        case .instantFrame:
            ZStack {
                style.paper.opacity(0.94)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.72))
                    .padding(.horizontal, size.width * 0.12)
                    .padding(.top, size.height * 0.12)
                    .padding(.bottom, size.height * 0.24)
                FilmSampleSceneView(film: film, style: style)
                    .padding(.horizontal, size.width * 0.18)
                    .padding(.top, size.height * 0.18)
                    .padding(.bottom, size.height * 0.32)
            }
        case .halfFrame:
            HStack(spacing: size.width * 0.035) {
                FilmSampleSceneView(film: film, style: style)
                FilmSampleSceneView(film: film, style: style)
                    .opacity(0.76)
            }
            .padding(.horizontal, size.width * 0.12)
            .padding(.vertical, size.height * 0.16)
            .background(style.ink.opacity(0.82))
        case .negativeSleeve:
            ZStack {
                style.paper.opacity(0.88)
                negativeStrip
                    .rotationEffect(.degrees(style.tilt * 0.25))
                    .padding(.horizontal, size.width * 0.04)
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 1)
                    .offset(y: -size.height * 0.24)
            }
        }
    }

    private var canister: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(StillLightTheme.panel.opacity(0.01))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            style.ink.opacity(0.94),
                            style.ink.opacity(0.66),
                            style.ink.opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size.width * 0.90, height: size.height * 0.42)
                .shadow(color: .black.opacity(0.26), radius: 9, x: 0, y: 7)

            HStack(spacing: 0) {
                canisterCap
                Spacer()
                canisterCap
            }
            .frame(width: size.width * 0.98, height: size.height * 0.46)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(style.paper.opacity(0.94))
                .frame(width: size.width * 0.60, height: size.height * 0.35)
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
                .overlay {
                    FilmSampleSceneView(film: film, style: style)
                        .padding(.leading, size.width * 0.12)
                        .padding(.trailing, size.width * 0.12)
                        .padding(.vertical, size.height * 0.045)
                        .opacity(0.72)
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(style.accent.opacity(0.88))
                        .frame(width: size.width * 0.09)
                }
                .overlay(alignment: .trailing) {
                    VStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(style.ink.opacity(0.18))
                                .frame(width: size.width * 0.08, height: 1)
                        }
                    }
                    .padding(.trailing, size.width * 0.05)
                }
                .overlay {
                    VStack(spacing: 2) {
                        Text(style.label)
                            .font(.system(size: size.width * 0.068, weight: .black, design: .monospaced))
                            .tracking(0.2)
                            .foregroundStyle(style.ink.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text("B&W \(film.iso)")
                            .font(.system(size: size.width * 0.060, weight: .semibold, design: .monospaced))
                            .foregroundStyle(style.ink.opacity(0.56))
                    }
                    .padding(.leading, size.width * 0.08)
                }

            VStack(spacing: size.height * 0.14) {
                canisterRidges
                canisterRidges
            }
            .opacity(0.7)

            Capsule()
                .stroke(.white.opacity(0.10), lineWidth: 1)
                .frame(width: size.width * 0.82, height: size.height * 0.34)
                .offset(y: -size.height * 0.025)
        }
        .rotationEffect(.degrees(-5))
    }

    private var instantPack: some View {
        ZStack(alignment: .top) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(style.paper.opacity(0.42 - Double(index) * 0.09))
                    .frame(width: size.width * (0.82 + CGFloat(index) * 0.04), height: size.height * 0.82)
                    .offset(y: size.height * (0.10 + CGFloat(index) * 0.035))
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            }

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(style.paper.opacity(0.98))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(style.ink.opacity(0.08))
                        .frame(width: size.width * 0.055)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(style.ink.opacity(0.80))
                        .frame(width: size.width * 0.42, height: size.height * 0.032)
                        .padding(.top, size.height * 0.075)
                }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.wash[0].opacity(0.36), style.wash[1].opacity(0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.width * 0.56, height: size.width * 0.56)
                .padding(.top, size.height * 0.19)
                .overlay {
                    FilmSampleSceneView(film: film, style: style)
                        .frame(width: size.width * 0.50, height: size.width * 0.50)
                        .padding(.top, size.height * 0.19)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(style.ink.opacity(0.13), lineWidth: 1)
                        .frame(width: size.width * 0.56, height: size.width * 0.56)
                        .padding(.top, size.height * 0.19)
                }

            VStack(spacing: size.height * 0.018) {
                Spacer()
                Text(style.label)
                    .font(.system(size: size.width * 0.077, weight: .black, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(style.ink.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Rectangle()
                    .fill(style.accent.opacity(0.80))
                    .frame(width: size.width * 0.48, height: 4)
                Text("INSTANT PACK")
                    .font(.system(size: size.width * 0.052, weight: .bold, design: .monospaced))
                    .foregroundStyle(style.ink.opacity(0.42))
            }
            .padding(.bottom, size.height * 0.09)

            paperTexture.opacity(0.36)
            packageWear.opacity(0.42)
            packageGloss(cornerRadius: 9).opacity(0.72)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(packageStroke(cornerRadius: 9))
    }

    private var cameraBody: some View {
        VStack(spacing: size.height * 0.045) {
            CameraModelPlate(film: film)
                .frame(width: size.width, height: size.height * 0.72)
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(style.paper.opacity(0.20))
                        .frame(width: size.width * 0.18)
                        .blur(radius: 5)
                        .offset(x: size.width * 0.10, y: size.height * 0.05)
                }
                .overlay(alignment: .bottomTrailing) {
                    FilmSampleSceneView(film: film, style: style)
                        .frame(width: size.width * 0.34, height: size.height * 0.24)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(style.paper.opacity(0.26), lineWidth: 1)
                        }
                        .offset(x: -size.width * 0.08, y: -size.height * 0.08)
                }

            Text(style.label)
                .font(.system(size: size.width * 0.066, weight: .bold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(style.ink.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, size.width * 0.10)
                .padding(.vertical, size.height * 0.035)
                .background(style.paper.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private var paperSleeve: some View {
        ZStack {
            negativeStrip
                .rotationEffect(.degrees(-7))
                .offset(y: size.height * 0.02)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(style.paper.opacity(0.66))
                .background(.ultraThinMaterial.opacity(0.42))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.white.opacity(0.20))
                        .frame(height: 1)
                        .padding(.horizontal, size.width * 0.08)
                        .padding(.top, size.height * 0.08)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(style.ink.opacity(0.17), lineWidth: 1)
                }

            Rectangle()
                .fill(style.accent.opacity(0.72))
                .frame(width: size.width * 1.18, height: size.height * 0.12)
                .rotationEffect(.degrees(-15))
                .offset(y: -size.height * 0.15)

            FilmSampleSceneView(film: film, style: style)
                .frame(width: size.width * 0.52, height: size.height * 0.34)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(style.ink.opacity(0.18), lineWidth: 1)
                }
                .offset(y: -size.height * 0.12)

            VStack(spacing: size.height * 0.035) {
                Text(style.label)
                    .font(.system(size: size.width * 0.083, weight: .black, design: .monospaced))
                    .tracking(0.2)
                    .foregroundStyle(style.ink.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text("120 / \(film.iso)")
                    .font(.system(size: size.width * 0.058, weight: .semibold, design: .monospaced))
                    .foregroundStyle(style.ink.opacity(0.50))
            }
            .padding(.top, size.height * 0.24)

            paperTexture.opacity(0.28)
            packageWear.opacity(0.42)
            sleeveCrinkles
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(packageStroke(cornerRadius: 5))
    }

    private var disposable: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.wash[0], style.wash[1]],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.08))
                        .frame(width: size.width * 0.60, height: size.height * 0.18)
                        .blur(radius: 5)
                        .offset(x: size.width * 0.06, y: size.height * 0.04)
                }

            Rectangle()
                .fill(style.paper.opacity(0.80))
                .frame(height: size.height * 0.35)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(style.accent.opacity(0.82))
                        .frame(height: 4)
                }
                .overlay(alignment: .leading) {
                    FilmSampleSceneView(film: film, style: style)
                        .frame(width: size.width * 0.34, height: size.height * 0.24)
                        .padding(.leading, size.width * 0.10)
                        .padding(.top, size.height * 0.08)
                }

            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.paper.opacity(0.84))
                    .frame(width: size.width * 0.28, height: size.height * 0.16)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(style.ink.opacity(0.35))
                            .padding(size.width * 0.035)
                    }
                Spacer()
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.accent.opacity(0.78))
                    .frame(width: size.width * 0.23, height: size.height * 0.18)
                    .overlay {
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(style.paper.opacity(0.58))
                                    .frame(width: size.width * 0.12, height: 1)
                            }
                        }
                    }
            }
            .padding(size.width * 0.11)

            Circle()
                .fill(style.ink.opacity(0.86))
                .frame(width: size.width * 0.36)
                .overlay {
                    Circle()
                        .stroke(style.paper.opacity(0.82), lineWidth: isHeroScale ? 5 : 4)
                        .padding(size.width * 0.035)
                }
                .overlay {
                    Circle()
                        .fill(style.swatches[2].opacity(0.82))
                        .padding(size.width * 0.12)
                }
                .offset(y: -size.height * 0.02)

            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text("ONE TIME")
                    .font(.system(size: size.width * 0.050, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(style.ink.opacity(0.48))
                Text(style.label)
                    .font(.system(size: size.width * 0.080, weight: .black, design: .monospaced))
                    .foregroundStyle(style.ink.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(size.width * 0.11)

            paperTexture.opacity(0.26)
            packageWear.opacity(0.32)
            packageGloss(cornerRadius: 10).opacity(0.55)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(packageStroke(cornerRadius: 10))
    }

    private var halfFrameTicket: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(style.paper)

            HStack(spacing: size.width * 0.052) {
                ForEach(0..<2, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(style.paper.opacity(0.20))
                        .overlay {
                            FilmSampleSceneView(film: film, style: style)
                                .opacity(index == 0 ? 0.95 : 0.78)
                        }
                        .overlay(alignment: .topLeading) {
                            Circle()
                                .fill(style.paper.opacity(0.36))
                                .frame(width: size.width * 0.10)
                                .blur(radius: 4)
                                .offset(x: size.width * 0.10, y: size.height * 0.05)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(style.ink.opacity(0.18), lineWidth: 1)
                        }
                }
            }
            .padding(.horizontal, size.width * 0.13)
            .padding(.top, size.height * 0.16)
            .padding(.bottom, size.height * 0.30)

            Rectangle()
                .fill(style.ink.opacity(0.13))
                .frame(width: 1)
                .padding(.vertical, size.height * 0.11)

            VStack(spacing: size.height * 0.025) {
                HStack(spacing: size.width * 0.07) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .fill(style.ink.opacity(0.25))
                            .frame(width: size.width * 0.035)
                    }
                }
                Spacer()
                Text(style.label)
                    .font(.system(size: size.width * 0.066, weight: .black, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(style.ink.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text("18 x 24")
                    .font(.system(size: size.width * 0.050, weight: .semibold, design: .monospaced))
                    .foregroundStyle(style.ink.opacity(0.44))
            }
            .padding(size.width * 0.10)

            paperTexture.opacity(0.30)
            packageWear.opacity(0.36)
            ticketTornEdges
            packageGloss(cornerRadius: 5).opacity(0.52)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(packageStroke(cornerRadius: 5))
    }

    private var objectAmbientShadow: some View {
        VStack {
            Spacer()
            Capsule()
                .fill(.black.opacity(isHeroScale ? 0.22 : 0.16))
                .frame(width: size.width * 0.88, height: size.height * 0.11)
                .blur(radius: isHeroScale ? 8 : 5)
                .offset(y: size.height * 0.05)
        }
        .allowsHitTesting(false)
    }

    private var boxSidePanel: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            style.paper.opacity(0.22),
                            style.ink.opacity(0.18),
                            style.ink.opacity(0.28)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size.width * 0.16)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.07))
                        .frame(width: 1)
                }
        }
    }

    private var boxTopLip: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.18),
                            style.paper.opacity(0.18),
                            style.ink.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: size.height * 0.075)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(style.ink.opacity(0.10))
                        .frame(height: 1)
                }
            Spacer()
        }
    }

    private var productionTicks: some View {
        VStack {
            Spacer()
            HStack(spacing: size.width * 0.024) {
                ForEach(0..<7, id: \.self) { index in
                    Rectangle()
                        .fill(style.ink.opacity(index.isMultiple(of: 2) ? 0.18 : 0.10))
                        .frame(width: 1, height: size.height * CGFloat(index.isMultiple(of: 3) ? 0.050 : 0.032))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, size.width * 0.14)
            .padding(.bottom, size.height * 0.08)
        }
    }

    private var sleeveCrinkles: some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.13))
                .frame(width: 1, height: size.height * 0.74)
                .rotationEffect(.degrees(-12))
                .offset(x: -size.width * 0.18, y: size.height * 0.02)
            Rectangle()
                .fill(style.ink.opacity(0.08))
                .frame(width: 1, height: size.height * 0.56)
                .rotationEffect(.degrees(9))
                .offset(x: size.width * 0.20, y: -size.height * 0.04)
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(width: size.width * 0.54, height: 1)
                .rotationEffect(.degrees(-4))
                .offset(y: size.height * 0.30)
        }
    }

    private var ticketTornEdges: some View {
        VStack {
            HStack(spacing: size.width * 0.075) {
                ForEach(0..<6, id: \.self) { _ in
                    Circle()
                        .fill(StillLightTheme.background.opacity(0.55))
                        .frame(width: size.width * 0.045)
                }
            }
            .offset(y: -size.height * 0.02)
            Spacer()
            HStack(spacing: size.width * 0.075) {
                ForEach(0..<6, id: \.self) { _ in
                    Circle()
                        .fill(StillLightTheme.background.opacity(0.48))
                        .frame(width: size.width * 0.045)
                }
            }
            .offset(y: size.height * 0.02)
        }
        .allowsHitTesting(false)
    }

    private func packageGloss(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.20),
                        .white.opacity(0.055),
                        .clear,
                        style.ink.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.plusLighter)
    }

    private func packageInsetStroke(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(.white.opacity(0.11), lineWidth: 1)
    }

    @ViewBuilder
    private var packageMotif: some View {
        FilmSampleSceneView(film: film, style: style)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(style.paper.opacity(0.24), lineWidth: 1)
            }
            .rotationEffect(.degrees(style.tilt * 0.45))
    }

    private var perforationRail: some View {
        VStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(style.paper.opacity(0.55))
                    .frame(width: size.width * 0.045, height: size.height * 0.024)
            }
        }
        .padding(.vertical, 3)
        .background(style.ink.opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }

    private var canisterCap: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [style.paper.opacity(0.86), style.paper.opacity(0.42), style.ink.opacity(0.48)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size.width * 0.22, height: size.height * 0.50)
            .overlay {
                Capsule()
                    .stroke(style.ink.opacity(0.18), lineWidth: 1)
                    .padding(2)
            }
    }

    private var canisterRidges: some View {
        HStack(spacing: 2) {
            ForEach(0..<9, id: \.self) { _ in
                Capsule()
                    .fill(style.paper.opacity(0.10))
                    .frame(width: 1.2, height: size.height * 0.11)
            }
        }
    }

    private var negativeStrip: some View {
        HStack(spacing: size.width * 0.035) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(style.swatches[index % style.swatches.count].opacity(0.58))
                    .overlay {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .stroke(style.paper.opacity(0.16), lineWidth: 1)
                    }
            }
        }
        .padding(.horizontal, size.width * 0.08)
        .padding(.vertical, size.height * 0.11)
        .background(style.ink.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(alignment: .top) {
            sprocketRow
                .padding(.top, size.height * 0.025)
        }
        .overlay(alignment: .bottom) {
            sprocketRow
                .padding(.bottom, size.height * 0.025)
        }
    }

    private var sprocketRow: some View {
        HStack(spacing: size.width * 0.036) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(style.paper.opacity(0.50))
                    .frame(width: size.width * 0.035, height: size.height * 0.018)
            }
        }
    }

    private var boxFoldLines: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(style.ink.opacity(0.10))
                .frame(height: 1)
                .padding(.horizontal, size.width * 0.12)
                .padding(.top, size.height * 0.18)
            Spacer()
            Rectangle()
                .fill(style.paper.opacity(0.20))
                .frame(height: 1)
                .padding(.horizontal, size.width * 0.08)
                .padding(.bottom, size.height * 0.14)
        }
    }

    private var paperTexture: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                Rectangle()
                    .fill(style.ink.opacity(index.isMultiple(of: 4) ? 0.065 : 0.032))
                    .frame(width: CGFloat(6 + (textureSeed(index, salt: 11) % 18)), height: 1)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -7 : 9))
                    .offset(
                        x: textureOffset(index, salt: 17, length: size.width),
                        y: textureOffset(index, salt: 29, length: size.height)
                    )
            }
        }
        .opacity(0.50)
    }

    private var packageWear: some View {
        ZStack {
            ForEach(0..<22, id: \.self) { index in
                Circle()
                    .fill(style.ink.opacity(index.isMultiple(of: 5) ? 0.070 : 0.038))
                    .frame(width: CGFloat(1 + textureSeed(index, salt: 43) % 3))
                    .offset(
                        x: textureOffset(index, salt: 37, length: size.width * 0.86),
                        y: textureOffset(index, salt: 53, length: size.height * 0.86)
                    )
            }

            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(style.paper.opacity(0.16))
                    .frame(width: CGFloat(10 + textureSeed(index, salt: 71) % 16), height: 1)
                    .rotationEffect(.degrees(Double(textureSeed(index, salt: 83) % 28) - 14))
                    .offset(
                        x: textureOffset(index, salt: 89, length: size.width * 0.78),
                        y: textureOffset(index, salt: 97, length: size.height * 0.78)
                    )
            }
        }
    }

    private func textureSeed(_ index: Int, salt: UInt64) -> Int {
        var value: UInt64 = 14_695_981_039_346_656_037 &+ salt
        for scalar in film.id.unicodeScalars {
            value ^= UInt64(scalar.value)
            value = value &* 1_099_511_628_211
        }
        value ^= UInt64(index + 1) &* 16_777_619
        return Int(value % 10_000)
    }

    private func textureOffset(_ index: Int, salt: UInt64, length: CGFloat) -> CGFloat {
        let normalized = CGFloat(textureSeed(index, salt: salt)) / 10_000.0
        return normalized * length - length / 2
    }

    private func packageStroke(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(style.ink.opacity(0.16), lineWidth: 1)
    }
}

private enum CameraPlateKind {
    case rangefinder
    case medium
    case compact
    case ccd
    case instant
    case toy

    static func kind(for film: FilmPreset) -> CameraPlateKind {
        switch film.id {
        case "medium-500c", "hncs-natural":
            return .medium
        case "ccd-2003", "cyber-ccd-blue":
            return .ccd
        case "instant-square", "instant-wide", "sx-fade":
            return .instant
        case "pocket-flash", "holga-120-dream", "lca-vivid":
            return .toy
        case "t-compact-gold", "gr-street-snap", "classic-chrome-x", "half-frame-diary":
            return .compact
        default:
            return .rangefinder
        }
    }
}

private struct CameraModelPlate: View {
    let film: FilmPreset

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    private var kind: CameraPlateKind {
        CameraPlateKind.kind(for: film)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                switch kind {
                case .rangefinder:
                    rangefinder(width: width, height: height)
                case .medium:
                    mediumCamera(width: width, height: height)
                case .compact:
                    compactCamera(width: width, height: height)
                case .ccd:
                    ccdCamera(width: width, height: height)
                case .instant:
                    instantCamera(width: width, height: height)
                case .toy:
                    toyCamera(width: width, height: height)
                }
            }
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
        }
    }

    private func cameraShell(width: CGFloat, height: CGFloat, radius: CGFloat = 12) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        style.ink.opacity(0.92),
                        style.ink.opacity(0.72),
                        style.ink.opacity(0.54)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(style.paper.opacity(0.13))
                    .frame(height: height * 0.22)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(style.paper.opacity(0.17))
                    .frame(height: height * 0.36)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(style.paper.opacity(0.15), lineWidth: 1)
            }
    }

    private func lens(width: CGFloat, height: CGFloat, diameter: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        style.swatches[2].opacity(0.92),
                        style.ink.opacity(0.98),
                        .black.opacity(0.96)
                    ],
                    center: .center,
                    startRadius: diameter * 0.05,
                    endRadius: diameter * 0.50
                )
            )
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .stroke(style.paper.opacity(0.70), lineWidth: Swift.max(2, diameter * 0.08))
                    .padding(diameter * 0.08)
            }
            .overlay {
                Circle()
                    .stroke(.black.opacity(0.55), lineWidth: Swift.max(1, diameter * 0.045))
                    .padding(diameter * 0.17)
            }
            .overlay {
                Circle()
                    .stroke(style.accent.opacity(0.46), lineWidth: Swift.max(1, diameter * 0.025))
                    .padding(diameter * 0.22)
            }
            .overlay {
                Circle()
                    .stroke(style.paper.opacity(0.24), lineWidth: Swift.max(1, diameter * 0.018))
                    .padding(diameter * 0.32)
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(style.paper.opacity(0.50))
                    .frame(width: diameter * 0.16, height: diameter * 0.16)
                    .blur(radius: 1.2)
                    .offset(x: diameter * 0.27, y: diameter * 0.25)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(style.accent.opacity(0.20))
                    .frame(width: diameter * 0.22, height: diameter * 0.22)
                    .blur(radius: 2)
                    .offset(x: -diameter * 0.18, y: -diameter * 0.18)
            }
            .shadow(color: .black.opacity(0.22), radius: diameter * 0.08, x: 0, y: diameter * 0.035)
    }

    private func viewfinder(width: CGFloat, height: CGFloat, isRound: Bool = false) -> some View {
        Group {
            if isRound {
                Circle()
                    .fill(style.paper.opacity(0.68))
                    .overlay {
                        Circle()
                            .fill(style.ink.opacity(0.36))
                            .padding(width * 0.015)
                    }
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.paper.opacity(0.70))
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(style.ink.opacity(0.34))
                            .padding(width * 0.012)
                    }
            }
        }
        .frame(width: width * 0.17, height: height * 0.16)
    }

    private func rangefinder(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            cameraShell(width: width, height: height)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(style.paper.opacity(0.20))
                .frame(height: height * 0.30)
                .padding(.horizontal, width * 0.08)
                .frame(maxHeight: .infinity, alignment: .bottom)

            HStack {
                viewfinder(width: width, height: height)
                Spacer()
                Capsule()
                    .fill(style.accent.opacity(0.72))
                    .frame(width: width * 0.20, height: 4)
            }
            .padding(.horizontal, width * 0.10)
            .padding(.top, height * 0.14)
            .frame(maxHeight: .infinity, alignment: .top)

            lens(width: width, height: height, diameter: min(width, height) * 0.48)
                .offset(x: width * 0.06, y: height * 0.06)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(style.paper.opacity(0.28))
                .frame(width: width * 0.18, height: height * 0.05)
                .offset(x: -width * 0.27, y: -height * 0.28)
        }
    }

    private func mediumCamera(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(style.ink.opacity(0.88))
                .frame(width: width * 0.86, height: height * 0.82)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(style.paper.opacity(0.20), lineWidth: 1)
                }

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(style.paper.opacity(0.20))
                .frame(width: width * 0.34, height: height * 0.27)
                .offset(y: -height * 0.23)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(style.paper.opacity(0.28), lineWidth: 1)
                        .padding(4)
                        .offset(y: -height * 0.23)
                }

            lens(width: width, height: height, diameter: min(width, height) * 0.54)
                .offset(y: height * 0.08)

            HStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.paper.opacity(0.42))
                    .frame(width: width * 0.16, height: height * 0.10)
                Spacer()
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.accent.opacity(0.40))
                    .frame(width: width * 0.12, height: height * 0.10)
            }
            .padding(.horizontal, width * 0.16)
            .offset(y: -height * 0.12)
        }
    }

    private func compactCamera(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            cameraShell(width: width, height: height, radius: 14)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(style.paper.opacity(0.16))
                .frame(width: width * 0.46, height: height * 0.48)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, width * 0.08)

            lens(width: width, height: height, diameter: min(width, height) * 0.42)
                .offset(x: width * 0.12, y: height * 0.06)

            HStack {
                viewfinder(width: width, height: height)
                    .frame(width: width * 0.18, height: height * 0.13)
                Spacer()
                Circle()
                    .fill(style.accent.opacity(0.72))
                    .frame(width: height * 0.08, height: height * 0.08)
            }
            .padding(.horizontal, width * 0.11)
            .padding(.top, height * 0.14)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func ccdCamera(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.paper.opacity(0.94), style.swatches[1].opacity(0.76), style.ink.opacity(0.80)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(style.paper.opacity(0.25), lineWidth: 1)
                }

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(style.ink.opacity(0.78))
                .frame(width: width * 0.30, height: height * 0.34)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, width * 0.12)
                .overlay {
                    Rectangle()
                        .fill(style.accent.opacity(0.40))
                        .frame(width: width * 0.18, height: height * 0.18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, width * 0.18)
                }

            lens(width: width, height: height, diameter: min(width, height) * 0.36)
                .offset(x: width * 0.18)

            Capsule()
                .fill(style.ink.opacity(0.44))
                .frame(width: width * 0.22, height: 4)
                .offset(y: -height * 0.30)
        }
    }

    private func instantCamera(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(style.paper.opacity(0.94))
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(style.ink.opacity(0.62))
                        .frame(height: height * 0.26)
                        .padding(.horizontal, width * 0.12)
                        .padding(.bottom, height * 0.09)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(style.ink.opacity(0.13), lineWidth: 1)
                }

            lens(width: width, height: height, diameter: min(width, height) * 0.35)
                .offset(x: width * 0.12, y: -height * 0.06)

            HStack {
                viewfinder(width: width, height: height, isRound: true)
                    .frame(width: height * 0.18, height: height * 0.18)
                Spacer()
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(style.accent.opacity(0.62))
                    .frame(width: width * 0.20, height: height * 0.16)
            }
            .padding(.horizontal, width * 0.14)
            .offset(y: -height * 0.22)
        }
    }

    private func toyCamera(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.wash[0].opacity(0.92), style.wash[1].opacity(0.86), style.ink.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(style.paper.opacity(0.22))
                .frame(height: height * 0.32)
                .frame(maxHeight: .infinity, alignment: .bottom)

            lens(width: width, height: height, diameter: min(width, height) * 0.43)
                .offset(y: height * 0.05)

            HStack {
                viewfinder(width: width, height: height)
                    .frame(width: width * 0.18, height: height * 0.14)
                Spacer()
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(style.accent.opacity(0.64))
                    .frame(width: width * 0.22, height: height * 0.16)
            }
            .padding(.horizontal, width * 0.12)
            .padding(.top, height * 0.15)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(style.paper.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct ExposureCounter: View {
    let film: FilmPreset
    let currentRoll: FilmRoll?
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(formatText)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(StillLightTheme.secondaryText.opacity(0.68))

            Text(countText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.2)
                .foregroundStyle(StillLightTheme.text.opacity(0.90))
                .contentTransition(.numericText())
                .id(countText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(StillLightTheme.panelElevated.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(StillLightTheme.text.opacity(0.08), lineWidth: 1)
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            LinearGradient(
                colors: [
                    StillLightTheme.panelElevated.opacity(0.68),
                    StillLightTheme.panel.opacity(0.46)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StillLightTheme.text.opacity(0.08), lineWidth: 1)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: countText)
    }

    private var formatText: String {
        switch film.category {
        case .instant:
            return language == .chinese ? "相纸盒" : "PACK"
        case .digital:
            return "CCD"
        default:
            return "135 FILM"
        }
    }

    private var countText: String {
        if let currentRoll {
            return language == .chinese ? "剩 \(currentRoll.remainingShots) 张" : "\(currentRoll.remainingShots) left"
        }
        switch film.category {
        case .instant:
            return language == .chinese ? "未开封" : "sealed"
        case .digital:
            return language == .chinese ? "文件" : "files"
        default:
            return "\(film.defaultShotCount) exp"
        }
    }
}

private struct LoadedSeal: View {
    let language: AppLanguage

    var body: some View {
        Text(language == .chinese ? "已装卷" : "LOADED")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(StillLightTheme.background)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(StillLightTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct LoadedTab: View {
    let language: AppLanguage

    var body: some View {
        Text(language == .chinese ? "装入" : "IN")
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(StillLightTheme.background)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(StillLightTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct FavoritePin: View {
    var body: some View {
        Circle()
            .fill(StillLightTheme.accent)
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .stroke(StillLightTheme.background.opacity(0.76), lineWidth: 1)
                    .padding(3)
            }
    }
}

private struct EmptyShelfMark: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StillLightTheme.secondaryText.opacity(0.28), lineWidth: 1)
                .frame(width: 58, height: 44)
                .offset(y: -10)
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(StillLightTheme.panelElevated.opacity(0.9))
                    .frame(width: 20, height: 34)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(StillLightTheme.panelElevated.opacity(0.52))
                    .frame(width: 20, height: 28)
            }
            Rectangle()
                .fill(StillLightTheme.accent.opacity(0.48))
                .frame(width: 86, height: 2)
        }
    }
}

private struct FilmPresetRow: View {
    let film: FilmPreset
    let isSelected: Bool
    let isFavorite: Bool
    let currentRoll: FilmRoll?
    let language: AppLanguage
    let favoriteTitle: String
    let selectAction: () -> Void
    let favoriteAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: selectAction) {
                HStack(spacing: 14) {
                    FilmCoverView(film: film)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Text(film.displayName(language: language))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(StillLightTheme.text)
                                .lineLimit(1)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(StillLightTheme.accent)
                            }
                        }

                        Text(toneLine)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(StillLightTheme.secondaryText)
                            .lineLimit(1)

                        Text(statusLine)
                            .font(.caption2.weight(currentRoll == nil ? .regular : .semibold))
                            .foregroundStyle(currentRoll == nil ? StillLightTheme.secondaryText.opacity(0.72) : StillLightTheme.accent.opacity(0.86))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: favoriteAction) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isFavorite ? StillLightTheme.accent : StillLightTheme.secondaryText.opacity(0.58))
                    .frame(width: 32, height: 46)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favoriteTitle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isSelected ? StillLightTheme.panelElevated.opacity(0.92) : StillLightTheme.panel.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? StillLightTheme.accent.opacity(0.24) : StillLightTheme.text.opacity(0.05), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var toneLine: String {
        let category = film.category.title(language: language)
        let scenes = language == .chinese && !film.localizedSuitableScenes.isEmpty
            ? film.localizedSuitableScenes
            : film.suitableScenes
        let sceneSummary = scenes.prefix(2).joined(separator: " / ")

        if sceneSummary.isEmpty {
            return category
        }
        return "\(category) · \(sceneSummary)"
    }

    private var statusLine: String {
        if let currentRoll {
            if language == .chinese {
                return "剩余 \(currentRoll.remainingShots) 张"
            }
            return "\(currentRoll.remainingShots) exposures left"
        }
        return film.displayCameraName(language: language)
    }

}

private struct FilmCoverView: View {
    let film: FilmPreset

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(style.paper)

            wrapperBands

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(style.ink.opacity(0.09), lineWidth: 1)
                .padding(5)

            coverArtwork
                .padding(.horizontal, 8)
                .padding(.vertical, 13)

            paperFolds
                .foregroundStyle(style.ink.opacity(0.10))

            VStack {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(style.ink.opacity(0.58))
                        .frame(width: 13, height: 1)
                    Text(style.label)
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .tracking(0.2)
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundStyle(style.ink.opacity(0.68))

                Spacer()

                productionMarks
            }
            .padding(7)
        }
        .frame(width: 62, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(style.ink.opacity(0.18), lineWidth: 1)
        }
    }

    private var wrapperBands: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(style.wash[0].opacity(0.72))
                .frame(height: 15)
            Rectangle()
                .fill(style.paper.opacity(0.88))
            Rectangle()
                .fill(style.wash[1].opacity(0.64))
                .frame(height: 13)
            Rectangle()
                .fill(style.wash[2].opacity(0.78))
                .frame(height: 14)
        }
        .overlay(alignment: .topTrailing) {
            Rectangle()
                .fill(style.accent.opacity(0.76))
                .frame(width: 7)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(style.ink.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 5)
                .padding(.leading, 7)
        }
        .padding(4)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    @ViewBuilder
    private var coverArtwork: some View {
        FilmSampleSceneView(film: film, style: style)
            .frame(width: 40, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(style.ink.opacity(0.20), lineWidth: 1)
            }
            .rotationEffect(.degrees(style.tilt * 0.55))
    }

    private var sprocketRail: some View {
        VStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(style.paper.opacity(0.82))
                    .frame(width: 4, height: 5)
            }
        }
    }

    private var sprocketRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(style.paper.opacity(0.82))
                    .frame(width: 4, height: 3)
            }
        }
    }

    private var productionMarks: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Rectangle()
                .fill(style.ink.opacity(0.34))
                .frame(width: 17, height: 1)
            Rectangle()
                .fill(style.ink.opacity(0.22))
                .frame(width: 9, height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var paperFolds: some View {
        ZStack {
            Rectangle()
                .frame(width: 48, height: 1)
                .offset(y: -22)
            Rectangle()
                .frame(width: 1, height: 58)
                .offset(x: -22)
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .frame(width: CGFloat(11 + index * 3), height: 1)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -8 : 10))
                    .offset(x: CGFloat(index * 14 - 16), y: CGFloat(index * 19 - 15))
            }
        }
    }
}

private struct FilmContactSheetCrop: View {
    let frame: FilmSamplePhotoFrame

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            if let contactSheet = UIImage(named: frame.assetName) {
                Image(uiImage: contactSheet)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: width * CGFloat(frame.columns) * 1.04, height: height * CGFloat(frame.rows) * 1.04)
                    .offset(
                        x: frame.offsetX * width,
                        y: frame.offsetY * height
                    )
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.24, green: 0.20, blue: 0.14),
                        Color(red: 0.08, green: 0.10, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

private enum FilmSamplePhotoFrame {
    case warmCafe
    case shadowInterior
    case windowPortrait
    case streetMarket
    case naturalProduct
    case tungstenNight
    case ccdParty
    case instantDesk
    case noirWindow

    var assetName: String {
        "film_sample_contact_sheet_v2"
    }

    var columns: Int { 3 }
    var rows: Int { 3 }

    private var gridPosition: (column: Int, row: Int) {
        switch self {
        case .warmCafe:
            return (0, 0)
        case .shadowInterior:
            return (1, 0)
        case .windowPortrait:
            return (2, 0)
        case .streetMarket:
            return (0, 1)
        case .naturalProduct:
            return (1, 1)
        case .tungstenNight:
            return (2, 1)
        case .ccdParty:
            return (0, 2)
        case .instantDesk:
            return (1, 2)
        case .noirWindow:
            return (2, 2)
        }
    }

    var offsetX: CGFloat {
        let centerColumn = CGFloat(columns - 1) / 2
        return (centerColumn - CGFloat(gridPosition.column)) * 1.04
    }

    var offsetY: CGFloat {
        let centerRow = CGFloat(rows - 1) / 2
        return (centerRow - CGFloat(gridPosition.row)) * 1.04
    }

    static func frame(for film: FilmPreset) -> FilmSamplePhotoFrame {
        switch film.id {
        case "human-warm-400", "sunlit-gold-200", "t-compact-gold", "classic-chrome-x":
            return .warmCafe
        case "human-vignette-800", "gr-street-snap", "green-street-400":
            return .shadowInterior
        case "muse-portrait-400", "soft-portrait-400", "m-rangefinder", "medium-500c":
            return .windowPortrait
        case "superia-green", "half-frame-diary", "lca-vivid":
            return .streetMarket
        case "hncs-natural", "ektar-vivid-100":
            return .naturalProduct
        case "tungsten-800", "cyber-ccd-blue":
            return .tungstenNight
        case "ccd-2003", "pocket-flash":
            return .ccdParty
        case "instant-square", "instant-wide", "sx-fade", "holga-120-dream":
            return .instantDesk
        case "silver-hp5", "tri-x-street", "noir-soft":
            return .noirWindow
        default:
            return .streetMarket
        }
    }
}

private struct FilmSampleSceneView: View {
    let film: FilmPreset
    let style: FilmCoverStyle

    private var scene: FilmSampleSceneKind {
        FilmSampleSceneKind.kind(for: film)
    }

    private var photoFrame: FilmSamplePhotoFrame {
        FilmSamplePhotoFrame.frame(for: film)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                FilmContactSheetCrop(frame: photoFrame)
                photoPrintFinish(width: width, height: height)
                sceneTone(width: width, height: height)
                sceneGrain(width: width, height: height)
            }
            .clipShape(RoundedRectangle(cornerRadius: min(width, height) * 0.08, style: .continuous))
        }
    }

    private func sceneBackdrop(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        style.wash[0].opacity(0.94),
                        style.swatches[1].opacity(0.70),
                        style.swatches[2].opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func photoPrintFinish(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    style.swatches[0].opacity(0.24),
                    .clear,
                    style.swatches[2].opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)

            LinearGradient(
                colors: [
                    .white.opacity(0.08),
                    .clear,
                    style.ink.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private func sceneContent(_ scene: FilmSampleSceneKind, width: CGFloat, height: CGFloat) -> some View {
        switch scene {
        case .humanCafe:
            humanCafeScene(width: width, height: height)
        case .shadowStreet:
            shadowStreetScene(width: width, height: height)
        case .musePortrait:
            musePortraitScene(width: width, height: height)
        case .goldenLandscape:
            goldenLandscapeScene(width: width, height: height)
        case .softPortrait:
            softPortraitScene(width: width, height: height)
        case .monoStreet:
            monoStreetScene(width: width, height: height)
        case .greenCity:
            greenCityScene(width: width, height: height)
        case .tungstenNight:
            tungstenNightScene(width: width, height: height)
        case .flashParty:
            flashPartyScene(width: width, height: height)
        case .ccdCampus:
            ccdCampusScene(width: width, height: height)
        case .instantHome:
            instantHomeScene(width: width, height: height)
        case .naturalLandscape:
            naturalLandscapeScene(width: width, height: height)
        case .rangefinderRed:
            rangefinderRedScene(width: width, height: height)
        case .compactTravel:
            compactTravelScene(width: width, height: height)
        case .grStreet:
            grStreetScene(width: width, height: height)
        case .chromeCity:
            chromeCityScene(width: width, height: height)
        case .mediumStudio:
            mediumStudioScene(width: width, height: height)
        case .holgaDream:
            holgaDreamScene(width: width, height: height)
        case .lcaSunset:
            lcaSunsetScene(width: width, height: height)
        case .instantTable:
            instantTableScene(width: width, height: height)
        case .sxFlowers:
            sxFlowersScene(width: width, height: height)
        case .halfFrameDiary:
            halfFrameDiaryScene(width: width, height: height)
        case .vividLandscape:
            vividLandscapeScene(width: width, height: height)
        case .superiaBeach:
            superiaBeachScene(width: width, height: height)
        case .noirWindow:
            noirWindowScene(width: width, height: height)
        }
    }

    private func humanCafeScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(style.paper.opacity(0.26))
                .frame(width: width * 0.70, height: height * 0.42)
                .offset(x: width * 0.02, y: -height * 0.22)
                .overlay {
                    HStack(spacing: width * 0.10) {
                        Rectangle().fill(style.ink.opacity(0.13)).frame(width: 1)
                        Rectangle().fill(style.ink.opacity(0.10)).frame(width: 1)
                    }
                    .offset(y: -height * 0.22)
                }

            Circle()
                .fill(style.accent.opacity(0.78))
                .frame(width: width * 0.20, height: width * 0.20)
                .blur(radius: 1.5)
                .offset(x: -width * 0.22, y: -height * 0.60)

            RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                .fill(style.ink.opacity(0.26))
                .frame(width: width * 0.95, height: height * 0.25)

            cafeCup(width: width, height: height)
                .offset(x: width * 0.19, y: -height * 0.18)

            plant(width: width, height: height)
                .offset(x: -width * 0.30, y: -height * 0.15)

            seatedPerson(width: width, height: height)
                .offset(x: -width * 0.02, y: -height * 0.18)
        }
    }

    private func shadowStreetScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(style.ink.opacity(0.62))

            HStack(alignment: .bottom, spacing: width * 0.08) {
                building(width: width * 0.24, height: height * 0.74, windows: 3)
                Spacer()
                building(width: width * 0.30, height: height * 0.86, windows: 4)
            }
            .padding(.horizontal, width * 0.08)

            Path { path in
                path.move(to: CGPoint(x: width * 0.40, y: height))
                path.addLine(to: CGPoint(x: width * 0.52, y: height * 0.48))
                path.addLine(to: CGPoint(x: width * 0.66, y: height))
                path.closeSubpath()
            }
            .fill(style.paper.opacity(0.15))

            Capsule()
                .fill(style.accent.opacity(0.52))
                .frame(width: width * 0.07, height: height * 0.56)
                .offset(x: -width * 0.16, y: -height * 0.24)

            person(width: width, height: height, color: style.paper.opacity(0.64))
                .offset(x: width * 0.05, y: -height * 0.16)

            RadialGradient(
                colors: [.clear, style.ink.opacity(0.66), .black.opacity(0.62)],
                center: .center,
                startRadius: min(width, height) * 0.24,
                endRadius: max(width, height) * 0.70
            )
        }
    }

    private func musePortraitScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(style.paper.opacity(0.48))
                .frame(width: width * 0.86, height: width * 0.86)
                .blur(radius: 3)
                .offset(x: -width * 0.20, y: -height * 0.30)

            RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                .fill(.white.opacity(0.22))
                .frame(width: width * 0.24, height: height * 0.72)
                .offset(x: -width * 0.34, y: -height * 0.18)

            Capsule()
                .fill(style.swatches[2].opacity(0.72))
                .frame(width: width * 0.46, height: height * 0.50)
                .offset(y: -height * 0.28)

            Circle()
                .fill(style.wash[0].opacity(0.92))
                .frame(width: width * 0.34, height: width * 0.34)
                .offset(x: width * 0.02, y: -height * 0.45)

            Capsule()
                .fill(style.wash[2].opacity(0.55))
                .frame(width: width * 0.64, height: height * 0.34)
                .offset(y: -height * 0.02)

            HStack(spacing: width * 0.08) {
                Circle().fill(style.ink.opacity(0.32)).frame(width: width * 0.035)
                Circle().fill(style.ink.opacity(0.32)).frame(width: width * 0.035)
            }
            .offset(x: width * 0.02, y: -height * 0.48)

            Capsule()
                .fill(style.accent.opacity(0.74))
                .frame(width: width * 0.18, height: height * 0.035)
                .offset(x: width * 0.02, y: -height * 0.39)
        }
    }

    private func goldenLandscapeScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(style.accent.opacity(0.86))
                .frame(width: width * 0.25, height: width * 0.25)
                .offset(x: width * 0.24, y: -height * 0.62)
            hill(color: style.swatches[1].opacity(0.76), width: width, height: height, lift: 0.20)
            hill(color: style.swatches[2].opacity(0.72), width: width, height: height, lift: 0.06)
            Rectangle()
                .fill(style.paper.opacity(0.18))
                .frame(height: height * 0.11)
        }
    }

    private func softPortraitScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(style.paper.opacity(0.20))
                    .frame(width: width * CGFloat(0.16 + Double(index) * 0.04))
                    .offset(
                        x: width * CGFloat([-0.31, 0.28, -0.10, 0.16][index]),
                        y: -height * CGFloat([0.62, 0.50, 0.28, 0.75][index])
                    )
            }
            Capsule()
                .fill(style.wash[2].opacity(0.48))
                .frame(width: width * 0.58, height: height * 0.28)
                .offset(y: -height * 0.03)
            Circle()
                .fill(style.wash[0].opacity(0.92))
                .frame(width: width * 0.36)
                .offset(y: -height * 0.42)
            Capsule()
                .fill(style.ink.opacity(0.38))
                .frame(width: width * 0.40, height: height * 0.24)
                .offset(y: -height * 0.50)
        }
    }

    private func monoStreetScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.paper.opacity(0.26))
            HStack(alignment: .bottom, spacing: width * 0.05) {
                building(width: width * 0.24, height: height * 0.68, windows: 3)
                building(width: width * 0.18, height: height * 0.54, windows: 2)
                building(width: width * 0.24, height: height * 0.78, windows: 4)
            }
            .opacity(0.82)
            .padding(.bottom, height * 0.22)
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: 2) ? style.paper.opacity(0.88) : style.ink.opacity(0.22))
                    .frame(width: width * 0.18, height: height * 0.08)
                    .rotationEffect(.degrees(-12))
                    .offset(x: width * CGFloat(Double(index) * 0.18 - 0.28), y: -height * 0.08)
            }
            person(width: width, height: height, color: style.ink.opacity(0.84))
                .offset(x: -width * 0.18, y: -height * 0.21)
        }
    }

    private func greenCityScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: width * 0.05) {
                building(width: width * 0.22, height: height * 0.72, windows: 3)
                building(width: width * 0.28, height: height * 0.56, windows: 2)
                building(width: width * 0.20, height: height * 0.80, windows: 4)
            }
            .padding(.bottom, height * 0.18)
            HStack(spacing: width * 0.09) {
                ForEach(0..<3, id: \.self) { _ in
                    tree(width: width, height: height)
                }
            }
            .padding(.bottom, height * 0.08)
        }
    }

    private func tungstenNightScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.ink.opacity(0.48))
            HStack(alignment: .bottom, spacing: width * 0.08) {
                building(width: width * 0.26, height: height * 0.78, windows: 4)
                building(width: width * 0.22, height: height * 0.58, windows: 3)
                building(width: width * 0.22, height: height * 0.86, windows: 4)
            }
            .padding(.bottom, height * 0.08)
            Circle()
                .fill(style.accent.opacity(0.74))
                .frame(width: width * 0.17)
                .blur(radius: 2)
                .offset(x: width * 0.22, y: -height * 0.52)
            Capsule()
                .fill(style.swatches[1].opacity(0.86))
                .frame(width: width * 0.08, height: height * 0.70)
                .offset(x: -width * 0.24, y: -height * 0.19)
        }
    }

    private func flashPartyScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(.white.opacity(0.82))
                .frame(width: width * 0.34)
                .blur(radius: 1.2)
                .offset(x: -width * 0.22, y: -height * 0.54)
            ForEach(0..<3, id: \.self) { index in
                person(
                    width: width,
                    height: height,
                    color: style.swatches[index].opacity(0.86)
                )
                .offset(
                    x: width * CGFloat([-0.24, 0.02, 0.25][index]),
                    y: -height * CGFloat([0.14, 0.20, 0.12][index])
                )
            }
            Rectangle()
                .fill(style.paper.opacity(0.15))
                .frame(height: height * 0.15)
        }
    }

    private func ccdCampusScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.paper.opacity(0.30))
            RoundedRectangle(cornerRadius: width * 0.03, style: .continuous)
                .fill(style.swatches[1].opacity(0.74))
                .frame(width: width * 0.70, height: height * 0.42)
                .overlay(alignment: .top) {
                    HStack(spacing: width * 0.07) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle().fill(.white.opacity(0.58)).frame(width: width * 0.055, height: height * 0.12)
                        }
                    }
                    .padding(.top, height * 0.08)
                }
                .offset(y: -height * 0.17)
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill((index.isMultiple(of: 2) ? style.accent : .white).opacity(0.72))
                    .frame(width: width * 0.06, height: width * 0.06)
                    .offset(
                        x: width * CGFloat(Double(index) * 0.16 - 0.32),
                        y: -height * CGFloat(0.68 - Double(index % 2) * 0.10)
                    )
            }
        }
    }

    private func instantHomeScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                .fill(style.paper.opacity(0.34))
                .frame(width: width * 0.60, height: height * 0.44)
                .offset(y: -height * 0.32)
            Rectangle()
                .fill(style.ink.opacity(0.24))
                .frame(height: height * 0.25)
            plant(width: width, height: height)
                .offset(x: -width * 0.22, y: -height * 0.18)
            cafeCup(width: width, height: height)
                .offset(x: width * 0.22, y: -height * 0.18)
        }
    }

    private func naturalLandscapeScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            hill(color: style.paper.opacity(0.52), width: width, height: height, lift: 0.26)
            hill(color: style.swatches[1].opacity(0.72), width: width, height: height, lift: 0.11)
            tree(width: width, height: height)
                .scaleEffect(1.18)
                .offset(x: width * 0.26, y: -height * 0.12)
        }
    }

    private func rangefinderRedScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.swatches[0].opacity(0.70))
            Rectangle()
                .fill(style.ink.opacity(0.26))
                .frame(height: height * 0.28)
            person(width: width, height: height, color: style.paper.opacity(0.78))
                .offset(x: -width * 0.18, y: -height * 0.16)
            RoundedRectangle(cornerRadius: width * 0.03, style: .continuous)
                .fill(style.paper.opacity(0.24))
                .frame(width: width * 0.36, height: height * 0.28)
                .offset(x: width * 0.20, y: -height * 0.48)
        }
    }

    private func compactTravelScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(style.accent.opacity(0.76))
                .frame(width: width * 0.22)
                .offset(x: width * 0.25, y: -height * 0.62)
            building(width: width * 0.34, height: height * 0.52, windows: 2)
                .offset(x: -width * 0.22, y: -height * 0.12)
            RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                .fill(style.ink.opacity(0.42))
                .frame(width: width * 0.30, height: height * 0.26)
                .offset(x: width * 0.18, y: -height * 0.10)
        }
    }

    private func grStreetScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.ink.opacity(0.42))
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(style.paper.opacity(0.72))
                    .frame(width: width * 0.15, height: height * 0.07)
                    .rotationEffect(.degrees(-18))
                    .offset(x: width * CGFloat(Double(index) * 0.16 - 0.32), y: -height * 0.11)
            }
            person(width: width, height: height, color: style.paper.opacity(0.76))
                .offset(x: width * 0.10, y: -height * 0.23)
            building(width: width * 0.22, height: height * 0.74, windows: 4)
                .offset(x: -width * 0.28, y: -height * 0.18)
        }
    }

    private func chromeCityScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: width * 0.04) {
                building(width: width * 0.22, height: height * 0.58, windows: 2)
                building(width: width * 0.28, height: height * 0.72, windows: 3)
                building(width: width * 0.18, height: height * 0.48, windows: 2)
            }
            .padding(.bottom, height * 0.16)
            Rectangle()
                .fill(style.paper.opacity(0.18))
                .frame(height: height * 0.18)
        }
    }

    private func mediumStudioScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                .fill(style.paper.opacity(0.26))
                .frame(width: width * 0.70, height: height * 0.66)
                .offset(y: -height * 0.18)
            Rectangle()
                .fill(style.ink.opacity(0.20))
                .frame(height: height * 0.22)
            Capsule()
                .fill(style.swatches[1].opacity(0.76))
                .frame(width: width * 0.20, height: height * 0.34)
                .offset(x: width * 0.16, y: -height * 0.20)
            Circle()
                .fill(style.accent.opacity(0.70))
                .frame(width: width * 0.18)
                .offset(x: -width * 0.18, y: -height * 0.25)
        }
    }

    private func holgaDreamScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(style.accent.opacity(0.52))
                .frame(width: width * 0.46)
                .blur(radius: 4)
                .offset(x: width * 0.24, y: -height * 0.55)
            hill(color: style.swatches[1].opacity(0.62), width: width, height: height, lift: 0.18)
            hill(color: style.swatches[2].opacity(0.58), width: width, height: height, lift: 0.03)
            RadialGradient(
                colors: [.clear, style.ink.opacity(0.62)],
                center: .center,
                startRadius: min(width, height) * 0.20,
                endRadius: max(width, height) * 0.66
            )
        }
    }

    private func lcaSunsetScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.swatches[0].opacity(0.80))
            Circle()
                .fill(style.accent.opacity(0.88))
                .frame(width: width * 0.28)
                .offset(x: -width * 0.20, y: -height * 0.52)
            hill(color: style.swatches[1].opacity(0.86), width: width, height: height, lift: 0.10)
            tree(width: width, height: height)
                .offset(x: width * 0.27, y: -height * 0.13)
        }
    }

    private func instantTableScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                .fill(style.paper.opacity(0.25))
                .frame(width: width * 0.72, height: height * 0.34)
                .offset(y: -height * 0.35)
            Rectangle()
                .fill(style.ink.opacity(0.22))
                .frame(height: height * 0.27)
            cafeCup(width: width, height: height)
                .offset(x: -width * 0.18, y: -height * 0.19)
            cafeCup(width: width, height: height)
                .scaleEffect(0.78)
                .offset(x: width * 0.19, y: -height * 0.18)
        }
    }

    private func sxFlowersScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(style.paper.opacity(0.22))
                .frame(height: height * 0.22)
            ForEach(0..<3, id: \.self) { index in
                flower(width: width, height: height, index: index)
                    .offset(x: width * CGFloat([-0.22, 0.02, 0.24][index]), y: -height * 0.10)
            }
        }
    }

    private func halfFrameDiaryScene(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.04) {
            goldenLandscapeScene(width: width * 0.48, height: height)
                .frame(width: width * 0.48, height: height)
                .clipped()
            humanCafeScene(width: width * 0.48, height: height)
                .frame(width: width * 0.48, height: height)
                .clipped()
        }
    }

    private func vividLandscapeScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.swatches[1].opacity(0.78))
            hill(color: style.swatches[2].opacity(0.60), width: width, height: height, lift: 0.08)
            RoundedRectangle(cornerRadius: width * 0.035, style: .continuous)
                .fill(style.swatches[0].opacity(0.92))
                .frame(width: width * 0.36, height: height * 0.16)
                .offset(x: width * 0.12, y: -height * 0.12)
            Circle()
                .fill(style.paper.opacity(0.72))
                .frame(width: width * 0.07)
                .offset(x: width * 0.00, y: -height * 0.08)
            Circle()
                .fill(style.paper.opacity(0.72))
                .frame(width: width * 0.07)
                .offset(x: width * 0.24, y: -height * 0.08)
        }
    }

    private func superiaBeachScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.swatches[1].opacity(0.70))
            Rectangle()
                .fill(style.paper.opacity(0.36))
                .frame(height: height * 0.32)
            Rectangle()
                .fill(style.swatches[0].opacity(0.38))
                .frame(height: height * 0.12)
                .offset(y: -height * 0.22)
            Capsule()
                .fill(style.accent.opacity(0.82))
                .frame(width: width * 0.30, height: height * 0.06)
                .rotationEffect(.degrees(-12))
                .offset(x: width * 0.20, y: -height * 0.32)
        }
    }

    private func noirWindowScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(style.ink.opacity(0.66))
            RoundedRectangle(cornerRadius: width * 0.02, style: .continuous)
                .fill(style.paper.opacity(0.58))
                .frame(width: width * 0.28, height: height * 0.62)
                .offset(x: -width * 0.22, y: -height * 0.22)
                .blur(radius: 0.8)
            person(width: width, height: height, color: .black.opacity(0.72))
                .offset(x: width * 0.10, y: -height * 0.18)
        }
    }

    private func sceneTone(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [.white.opacity(0.16), .clear, style.ink.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.clear, style.ink.opacity(scene == .shadowStreet || scene == .holgaDream ? 0.54 : 0.24)],
                center: .center,
                startRadius: min(width, height) * 0.34,
                endRadius: max(width, height) * 0.72
            )
        }
    }

    private func sceneGrain(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .fill(style.paper.opacity(index.isMultiple(of: 3) ? 0.15 : 0.08))
                    .frame(width: CGFloat(1 + sceneSeed(index, salt: 23) % 3))
                    .offset(
                        x: sceneOffset(index, salt: 41, length: width * 0.92),
                        y: sceneOffset(index, salt: 59, length: height * 0.92)
                    )
            }
        }
    }

    private func cafeCup(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: height * 0.015) {
            RoundedRectangle(cornerRadius: width * 0.035, style: .continuous)
                .fill(style.paper.opacity(0.82))
                .frame(width: width * 0.20, height: height * 0.12)
                .overlay(alignment: .trailing) {
                    Circle()
                        .stroke(style.paper.opacity(0.72), lineWidth: 1)
                        .frame(width: width * 0.07)
                        .offset(x: width * 0.045)
                }
            Capsule()
                .fill(style.ink.opacity(0.22))
                .frame(width: width * 0.25, height: height * 0.025)
        }
    }

    private func person(width: CGFloat, height: CGFloat, color: Color) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(color)
                .frame(width: width * 0.12, height: width * 0.12)
            Capsule()
                .fill(color.opacity(0.92))
                .frame(width: width * 0.16, height: height * 0.28)
        }
    }

    private func seatedPerson(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(style.wash[0].opacity(0.88))
                .frame(width: width * 0.15, height: width * 0.15)
            Capsule()
                .fill(style.swatches[1].opacity(0.82))
                .frame(width: width * 0.22, height: height * 0.24)
        }
    }

    private func plant(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: -width * 0.015) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(style.swatches[1].opacity(0.86))
                        .frame(width: width * 0.065, height: height * 0.18)
                        .rotationEffect(.degrees(Double(index - 1) * 22))
                }
            }
            RoundedRectangle(cornerRadius: width * 0.018, style: .continuous)
                .fill(style.ink.opacity(0.38))
                .frame(width: width * 0.16, height: height * 0.08)
        }
    }

    private func tree(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(style.swatches[1].opacity(0.82))
                .frame(width: width * 0.16)
            Rectangle()
                .fill(style.ink.opacity(0.34))
                .frame(width: width * 0.025, height: height * 0.16)
        }
    }

    private func building(width: CGFloat, height: CGFloat, windows: Int) -> some View {
        RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
            .fill(style.ink.opacity(0.42))
            .frame(width: width, height: height)
            .overlay {
                VStack(spacing: height * 0.08) {
                    ForEach(0..<windows, id: \.self) { index in
                        HStack(spacing: width * 0.16) {
                            Rectangle()
                                .fill((index.isMultiple(of: 2) ? style.accent : style.paper).opacity(0.42))
                                .frame(width: width * 0.18, height: height * 0.055)
                            Rectangle()
                                .fill(style.paper.opacity(0.28))
                                .frame(width: width * 0.18, height: height * 0.055)
                        }
                    }
                }
                .padding(.vertical, height * 0.14)
            }
    }

    private func hill(color: Color, width: CGFloat, height: CGFloat, lift: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: height * (0.74 - lift)))
            path.addCurve(
                to: CGPoint(x: width, y: height * (0.68 - lift * 0.50)),
                control1: CGPoint(x: width * 0.22, y: height * (0.48 - lift)),
                control2: CGPoint(x: width * 0.64, y: height * (0.86 - lift))
            )
            path.addLine(to: CGPoint(x: width, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.closeSubpath()
        }
        .fill(color)
    }

    private func flower(width: CGFloat, height: CGFloat, index: Int) -> some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(0..<4, id: \.self) { petal in
                    Circle()
                        .fill(style.wash[petal % style.wash.count].opacity(0.78))
                        .frame(width: width * 0.08)
                        .offset(
                            x: width * CGFloat([0.04, -0.04, 0.0, 0.0][petal]),
                            y: height * CGFloat([0.0, 0.0, 0.04, -0.04][petal])
                        )
                }
                Circle()
                    .fill(style.accent.opacity(0.90))
                    .frame(width: width * 0.055)
            }
            Rectangle()
                .fill(style.swatches[1].opacity(0.70))
                .frame(width: width * 0.018, height: height * CGFloat(0.20 + Double(index) * 0.03))
        }
    }

    private func sceneSeed(_ index: Int, salt: UInt64) -> Int {
        var value: UInt64 = 14_695_981_039_346_656_037 &+ salt
        for scalar in film.id.unicodeScalars {
            value ^= UInt64(scalar.value)
            value = value &* 1_099_511_628_211
        }
        value ^= UInt64(index + 1) &* 16_777_619
        return Int(value % 10_000)
    }

    private func sceneOffset(_ index: Int, salt: UInt64, length: CGFloat) -> CGFloat {
        let normalized = CGFloat(sceneSeed(index, salt: salt)) / 10_000.0
        return normalized * length - length / 2
    }
}

private enum FilmSampleSceneKind: Equatable {
    case humanCafe
    case shadowStreet
    case musePortrait
    case goldenLandscape
    case softPortrait
    case monoStreet
    case greenCity
    case tungstenNight
    case flashParty
    case ccdCampus
    case instantHome
    case naturalLandscape
    case rangefinderRed
    case compactTravel
    case grStreet
    case chromeCity
    case mediumStudio
    case holgaDream
    case lcaSunset
    case instantTable
    case sxFlowers
    case halfFrameDiary
    case vividLandscape
    case superiaBeach
    case noirWindow

    static func kind(for film: FilmPreset) -> FilmSampleSceneKind {
        switch film.id {
        case "human-warm-400":
            return .humanCafe
        case "human-vignette-800":
            return .shadowStreet
        case "muse-portrait-400":
            return .musePortrait
        case "sunlit-gold-200":
            return .goldenLandscape
        case "soft-portrait-400":
            return .softPortrait
        case "silver-hp5", "tri-x-street":
            return .monoStreet
        case "green-street-400":
            return .greenCity
        case "tungsten-800":
            return .tungstenNight
        case "pocket-flash":
            return .flashParty
        case "ccd-2003", "cyber-ccd-blue":
            return .ccdCampus
        case "instant-square":
            return .instantHome
        case "hncs-natural":
            return .naturalLandscape
        case "m-rangefinder":
            return .rangefinderRed
        case "t-compact-gold":
            return .compactTravel
        case "gr-street-snap":
            return .grStreet
        case "classic-chrome-x":
            return .chromeCity
        case "medium-500c":
            return .mediumStudio
        case "holga-120-dream":
            return .holgaDream
        case "lca-vivid":
            return .lcaSunset
        case "instant-wide":
            return .instantTable
        case "sx-fade":
            return .sxFlowers
        case "half-frame-diary":
            return .halfFrameDiary
        case "ektar-vivid-100":
            return .vividLandscape
        case "superia-green":
            return .superiaBeach
        case "noir-soft":
            return .noirWindow
        default:
            switch film.category {
            case .blackWhite:
                return .monoStreet
            case .portrait:
                return .softPortrait
            case .instant:
                return .instantHome
            case .digital:
                return .ccdCampus
            case .camera:
                return .compactTravel
            case .experimental:
                return .holgaDream
            case .negative:
                return .goldenLandscape
            case .featured:
                return .humanCafe
            case .favorites:
                return .goldenLandscape
            }
        }
    }
}

private struct FilmCoverStyle {
    let paper: Color
    let wash: [Color]
    let glowCenter: UnitPoint
    let ink: Color
    let accent: Color
    let swatches: [Color]
    let label: String
    let kind: FilmCoverKind
    let tilt: Double

    static func style(for film: FilmPreset) -> FilmCoverStyle {
        switch film.id {
        case "human-warm-400":
            return .init(paper: c(0.86, 0.77, 0.60), wash: [c(0.86, 0.64, 0.38), c(0.38, 0.44, 0.32), c(0.15, 0.13, 0.09)], glowCenter: .center, ink: c(0.15, 0.10, 0.06), accent: c(0.98, 0.60, 0.28), swatches: [c(0.96, 0.74, 0.45), c(0.55, 0.62, 0.44), c(0.23, 0.18, 0.12)], label: "WARM CN", kind: .filmStrip, tilt: -3)
        case "human-vignette-800":
            return .init(paper: c(0.22, 0.20, 0.16), wash: [c(0.47, 0.43, 0.32), c(0.17, 0.20, 0.16), c(0.04, 0.04, 0.035)], glowCenter: .center, ink: c(0.89, 0.78, 0.55), accent: c(0.77, 0.55, 0.28), swatches: [c(0.68, 0.58, 0.38), c(0.26, 0.30, 0.22), c(0.06, 0.06, 0.05)], label: "LOW KEY", kind: .darkroomCard, tilt: 6)
        case "muse-portrait-400":
            return .init(paper: c(0.89, 0.78, 0.73), wash: [c(0.96, 0.73, 0.65), c(0.76, 0.56, 0.52), c(0.48, 0.39, 0.41)], glowCenter: .top, ink: c(0.29, 0.15, 0.15), accent: c(0.98, 0.72, 0.68), swatches: [c(0.96, 0.68, 0.61), c(0.74, 0.58, 0.58), c(0.42, 0.35, 0.38)], label: "PORTRAIT", kind: .colorRecipe, tilt: 1)
        case "sunlit-gold-200":
            return .init(paper: c(0.88, 0.78, 0.52), wash: [c(0.96, 0.72, 0.32), c(0.61, 0.62, 0.36), c(0.27, 0.27, 0.15)], glowCenter: .topLeading, ink: c(0.20, 0.13, 0.04), accent: c(1.00, 0.82, 0.36), swatches: [c(0.99, 0.78, 0.34), c(0.72, 0.67, 0.35), c(0.33, 0.30, 0.14)], label: "GOLDEN HR", kind: .contactSheet, tilt: -2)
        case "soft-portrait-400":
            return .init(paper: c(0.84, 0.75, 0.67), wash: [c(0.84, 0.66, 0.55), c(0.61, 0.65, 0.61), c(0.38, 0.38, 0.35)], glowCenter: .top, ink: c(0.23, 0.17, 0.14), accent: c(0.96, 0.76, 0.62), swatches: [c(0.90, 0.69, 0.58), c(0.65, 0.69, 0.63), c(0.43, 0.40, 0.36)], label: "SKIN SOFT", kind: .instantFrame, tilt: 0)
        case "silver-hp5":
            return .init(paper: c(0.82, 0.80, 0.74), wash: [c(0.80, 0.78, 0.72), c(0.43, 0.43, 0.40), c(0.15, 0.15, 0.14)], glowCenter: .center, ink: c(0.07, 0.07, 0.07), accent: c(0.90, 0.88, 0.80), swatches: [c(0.91, 0.90, 0.84), c(0.55, 0.55, 0.52), c(0.12, 0.12, 0.11)], label: "SILVER", kind: .negativeSleeve, tilt: 0)
        case "green-street-400":
            return .init(paper: c(0.70, 0.75, 0.58), wash: [c(0.62, 0.68, 0.50), c(0.27, 0.47, 0.41), c(0.09, 0.16, 0.14)], glowCenter: .bottomLeading, ink: c(0.06, 0.17, 0.12), accent: c(0.72, 0.86, 0.58), swatches: [c(0.68, 0.73, 0.48), c(0.25, 0.55, 0.39), c(0.08, 0.20, 0.14)], label: "STREET GN", kind: .filmStrip, tilt: 3)
        case "tungsten-800":
            return .init(paper: c(0.19, 0.20, 0.30), wash: [c(0.21, 0.25, 0.44), c(0.62, 0.30, 0.21), c(0.07, 0.06, 0.11)], glowCenter: .trailing, ink: c(0.94, 0.60, 0.38), accent: c(1.00, 0.34, 0.16), swatches: [c(0.18, 0.28, 0.58), c(0.84, 0.38, 0.18), c(0.09, 0.07, 0.15)], label: "TUNGSTEN", kind: .darkroomCard, tilt: -8)
        case "pocket-flash":
            return .init(paper: c(0.91, 0.64, 0.34), wash: [c(0.98, 0.71, 0.30), c(0.72, 0.23, 0.20), c(0.12, 0.09, 0.07)], glowCenter: .topLeading, ink: c(0.24, 0.09, 0.05), accent: c(1.00, 0.92, 0.64), swatches: [c(1.00, 0.82, 0.35), c(0.82, 0.24, 0.17), c(0.18, 0.10, 0.07)], label: "FLASH", kind: .contactSheet, tilt: 2)
        case "ccd-2003":
            return .init(paper: c(0.72, 0.84, 0.88), wash: [c(0.74, 0.87, 0.91), c(0.39, 0.55, 0.69), c(0.15, 0.19, 0.27)], glowCenter: .topTrailing, ink: c(0.04, 0.15, 0.23), accent: c(0.78, 0.94, 1.00), swatches: [c(0.66, 0.91, 1.00), c(0.37, 0.57, 0.79), c(0.15, 0.23, 0.34)], label: "DIGITAL", kind: .colorRecipe, tilt: 0)
        case "instant-square":
            return .init(paper: c(0.93, 0.86, 0.70), wash: [c(0.93, 0.85, 0.69), c(0.61, 0.51, 0.41), c(0.30, 0.25, 0.21)], glowCenter: .center, ink: c(0.27, 0.21, 0.14), accent: c(1.00, 0.91, 0.72), swatches: [c(0.88, 0.76, 0.55), c(0.62, 0.51, 0.40), c(0.32, 0.26, 0.21)], label: "SX SQUARE", kind: .instantFrame, tilt: 0)
        case "hncs-natural":
            return .init(paper: c(0.82, 0.80, 0.68), wash: [c(0.79, 0.78, 0.68), c(0.51, 0.59, 0.54), c(0.25, 0.28, 0.24)], glowCenter: .center, ink: c(0.17, 0.17, 0.13), accent: c(0.93, 0.89, 0.74), swatches: [c(0.82, 0.78, 0.63), c(0.55, 0.63, 0.55), c(0.30, 0.32, 0.26)], label: "NATURAL", kind: .colorRecipe, tilt: 0)
        case "m-rangefinder":
            return .init(paper: c(0.59, 0.22, 0.18), wash: [c(0.67, 0.17, 0.13), c(0.40, 0.37, 0.29), c(0.07, 0.07, 0.06)], glowCenter: .leading, ink: c(0.97, 0.77, 0.55), accent: c(0.94, 0.50, 0.34), swatches: [c(0.76, 0.18, 0.13), c(0.45, 0.40, 0.28), c(0.10, 0.08, 0.06)], label: "RANGE", kind: .negativeSleeve, tilt: 0)
        case "t-compact-gold":
            return .init(paper: c(0.89, 0.68, 0.38), wash: [c(0.94, 0.72, 0.35), c(0.73, 0.43, 0.26), c(0.19, 0.15, 0.11)], glowCenter: .top, ink: c(0.20, 0.11, 0.04), accent: c(1.00, 0.83, 0.43), swatches: [c(0.97, 0.74, 0.33), c(0.78, 0.46, 0.25), c(0.26, 0.16, 0.09)], label: "COMPACT", kind: .filmStrip, tilt: -2)
        case "gr-street-snap":
            return .init(paper: c(0.70, 0.73, 0.70), wash: [c(0.72, 0.75, 0.71), c(0.33, 0.38, 0.39), c(0.045, 0.055, 0.065)], glowCenter: .bottom, ink: c(0.09, 0.13, 0.13), accent: c(0.82, 0.90, 0.88), swatches: [c(0.76, 0.80, 0.75), c(0.39, 0.45, 0.45), c(0.06, 0.07, 0.08)], label: "SNAP", kind: .contactSheet, tilt: 1)
        case "classic-chrome-x":
            return .init(paper: c(0.65, 0.68, 0.62), wash: [c(0.62, 0.67, 0.63), c(0.42, 0.48, 0.49), c(0.21, 0.23, 0.21)], glowCenter: .topLeading, ink: c(0.13, 0.15, 0.13), accent: c(0.76, 0.79, 0.66), swatches: [c(0.68, 0.72, 0.64), c(0.45, 0.51, 0.51), c(0.23, 0.25, 0.22)], label: "CHROME X", kind: .colorRecipe, tilt: 0)
        case "medium-500c":
            return .init(paper: c(0.82, 0.74, 0.61), wash: [c(0.81, 0.73, 0.60), c(0.55, 0.52, 0.44), c(0.23, 0.22, 0.19)], glowCenter: .center, ink: c(0.17, 0.14, 0.09), accent: c(0.93, 0.82, 0.61), swatches: [c(0.84, 0.72, 0.53), c(0.58, 0.55, 0.45), c(0.26, 0.24, 0.19)], label: "MEDIUM", kind: .halfFrame, tilt: 0)
        case "holga-120-dream":
            return .init(paper: c(0.77, 0.58, 0.48), wash: [c(0.86, 0.62, 0.42), c(0.44, 0.38, 0.47), c(0.09, 0.07, 0.11)], glowCenter: .topTrailing, ink: c(0.21, 0.09, 0.11), accent: c(1.00, 0.36, 0.18), swatches: [c(0.94, 0.58, 0.33), c(0.50, 0.40, 0.56), c(0.12, 0.08, 0.14)], label: "DREAM", kind: .darkroomCard, tilt: 10)
        case "lca-vivid":
            return .init(paper: c(0.82, 0.42, 0.28), wash: [c(0.98, 0.41, 0.19), c(0.17, 0.53, 0.42), c(0.07, 0.06, 0.09)], glowCenter: .bottomLeading, ink: c(0.08, 0.06, 0.05), accent: c(1.00, 0.76, 0.28), swatches: [c(1.00, 0.34, 0.16), c(0.10, 0.62, 0.44), c(0.08, 0.07, 0.11)], label: "VIVID LC", kind: .filmStrip, tilt: 5)
        case "instant-wide":
            return .init(paper: c(0.92, 0.84, 0.66), wash: [c(0.92, 0.83, 0.65), c(0.68, 0.57, 0.46), c(0.29, 0.26, 0.23)], glowCenter: .center, ink: c(0.26, 0.20, 0.13), accent: c(1.00, 0.89, 0.70), swatches: [c(0.86, 0.73, 0.51), c(0.68, 0.56, 0.44), c(0.30, 0.27, 0.23)], label: "WIDE PN", kind: .instantFrame, tilt: 0)
        case "sx-fade":
            return .init(paper: c(0.90, 0.78, 0.70), wash: [c(0.91, 0.75, 0.66), c(0.71, 0.67, 0.61), c(0.47, 0.44, 0.43)], glowCenter: .top, ink: c(0.35, 0.24, 0.19), accent: c(1.00, 0.70, 0.62), swatches: [c(0.95, 0.73, 0.64), c(0.75, 0.69, 0.60), c(0.50, 0.45, 0.42)], label: "FADE SX", kind: .colorRecipe, tilt: 0)
        case "half-frame-diary":
            return .init(paper: c(0.84, 0.71, 0.50), wash: [c(0.85, 0.69, 0.44), c(0.44, 0.56, 0.47), c(0.21, 0.19, 0.15)], glowCenter: .topLeading, ink: c(0.19, 0.13, 0.05), accent: c(1.00, 0.77, 0.40), swatches: [c(0.90, 0.69, 0.39), c(0.47, 0.61, 0.48), c(0.25, 0.21, 0.15)], label: "DIARY HF", kind: .halfFrame, tilt: -3)
        case "ektar-vivid-100":
            return .init(paper: c(0.78, 0.34, 0.24), wash: [c(0.95, 0.23, 0.15), c(0.17, 0.47, 0.73), c(0.11, 0.19, 0.23)], glowCenter: .topLeading, ink: c(0.06, 0.07, 0.08), accent: c(1.00, 0.75, 0.27), swatches: [c(1.00, 0.22, 0.12), c(0.12, 0.54, 0.88), c(0.12, 0.22, 0.25)], label: "SAT C41", kind: .contactSheet, tilt: -1)
        case "tri-x-street":
            return .init(paper: c(0.88, 0.87, 0.82), wash: [c(0.91, 0.90, 0.85), c(0.51, 0.51, 0.48), c(0.07, 0.07, 0.07)], glowCenter: .top, ink: c(0.045, 0.045, 0.045), accent: c(0.97, 0.95, 0.87), swatches: [c(0.94, 0.93, 0.88), c(0.54, 0.54, 0.51), c(0.08, 0.08, 0.08)], label: "TRI STREET", kind: .negativeSleeve, tilt: 0)
        case "cyber-ccd-blue":
            return .init(paper: c(0.45, 0.70, 0.88), wash: [c(0.61, 0.89, 1.00), c(0.20, 0.39, 0.79), c(0.06, 0.08, 0.17)], glowCenter: .topTrailing, ink: c(0.025, 0.09, 0.25), accent: c(0.50, 0.91, 1.00), swatches: [c(0.58, 0.93, 1.00), c(0.18, 0.43, 0.92), c(0.06, 0.10, 0.22)], label: "BLUE CCD", kind: .darkroomCard, tilt: 7)
        case "superia-green":
            return .init(paper: c(0.74, 0.76, 0.42), wash: [c(0.79, 0.77, 0.36), c(0.21, 0.56, 0.35), c(0.08, 0.17, 0.11)], glowCenter: .topLeading, ink: c(0.06, 0.16, 0.07), accent: c(0.92, 0.88, 0.40), swatches: [c(0.84, 0.80, 0.34), c(0.20, 0.62, 0.36), c(0.08, 0.21, 0.11)], label: "GREEN CN", kind: .filmStrip, tilt: -5)
        case "noir-soft":
            return .init(paper: c(0.76, 0.74, 0.68), wash: [c(0.75, 0.73, 0.67), c(0.35, 0.34, 0.33), c(0.035, 0.035, 0.04)], glowCenter: .center, ink: c(0.07, 0.07, 0.07), accent: c(0.87, 0.84, 0.76), swatches: [c(0.80, 0.78, 0.71), c(0.39, 0.38, 0.36), c(0.05, 0.05, 0.05)], label: "NOIR SOFT", kind: .instantFrame, tilt: 0)
        default:
            return .init(paper: c(0.84, 0.71, 0.50), wash: [c(0.91, 0.66, 0.29), c(0.52, 0.60, 0.43), c(0.17, 0.17, 0.13)], glowCenter: .center, ink: c(0.17, 0.11, 0.04), accent: c(1.00, 0.79, 0.44), swatches: [c(0.94, 0.68, 0.30), c(0.54, 0.64, 0.42), c(0.20, 0.18, 0.13)], label: "STILL", kind: .contactSheet, tilt: 0)
        }
    }

    private static func c(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }
}

private enum FilmCoverKind {
    case filmStrip
    case contactSheet
    case darkroomCard
    case colorRecipe
    case instantFrame
    case halfFrame
    case negativeSleeve
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? StillLightTheme.background : StillLightTheme.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(isSelected ? StillLightTheme.accent : StillLightTheme.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
