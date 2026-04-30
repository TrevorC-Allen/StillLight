import PhotosUI
import SwiftUI

struct ImportLabScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ImportLabViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsFilmPicker = false
    @State private var showsShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                StillLightTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        previewArea
                        controls
                        actionArea
                    }
                    .padding(18)
                }
            }
            .navigationTitle(appState.t(.lab))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showsFilmPicker) {
                FilmPickerSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsShareSheet) {
                if let savedRecord = viewModel.savedRecord {
                    ShareSheet(activityItems: [savedRecord.processedURL])
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                viewModel.load(
                    item: newItem,
                    presets: appState.filmLibrary.presets,
                    frameLoadedMessage: appState.t(.frameLoaded)
                )
            }
        }
    }

    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(StillLightTheme.panel)
                .aspectRatio(0.78, contentMode: .fit)

            if let processedImage = viewModel.processedImage {
                Image(uiImage: processedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let originalImage = viewModel.originalImage {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        Color.black.opacity(0.08)
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(StillLightTheme.accent)
                    Text(appState.t(.importFrame))
                        .font(.headline)
                        .foregroundStyle(StillLightTheme.text)
                    Text(appState.t(.importFrameSubtitle))
                        .font(.subheadline)
                        .foregroundStyle(StillLightTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                }
            }

            if viewModel.isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(StillLightTheme.accent)
                    Text(appState.t(.developing))
                        .font(.caption.monospaced())
                        .foregroundStyle(StillLightTheme.secondaryText)
                }
                .stillLightPanel()
            }
        }
    }

    private var controls: some View {
        let importPhotoTitle = appState.t(.importPhoto)
        let selectedFilmTitle = appState.selectedFilm.displayShortName(language: appState.language)

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(importPhotoTitle, systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())

                Button {
                    showsFilmPicker = true
                } label: {
                    Label(selectedFilmTitle, systemImage: "film")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
            }

            HStack {
                Text(appState.t(.strength))
                    .font(.caption)
                    .foregroundStyle(StillLightTheme.secondaryText)
                Slider(value: $viewModel.strength, in: 0.35...1.0, step: 0.05)
                    .tint(StillLightTheme.accent)
                Text("\(Int(viewModel.strength * 100))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(StillLightTheme.secondaryText)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(StillLightTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker(appState.t(.ratio), selection: $viewModel.aspectRatio) {
                ForEach(CaptureAspectRatio.allCases) { ratio in
                    Text(ratio.label).tag(ratio)
                }
            }
            .pickerStyle(.segmented)

            if let recommendation = viewModel.recommendation {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundStyle(StillLightTheme.accent)
                        Text(appState.t(.suggestedRoll))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(StillLightTheme.secondaryText)
                        Spacer()
                        Text(recommendation.metrics.summary)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(StillLightTheme.secondaryText)
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation.film.displayName(language: appState.language))
                                .font(.headline)
                                .foregroundStyle(StillLightTheme.text)
                            Text(recommendation.displayReason(language: appState.language))
                                .font(.caption)
                                .foregroundStyle(StillLightTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Button(appState.t(.use)) {
                            appState.selectFilm(recommendation.film)
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(StillLightTheme.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(StillLightTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .stillLightPanel()
            }
        }
    }

    private var actionArea: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.develop(
                    film: appState.selectedFilm,
                    addTimestamp: appState.addTimestamp,
                    developedWithPrefix: appState.t(.developedWith),
                    language: appState.language
                )
            } label: {
                Label(appState.t(.develop), systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LabButtonStyle(isPrimary: true))
            .disabled(viewModel.originalData == nil || viewModel.isProcessing)

            if viewModel.processedImage != nil {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.save(
                                film: appState.selectedFilm,
                                jpegQuality: appState.jpegQuality,
                                saveOriginal: appState.saveOriginalPhoto,
                                photoStore: appState.photoStore,
                                successMessage: appState.t(.savedToRoll),
                                photosSaveFailedPrefix: appState.t(.photosSaveFailed)
                            )
                        }
                    } label: {
                        Label(appState.t(.save), systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())

                    Button {
                        showsShareSheet = true
                    } label: {
                        Label(appState.t(.share), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())
                    .disabled(viewModel.savedRecord == nil)
                }
            }

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(StillLightTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.78, green: 0.36, blue: 0.33))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
}

@MainActor
final class ImportLabViewModel: ObservableObject {
    @Published var originalData: Data?
    @Published var originalImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var savedRecord: PhotoRecord?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var recommendation: FilmRecommendation?
    @Published var strength = 1.0
    @Published var aspectRatio: CaptureAspectRatio = .ratio3x2

    func load(item: PhotosPickerItem, presets: [FilmPreset], frameLoadedMessage: String) {
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        processedImage = nil
        savedRecord = nil
        recommendation = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw ImportLabError.cannotLoadImage
                }

                originalData = data
                originalImage = image
                recommendation = await Task.detached(priority: .utility) {
                    FilmRecommender.recommend(image: image, presets: presets)
                }.value
                statusMessage = frameLoadedMessage
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    func develop(
        film: FilmPreset,
        addTimestamp: Bool,
        developedWithPrefix: String,
        language: AppLanguage
    ) {
        guard let originalImage else { return }
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        savedRecord = nil

        let aspectRatio = aspectRatio
        let strength = strength

        Task {
            do {
                let output = try await Task.detached(priority: .userInitiated) {
                    try FilmImagePipeline.process(
                        image: originalImage,
                        film: film,
                        aspectRatio: aspectRatio,
                        date: Date(),
                        addTimestamp: addTimestamp,
                        intensity: strength
                    )
                }.value

                processedImage = output
                statusMessage = "\(developedWithPrefix) \(film.displayShortName(language: language))"
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    func save(
        film: FilmPreset,
        jpegQuality: Double,
        saveOriginal: Bool,
        photoStore: PhotoStore,
        successMessage: String,
        photosSaveFailedPrefix: String
    ) async {
        guard let processedImage else { return }
        isProcessing = true
        errorMessage = nil
        statusMessage = nil

        do {
            let exportResult = try await PhotoExporter.export(
                processedImage: processedImage,
                originalData: saveOriginal ? originalData : nil,
                film: film,
                aspectRatio: aspectRatio,
                jpegQuality: jpegQuality,
                photosSaveFailedPrefix: photosSaveFailedPrefix
            )
            savedRecord = exportResult.record
            photoStore.add(exportResult.record)
            statusMessage = exportResult.warningMessage ?? successMessage
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}

private enum ImportLabError: LocalizedError {
    case cannotLoadImage

    var errorDescription: String? {
        "Could not load the selected photo."
    }
}

private struct LabButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(isPrimary ? StillLightTheme.background : StillLightTheme.text)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(isPrimary ? StillLightTheme.accent : StillLightTheme.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
