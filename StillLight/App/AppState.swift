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
    @Published private(set) var currentRoll: FilmRoll

    let filmLibrary = FilmLibrary()
    private let filmRollStore = FilmRollStore()

    init() {
        let firstFilm = filmLibrary.presets[0]
        selectedFilm = firstFilm
        currentRoll = filmRollStore.loadOrCreate(for: firstFilm)
        photoStore.load()
    }

    func selectFilm(_ film: FilmPreset) {
        selectedFilm = film
        currentRoll = filmRollStore.switchRoll(to: film)
    }

    func recordShot() {
        currentRoll = filmRollStore.recordShot(for: selectedFilm)
    }
}
