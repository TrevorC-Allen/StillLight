import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedFilm: FilmPreset
    @Published var selectedAspectRatio: CaptureAspectRatio = .ratio3x2
    @Published var saveOriginalPhoto = true
    @Published var addTimestamp = true
    @Published var enableHaptics = true
    @Published var showGrid = true
    @Published var showLevel = true
    @Published var jpegQuality: Double = 0.93
    @Published var photoStore = PhotoStore()

    let filmLibrary = FilmLibrary()

    init() {
        selectedFilm = filmLibrary.presets[0]
        photoStore.load()
    }
}
