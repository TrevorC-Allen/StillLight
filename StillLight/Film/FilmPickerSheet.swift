import SwiftUI

struct FilmPickerSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    ForEach(appState.filmLibrary.presets) { film in
                        Button {
                            appState.selectedFilm = film
                            dismiss()
                        } label: {
                            FilmPresetRow(
                                film: film,
                                isSelected: film.id == appState.selectedFilm.id
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
            Text("Film Roll")
                .font(.title2.weight(.semibold))
                .foregroundStyle(StillLightTheme.text)
            Text("Choose before shooting. The roll defines color, contrast, grain, and timestamp behavior.")
                .font(.subheadline)
                .foregroundStyle(StillLightTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }
}

private struct FilmPresetRow: View {
    let film: FilmPreset
    let isSelected: Bool

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
                    Text(film.name)
                        .font(.headline)
                        .foregroundStyle(StillLightTheme.text)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(StillLightTheme.accent)
                    }
                }
                Text(film.description)
                    .font(.subheadline)
                    .foregroundStyle(StillLightTheme.secondaryText)
                    .lineLimit(2)
                Text(film.metadataLine)
                    .font(.caption.monospaced())
                    .foregroundStyle(StillLightTheme.accent)
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
