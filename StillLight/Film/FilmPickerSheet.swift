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

                    ForEach(filteredPresets) { film in
                        Button {
                            appState.selectFilm(film)
                            dismiss()
                        } label: {
                            FilmPresetRow(
                                film: film,
                                isSelected: film.id == appState.selectedFilm.id,
                                currentRoll: film.id == appState.currentRoll.filmPresetId ? appState.currentRoll : nil,
                                language: appState.language
                            )
                        }
                        .buttonStyle(.plain)
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
        return appState.filmLibrary.presets.filter { $0.category == selectedCategory }
    }
}

private struct FilmPresetRow: View {
    let film: FilmPreset
    let isSelected: Bool
    let currentRoll: FilmRoll?
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 14) {
            FilmCoverView(film: film)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(film.displayName(language: language))
                        .font(.headline)
                        .foregroundStyle(StillLightTheme.text)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(StillLightTheme.accent)
                    }
                }
                Text(film.displayDescription(language: language))
                    .font(.subheadline)
                    .foregroundStyle(StillLightTheme.secondaryText)
                    .lineLimit(2)
                Text(film.displayMetadataLine(language: language))
                    .font(.caption.monospaced())
                    .foregroundStyle(StillLightTheme.accent)
                HStack(spacing: 8) {
                    Text(film.displayCameraName(language: language))
                    Text(rollLine)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(StillLightTheme.secondaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(isSelected ? StillLightTheme.panelElevated : StillLightTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? StillLightTheme.accent.opacity(0.55) : .clear, lineWidth: 1)
        }
    }

    private var rollLine: String {
        if let currentRoll {
            return "\(AppText.get(.roll, language: language)) \(currentRoll.remainingShots)/\(currentRoll.totalShots)"
        }
        return "\(AppText.get(.newRoll, language: language)) \(film.defaultShotCount)"
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
                .fill(LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing))

            RadialGradient(
                colors: [
                    style.glow.opacity(0.72),
                    style.glow.opacity(0.16),
                    .black.opacity(style.vignette)
                ],
                center: style.glowCenter,
                startRadius: 3,
                endRadius: 72
            )
            .blendMode(style.blendMode)

            if let leak = style.lightLeak {
                Capsule()
                    .fill(leak.opacity(0.42))
                    .frame(width: 18, height: 98)
                    .rotationEffect(.degrees(-22))
                    .offset(x: -26, y: -10)
                    .blur(radius: 6)
            }

            if style.hasPaperEdge {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color(red: 0.95, green: 0.92, blue: 0.85).opacity(0.82))
                        .frame(height: 17)
                }
            }

            Image(systemName: style.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(style.ink.opacity(0.64))
                .offset(y: -10)

            VStack {
                HStack {
                    Text(style.mark)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Spacer()
                    Text("\(film.iso)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(style.ink.opacity(0.78))
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(style.ink.opacity(0.54))
                        .frame(width: 4, height: 4)
                }
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
}

private struct FilmCoverStyle {
    let colors: [Color]
    let glow: Color
    let glowCenter: UnitPoint
    let ink: Color
    let symbol: String
    let mark: String
    let vignette: Double
    let lightLeak: Color?
    let hasPaperEdge: Bool
    let blendMode: BlendMode

    static func style(for film: FilmPreset) -> FilmCoverStyle {
        switch film.id {
        case "human-warm-400":
            return .init(colors: [c(0.93, 0.74, 0.47), c(0.47, 0.55, 0.42), c(0.18, 0.16, 0.11)], glow: c(1.00, 0.86, 0.58), glowCenter: .center, ink: c(0.17, 0.12, 0.08), symbol: "person.2", mark: "HUM", vignette: 0.34, lightLeak: c(1.00, 0.62, 0.28), hasPaperEdge: false, blendMode: .softLight)
        case "human-vignette-800":
            return .init(colors: [c(0.54, 0.49, 0.37), c(0.18, 0.22, 0.18), c(0.05, 0.05, 0.04)], glow: c(0.86, 0.68, 0.42), glowCenter: .center, ink: c(0.90, 0.78, 0.54), symbol: "figure.walk", mark: "SW", vignette: 0.62, lightLeak: nil, hasPaperEdge: false, blendMode: .screen)
        case "muse-portrait-400":
            return .init(colors: [c(0.96, 0.74, 0.65), c(0.77, 0.58, 0.53), c(0.50, 0.42, 0.43)], glow: c(1.00, 0.86, 0.74), glowCenter: .top, ink: c(0.30, 0.16, 0.16), symbol: "sparkles", mark: "MUSE", vignette: 0.14, lightLeak: c(1.00, 0.72, 0.68), hasPaperEdge: false, blendMode: .softLight)
        case "sunlit-gold-200":
            return .init(colors: [c(0.96, 0.73, 0.34), c(0.62, 0.64, 0.37), c(0.28, 0.28, 0.16)], glow: c(1.00, 0.85, 0.42), glowCenter: .topLeading, ink: c(0.21, 0.14, 0.05), symbol: "sun.max", mark: "GLD", vignette: 0.22, lightLeak: nil, hasPaperEdge: false, blendMode: .softLight)
        case "soft-portrait-400":
            return .init(colors: [c(0.86, 0.68, 0.57), c(0.62, 0.66, 0.62), c(0.39, 0.39, 0.36)], glow: c(1.00, 0.82, 0.68), glowCenter: .top, ink: c(0.24, 0.18, 0.15), symbol: "person.crop.rectangle", mark: "POR", vignette: 0.16, lightLeak: nil, hasPaperEdge: false, blendMode: .softLight)
        case "silver-hp5":
            return .init(colors: [c(0.82, 0.80, 0.74), c(0.44, 0.44, 0.41), c(0.16, 0.16, 0.15)], glow: c(0.92, 0.90, 0.82), glowCenter: .center, ink: c(0.08, 0.08, 0.08), symbol: "circle.lefthalf.filled", mark: "HP5", vignette: 0.32, lightLeak: nil, hasPaperEdge: true, blendMode: .overlay)
        case "green-street-400":
            return .init(colors: [c(0.63, 0.69, 0.51), c(0.28, 0.48, 0.42), c(0.10, 0.17, 0.15)], glow: c(0.72, 0.86, 0.60), glowCenter: .bottomLeading, ink: c(0.07, 0.18, 0.13), symbol: "building.2", mark: "STR", vignette: 0.28, lightLeak: nil, hasPaperEdge: false, blendMode: .softLight)
        case "tungsten-800":
            return .init(colors: [c(0.22, 0.26, 0.45), c(0.64, 0.31, 0.22), c(0.08, 0.07, 0.12)], glow: c(1.00, 0.39, 0.18), glowCenter: .trailing, ink: c(0.94, 0.60, 0.38), symbol: "moon.stars", mark: "TNG", vignette: 0.42, lightLeak: c(1.00, 0.30, 0.15), hasPaperEdge: false, blendMode: .screen)
        case "pocket-flash":
            return .init(colors: [c(0.98, 0.72, 0.31), c(0.72, 0.24, 0.22), c(0.13, 0.10, 0.08)], glow: c(1.00, 0.95, 0.72), glowCenter: .topLeading, ink: c(0.25, 0.10, 0.06), symbol: "bolt.fill", mark: "FLS", vignette: 0.38, lightLeak: c(1.00, 0.52, 0.18), hasPaperEdge: false, blendMode: .screen)
        case "ccd-2003":
            return .init(colors: [c(0.75, 0.88, 0.92), c(0.40, 0.56, 0.70), c(0.16, 0.20, 0.28)], glow: c(0.78, 0.95, 1.00), glowCenter: .topTrailing, ink: c(0.05, 0.16, 0.24), symbol: "camera.compact", mark: "CCD", vignette: 0.18, lightLeak: nil, hasPaperEdge: false, blendMode: .overlay)
        case "instant-square":
            return .init(colors: [c(0.94, 0.86, 0.70), c(0.62, 0.52, 0.42), c(0.31, 0.26, 0.22)], glow: c(1.00, 0.92, 0.76), glowCenter: .center, ink: c(0.28, 0.22, 0.15), symbol: "square", mark: "INS", vignette: 0.18, lightLeak: nil, hasPaperEdge: true, blendMode: .softLight)
        case "hncs-natural":
            return .init(colors: [c(0.80, 0.79, 0.69), c(0.52, 0.60, 0.55), c(0.26, 0.29, 0.25)], glow: c(0.94, 0.90, 0.76), glowCenter: .center, ink: c(0.18, 0.18, 0.14), symbol: "h.square", mark: "H", vignette: 0.12, lightLeak: nil, hasPaperEdge: true, blendMode: .softLight)
        case "m-rangefinder":
            return .init(colors: [c(0.68, 0.18, 0.14), c(0.41, 0.38, 0.30), c(0.08, 0.08, 0.07)], glow: c(0.95, 0.52, 0.36), glowCenter: .leading, ink: c(0.98, 0.78, 0.56), symbol: "viewfinder", mark: "M", vignette: 0.34, lightLeak: nil, hasPaperEdge: true, blendMode: .softLight)
        case "t-compact-gold":
            return .init(colors: [c(0.95, 0.73, 0.36), c(0.74, 0.44, 0.27), c(0.20, 0.16, 0.12)], glow: c(1.00, 0.84, 0.44), glowCenter: .top, ink: c(0.21, 0.12, 0.05), symbol: "camera", mark: "T", vignette: 0.25, lightLeak: c(1.00, 0.67, 0.32), hasPaperEdge: true, blendMode: .screen)
        case "gr-street-snap":
            return .init(colors: [c(0.73, 0.76, 0.72), c(0.34, 0.39, 0.40), c(0.05, 0.06, 0.07)], glow: c(0.82, 0.91, 0.89), glowCenter: .bottom, ink: c(0.10, 0.14, 0.14), symbol: "scope", mark: "GR", vignette: 0.26, lightLeak: nil, hasPaperEdge: false, blendMode: .overlay)
        case "classic-chrome-x":
            return .init(colors: [c(0.63, 0.68, 0.64), c(0.43, 0.49, 0.50), c(0.22, 0.24, 0.22)], glow: c(0.77, 0.80, 0.67), glowCenter: .topLeading, ink: c(0.14, 0.16, 0.14), symbol: "newspaper", mark: "CHR", vignette: 0.22, lightLeak: nil, hasPaperEdge: false, blendMode: .softLight)
        case "medium-500c":
            return .init(colors: [c(0.82, 0.74, 0.61), c(0.56, 0.53, 0.45), c(0.24, 0.23, 0.20)], glow: c(0.94, 0.83, 0.63), glowCenter: .center, ink: c(0.18, 0.15, 0.10), symbol: "square.dashed", mark: "500", vignette: 0.15, lightLeak: nil, hasPaperEdge: true, blendMode: .softLight)
        case "holga-120-dream":
            return .init(colors: [c(0.87, 0.63, 0.43), c(0.45, 0.39, 0.48), c(0.10, 0.08, 0.12)], glow: c(1.00, 0.68, 0.46), glowCenter: .topTrailing, ink: c(0.22, 0.10, 0.12), symbol: "camera.macro", mark: "120", vignette: 0.58, lightLeak: c(1.00, 0.36, 0.18), hasPaperEdge: true, blendMode: .screen)
        case "lca-vivid":
            return .init(colors: [c(0.99, 0.42, 0.20), c(0.18, 0.54, 0.43), c(0.08, 0.07, 0.10)], glow: c(1.00, 0.77, 0.30), glowCenter: .bottomLeading, ink: c(0.08, 0.06, 0.05), symbol: "circle.grid.cross", mark: "LC", vignette: 0.48, lightLeak: c(1.00, 0.30, 0.15), hasPaperEdge: false, blendMode: .screen)
        case "instant-wide":
            return .init(colors: [c(0.93, 0.84, 0.66), c(0.69, 0.58, 0.47), c(0.30, 0.27, 0.24)], glow: c(1.00, 0.90, 0.72), glowCenter: .center, ink: c(0.27, 0.21, 0.14), symbol: "rectangle", mark: "WID", vignette: 0.16, lightLeak: nil, hasPaperEdge: true, blendMode: .softLight)
        case "sx-fade":
            return .init(colors: [c(0.92, 0.76, 0.67), c(0.72, 0.68, 0.62), c(0.48, 0.45, 0.44)], glow: c(1.00, 0.86, 0.76), glowCenter: .top, ink: c(0.36, 0.25, 0.20), symbol: "camera.aperture", mark: "SX", vignette: 0.10, lightLeak: c(1.00, 0.70, 0.62), hasPaperEdge: true, blendMode: .softLight)
        case "half-frame-diary":
            return .init(colors: [c(0.86, 0.70, 0.45), c(0.45, 0.57, 0.48), c(0.22, 0.20, 0.16)], glow: c(1.00, 0.78, 0.42), glowCenter: .topLeading, ink: c(0.20, 0.14, 0.06), symbol: "rectangle.split.2x1", mark: "HF", vignette: 0.24, lightLeak: nil, hasPaperEdge: true, blendMode: .softLight)
        case "ektar-vivid-100":
            return .init(colors: [c(0.96, 0.24, 0.16), c(0.18, 0.48, 0.74), c(0.12, 0.20, 0.24)], glow: c(1.00, 0.76, 0.28), glowCenter: .topLeading, ink: c(0.07, 0.08, 0.09), symbol: "mountain.2", mark: "EKT", vignette: 0.18, lightLeak: nil, hasPaperEdge: false, blendMode: .overlay)
        case "tri-x-street":
            return .init(colors: [c(0.92, 0.91, 0.86), c(0.52, 0.52, 0.49), c(0.08, 0.08, 0.08)], glow: c(0.98, 0.96, 0.88), glowCenter: .top, ink: c(0.05, 0.05, 0.05), symbol: "camera.filters", mark: "TRI", vignette: 0.36, lightLeak: nil, hasPaperEdge: true, blendMode: .overlay)
        case "cyber-ccd-blue":
            return .init(colors: [c(0.62, 0.90, 1.00), c(0.21, 0.40, 0.80), c(0.07, 0.09, 0.18)], glow: c(0.52, 0.92, 1.00), glowCenter: .topTrailing, ink: c(0.03, 0.10, 0.26), symbol: "sparkle.magnifyingglass", mark: "CYB", vignette: 0.20, lightLeak: nil, hasPaperEdge: false, blendMode: .screen)
        case "superia-green":
            return .init(colors: [c(0.80, 0.78, 0.37), c(0.22, 0.57, 0.36), c(0.09, 0.18, 0.12)], glow: c(0.93, 0.89, 0.42), glowCenter: .topLeading, ink: c(0.07, 0.17, 0.08), symbol: "leaf", mark: "SUP", vignette: 0.24, lightLeak: nil, hasPaperEdge: false, blendMode: .softLight)
        case "noir-soft":
            return .init(colors: [c(0.76, 0.74, 0.68), c(0.36, 0.35, 0.34), c(0.04, 0.04, 0.045)], glow: c(0.88, 0.85, 0.78), glowCenter: .center, ink: c(0.08, 0.08, 0.08), symbol: "theatermasks", mark: "NOIR", vignette: 0.42, lightLeak: nil, hasPaperEdge: true, blendMode: .softLight)
        default:
            return .init(colors: [c(0.92, 0.67, 0.30), c(0.53, 0.61, 0.44), c(0.18, 0.18, 0.14)], glow: c(1.00, 0.80, 0.46), glowCenter: .center, ink: c(0.18, 0.12, 0.05), symbol: "film", mark: "SL", vignette: 0.22, lightLeak: nil, hasPaperEdge: false, blendMode: .softLight)
        }
    }

    private static func c(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }
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
