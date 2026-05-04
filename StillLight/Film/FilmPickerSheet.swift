import SwiftUI

struct FilmPickerSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: FilmCategory?

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    categoryPicker

                    if filteredPresets.isEmpty, selectedCategory == .favorites {
                        favoriteEmptyState
                    } else {
                        ForEach(filteredPresets) { film in
                            FilmPresetRow(
                                film: film,
                                isSelected: film.id == appState.selectedFilm.id,
                                isFavorite: appState.isFavorite(film),
                                currentRoll: film.id == appState.currentRoll.filmPresetId ? appState.currentRoll : nil,
                                language: appState.language,
                                favoriteTitle: appState.t(appState.isFavorite(film) ? .unfavoriteFilm : .favoriteFilm),
                                selectAction: {
                                    appState.selectFilm(film)
                                    dismiss()
                                },
                                favoriteAction: {
                                    appState.toggleFavorite(film)
                                }
                            )
                        }
                    }
                }
                .padding(18)
            }
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

    private var favoriteEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(StillLightTheme.accent)
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
                            .font(.caption2.monospacedDigit().weight(currentRoll == nil ? .regular : .semibold))
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
            return "\(category) · ISO \(film.iso)"
        }
        return "\(category) · \(sceneSummary) · ISO \(film.iso)"
    }

    private var statusLine: String {
        if let currentRoll {
            return "\(AppText.get(.roll, language: language)) \(currentRoll.remainingShots)/\(currentRoll.totalShots)"
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

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: style.wash, startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(4)

            RadialGradient(colors: [style.accent.opacity(0.34), .clear], center: style.glowCenter, startRadius: 2, endRadius: 56)
                .blendMode(.screen)

            coverArtwork
                .padding(8)

            grainMarks
                .foregroundStyle(style.ink.opacity(0.12))

            VStack {
                HStack(spacing: 3) {
                    Capsule()
                        .fill(style.accent.opacity(0.86))
                        .frame(width: 10, height: 3)
                    Text(style.label)
                        .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundStyle(style.ink.opacity(0.76))

                Spacer()

                HStack(spacing: 3) {
                    ForEach(0..<style.swatches.count, id: \.self) { index in
                        Rectangle()
                            .fill(style.swatches[index])
                            .frame(width: 7, height: 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
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

    @ViewBuilder
    private var coverArtwork: some View {
        switch style.kind {
        case .filmStrip:
            HStack(spacing: 5) {
                sprocketRail
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(style.swatches[index % style.swatches.count].opacity(0.74))
                            .overlay {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .stroke(style.ink.opacity(0.22), lineWidth: 0.7)
                            }
                    }
                }
                sprocketRail
            }
            .rotationEffect(.degrees(style.tilt))

        case .contactSheet:
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<2, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(style.swatches[(row + column) % style.swatches.count].opacity(0.62))
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(style.ink.opacity(0.18))
                                        .frame(height: 2)
                                }
                        }
                    }
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 3)

        case .darkroomCard:
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(style.swatches[index % style.swatches.count].opacity(0.66), lineWidth: 2)
                        .frame(width: CGFloat(34 - index * 7), height: CGFloat(46 - index * 9))
                        .rotationEffect(.degrees(style.tilt + Double(index * 9)))
                }
                Capsule()
                    .fill(style.accent.opacity(0.72))
                    .frame(width: 38, height: 8)
                    .rotationEffect(.degrees(-18))
                    .blur(radius: 0.4)
            }

        case .colorRecipe:
            VStack(spacing: 5) {
                ForEach(0..<style.swatches.count, id: \.self) { index in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(style.swatches[index])
                            .frame(width: 14, height: 10)
                        VStack(spacing: 2) {
                            Rectangle().fill(style.ink.opacity(0.28)).frame(height: 1)
                            Rectangle().fill(style.ink.opacity(0.16)).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.top, 8)

        case .instantFrame:
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.ink.opacity(0.18))
                    .overlay {
                        LinearGradient(colors: style.swatches.map { $0.opacity(0.68) }, startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                            .padding(3)
                    }
                Rectangle()
                    .fill(style.paper.opacity(0.76))
                    .frame(height: 12)
            }
            .padding(.top, 6)

        case .halfFrame:
            HStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(style.swatches[index % style.swatches.count].opacity(0.66))
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(style.paper.opacity(0.75), lineWidth: 2)
                        }
                }
            }
            .padding(.vertical, 9)
            .rotationEffect(.degrees(style.tilt))

        case .negativeSleeve:
            VStack(spacing: 4) {
                sprocketRow
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(style.swatches[index % style.swatches.count].opacity(0.48))
                            .overlay {
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .stroke(style.ink.opacity(0.18), lineWidth: 0.6)
                            }
                    }
                }
                sprocketRow
            }
            .padding(.vertical, 10)
        }
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

    private var grainMarks: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .frame(width: index.isMultiple(of: 3) ? 2 : 1, height: index.isMultiple(of: 3) ? 2 : 1)
                    .offset(x: CGFloat((index * 13) % 42) - 21, y: CGFloat((index * 19) % 54) - 27)
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
            return .init(paper: c(0.89, 0.78, 0.73), wash: [c(0.96, 0.73, 0.65), c(0.76, 0.56, 0.52), c(0.48, 0.39, 0.41)], glowCenter: .top, ink: c(0.29, 0.15, 0.15), accent: c(0.98, 0.72, 0.68), swatches: [c(0.96, 0.68, 0.61), c(0.74, 0.58, 0.58), c(0.42, 0.35, 0.38)], label: "MUSE LAB", kind: .colorRecipe, tilt: 1)
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
            return .init(paper: c(0.91, 0.64, 0.34), wash: [c(0.98, 0.71, 0.30), c(0.72, 0.23, 0.20), c(0.12, 0.09, 0.07)], glowCenter: .topLeading, ink: c(0.24, 0.09, 0.05), accent: c(1.00, 0.92, 0.64), swatches: [c(1.00, 0.82, 0.35), c(0.82, 0.24, 0.17), c(0.18, 0.10, 0.07)], label: "FLASH LAB", kind: .contactSheet, tilt: 2)
        case "ccd-2003":
            return .init(paper: c(0.72, 0.84, 0.88), wash: [c(0.74, 0.87, 0.91), c(0.39, 0.55, 0.69), c(0.15, 0.19, 0.27)], glowCenter: .topTrailing, ink: c(0.04, 0.15, 0.23), accent: c(0.78, 0.94, 1.00), swatches: [c(0.66, 0.91, 1.00), c(0.37, 0.57, 0.79), c(0.15, 0.23, 0.34)], label: "CCD TONE", kind: .colorRecipe, tilt: 0)
        case "instant-square":
            return .init(paper: c(0.93, 0.86, 0.70), wash: [c(0.93, 0.85, 0.69), c(0.61, 0.51, 0.41), c(0.30, 0.25, 0.21)], glowCenter: .center, ink: c(0.27, 0.21, 0.14), accent: c(1.00, 0.91, 0.72), swatches: [c(0.88, 0.76, 0.55), c(0.62, 0.51, 0.40), c(0.32, 0.26, 0.21)], label: "SX SQUARE", kind: .instantFrame, tilt: 0)
        case "hncs-natural":
            return .init(paper: c(0.82, 0.80, 0.68), wash: [c(0.79, 0.78, 0.68), c(0.51, 0.59, 0.54), c(0.25, 0.28, 0.24)], glowCenter: .center, ink: c(0.17, 0.17, 0.13), accent: c(0.93, 0.89, 0.74), swatches: [c(0.82, 0.78, 0.63), c(0.55, 0.63, 0.55), c(0.30, 0.32, 0.26)], label: "NATURAL", kind: .colorRecipe, tilt: 0)
        case "m-rangefinder":
            return .init(paper: c(0.59, 0.22, 0.18), wash: [c(0.67, 0.17, 0.13), c(0.40, 0.37, 0.29), c(0.07, 0.07, 0.06)], glowCenter: .leading, ink: c(0.97, 0.77, 0.55), accent: c(0.94, 0.50, 0.34), swatches: [c(0.76, 0.18, 0.13), c(0.45, 0.40, 0.28), c(0.10, 0.08, 0.06)], label: "RANGE", kind: .negativeSleeve, tilt: 0)
        case "t-compact-gold":
            return .init(paper: c(0.89, 0.68, 0.38), wash: [c(0.94, 0.72, 0.35), c(0.73, 0.43, 0.26), c(0.19, 0.15, 0.11)], glowCenter: .top, ink: c(0.20, 0.11, 0.04), accent: c(1.00, 0.83, 0.43), swatches: [c(0.97, 0.74, 0.33), c(0.78, 0.46, 0.25), c(0.26, 0.16, 0.09)], label: "COMPACT", kind: .filmStrip, tilt: -2)
        case "gr-street-snap":
            return .init(paper: c(0.70, 0.73, 0.70), wash: [c(0.72, 0.75, 0.71), c(0.33, 0.38, 0.39), c(0.045, 0.055, 0.065)], glowCenter: .bottom, ink: c(0.09, 0.13, 0.13), accent: c(0.82, 0.90, 0.88), swatches: [c(0.76, 0.80, 0.75), c(0.39, 0.45, 0.45), c(0.06, 0.07, 0.08)], label: "SNAP LOG", kind: .contactSheet, tilt: 1)
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
            return .init(paper: c(0.84, 0.71, 0.50), wash: [c(0.91, 0.66, 0.29), c(0.52, 0.60, 0.43), c(0.17, 0.17, 0.13)], glowCenter: .center, ink: c(0.17, 0.11, 0.04), accent: c(1.00, 0.79, 0.44), swatches: [c(0.94, 0.68, 0.30), c(0.54, 0.64, 0.42), c(0.20, 0.18, 0.13)], label: "STILL LAB", kind: .contactSheet, tilt: 0)
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
