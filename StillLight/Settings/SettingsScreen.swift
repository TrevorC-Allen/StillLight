import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                StillLightTheme.background.ignoresSafeArea()

                Form {
                    Section("Output") {
                        Toggle("Save original photo", isOn: $appState.saveOriginalPhoto)
                        Toggle("Add date stamp", isOn: $appState.addTimestamp)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("JPEG quality")
                                Spacer()
                                Text("\(Int(appState.jpegQuality * 100))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(StillLightTheme.secondaryText)
                            }
                            Slider(value: $appState.jpegQuality, in: 0.75...0.98, step: 0.01)
                        }
                    }

                    Section("Camera") {
                        Toggle("Haptic shutter", isOn: $appState.enableHaptics)
                        Toggle("Grid lines", isOn: $appState.showGrid)
                        Toggle("Horizon level", isOn: $appState.showLevel)
                        Picker("Default ratio", selection: $appState.selectedAspectRatio) {
                            ForEach(CaptureAspectRatio.allCases) { ratio in
                                Text(ratio.label).tag(ratio)
                            }
                        }
                    }

                    Section("MVP") {
                        LabeledContent("Pipeline") {
                            Text("CoreImage + Grain")
                        }
                        LabeledContent("Presets") {
                            Text("\(appState.filmLibrary.presets.count)")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
