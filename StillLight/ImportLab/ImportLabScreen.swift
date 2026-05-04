import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct ImportLabScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ImportLabViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsFilmPicker = false
    @State private var showsShareSheet = false
    @State private var showsOriginalPreview = false

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
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                viewModel.load(
                    items: newItems,
                    presets: appState.filmLibrary.presets,
                    framesLoadedFormat: appState.t(.framesLoaded)
                )
            }
            .onChange(of: viewModel.selectedFrame?.id) { _, _ in
                showsOriginalPreview = false
            }
        }
    }

    private var previewArea: some View {
        let selectedFrame = viewModel.selectedFrame
        let isComparingOriginal = showsOriginalPreview && selectedFrame?.processedImage != nil
        let previewImage = isComparingOriginal ? selectedFrame?.originalImage : (selectedFrame?.processedImage ?? selectedFrame?.originalImage)

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(StillLightTheme.panel)
                .aspectRatio(0.78, contentMode: .fit)

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        if selectedFrame?.processedImage == nil {
                            Color.black.opacity(0.08)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onLongPressGesture(
                        minimumDuration: 0.18,
                        maximumDistance: 80,
                        pressing: { pressing in
                            guard selectedFrame?.processedImage != nil else { return }
                            withAnimation(.easeInOut(duration: 0.12)) {
                                showsOriginalPreview = pressing
                            }
                        },
                        perform: {}
                    )
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

            if let number = viewModel.selectedFrameNumber {
                VStack {
                    HStack {
                        if selectedFrame?.processedImage != nil {
                            Text(isComparingOriginal ? appState.t(.original) : appState.t(.developed))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(StillLightTheme.text)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(StillLightTheme.panel.opacity(0.82))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        Spacer()
                        Text("\(number)/\(viewModel.frames.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(StillLightTheme.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(StillLightTheme.panel.opacity(0.82))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    Spacer()
                }
                .padding(12)
            }

            if viewModel.isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(StillLightTheme.accent)
                    Text(viewModel.processingMessage ?? appState.t(.developing))
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
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 12, matching: .images) {
                    Label(importPhotoTitle, systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
                .disabled(viewModel.isProcessing)

                Button {
                    showsFilmPicker = true
                } label: {
                    Label(selectedFilmTitle, systemImage: "film")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
                .disabled(viewModel.isProcessing)
            }

            thumbnailStrip

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

            if let recommendation = viewModel.selectedRecommendation {
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

    @ViewBuilder
    private var thumbnailStrip: some View {
        if !viewModel.frames.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(String(format: appState.t(.selectedFrames), viewModel.frames.count))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StillLightTheme.secondaryText)
                    Spacer()
                    if viewModel.hasAnyProcessedImage {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(StillLightTheme.accent)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(viewModel.frames) { frame in
                            Button {
                                viewModel.selectFrame(frame.id)
                            } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    Image(uiImage: frame.processedImage ?? frame.originalImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 58, height: 74)
                                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .stroke(
                                                    frame.id == viewModel.selectedFrame?.id ? StillLightTheme.accent : Color.white.opacity(0.10),
                                                    lineWidth: frame.id == viewModel.selectedFrame?.id ? 2 : 1
                                                )
                                        }

                                    if frame.processingError != nil {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color(red: 0.78, green: 0.36, blue: 0.33))
                                            .padding(5)
                                    } else if frame.processedImage != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(StillLightTheme.accent)
                                            .padding(5)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .stillLightPanel()
        }
    }

    private var actionArea: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    viewModel.developSelected(
                        film: appState.selectedFilm,
                        addTimestamp: appState.addTimestamp,
                        developedWithPrefix: appState.t(.developedWith),
                        language: appState.language
                    )
                } label: {
                    Label(appState.t(.developCurrent), systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isPrimary: true))
                .disabled(!viewModel.hasSelectedFrame || viewModel.isProcessing)

                Button {
                    viewModel.developAll(
                        film: appState.selectedFilm,
                        addTimestamp: appState.addTimestamp,
                        developedWithPrefix: appState.t(.developedWith),
                        progressFormat: appState.t(.developingFrameProgress),
                        cancelledFormat: appState.t(.batchDevelopCancelled),
                        completedFormat: appState.t(.batchDevelopedFrames),
                        language: appState.language
                    )
                } label: {
                    Label(appState.t(.developAll), systemImage: "rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
                .disabled(viewModel.frames.isEmpty || viewModel.isProcessing)
            }

            if viewModel.isBatchDeveloping {
                Button {
                    viewModel.cancelBatchDevelop()
                } label: {
                    Label(appState.t(.cancelDevelop), systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
            }

            if viewModel.hasSelectedFailedFrame {
                Button {
                    viewModel.developSelected(
                        film: appState.selectedFilm,
                        addTimestamp: appState.addTimestamp,
                        developedWithPrefix: appState.t(.developedWith),
                        language: appState.language
                    )
                } label: {
                    Label(appState.t(.tryAgain), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
                .disabled(!viewModel.hasSelectedFrame || viewModel.isProcessing)
            }

            if viewModel.hasAnyProcessedImage {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.saveSelected(
                                film: appState.selectedFilm,
                                jpegQuality: appState.jpegQuality,
                                saveOriginal: appState.saveOriginalPhoto,
                                photoStore: appState.photoStore,
                                successMessage: appState.t(.savedToRoll),
                                photosSaveFailedPrefix: appState.t(.photosSaveFailed)
                            )
                        }
                    } label: {
                        Label(appState.t(.saveCurrent), systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())
                    .disabled(!viewModel.hasSelectedProcessedImage || viewModel.isProcessing)

                    Button {
                        Task {
                            await viewModel.saveAll(
                                film: appState.selectedFilm,
                                jpegQuality: appState.jpegQuality,
                                saveOriginal: appState.saveOriginalPhoto,
                                photoStore: appState.photoStore,
                                successFormat: appState.t(.savedFrames),
                                progressFormat: appState.t(.savingFrame),
                                photosSaveFailedPrefix: appState.t(.photosSaveFailed)
                            )
                        }
                    } label: {
                        Label(appState.t(.saveAll), systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())
                    .disabled(!viewModel.hasAnyProcessedImage || viewModel.isProcessing)
                }

                Button {
                    showsShareSheet = true
                } label: {
                    Label(appState.t(.share), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
                .disabled(viewModel.savedRecord == nil || viewModel.isProcessing)
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
            } else if let processingError = viewModel.selectedFrame?.processingError {
                Text(processingError)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.78, green: 0.36, blue: 0.33))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
}

private struct ImportLabFrame: Identifiable {
    let id = UUID()
    let originalData: Data
    let originalImage: UIImage
    var processedImage: UIImage?
    var savedRecord: PhotoRecord?
    var recommendation: FilmRecommendation?
    var processingError: String?
}

@MainActor
private final class ImportLabViewModel: ObservableObject {
    @Published var frames: [ImportLabFrame] = []
    @Published var selectedFrameID: UUID?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var processingMessage: String?
    @Published var strength = 1.0
    @Published var aspectRatio: CaptureAspectRatio = .ratio3x2
    @Published private(set) var isBatchDeveloping = false

    private var activeLoadID = UUID()
    private var batchDevelopTask: Task<Void, Never>?

    var selectedFrame: ImportLabFrame? {
        guard let selectedFrameID else { return frames.first }
        return frames.first { $0.id == selectedFrameID } ?? frames.first
    }

    var selectedFrameNumber: Int? {
        guard let selectedIndex else { return nil }
        return selectedIndex + 1
    }

    var selectedRecommendation: FilmRecommendation? {
        selectedFrame?.recommendation
    }

    var savedRecord: PhotoRecord? {
        selectedFrame?.savedRecord
    }

    var hasSelectedFrame: Bool {
        selectedFrame != nil
    }

    var hasSelectedProcessedImage: Bool {
        selectedFrame?.processedImage != nil
    }

    var hasSelectedFailedFrame: Bool {
        selectedFrame?.processingError != nil
    }

    var hasAnyProcessedImage: Bool {
        frames.contains { $0.processedImage != nil }
    }

    private var selectedIndex: Int? {
        guard let selectedFrameID else {
            return frames.isEmpty ? nil : 0
        }
        return frames.firstIndex { $0.id == selectedFrameID } ?? (frames.isEmpty ? nil : 0)
    }

    func selectFrame(_ id: UUID) {
        selectedFrameID = id
        statusMessage = nil
        errorMessage = nil
    }

    func load(
        items: [PhotosPickerItem],
        presets: [FilmPreset],
        framesLoadedFormat: String
    ) {
        let loadID = UUID()
        activeLoadID = loadID
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        processingMessage = nil

        Task {
            do {
                var loadedFrames: [ImportLabFrame] = []

                for (offset, item) in items.enumerated() {
                    guard activeLoadID == loadID else { return }
                    processingMessage = "\(offset + 1)/\(items.count)"

                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = Self.previewImage(from: data) else {
                        continue
                    }

                    let recommendation = await Task.detached(priority: .utility) {
                        FilmRecommender.recommend(image: image, presets: presets)
                    }.value
                    loadedFrames.append(
                        ImportLabFrame(
                            originalData: data,
                            originalImage: image,
                            recommendation: recommendation
                        )
                    )
                }

                guard activeLoadID == loadID else { return }
                guard !loadedFrames.isEmpty else {
                    throw ImportLabError.cannotLoadImage
                }

                frames = loadedFrames
                selectedFrameID = loadedFrames.first?.id
                statusMessage = String(format: framesLoadedFormat, loadedFrames.count)
            } catch {
                errorMessage = error.localizedDescription
            }

            processingMessage = nil
            isProcessing = false
        }
    }

    func developSelected(
        film: FilmPreset,
        addTimestamp: Bool,
        developedWithPrefix: String,
        language: AppLanguage
    ) {
        guard let selectedIndex else { return }
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        processingMessage = nil

        let aspectRatio = aspectRatio
        let strength = strength
        let sourceFrame = frames[selectedIndex]
        let sourceFrameID = sourceFrame.id
        updateFrame(at: selectedIndex) { frame in
            frame.processingError = nil
        }

        Task {
            do {
                let output = try await render(
                    frame: sourceFrame,
                    film: film,
                    aspectRatio: aspectRatio,
                    addTimestamp: addTimestamp,
                    strength: strength
                )
                if let index = frames.firstIndex(where: { $0.id == sourceFrameID }) {
                    updateFrame(at: index) { frame in
                        frame.processedImage = output
                        frame.savedRecord = nil
                        frame.processingError = nil
                    }
                }
                statusMessage = "\(developedWithPrefix) \(film.displayShortName(language: language))"
            } catch {
                if let index = frames.firstIndex(where: { $0.id == sourceFrameID }) {
                    updateFrame(at: index) { frame in
                        frame.processingError = error.localizedDescription
                    }
                }
                errorMessage = error.localizedDescription
            }

            isProcessing = false
        }
    }

    func cancelBatchDevelop() {
        batchDevelopTask?.cancel()
    }

    func developAll(
        film: FilmPreset,
        addTimestamp: Bool,
        developedWithPrefix: String,
        progressFormat: String,
        cancelledFormat: String,
        completedFormat: String,
        language: AppLanguage
    ) {
        guard !frames.isEmpty else { return }
        batchDevelopTask?.cancel()
        isProcessing = true
        isBatchDeveloping = true
        errorMessage = nil
        statusMessage = nil

        let aspectRatio = aspectRatio
        let strength = strength
        let sourceFrames = frames
        let totalCount = sourceFrames.count

        batchDevelopTask = Task {
            var completedCount = 0
            var successCount = 0
            var failedCount = 0
            var wasCancelled = false

            for (offset, frame) in sourceFrames.enumerated() {
                if Task.isCancelled {
                    wasCancelled = true
                    break
                }

                if let index = frames.firstIndex(where: { $0.id == frame.id }) {
                    updateFrame(at: index) { editableFrame in
                        editableFrame.processingError = nil
                    }
                }

                processingMessage = String(
                    format: progressFormat,
                    offset + 1,
                    totalCount,
                    successCount,
                    failedCount
                )

                do {
                    let output = try await render(
                        frame: frame,
                        film: film,
                        aspectRatio: aspectRatio,
                        addTimestamp: addTimestamp,
                        strength: strength
                    )

                    if Task.isCancelled {
                        wasCancelled = true
                        break
                    }

                    if let index = frames.firstIndex(where: { $0.id == frame.id }) {
                        updateFrame(at: index) { editableFrame in
                            editableFrame.processedImage = output
                            editableFrame.savedRecord = nil
                            editableFrame.processingError = nil
                        }
                    }
                    successCount += 1
                } catch is CancellationError {
                    wasCancelled = true
                    break
                } catch {
                    if let index = frames.firstIndex(where: { $0.id == frame.id }) {
                        updateFrame(at: index) { editableFrame in
                            editableFrame.processingError = error.localizedDescription
                        }
                    }
                    failedCount += 1
                }

                completedCount += 1
                processingMessage = String(
                    format: progressFormat,
                    min(offset + 2, totalCount),
                    totalCount,
                    successCount,
                    failedCount
                )
            }

            if wasCancelled {
                statusMessage = String(format: cancelledFormat, completedCount, totalCount, successCount, failedCount)
            } else {
                statusMessage = "\(developedWithPrefix) \(film.displayShortName(language: language)) · "
                    + String(format: completedFormat, successCount, totalCount, failedCount)
            }

            processingMessage = nil
            isBatchDeveloping = false
            isProcessing = false
            batchDevelopTask = nil
        }
    }

    func saveSelected(
        film: FilmPreset,
        jpegQuality: Double,
        saveOriginal: Bool,
        photoStore: PhotoStore,
        successMessage: String,
        photosSaveFailedPrefix: String
    ) async {
        guard let selectedIndex, let processedImage = frames[selectedIndex].processedImage else { return }
        isProcessing = true
        errorMessage = nil
        statusMessage = nil

        do {
            let frame = frames[selectedIndex]
            let exportResult = try await PhotoExporter.export(
                processedImage: processedImage,
                originalData: saveOriginal ? frame.originalData : nil,
                film: film,
                aspectRatio: aspectRatio,
                jpegQuality: jpegQuality,
                photosSaveFailedPrefix: photosSaveFailedPrefix
            )
            updateFrame(at: selectedIndex) { editableFrame in
                editableFrame.savedRecord = exportResult.record
            }
            photoStore.add(exportResult.record)
            statusMessage = exportResult.warningMessage ?? successMessage
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func saveAll(
        film: FilmPreset,
        jpegQuality: Double,
        saveOriginal: Bool,
        photoStore: PhotoStore,
        successFormat: String,
        progressFormat: String,
        photosSaveFailedPrefix: String
    ) async {
        let framesToSave = frames.filter { $0.processedImage != nil }
        guard !framesToSave.isEmpty else { return }

        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        var savedCount = 0
        var latestWarning: String?

        do {
            for (offset, frame) in framesToSave.enumerated() {
                guard let processedImage = frame.processedImage else { continue }
                processingMessage = String(format: progressFormat, offset + 1, framesToSave.count)
                let exportResult = try await PhotoExporter.export(
                    processedImage: processedImage,
                    originalData: saveOriginal ? frame.originalData : nil,
                    film: film,
                    aspectRatio: aspectRatio,
                    jpegQuality: jpegQuality,
                    photosSaveFailedPrefix: photosSaveFailedPrefix
                )
                if let index = frames.firstIndex(where: { $0.id == frame.id }) {
                    updateFrame(at: index) { editableFrame in
                        editableFrame.savedRecord = exportResult.record
                    }
                }
                photoStore.add(exportResult.record)
                savedCount += 1
                latestWarning = exportResult.warningMessage ?? latestWarning
            }

            statusMessage = latestWarning ?? String(format: successFormat, savedCount)
        } catch {
            errorMessage = error.localizedDescription
        }

        processingMessage = nil
        isProcessing = false
    }

    private func render(
        frame: ImportLabFrame,
        film: FilmPreset,
        aspectRatio: CaptureAspectRatio,
        addTimestamp: Bool,
        strength: Double
    ) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            try FilmImagePipeline.process(
                image: frame.originalImage,
                film: film,
                aspectRatio: aspectRatio,
                date: Date(),
                addTimestamp: addTimestamp,
                intensity: strength
            )
        }.value
    }

    private func updateFrame(at index: Int, update: (inout ImportLabFrame) -> Void) {
        guard frames.indices.contains(index) else { return }
        var frame = frames[index]
        update(&frame)
        frames[index] = frame
    }

    private static func previewImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2200
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
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
