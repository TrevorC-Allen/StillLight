import SwiftUI

struct ResultView: View {
    let result: CaptureResult
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showsShareSheet = false
    @GestureState private var showsOriginal = false

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.t(.developed))
                            .font(.headline)
                            .foregroundStyle(StillLightTheme.text)
                        Text(displayFilmName)
                            .font(.subheadline)
                            .foregroundStyle(StillLightTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(StillLightTheme.panelElevated)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                ZStack(alignment: .topTrailing) {
                    Image(uiImage: displayedImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if showsOriginal, originalImage != nil {
                        Text(appState.t(.original))
                            .font(.caption.monospaced())
                            .foregroundStyle(StillLightTheme.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(StillLightTheme.panel.opacity(0.82))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(10)
                    }
                }
                .padding(.horizontal, 14)
                .animation(.easeOut(duration: 0.12), value: showsOriginal)
                .simultaneousGesture(originalCompareGesture)

                HStack(spacing: 12) {
                    Button {
                        showsShareSheet = true
                    } label: {
                        Label(appState.t(.share), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ResultButtonStyle())

                    Button {
                        dismiss()
                    } label: {
                        Label(appState.t(.done), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ResultButtonStyle(isPrimary: true))
                }
                .padding(.horizontal, 18)

                if let warningMessage = result.warningMessage {
                    Text(warningMessage)
                        .font(.footnote)
                        .foregroundStyle(StillLightTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .stillLightPanel()
                        .padding(.horizontal, 18)
                } else {
                    Text(appState.t(.savedToPhotosAndRoll))
                        .font(.footnote)
                        .foregroundStyle(StillLightTheme.secondaryText)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showsShareSheet) {
            ShareSheet(activityItems: [result.record.processedURL])
        }
    }

    private var originalImage: UIImage? {
        guard let originalURL = result.record.originalURL else { return nil }
        return UIImage(contentsOfFile: originalURL.path)
    }

    private var displayedImage: UIImage {
        if showsOriginal, let originalImage {
            return originalImage
        }
        return result.image
    }

    private var displayFilmName: String {
        appState.filmLibrary.presets
            .first { $0.id == result.record.filmPresetId }?
            .displayName(language: appState.language) ?? result.record.filmName
    }

    private var originalCompareGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.28, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($showsOriginal) { value, state, _ in
                guard originalImage != nil else { return }
                switch value {
                case .second(true, _):
                    state = true
                default:
                    state = false
                }
            }
    }
}

private struct ResultButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(isPrimary ? StillLightTheme.background : StillLightTheme.text)
            .padding(.vertical, 14)
            .background(isPrimary ? StillLightTheme.accent : StillLightTheme.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
