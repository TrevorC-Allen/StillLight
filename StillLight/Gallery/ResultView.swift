import SwiftUI

struct ResultView: View {
    let result: CaptureResult
    @Environment(\.dismiss) private var dismiss
    @State private var showsShareSheet = false

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Developed")
                            .font(.headline)
                            .foregroundStyle(StillLightTheme.text)
                        Text(result.record.filmName)
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

                Image(uiImage: result.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 14)

                HStack(spacing: 12) {
                    Button {
                        showsShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ResultButtonStyle())

                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
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
                    Text("Saved to Photos and StillLight Roll")
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
