import SwiftUI
import UIKit

struct FilmPickerSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: FilmCategory?
    @State private var focusedFilmId: String?
    @State private var loadingFilmId: String?

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

                        CameraLibraryGrid(
                            films: filteredPresets,
                            focusedFilmId: focusedFilm.id,
                            selectedFilmId: appState.selectedFilm.id,
                            favoriteIds: appState.favoriteFilmIds,
                            language: appState.language,
                            enableHaptics: appState.enableHaptics
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
                            showsActions: false,
                            favoriteAction: {
                                appState.toggleFavorite(focusedFilm)
                            },
                            loadAction: { loadFilm(focusedFilm) }
                        )
                    }
                }
                .padding(18)
                .padding(.bottom, 78)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let focusedFilm {
                FilmPickerActionBar(
                    film: focusedFilm,
                    isLoaded: focusedFilm.id == appState.selectedFilm.id,
                    isFavorite: appState.isFavorite(focusedFilm),
                    isLoading: loadingFilmId == focusedFilm.id,
                    language: appState.language,
                    favoriteAction: { appState.toggleFavorite(focusedFilm) },
                    loadAction: { loadFilm(focusedFilm) }
                )
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
                    count: appState.filmLibrary.presets.count,
                    iconName: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(FilmCategory.allCases) { category in
                    CategoryChip(
                        title: category.title(language: appState.language),
                        count: appState.filmLibrary.presets(matching: category, favoriteIds: appState.favoriteFilmIds).count,
                        iconName: category.drawerIconName,
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

    private func loadFilm(_ film: FilmPreset) {
        guard loadingFilmId == nil else { return }
        if film.id == appState.selectedFilm.id {
            dismiss()
            return
        }

        loadingFilmId = film.id
        appState.selectFilm(film)
        if appState.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            guard loadingFilmId == film.id else { return }
            dismiss()
        }
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

            FilmSampleSceneView(film: film, style: style, sampleRole: .blur)
                .scaleEffect(1.18)
                .blur(radius: 10)
                .opacity(0.22)
                .saturation(0.82)
                .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    StillLightTheme.background.opacity(0.44),
                    StillLightTheme.panel.opacity(0.30),
                    StillLightTheme.background.opacity(0.70)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            shelfGlow
            heroStage

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isLoaded ? loadedText : drawerText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(0.9)
                            .foregroundStyle(style.accent.opacity(0.86))
                        Text(film.displayCameraName(language: language))
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

                Text(film.displayName(language: language))
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
        language == .chinese ? "相机库" : "CAMERA LIBRARY"
    }
}

private struct CameraLibraryGrid: View {
    let films: [FilmPreset]
    let focusedFilmId: String
    let selectedFilmId: String
    let favoriteIds: Set<String>
    let language: AppLanguage
    let enableHaptics: Bool
    let focusAction: (FilmPreset) -> Void

    private let rows = [
        GridItem(.fixed(154), spacing: 12, alignment: .top),
        GridItem(.fixed(154), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(language == .chinese ? "相机墙" : "Camera Wall")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(StillLightTheme.secondaryText.opacity(0.72))

                Rectangle()
                    .fill(StillLightTheme.secondaryText.opacity(0.14))
                    .frame(height: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, alignment: .top, spacing: 12) {
                    ForEach(films) { film in
                        CameraLibraryTile(
                            film: film,
                            isFocused: film.id == focusedFilmId,
                            isLoaded: film.id == selectedFilmId,
                            isFavorite: favoriteIds.contains(film.id),
                            language: language
                        ) {
                            if enableHaptics {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                focusAction(film)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .frame(height: 320)
        }
    }
}

private struct CameraLibraryTile: View {
    let film: FilmPreset
    let isFocused: Bool
    let isLoaded: Bool
    let isFavorite: Bool
    let language: AppLanguage
    let action: () -> Void

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    private var profile: FilmCameraProfile {
        film.cameraProfile
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    FilmSampleSceneView(film: film, style: style, sampleRole: .thumb)
                        .opacity(0.90)
                        .overlay {
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.10),
                                    style.ink.opacity(0.34),
                                    .black.opacity(0.62)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        .overlay(alignment: .bottomLeading) {
                            Rectangle()
                                .fill(style.accent.opacity(0.82))
                                .frame(width: 42, height: 3)
                                .padding(8)
                        }

                    CameraModelPlate(film: film)
                        .frame(height: 74)
                        .padding(.horizontal, 8)
                        .padding(.top, 15)
                        .padding(.bottom, 4)

                    if isLoaded {
                        LoadedTab(language: language)
                            .padding(7)
                    } else if isFavorite {
                        FavoritePin()
                            .padding(7)
                    }
                }
                .frame(width: 132, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isFocused ? style.accent.opacity(0.92) : .white.opacity(0.08), lineWidth: isFocused ? 1.4 : 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(style.accent)
                            .frame(width: 4, height: 14)
                        Text(profile.displayName(language: language))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(StillLightTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    Text(profile.displayLensAndEra(language: language))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(StillLightTheme.secondaryText.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    HStack(spacing: 4) {
                        CameraCapabilityPill(text: profile.category.title(language: language), style: style)
                        if let firstCapability = profile.accessoryLabels(language: language).first {
                            CameraCapabilityPill(text: firstCapability, style: style)
                        }
                    }
                }
                .frame(width: 132, alignment: .leading)
            }
            .padding(8)
            .frame(width: 148, height: 154, alignment: .top)
            .background(isFocused ? StillLightTheme.panelElevated.opacity(0.80) : StillLightTheme.panel.opacity(0.48))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isFocused ? style.accent.opacity(0.58) : .white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile.displayName(language: language))
    }
}

private struct CameraCapabilityPill: View {
    let text: String
    let style: FilmCoverStyle

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .foregroundStyle(StillLightTheme.background.opacity(0.88))
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(style.accent.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct FilmObjectShelf: View {
    let films: [FilmPreset]
    let focusedFilmId: String
    let selectedFilmId: String
    let favoriteIds: Set<String>
    let language: AppLanguage
    let enableHaptics: Bool
    let focusAction: (FilmPreset) -> Void
    @State private var centeredFilmId: FilmPreset.ID?
    @State private var selectionFeedback = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(language == .chinese ? "选择相机" : "Choose a camera")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(StillLightTheme.secondaryText.opacity(0.72))

                Rectangle()
                    .fill(StillLightTheme.secondaryText.opacity(0.14))
                    .frame(height: 1)
            }

            GeometryReader { proxy in
                let sideInset = max((proxy.size.width - 124) / 2, 8)

                ZStack(alignment: .bottom) {
                    shelfSurface
                    shelfBackRail

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .bottom, spacing: 16) {
                            ForEach(films) { film in
                                objectCard(for: film)
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 14)
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, sideInset, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $centeredFilmId, anchor: .center)
                }
            }
            .frame(height: 206)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .onAppear {
            centeredFilmId = focusedFilmId
            selectionFeedback.prepare()
        }
        .onChange(of: focusedFilmId) { _, newValue in
            guard centeredFilmId != newValue else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                centeredFilmId = newValue
            }
        }
        .onChange(of: centeredFilmId) { _, newValue in
            guard let newValue,
                  newValue != focusedFilmId,
                  let film = films.first(where: { $0.id == newValue })
            else {
                return
            }
            if enableHaptics {
                selectionFeedback.selectionChanged()
                selectionFeedback.prepare()
            }
            focusAction(film)
        }
    }

    private func objectCard(for film: FilmPreset) -> some View {
        FilmObjectCard(
            film: film,
            isFocused: film.id == focusedFilmId,
            isLoaded: film.id == selectedFilmId,
            isFavorite: favoriteIds.contains(film.id),
            language: language
        ) {
            focusAction(film)
            centeredFilmId = film.id
        }
        .id(film.id)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.90)
                .opacity(phase.isIdentity ? 1.0 : 0.70)
                .offset(y: phase.isIdentity ? 0 : 12)
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
                        CameraModelPlate(film: film)
                            .frame(width: isFocused ? 118 : 105, height: isFocused ? 92 : 82)
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

                Text(film.displayCameraName(language: language))
                    .font(.system(size: 12, weight: isFocused ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isFocused ? StillLightTheme.text : StillLightTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
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
        .accessibilityLabel(film.displayCameraName(language: language))
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
    let showsActions: Bool
    let favoriteAction: () -> Void
    let loadAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(film.displayCameraName(language: language))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(StillLightTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(film.displayName(language: language))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(style.accent.opacity(0.86))
                        .lineLimit(1)
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
            FilmProcessPassport(film: film, language: language, style: style)

            if showsActions {
                HStack(spacing: 10) {
                    Button(action: favoriteAction) {
                        HStack(spacing: 7) {
                            Image(systemName: isFavorite ? "pin.fill" : "pin")
                                .font(.system(size: 12, weight: .bold))
                            Text(isFavorite ? favoriteOnText : favoriteOffText)
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isFavorite ? StillLightTheme.background : StillLightTheme.text)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(isFavorite ? style.accent : StillLightTheme.panelElevated.opacity(0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: loadAction) {
                        HStack(spacing: 7) {
                            Image(systemName: isLoaded ? "camera.viewfinder" : "arrow.down.to.line.compact")
                                .font(.system(size: 12, weight: .bold))
                            Text(loadButtonText)
                        }
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
        }
        .padding(14)
        .background(StillLightTheme.panel.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var sceneTags: some View {
        HStack(spacing: 7) {
            Label(film.category.title(language: language), systemImage: film.category.drawerIconName)
            Text(primaryScene)
            Text(language == .chinese ? "\(film.defaultShotCount) 张" : "\(film.defaultShotCount) EXP")
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(StillLightTheme.secondaryText.opacity(0.86))
        .lineLimit(1)
        .minimumScaleFactor(0.70)
    }

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    private var primaryScene: String {
        let scenes = language == .chinese && !film.localizedSuitableScenes.isEmpty
            ? film.localizedSuitableScenes
            : film.suitableScenes
        return scenes.first ?? (language == .chinese ? "日常" : "Daily")
    }

    private var exposureText: String {
        String(format: "%+.1f EV", film.exposureBias)
    }

    private var loadButtonText: String {
        if isLoaded {
            return language == .chinese ? "继续拍" : "Keep Shooting"
        }
        return language == .chinese ? "使用相机" : "Use Camera"
    }

    private var favoriteOnText: String {
        language == .chinese ? "已收藏" : "Pinned"
    }

    private var favoriteOffText: String {
        language == .chinese ? "收藏" : "Pin"
    }

}

private struct FilmPickerActionBar: View {
    let film: FilmPreset
    let isLoaded: Bool
    let isFavorite: Bool
    let isLoading: Bool
    let language: AppLanguage
    let favoriteAction: () -> Void
    let loadAction: () -> Void

    private var style: FilmCoverStyle {
        FilmCoverStyle.style(for: film)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: favoriteAction) {
                Image(systemName: isFavorite ? "pin.fill" : "pin")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isFavorite ? StillLightTheme.background : StillLightTheme.text)
                    .frame(width: 48, height: 48)
                    .background(isFavorite ? style.accent : StillLightTheme.panelElevated.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? favoriteOnText : favoriteOffText)

            VStack(alignment: .leading, spacing: 2) {
                Text(film.displayCameraName(language: language))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(StillLightTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Text(actionBarSubtitle)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(StillLightTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: loadAction) {
                HStack(spacing: 7) {
                    if isLoading {
                        ProgressView()
                            .tint(StillLightTheme.background)
                            .scaleEffect(0.72)
                    } else {
                        Image(systemName: isLoaded ? "camera.viewfinder" : "arrow.down.to.line.compact")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(loadButtonText)
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(StillLightTheme.background)
                .padding(.horizontal, 15)
                .frame(height: 48)
                .background(StillLightTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var loadButtonText: String {
        if isLoading {
            return language == .chinese ? "启用中" : "Loading"
        }
        if isLoaded {
            return language == .chinese ? "继续拍" : "Keep Shooting"
        }
        return language == .chinese ? "使用" : "Use"
    }

    private var actionBarSubtitle: String {
        if language == .chinese {
            return "ISO \(film.iso) / \(film.defaultShotCount) 张"
        }
        return "ISO \(film.iso) / \(film.defaultShotCount) EXP"
    }

    private var favoriteOnText: String {
        language == .chinese ? "已收藏" : "Pinned"
    }

    private var favoriteOffText: String {
        language == .chinese ? "收藏" : "Pin"
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
            HStack(spacing: 4) {
                ForEach(Array(FilmSamplePhotoFrame.sequence(for: film).enumerated()), id: \.offset) { index, frame in
                    FilmSampleSceneView(film: film, style: style, photoFrame: frame)
                        .frame(width: index == 0 ? 42 : 25, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                }
            }
            .frame(width: 100, alignment: .leading)

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

private struct FilmProcessPassport: View {
    let film: FilmPreset
    let language: AppLanguage
    let style: FilmCoverStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Circle()
                    .fill(style.accent.opacity(0.92))
                    .frame(width: 7, height: 7)
                Text(language == .chinese ? "冲扫标签" : "DARKROOM TAG")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(style.ink.opacity(0.72))
                Spacer()
                Text(batchCode)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(style.ink.opacity(0.45))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 2), spacing: 7) {
                FilmPassportStamp(title: "ISO", value: "\(film.iso)", style: style)
                FilmPassportStamp(title: language == .chinese ? "颗粒" : "GRAIN", value: grainLabel, style: style)
                FilmPassportStamp(title: "WB", value: temperatureLabel, style: style)
                FilmPassportStamp(title: "EV", value: exposureLabel, style: style)
            }
        }
        .padding(11)
        .background(
            LinearGradient(
                colors: [
                    style.paper.opacity(0.82),
                    style.wash[0].opacity(0.18),
                    style.paper.opacity(0.70)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(style.ink.opacity(0.10), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(style.accent.opacity(0.36))
                .frame(width: 42, height: 8)
                .rotationEffect(.degrees(3))
                .offset(x: -14, y: -3)
        }
    }

    private var grainLabel: String {
        switch film.grainAmount {
        case ..<0.12:
            return language == .chinese ? "细" : "FINE"
        case ..<0.28:
            return language == .chinese ? "中" : "MID"
        default:
            return language == .chinese ? "粗" : "COARSE"
        }
    }

    private var temperatureLabel: String {
        if abs(film.temperatureShift) < 10 {
            return "0K"
        }
        return String(format: "%+.0fK", film.temperatureShift)
    }

    private var exposureLabel: String {
        String(format: "%+.1f", film.exposureBias)
    }

    private var batchCode: String {
        let checksum = film.id.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult * 31 + Int(scalar.value)) % 900
        }
        let suffix = checksum + 100
        return "SL-\(suffix)"
    }
}

private struct FilmPassportStamp: View {
    let title: String
    let value: String
    let style: FilmCoverStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(style.ink.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(style.ink.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(style.ink.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(style.ink.opacity(0.08), lineWidth: 1)
        }
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
        let frames = FilmSamplePhotoFrame.sequence(for: film)
        return VStack(spacing: height * 0.035) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: width * 0.035) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        RoundedRectangle(cornerRadius: width * 0.02, style: .continuous)
                            .fill(style.ink.opacity(0.62))
                            .overlay {
                                FilmSampleSceneView(
                                    film: film,
                                    style: style,
                                    photoFrame: frames[index % frames.count],
                                    sampleRole: .micro
                                )
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
        let frames = FilmSamplePhotoFrame.sequence(for: film)
        return HStack(spacing: width * 0.03) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: width * 0.018, style: .continuous)
                    .fill(style.swatches[index % style.swatches.count].opacity(0.72))
                    .overlay {
                        FilmSampleSceneView(
                            film: film,
                            style: style,
                            photoFrame: frames[index % frames.count],
                            sampleRole: .micro
                        )
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

            FilmIdentityArtworkView(film: film, style: style)
                .padding(size.width * 0.055)
                .opacity(isHeroScale ? 0.92 : 0.86)
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
            .background(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(style.paper.opacity(0.30))
                    .blur(radius: 0.6)
                    .padding(.leading, size.width * 0.08)
                    .padding(.trailing, size.width * 0.20)
                    .padding(.top, size.height * 0.08)
                    .padding(.bottom, size.height * 0.50)
            }

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
    case slr
    case medium
    case compact
    case ccd
    case instant
    case toy
    case cinema

    static func kind(for film: FilmPreset) -> CameraPlateKind {
        switch film.cameraProfile.bodyStyle {
        case .hSystemBack, .waistLevelMedium:
            return .medium
        case .earlyCCDCard, .blueCCDCard:
            return .ccd
        case .squareInstantBox, .wideInstantPlastic, .foldingInstant:
            return .instant
        case .disposableFlashShell, .plasticToy120:
            return .toy
        case .blackPocketCompact, .daylightPointAndShoot, .lomoCompact, .halfFrameDiary:
            return .compact
        case .leatheretteSLR, .studioPortraitSLR:
            return .slr
        case .tungstenCinemaRig, .noirCinemaBody:
            return .cinema
        case .brassRangefinder:
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

    private var bodyStyle: CameraBodyStyle {
        film.cameraProfile.bodyStyle
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                switch kind {
                case .rangefinder:
                    rangefinder(width: width, height: height)
                case .slr:
                    slrCamera(width: width, height: height)
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
                case .cinema:
                    cinemaCamera(width: width, height: height)
                }
            }
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
        }
    }

    private func cameraShell(width: CGFloat, height: CGFloat, radius: CGFloat = 12, colors: [Color]? = nil) -> some View {
        let shellColors = colors ?? [
            style.ink.opacity(0.92),
            style.ink.opacity(0.72),
            style.ink.opacity(0.54)
        ]

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: shellColors,
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

    private func shutterButton(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(style.accent.opacity(0.78))
            .frame(width: width * 0.13, height: height * 0.045)
            .overlay {
                Capsule()
                    .fill(.white.opacity(0.20))
                    .padding(.horizontal, width * 0.025)
                    .padding(.vertical, height * 0.010)
            }
    }

    private func screw(size: CGFloat) -> some View {
        Circle()
            .fill(style.paper.opacity(0.48))
            .frame(width: size, height: size)
            .overlay {
                Rectangle()
                    .fill(style.ink.opacity(0.34))
                    .frame(width: size * 0.56, height: 1)
            }
    }

    private func flashWindow(width: CGFloat, height: CGFloat, color: Color? = nil) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        (color ?? style.paper).opacity(0.86),
                        style.accent.opacity(0.46),
                        style.ink.opacity(0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width * 0.20, height: height * 0.15)
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
                    .padding(2)
            }
    }

    private func gripRidges(width: CGFloat, height: CGFloat, count: Int = 4) -> some View {
        VStack(spacing: height * 0.035) {
            ForEach(0..<count, id: \.self) { _ in
                Capsule()
                    .fill(style.paper.opacity(0.18))
                    .frame(width: width * 0.10, height: 1)
            }
        }
    }

    private func leatherette(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(style.ink.opacity(0.42))
            .frame(width: width * 0.68, height: height * 0.28)
            .overlay {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(style.paper.opacity(0.07))
                        .frame(height: 1)
                        .offset(y: height * CGFloat(index - 2) * 0.035)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(style.paper.opacity(0.11), lineWidth: 1)
            }
    }

    private func modelSticker(_ text: String, width: CGFloat, height: CGFloat) -> some View {
        Text(text)
            .font(.system(size: Swift.max(5, width * 0.052), weight: .black, design: .monospaced))
            .tracking(0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(style.ink.opacity(0.76))
            .padding(.horizontal, width * 0.035)
            .frame(height: height * 0.11)
            .background(style.paper.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(style.ink.opacity(0.12), lineWidth: 1)
            }
    }

    private func rangefinder(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            cameraShell(
                width: width,
                height: height,
                radius: 10,
                colors: [
                    style.paper.opacity(0.88),
                    style.swatches[1].opacity(0.66),
                    style.ink.opacity(0.78)
                ]
            )

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(style.ink.opacity(0.44))
                .frame(height: height * 0.31)
                .padding(.horizontal, width * 0.09)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .overlay {
                    HStack(spacing: width * 0.04) {
                        screw(size: height * 0.045)
                        Spacer()
                        screw(size: height * 0.045)
                    }
                    .padding(.horizontal, width * 0.14)
                    .offset(y: height * 0.25)
                }

            HStack {
                viewfinder(width: width, height: height)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(style.paper.opacity(0.62))
                    .frame(width: width * 0.10, height: height * 0.11)
                    .overlay {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(style.ink.opacity(0.34))
                            .padding(2)
                    }
                Spacer()
                shutterButton(width: width, height: height)
            }
            .padding(.horizontal, width * 0.09)
            .padding(.top, height * 0.14)
            .frame(maxHeight: .infinity, alignment: .top)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(style.ink.opacity(0.38))
                .frame(width: width * 0.18, height: height * 0.045)
                .offset(x: width * 0.20, y: -height * 0.28)

            lens(width: width, height: height, diameter: min(width, height) * 0.49)
                .offset(x: width * 0.06, y: height * 0.07)

            modelSticker("RF", width: width, height: height)
                .frame(width: width * 0.18)
                .offset(x: -width * 0.24, y: height * 0.10)
        }
    }

    private func slrCamera(width: CGFloat, height: CGFloat) -> some View {
        let isStudioBody = bodyStyle == .studioPortraitSLR
        let bodyColors = isStudioBody
            ? [style.paper.opacity(0.78), style.swatches[1].opacity(0.62), style.ink.opacity(0.80)]
            : [style.ink.opacity(0.94), style.ink.opacity(0.76), style.swatches[1].opacity(0.58)]

        return ZStack {
            cameraShell(width: width, height: height, radius: 10, colors: bodyColors)

            Path { path in
                path.move(to: CGPoint(x: width * 0.35, y: height * 0.26))
                path.addLine(to: CGPoint(x: width * 0.46, y: height * 0.06))
                path.addLine(to: CGPoint(x: width * 0.58, y: height * 0.06))
                path.addLine(to: CGPoint(x: width * 0.70, y: height * 0.26))
                path.closeSubpath()
            }
            .fill(style.ink.opacity(isStudioBody ? 0.58 : 0.86))
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.39, y: height * 0.24))
                    path.addLine(to: CGPoint(x: width * 0.48, y: height * 0.10))
                    path.addLine(to: CGPoint(x: width * 0.57, y: height * 0.10))
                    path.addLine(to: CGPoint(x: width * 0.66, y: height * 0.24))
                }
                .stroke(style.paper.opacity(0.18), lineWidth: 1)
            }

            leatherette(width: width, height: height)
                .offset(y: height * 0.16)

            HStack {
                shutterButton(width: width, height: height)
                Spacer()
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(style.paper.opacity(0.30))
                    .frame(width: width * 0.18, height: height * 0.045)
            }
            .padding(.horizontal, width * 0.11)
            .padding(.top, height * 0.12)
            .frame(maxHeight: .infinity, alignment: .top)

            lens(width: width, height: height, diameter: min(width, height) * (isStudioBody ? 0.58 : 0.54))
                .offset(y: height * 0.08)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.paper.opacity(isStudioBody ? 0.62 : 0.42))
                .frame(width: width * 0.12, height: height * 0.22)
                .offset(x: width * 0.36, y: height * 0.08)

            modelSticker(isStudioBody ? "85" : "SLR", width: width, height: height)
                .frame(width: width * 0.21)
                .offset(x: -width * 0.28, y: -height * 0.12)
        }
    }

    private func mediumCamera(width: CGFloat, height: CGFloat) -> some View {
        let isDigitalBack = bodyStyle == .hSystemBack

        return ZStack {
            RoundedRectangle(cornerRadius: isDigitalBack ? 12 : 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            style.ink.opacity(0.90),
                            style.swatches[1].opacity(isDigitalBack ? 0.58 : 0.42),
                            style.ink.opacity(0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width * (isDigitalBack ? 0.92 : 0.82), height: height * (isDigitalBack ? 0.72 : 0.84))
                .overlay {
                    RoundedRectangle(cornerRadius: isDigitalBack ? 10 : 7, style: .continuous)
                        .stroke(style.paper.opacity(0.20), lineWidth: 1)
                }

            if isDigitalBack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(style.paper.opacity(0.20))
                    .frame(width: width * 0.24, height: height * 0.48)
                    .offset(x: -width * 0.25, y: height * 0.02)
                    .overlay {
                        VStack(spacing: height * 0.025) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(style.ink.opacity(0.46))
                                .frame(width: width * 0.15, height: height * 0.12)
                            HStack(spacing: width * 0.015) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle()
                                        .fill(style.accent.opacity(0.46))
                                        .frame(width: width * 0.022, height: width * 0.022)
                                }
                            }
                        }
                    }
            } else {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.35, y: height * 0.26))
                    path.addLine(to: CGPoint(x: width * 0.42, y: height * 0.02))
                    path.addLine(to: CGPoint(x: width * 0.61, y: height * 0.02))
                    path.addLine(to: CGPoint(x: width * 0.69, y: height * 0.26))
                    path.closeSubpath()
                }
                .fill(style.paper.opacity(0.22))
                .overlay {
                    Path { path in
                        path.move(to: CGPoint(x: width * 0.40, y: height * 0.16))
                        path.addLine(to: CGPoint(x: width * 0.62, y: height * 0.16))
                    }
                    .stroke(style.paper.opacity(0.28), lineWidth: 1)
                }
            }

            lens(width: width, height: height, diameter: min(width, height) * (isDigitalBack ? 0.50 : 0.56))
                .offset(x: isDigitalBack ? width * 0.09 : 0, y: height * 0.08)

            HStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.paper.opacity(isDigitalBack ? 0.26 : 0.42))
                    .frame(width: width * 0.16, height: height * 0.10)
                Spacer()
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.accent.opacity(isDigitalBack ? 0.62 : 0.40))
                    .frame(width: width * (isDigitalBack ? 0.18 : 0.12), height: height * 0.10)
            }
            .padding(.horizontal, width * 0.16)
            .offset(y: -height * 0.17)

            modelSticker(isDigitalBack ? "H" : "500", width: width, height: height)
                .frame(width: width * 0.20)
                .offset(x: width * 0.26, y: height * 0.23)
        }
    }

    private func compactCamera(width: CGFloat, height: CGFloat) -> some View {
        let isHalfFrame = bodyStyle == .halfFrameDiary
        let isDaylight = bodyStyle == .daylightPointAndShoot
        let isLomo = bodyStyle == .lomoCompact
        let shellWidth = isHalfFrame ? width * 0.76 : width
        let shellColors = isDaylight
            ? [style.paper.opacity(0.90), style.swatches[0].opacity(0.72), style.ink.opacity(0.62)]
            : isLomo
                ? [style.wash[0].opacity(0.92), style.wash[1].opacity(0.80), style.ink.opacity(0.84)]
                : [style.ink.opacity(0.92), style.ink.opacity(0.76), style.swatches[1].opacity(0.54)]

        return ZStack {
            cameraShell(width: shellWidth, height: height, radius: isHalfFrame ? 10 : 14, colors: shellColors)
                .frame(width: shellWidth, height: height)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(style.paper.opacity(isDaylight ? 0.30 : 0.16))
                .frame(width: shellWidth * (isHalfFrame ? 0.28 : 0.42), height: height * (isHalfFrame ? 0.56 : 0.48))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, width * (isHalfFrame ? 0.20 : 0.08))

            if isLomo {
                Rectangle()
                    .fill(style.accent.opacity(0.72))
                    .frame(width: width * 0.92, height: height * 0.10)
                    .rotationEffect(.degrees(-11))
                    .offset(y: height * 0.19)
                Rectangle()
                    .fill(style.swatches[1].opacity(0.58))
                    .frame(width: width * 0.78, height: height * 0.07)
                    .rotationEffect(.degrees(9))
                    .offset(y: -height * 0.16)
            }

            if isHalfFrame {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(style.paper.opacity(0.24))
                    .frame(width: shellWidth * 0.18, height: height * 0.58)
                    .offset(x: -width * 0.15, y: height * 0.05)
                    .overlay {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .stroke(style.accent.opacity(0.36), lineWidth: 1)
                            .padding(3)
                    }
            }

            lens(width: width, height: height, diameter: min(width, height) * (isHalfFrame ? 0.37 : isDaylight ? 0.40 : 0.43))
                .offset(x: width * (isHalfFrame ? 0.10 : isDaylight ? 0.16 : 0.08), y: height * 0.06)

            HStack {
                viewfinder(width: width, height: height)
                    .frame(width: width * (isHalfFrame ? 0.14 : 0.18), height: height * 0.13)
                Spacer()
                if isDaylight {
                    flashWindow(width: width, height: height)
                } else {
                    Circle()
                        .fill(style.accent.opacity(0.72))
                        .frame(width: height * 0.08, height: height * 0.08)
                }
            }
            .padding(.horizontal, width * (isHalfFrame ? 0.21 : 0.11))
            .padding(.top, height * 0.14)
            .frame(maxHeight: .infinity, alignment: .top)

            gripRidges(width: width, height: height, count: isHalfFrame ? 5 : 4)
                .offset(x: width * (isHalfFrame ? 0.23 : 0.34), y: height * 0.20)

            modelSticker(isHalfFrame ? "1/2" : isLomo ? "LC" : isDaylight ? "AF" : "35", width: width, height: height)
                .frame(width: width * 0.20)
                .offset(x: -width * (isHalfFrame ? 0.15 : 0.24), y: height * 0.19)
        }
    }

    private func ccdCamera(width: CGFloat, height: CGFloat) -> some View {
        let isBlueCCD = bodyStyle == .blueCCDCard

        return ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isBlueCCD
                            ? [style.accent.opacity(0.86), style.swatches[1].opacity(0.82), style.ink.opacity(0.86)]
                            : [style.paper.opacity(0.94), style.swatches[1].opacity(0.76), style.ink.opacity(0.80)],
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
                .frame(width: width * (isBlueCCD ? 0.22 : 0.30), height: height * (isBlueCCD ? 0.58 : 0.34))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, width * (isBlueCCD ? 0.10 : 0.12))
                .overlay {
                    Rectangle()
                        .fill((isBlueCCD ? style.paper : style.accent).opacity(0.40))
                        .frame(width: width * (isBlueCCD ? 0.10 : 0.18), height: height * (isBlueCCD ? 0.30 : 0.18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, width * (isBlueCCD ? 0.16 : 0.18))
                }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(style.ink.opacity(0.42))
                .frame(width: width * 0.22, height: height * 0.22)
                .offset(x: width * 0.04, y: -height * 0.16)
                .overlay {
                    HStack(spacing: width * 0.018) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(style.paper.opacity(index == 0 ? 0.54 : 0.28))
                                .frame(width: width * 0.022, height: width * 0.022)
                        }
                    }
                }

            lens(width: width, height: height, diameter: min(width, height) * (isBlueCCD ? 0.34 : 0.36))
                .offset(x: width * (isBlueCCD ? 0.20 : 0.18), y: height * (isBlueCCD ? 0.03 : 0))

            Capsule()
                .fill(style.ink.opacity(0.44))
                .frame(width: width * (isBlueCCD ? 0.34 : 0.22), height: 4)
                .offset(y: -height * 0.30)

            modelSticker(isBlueCCD ? "5MP" : "3MP", width: width, height: height)
                .frame(width: width * 0.24)
                .offset(x: width * 0.24, y: height * 0.23)
        }
    }

    private func instantCamera(width: CGFloat, height: CGFloat) -> some View {
        let isWide = bodyStyle == .wideInstantPlastic
        let isFolding = bodyStyle == .foldingInstant
        let bodyWidth = isWide ? width : width * (isFolding ? 0.86 : 0.82)

        return ZStack {
            RoundedRectangle(cornerRadius: isFolding ? 8 : 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            style.paper.opacity(0.95),
                            style.swatches[1].opacity(isFolding ? 0.58 : 0.42),
                            style.paper.opacity(0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: bodyWidth, height: height)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(style.ink.opacity(0.62))
                        .frame(width: bodyWidth * (isWide ? 0.70 : 0.66), height: height * (isFolding ? 0.20 : 0.26))
                        .padding(.bottom, height * 0.09)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: isFolding ? 8 : 14, style: .continuous)
                        .stroke(style.ink.opacity(0.13), lineWidth: 1)
                }

            if isFolding {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(style.ink.opacity(0.18), lineWidth: 1)
                        .frame(width: width * CGFloat(0.56 - Double(index) * 0.055), height: height * CGFloat(0.44 - Double(index) * 0.045))
                        .offset(x: width * 0.05, y: height * 0.05)
                }
                Path { path in
                    path.move(to: CGPoint(x: width * 0.23, y: height * 0.30))
                    path.addLine(to: CGPoint(x: width * 0.38, y: height * 0.12))
                    path.addLine(to: CGPoint(x: width * 0.67, y: height * 0.12))
                    path.addLine(to: CGPoint(x: width * 0.76, y: height * 0.30))
                    path.closeSubpath()
                }
                .fill(style.ink.opacity(0.28))
            }

            lens(width: width, height: height, diameter: min(width, height) * (isWide ? 0.33 : isFolding ? 0.32 : 0.36))
                .offset(x: width * (isWide ? 0.18 : isFolding ? 0.06 : 0.12), y: height * (isFolding ? 0.04 : -0.06))

            HStack {
                viewfinder(width: width, height: height, isRound: true)
                    .frame(width: height * 0.18, height: height * 0.18)
                Spacer()
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(style.accent.opacity(0.62))
                    .frame(width: width * (isWide ? 0.24 : 0.20), height: height * (isWide ? 0.20 : 0.16))
            }
            .padding(.horizontal, width * (isWide ? 0.12 : 0.18))
            .offset(y: -height * (isFolding ? 0.25 : 0.22))

            if isWide {
                Capsule()
                    .fill(style.ink.opacity(0.20))
                    .frame(width: width * 0.30, height: height * 0.07)
                    .offset(x: -width * 0.22, y: height * 0.25)
            }

            modelSticker(isWide ? "WIDE" : isFolding ? "SX" : "640", width: width, height: height)
                .frame(width: width * (isWide ? 0.26 : 0.22))
                .offset(x: -width * (isWide ? 0.24 : 0.18), y: height * 0.20)
        }
    }

    private func toyCamera(width: CGFloat, height: CGFloat) -> some View {
        let isDisposable = bodyStyle == .disposableFlashShell

        return ZStack {
            RoundedRectangle(cornerRadius: isDisposable ? 8 : 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isDisposable
                            ? [style.paper.opacity(0.94), style.wash[0].opacity(0.82), style.swatches[1].opacity(0.74)]
                            : [style.wash[0].opacity(0.92), style.wash[1].opacity(0.86), style.ink.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill((isDisposable ? style.ink : style.paper).opacity(isDisposable ? 0.20 : 0.22))
                .frame(height: height * (isDisposable ? 0.36 : 0.32))
                .frame(maxHeight: .infinity, alignment: .bottom)

            if isDisposable {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(style.accent.opacity(0.70))
                    .frame(width: width * 0.34, height: height * 0.24)
                    .offset(x: -width * 0.18, y: -height * 0.13)
                    .overlay {
                        VStack(spacing: height * 0.025) {
                            Rectangle()
                                .fill(style.ink.opacity(0.24))
                                .frame(width: width * 0.22, height: 1)
                            Rectangle()
                                .fill(style.ink.opacity(0.18))
                                .frame(width: width * 0.16, height: 1)
                        }
                    }
            } else {
                HStack {
                    Circle()
                        .fill(style.paper.opacity(0.28))
                        .frame(width: height * 0.16, height: height * 0.16)
                    Spacer()
                    Circle()
                        .fill(style.paper.opacity(0.28))
                        .frame(width: height * 0.16, height: height * 0.16)
                }
                .padding(.horizontal, width * 0.16)
                .offset(y: -height * 0.24)
            }

            lens(width: width, height: height, diameter: min(width, height) * (isDisposable ? 0.34 : 0.45))
                .offset(x: width * (isDisposable ? 0.17 : 0), y: height * 0.06)

            HStack {
                viewfinder(width: width, height: height)
                    .frame(width: width * (isDisposable ? 0.16 : 0.18), height: height * 0.14)
                Spacer()
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(style.accent.opacity(0.64))
                    .frame(width: width * (isDisposable ? 0.26 : 0.22), height: height * (isDisposable ? 0.20 : 0.16))
            }
            .padding(.horizontal, width * 0.12)
            .padding(.top, height * 0.15)
            .frame(maxHeight: .infinity, alignment: .top)

            modelSticker(isDisposable ? "27" : "120", width: width, height: height)
                .frame(width: width * 0.20)
                .offset(x: -width * 0.25, y: height * 0.22)

            if !isDisposable {
                Rectangle()
                    .fill(style.accent.opacity(0.64))
                    .frame(width: width * 0.74, height: height * 0.07)
                    .rotationEffect(.degrees(-5))
                    .offset(y: height * 0.20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isDisposable ? 8 : 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: isDisposable ? 8 : 12, style: .continuous)
                .stroke(style.paper.opacity(0.16), lineWidth: 1)
        }
    }

    private func cinemaCamera(width: CGFloat, height: CGFloat) -> some View {
        let isNoir = bodyStyle == .noirCinemaBody

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            style.ink.opacity(isNoir ? 0.94 : 0.88),
                            style.swatches[1].opacity(isNoir ? 0.42 : 0.64),
                            style.ink.opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width * 0.78, height: height * 0.58)
                .offset(x: -width * 0.06, y: height * 0.06)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(style.paper.opacity(0.16), lineWidth: 1)
                        .frame(width: width * 0.70, height: height * 0.50)
                }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(style.paper.opacity(isNoir ? 0.18 : 0.26))
                .frame(width: width * 0.42, height: height * 0.12)
                .offset(x: -width * 0.13, y: -height * 0.26)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(style.accent.opacity(0.70))
                        .frame(width: height * 0.08, height: height * 0.08)
                        .padding(.leading, width * 0.04)
                }

            Circle()
                .fill(style.ink.opacity(0.86))
                .frame(width: height * 0.30, height: height * 0.30)
                .offset(x: -width * 0.30, y: -height * 0.16)
                .overlay {
                    Circle()
                        .stroke(style.paper.opacity(0.18), lineWidth: 2)
                        .frame(width: height * 0.22, height: height * 0.22)
                }

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.ink.opacity(0.92))
                .frame(width: width * 0.18, height: height * 0.34)
                .offset(x: width * 0.26, y: height * 0.07)

            lens(width: width, height: height, diameter: min(width, height) * (isNoir ? 0.39 : 0.43))
                .offset(x: width * 0.18, y: height * 0.06)
                .overlay(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.black.opacity(0.72))
                        .frame(width: width * 0.20, height: height * 0.25)
                        .offset(x: width * 0.27, y: height * 0.06)
                }

            VStack(spacing: height * 0.035) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule()
                        .fill(style.paper.opacity(0.24))
                        .frame(width: width * 0.62, height: 2)
                }
            }
            .offset(x: width * 0.04, y: height * 0.36)

            modelSticker(isNoir ? "NOIR" : "S35", width: width, height: height)
                .frame(width: width * 0.24)
                .offset(x: -width * 0.14, y: height * 0.18)
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
        Text(language == .chinese ? "当前相机" : "ACTIVE")
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
        Text(language == .chinese ? "使用中" : "IN USE")
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
            if let sampleImage = FilmSampleImageCache.image(for: frame) {
                Image(uiImage: sampleImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
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

private enum FilmSamplePhotoFrame: CaseIterable, Hashable {
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

    var gridPosition: (column: Int, row: Int) {
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

    func cropRect(in imageSize: CGSize) -> CGRect {
        let cellWidth = imageSize.width / CGFloat(columns)
        let cellHeight = imageSize.height / CGFloat(rows)
        return CGRect(
            x: CGFloat(gridPosition.column) * cellWidth,
            y: CGFloat(gridPosition.row) * cellHeight,
            width: cellWidth,
            height: cellHeight
        ).integral
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

    static func sequence(for film: FilmPreset) -> [FilmSamplePhotoFrame] {
        switch film.id {
        case "human-warm-400":
            return [.shadowInterior, .warmCafe, .streetMarket]
        case "human-vignette-800":
            return [.shadowInterior, .noirWindow, .warmCafe]
        case "muse-portrait-400":
            return [.windowPortrait, .warmCafe, .instantDesk]
        case "soft-portrait-400":
            return [.windowPortrait, .naturalProduct, .warmCafe]
        case "sunlit-gold-200", "t-compact-gold":
            return [.warmCafe, .streetMarket, .naturalProduct]
        case "green-street-400", "gr-street-snap":
            return [.shadowInterior, .streetMarket, .noirWindow]
        case "superia-green", "classic-chrome-x", "lca-vivid":
            return [.streetMarket, .warmCafe, .naturalProduct]
        case "tungsten-800", "cyber-ccd-blue":
            return [.tungstenNight, .ccdParty, .shadowInterior]
        case "ccd-2003", "pocket-flash":
            return [.ccdParty, .tungstenNight, .instantDesk]
        case "instant-square", "instant-wide", "sx-fade", "holga-120-dream":
            return [.instantDesk, .windowPortrait, .warmCafe]
        case "hncs-natural", "medium-500c", "ektar-vivid-100":
            return [.naturalProduct, .streetMarket, .warmCafe]
        case "silver-hp5", "tri-x-street", "noir-soft":
            return [.noirWindow, .shadowInterior, .streetMarket]
        default:
            return [frame(for: film), .warmCafe, .streetMarket]
        }
    }
}

private enum FilmSampleImageCache {
    private static let images: [FilmSamplePhotoFrame: UIImage] = {
        guard let contactSheet = UIImage(named: "film_sample_contact_sheet_v2"),
              let sourceImage = contactSheet.cgImage
        else {
            return [:]
        }

        let imageSize = CGSize(width: sourceImage.width, height: sourceImage.height)
        return Dictionary(uniqueKeysWithValues: FilmSamplePhotoFrame.allCases.compactMap { frame in
            guard let cropped = sourceImage.cropping(to: frame.cropRect(in: imageSize)) else {
                return nil
            }
            return (frame, UIImage(cgImage: cropped, scale: contactSheet.scale, orientation: contactSheet.imageOrientation))
        })
    }()

    static func image(for frame: FilmSamplePhotoFrame) -> UIImage? {
        images[frame]
    }
}

private struct FilmSampleTreatment {
    let scale: CGFloat
    let offset: CGSize
    let rotation: Double
    let saturation: Double
    let contrast: Double
    let brightness: Double
    let hueShift: Double
    let tint: Color
    let tintOpacity: Double
    let tintBlendMode: BlendMode
    let vignetteAmount: Double
    let vignetteColor: Color
    let vignetteCenter: UnitPoint
    let lightLeakOpacity: Double
    let lightLeakColor: Color
    let lightLeakStart: UnitPoint
    let lightLeakEnd: UnitPoint

    static func treatment(for film: FilmPreset, style: FilmCoverStyle) -> FilmSampleTreatment {
        let seed = checksum(for: film.id)
        let baseScale = CGFloat(1.04 + Double(seed % 7) * 0.012)
        let baseOffset = CGSize(
            width: CGFloat(Double((seed / 7) % 9) - 4.0) * 0.008,
            height: CGFloat(Double((seed / 19) % 9) - 4.0) * 0.008
        )
        let baseRotation = Double((seed / 31) % 7) - 3.0

        let base = FilmSampleTreatment(
            scale: baseScale,
            offset: baseOffset,
            rotation: baseRotation,
            saturation: max(0.0, min(1.36, 0.94 + film.saturation * 0.22)),
            contrast: max(0.82, min(1.34, 0.98 + film.contrast * 0.18)),
            brightness: max(-0.06, min(0.07, film.exposureBias * 0.018)),
            hueShift: max(-9, min(9, film.temperatureShift / 75.0)),
            tint: style.accent,
            tintOpacity: 0.12,
            tintBlendMode: .softLight,
            vignetteAmount: max(0.18, min(0.82, 0.18 + film.vignetteAmount * 0.92)),
            vignetteColor: style.ink,
            vignetteCenter: .center,
            lightLeakOpacity: film.lightLeakAmount > 0 ? max(0.08, min(0.34, film.lightLeakAmount * 0.70)) : 0,
            lightLeakColor: style.accent,
            lightLeakStart: seed.isMultiple(of: 2) ? .topLeading : .topTrailing,
            lightLeakEnd: .center
        )

        switch film.id {
        case "human-warm-400":
            return base.reframed(scale: 1.09, offset: CGSize(width: 0.035, height: -0.035), rotation: -1.2)
                .graded(saturation: 1.12, contrast: 1.10, brightness: 0.018, hueShift: 4, tintOpacity: 0.18)
                .leak(opacity: 0.18, color: style.accent, start: .topLeading, end: .bottomTrailing)
                .vignette(0.38, center: UnitPoint(x: 0.48, y: 0.50))
        case "human-vignette-800":
            return base.reframed(scale: 1.14, offset: CGSize(width: -0.025, height: 0.020), rotation: 0.8)
                .graded(saturation: 0.86, contrast: 1.22, brightness: -0.025, hueShift: -2, tintOpacity: 0.10)
                .vignette(0.82, center: UnitPoint(x: 0.50, y: 0.46))
        case "muse-portrait-400":
            return base.reframed(scale: 1.12, offset: CGSize(width: 0.012, height: -0.030), rotation: -0.6)
                .graded(saturation: 1.06, contrast: 0.96, brightness: 0.035, hueShift: 3, tintOpacity: 0.22)
                .leak(opacity: 0.13, color: style.paper, start: .top, end: .bottom)
                .vignette(0.24, center: UnitPoint(x: 0.52, y: 0.42))
        case "soft-portrait-400":
            return base.reframed(scale: 1.08, offset: CGSize(width: -0.010, height: -0.018), rotation: 0.4)
                .graded(saturation: 0.98, contrast: 0.90, brightness: 0.045, hueShift: 2, tintOpacity: 0.20)
                .vignette(0.20, center: UnitPoint(x: 0.50, y: 0.45))
        case "silver-hp5", "tri-x-street", "noir-soft":
            return base.reframed(scale: film.id == "noir-soft" ? 1.16 : 1.10, offset: baseOffset, rotation: baseRotation)
                .graded(saturation: 0.0, contrast: film.id == "tri-x-street" ? 1.30 : 1.16, brightness: film.id == "noir-soft" ? -0.030 : 0.0, hueShift: 0, tintOpacity: 0.05)
                .vignette(film.id == "noir-soft" ? 0.78 : 0.46, center: UnitPoint(x: 0.48, y: 0.48))
        case "tungsten-800", "cyber-ccd-blue":
            return base.reframed(scale: 1.11, offset: CGSize(width: 0.020, height: 0.018), rotation: 1.0)
                .graded(saturation: 1.18, contrast: 1.18, brightness: -0.010, hueShift: -7, tintOpacity: 0.18)
                .leak(opacity: 0.26, color: style.accent, start: .trailing, end: .leading)
                .vignette(0.54, center: UnitPoint(x: 0.48, y: 0.52))
        case "ccd-2003", "pocket-flash":
            return base.reframed(scale: 1.07, offset: CGSize(width: -0.018, height: 0.006), rotation: -1.4)
                .graded(saturation: 1.28, contrast: 1.20, brightness: 0.030, hueShift: -4, tintOpacity: 0.16)
                .leak(opacity: 0.30, color: style.paper, start: .topLeading, end: .bottom)
                .vignette(0.36, center: UnitPoint(x: 0.50, y: 0.50))
        case "instant-square", "instant-wide", "sx-fade":
            return base.reframed(scale: 1.05, offset: CGSize(width: 0.0, height: -0.010), rotation: film.id == "sx-fade" ? -2.0 : 1.0)
                .graded(saturation: 0.92, contrast: 0.92, brightness: 0.040, hueShift: 2, tintOpacity: 0.18)
                .leak(opacity: 0.12, color: style.paper, start: .top, end: .center)
                .vignette(0.24, center: UnitPoint(x: 0.50, y: 0.48))
        case "hncs-natural", "medium-500c":
            return base.reframed(scale: 1.10, offset: CGSize(width: 0.018, height: -0.026), rotation: -0.8)
                .graded(saturation: 0.96, contrast: 1.02, brightness: 0.018, hueShift: -1, tintOpacity: 0.08)
                .vignette(0.26, center: UnitPoint(x: 0.50, y: 0.47))
        default:
            return base
        }
    }

    private func reframed(scale: CGFloat, offset: CGSize, rotation: Double) -> FilmSampleTreatment {
        FilmSampleTreatment(
            scale: scale,
            offset: offset,
            rotation: rotation,
            saturation: saturation,
            contrast: contrast,
            brightness: brightness,
            hueShift: hueShift,
            tint: tint,
            tintOpacity: tintOpacity,
            tintBlendMode: tintBlendMode,
            vignetteAmount: vignetteAmount,
            vignetteColor: vignetteColor,
            vignetteCenter: vignetteCenter,
            lightLeakOpacity: lightLeakOpacity,
            lightLeakColor: lightLeakColor,
            lightLeakStart: lightLeakStart,
            lightLeakEnd: lightLeakEnd
        )
    }

    private func graded(saturation: Double, contrast: Double, brightness: Double, hueShift: Double, tintOpacity: Double) -> FilmSampleTreatment {
        FilmSampleTreatment(
            scale: scale,
            offset: offset,
            rotation: rotation,
            saturation: saturation,
            contrast: contrast,
            brightness: brightness,
            hueShift: hueShift,
            tint: tint,
            tintOpacity: tintOpacity,
            tintBlendMode: tintBlendMode,
            vignetteAmount: vignetteAmount,
            vignetteColor: vignetteColor,
            vignetteCenter: vignetteCenter,
            lightLeakOpacity: lightLeakOpacity,
            lightLeakColor: lightLeakColor,
            lightLeakStart: lightLeakStart,
            lightLeakEnd: lightLeakEnd
        )
    }

    private func vignette(_ amount: Double, center: UnitPoint) -> FilmSampleTreatment {
        FilmSampleTreatment(
            scale: scale,
            offset: offset,
            rotation: rotation,
            saturation: saturation,
            contrast: contrast,
            brightness: brightness,
            hueShift: hueShift,
            tint: tint,
            tintOpacity: tintOpacity,
            tintBlendMode: tintBlendMode,
            vignetteAmount: amount,
            vignetteColor: vignetteColor,
            vignetteCenter: center,
            lightLeakOpacity: lightLeakOpacity,
            lightLeakColor: lightLeakColor,
            lightLeakStart: lightLeakStart,
            lightLeakEnd: lightLeakEnd
        )
    }

    private func leak(opacity: Double, color: Color, start: UnitPoint, end: UnitPoint) -> FilmSampleTreatment {
        FilmSampleTreatment(
            scale: scale,
            offset: offset,
            rotation: rotation,
            saturation: saturation,
            contrast: contrast,
            brightness: brightness,
            hueShift: hueShift,
            tint: tint,
            tintOpacity: tintOpacity,
            tintBlendMode: tintBlendMode,
            vignetteAmount: vignetteAmount,
            vignetteColor: vignetteColor,
            vignetteCenter: vignetteCenter,
            lightLeakOpacity: opacity,
            lightLeakColor: color,
            lightLeakStart: start,
            lightLeakEnd: end
        )
    }

    private static func checksum(for id: String) -> Int {
        id.unicodeScalars.reduce(17) { partialResult, scalar in
            (partialResult * 37 + Int(scalar.value)) % 10_000
        }
    }
}

private struct FilmSampleSceneView: View {
    let film: FilmPreset
    let style: FilmCoverStyle
    let photoFrame: FilmSamplePhotoFrame?
    let sampleRole: FilmSampleRole

    init(
        film: FilmPreset,
        style: FilmCoverStyle,
        photoFrame: FilmSamplePhotoFrame? = nil,
        sampleRole: FilmSampleRole = .thumb
    ) {
        self.film = film
        self.style = style
        self.photoFrame = photoFrame
        self.sampleRole = sampleRole
    }

    private var scene: FilmSampleSceneKind {
        FilmSampleSceneKind.kind(for: film)
    }

    private var resolvedPhotoFrame: FilmSamplePhotoFrame {
        photoFrame ?? FilmSamplePhotoFrame.frame(for: film)
    }

    private var treatment: FilmSampleTreatment {
        FilmSampleTreatment.treatment(for: film, style: style)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                sampleImage(width: width, height: height)
                    .saturation(treatment.saturation)
                    .contrast(treatment.contrast)
                    .brightness(treatment.brightness)
                    .hueRotation(.degrees(treatment.hueShift))
                    .scaleEffect(treatment.scale)
                    .rotationEffect(.degrees(treatment.rotation))
                    .offset(x: treatment.offset.width * width, y: treatment.offset.height * height)

                Rectangle()
                    .fill(treatment.tint)
                    .opacity(treatment.tintOpacity)
                    .blendMode(treatment.tintBlendMode)

                photoPrintFinish(width: width, height: height)
                sampleLightLeak(width: width, height: height)
                sampleVignette(width: width, height: height)
                sceneTone(width: width, height: height)
                sceneGrain(width: width, height: height)
            }
            .clipShape(RoundedRectangle(cornerRadius: min(width, height) * 0.08, style: .continuous))
        }
    }

    @ViewBuilder
    private func sampleImage(width: CGFloat, height: CGFloat) -> some View {
        let maxPixelSize = Int(max(width, height) * UIScreen.main.scale * 1.5)
        if let image = FilmSampleCatalog.image(for: film, role: sampleRole, maxPixelSize: maxPixelSize) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
        } else {
            FilmContactSheetCrop(frame: resolvedPhotoFrame)
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
    private func sampleLightLeak(width: CGFloat, height: CGFloat) -> some View {
        if treatment.lightLeakOpacity > 0 {
            LinearGradient(
                colors: [
                    treatment.lightLeakColor.opacity(treatment.lightLeakOpacity),
                    treatment.lightLeakColor.opacity(treatment.lightLeakOpacity * 0.28),
                    .clear
                ],
                startPoint: treatment.lightLeakStart,
                endPoint: treatment.lightLeakEnd
            )
            .blendMode(.screen)
            .blur(radius: min(width, height) * 0.015)
        }
    }

    private func sampleVignette(width: CGFloat, height: CGFloat) -> some View {
        RadialGradient(
            colors: [
                .clear,
                treatment.vignetteColor.opacity(treatment.vignetteAmount * 0.52),
                treatment.vignetteColor.opacity(treatment.vignetteAmount)
            ],
            center: treatment.vignetteCenter,
            startRadius: min(width, height) * 0.26,
            endRadius: max(width, height) * 0.72
        )
        .blendMode(.multiply)
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
    let count: Int
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 14)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? StillLightTheme.background.opacity(0.74) : StillLightTheme.secondaryText)
                    .padding(.horizontal, 5)
                    .frame(height: 17)
                    .background(isSelected ? Color.black.opacity(0.12) : StillLightTheme.panel.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .foregroundStyle(isSelected ? StillLightTheme.background : StillLightTheme.text)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(isSelected ? StillLightTheme.accent : StillLightTheme.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private extension FilmCategory {
    var drawerIconName: String {
        switch self {
        case .favorites:
            return "pin.fill"
        case .featured:
            return "sparkle"
        case .portrait:
            return "person.crop.square"
        case .negative:
            return "film"
        case .camera:
            return "camera.viewfinder"
        case .instant:
            return "rectangle.stack"
        case .blackWhite:
            return "circle.lefthalf.filled"
        case .digital:
            return "memorychip"
        case .experimental:
            return "dial.low"
        }
    }
}
