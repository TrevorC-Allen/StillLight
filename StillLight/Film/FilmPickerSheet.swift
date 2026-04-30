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
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(sampleGradient)
                    .frame(width: 62, height: 78)
                VStack(spacing: 4) {
                    Text("\(film.iso)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("ISO")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.black.opacity(0.68))
            }

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

    private var sampleGradient: LinearGradient {
        switch film.id {
        case "soft-portrait-400":
            return LinearGradient(colors: [
                Color(red: 0.83, green: 0.69, blue: 0.55),
                Color(red: 0.55, green: 0.65, blue: 0.61)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "silver-hp5":
            return LinearGradient(colors: [
                Color(red: 0.82, green: 0.80, blue: 0.74),
                Color(red: 0.24, green: 0.24, blue: 0.23)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [
                Color(red: 0.92, green: 0.67, blue: 0.30),
                Color(red: 0.53, green: 0.61, blue: 0.44)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
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
