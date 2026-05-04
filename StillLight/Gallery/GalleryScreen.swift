import SwiftUI

struct GalleryScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GalleryContent(photoStore: appState.photoStore)
            .environmentObject(appState)
    }
}

private enum GalleryFilter: String, CaseIterable, Identifiable {
    case all
    case favorites

    var id: String { rawValue }
}

private struct GalleryContent: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var photoStore: PhotoStore
    @State private var filter: GalleryFilter = .all

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                StillLightTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    filterPicker

                    if filteredRecords.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(filteredRecords) { record in
                                    NavigationLink {
                                        PhotoDetailView(record: record, photoStore: photoStore)
                                    } label: {
                                        GalleryThumbnail(record: record)
                                    }
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
            .navigationTitle(appState.t(.rollTitle))
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var filteredRecords: [PhotoRecord] {
        switch filter {
        case .all:
            return photoStore.records
        case .favorites:
            return photoStore.records.filter(\.isFavorite)
        }
    }

    private var filterPicker: some View {
        Picker("", selection: $filter) {
            Text(appState.t(.all)).tag(GalleryFilter.all)
            Text(appState.t(.favorites)).tag(GalleryFilter.favorites)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyStateIconName)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(StillLightTheme.accent)
            Text(appState.t(emptyTitleKey))
                .font(.headline)
                .foregroundStyle(StillLightTheme.text)
            Text(appState.t(emptySubtitleKey))
                .font(.subheadline)
                .foregroundStyle(StillLightTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private var emptyStateIconName: String {
        filter == .favorites ? "heart" : "film.stack"
    }

    private var emptyTitleKey: AppText.Key {
        filter == .favorites ? .favoritesEmpty : .firstRollEmpty
    }

    private var emptySubtitleKey: AppText.Key {
        filter == .favorites ? .favoritesEmptySubtitle : .firstRollEmptySubtitle
    }
}

private struct GalleryThumbnail: View {
    let record: PhotoRecord

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(contentsOfFile: record.processedPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    StillLightTheme.panel
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(StillLightTheme.secondaryText)
                }
            }

            if record.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StillLightTheme.accent)
                    .padding(7)
                    .background(StillLightTheme.panel.opacity(0.82))
                    .clipShape(Circle())
                    .padding(6)
            }
        }
        .frame(height: 132)
        .clipped()
    }
}

private struct PhotoDetailView: View {
    @EnvironmentObject private var appState: AppState
    let record: PhotoRecord
    @ObservedObject var photoStore: PhotoStore
    @State private var showsShareSheet = false
    @State private var showsOriginal = false

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                if let image = displayedImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
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
                    .onLongPressGesture(
                        minimumDuration: 0.16,
                        pressing: { isPressing in
                            guard originalImage != nil else { return }
                            withAnimation(.easeOut(duration: 0.12)) {
                                showsOriginal = isPressing
                            }
                        },
                        perform: {}
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(displayFilmName)
                            .font(.headline)
                            .foregroundStyle(StillLightTheme.text)
                        Spacer()
                        Text(currentRecord.aspectRatio)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(StillLightTheme.secondaryText)
                    }
                    Text(currentRecord.capturedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(StillLightTheme.secondaryText)
                    Text("\(currentRecord.width) x \(currentRecord.height)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(StillLightTheme.secondaryText)
                }
                .stillLightPanel()
                .padding(.horizontal, 14)

                Spacer()
            }
        }
        .navigationTitle(appState.t(.frame))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        photoStore.toggleFavorite(currentRecord)
                    }
                } label: {
                    Image(systemName: currentRecord.isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(appState.t(currentRecord.isFavorite ? .removeFavorite : .addFavorite))

                Button {
                    showsShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showsShareSheet) {
            ShareSheet(activityItems: [currentRecord.processedURL])
        }
    }

    private var currentRecord: PhotoRecord {
        photoStore.record(id: record.id) ?? record
    }

    private var processedImage: UIImage? {
        UIImage(contentsOfFile: currentRecord.processedPath)
    }

    private var originalImage: UIImage? {
        guard let originalURL = currentRecord.originalURL else { return nil }
        return UIImage(contentsOfFile: originalURL.path)
    }

    private var displayedImage: UIImage? {
        if showsOriginal, let originalImage {
            return originalImage
        }
        return processedImage
    }

    private var displayFilmName: String {
        appState.filmLibrary.presets
            .first { $0.id == currentRecord.filmPresetId }?
            .displayName(language: appState.language) ?? currentRecord.filmName
    }
}
