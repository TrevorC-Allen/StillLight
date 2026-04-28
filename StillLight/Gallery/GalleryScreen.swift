import SwiftUI

struct GalleryScreen: View {
    @EnvironmentObject private var appState: AppState
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                StillLightTheme.background.ignoresSafeArea()

                if appState.photoStore.records.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(appState.photoStore.records) { record in
                                NavigationLink {
                                    PhotoDetailView(record: record)
                                } label: {
                                    GalleryThumbnail(record: record)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .navigationTitle("Roll")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(StillLightTheme.accent)
            Text("First roll is empty")
                .font(.headline)
                .foregroundStyle(StillLightTheme.text)
            Text("Shoot a frame and it will appear here.")
                .font(.subheadline)
                .foregroundStyle(StillLightTheme.secondaryText)
        }
    }
}

private struct GalleryThumbnail: View {
    let record: PhotoRecord

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = UIImage(contentsOfFile: record.processedPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                StillLightTheme.panel
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(StillLightTheme.secondaryText)
            }
        }
        .frame(height: 132)
        .clipped()
    }
}

private struct PhotoDetailView: View {
    @EnvironmentObject private var appState: AppState
    let record: PhotoRecord
    @State private var showsShareSheet = false

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                if let image = UIImage(contentsOfFile: record.processedPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.horizontal, 14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(record.filmName)
                            .font(.headline)
                            .foregroundStyle(StillLightTheme.text)
                        Spacer()
                        Text(record.aspectRatio)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(StillLightTheme.secondaryText)
                    }
                    Text(record.capturedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(StillLightTheme.secondaryText)
                    Text("\(record.width) x \(record.height)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(StillLightTheme.secondaryText)
                }
                .stillLightPanel()
                .padding(.horizontal, 14)

                Spacer()
            }
        }
        .navigationTitle("Frame")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    appState.photoStore.toggleFavorite(record)
                } label: {
                    Image(systemName: record.isFavorite ? "heart.fill" : "heart")
                }

                Button {
                    showsShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showsShareSheet) {
            ShareSheet(activityItems: [record.processedURL])
        }
    }
}
