import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                StillLightTheme.background.ignoresSafeArea()

                Form {
                    Section(appState.t(.language)) {
                        Picker(appState.t(.language), selection: $appState.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(appState.t(.output)) {
                        Toggle(appState.t(.saveOriginalPhoto), isOn: $appState.saveOriginalPhoto)
                        Toggle(appState.t(.addDateStamp), isOn: $appState.addTimestamp)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(appState.t(.jpegQuality))
                                Spacer()
                                Text("\(Int(appState.jpegQuality * 100))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(StillLightTheme.secondaryText)
                            }
                            Slider(value: $appState.jpegQuality, in: 0.75...0.98, step: 0.01)
                        }
                    }

                    Section(appState.t(.camera)) {
                        Toggle(appState.t(.hapticShutter), isOn: $appState.enableHaptics)
                        Toggle(appState.t(.gridLines), isOn: $appState.showGrid)
                        Toggle(appState.t(.horizonLevel), isOn: $appState.showLevel)
                        Picker(appState.t(.defaultRatio), selection: $appState.selectedAspectRatio) {
                            ForEach(CaptureAspectRatio.allCases) { ratio in
                                Text(ratio.label).tag(ratio)
                            }
                        }
                    }

                    Section(appState.t(.styleLibrary)) {
                        LabeledContent(appState.t(.pipeline)) {
                            Text("CoreImage + Grain")
                        }
                        LabeledContent(appState.t(.presets)) {
                            Text("\(appState.filmLibrary.presets.count)")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(appState.t(.settings))
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
