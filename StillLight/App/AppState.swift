import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedFilm: FilmPreset
    @Published var selectedAspectRatio: CaptureAspectRatio = .ratio3x2
    @Published var saveOriginalPhoto = true
    @Published var fidelityMode: Bool {
        didSet {
            UserDefaults.standard.set(fidelityMode, forKey: Self.fidelityModeKey)
        }
    }
    @Published var addTimestamp = true
    @Published var enableHaptics = true
    @Published var showGrid = true
    @Published var showLevel = true
    @Published var jpegQuality: Double = 0.98
    @Published var photoStore = PhotoStore()
    @Published private(set) var currentRoll: FilmRoll
    @Published private(set) var favoriteFilmIds: Set<String> = [] {
        didSet {
            persistFavoriteFilmIds()
        }
    }
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    let filmLibrary = FilmLibrary()
    private let filmRollStore = FilmRollStore()
    private static let languageKey = "StillLight.language"
    private static let favoriteFilmIdsKey = "StillLight.favoriteFilmIds"
    private static let fidelityModeKey = "StillLight.fidelityMode"
    static let fidelityFilmIntensity = 0.62

    init() {
        let firstFilm = filmLibrary.presets[0]
        selectedFilm = firstFilm
        currentRoll = filmRollStore.loadOrCreate(for: firstFilm)
        let storedLanguage = UserDefaults.standard.string(forKey: Self.languageKey)
        language = storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? Self.defaultLanguage
        fidelityMode = UserDefaults.standard.object(forKey: Self.fidelityModeKey) as? Bool ?? true
        favoriteFilmIds = Self.loadFavoriteFilmIds(from: UserDefaults.standard, library: filmLibrary)
        persistFavoriteFilmIds()
        photoStore.load()
    }

    var effectiveFilmIntensity: Double {
        fidelityMode ? Self.fidelityFilmIntensity : 1.0
    }

    var effectiveSaveOriginalPhoto: Bool {
        fidelityMode || saveOriginalPhoto
    }

    var effectiveJPEGQuality: Double {
        fidelityMode ? max(jpegQuality, 0.98) : jpegQuality
    }

    func selectFilm(_ film: FilmPreset) {
        selectedFilm = film
        currentRoll = filmRollStore.switchRoll(to: film)
    }

    func isFavorite(_ film: FilmPreset) -> Bool {
        favoriteFilmIds.contains(film.id)
    }

    func toggleFavorite(_ film: FilmPreset) {
        var nextFavorites = favoriteFilmIds
        if nextFavorites.contains(film.id) {
            nextFavorites.remove(film.id)
        } else {
            nextFavorites.insert(film.id)
        }
        favoriteFilmIds = nextFavorites
    }

    func recordShot() {
        currentRoll = filmRollStore.recordShot(for: selectedFilm)
    }

    func t(_ key: AppText.Key) -> String {
        AppText.get(key, language: language)
    }

    private static func loadFavoriteFilmIds(from defaults: UserDefaults, library: FilmLibrary) -> Set<String> {
        let storedIds = Set(defaults.stringArray(forKey: favoriteFilmIdsKey) ?? [])
        return storedIds.intersection(library.presetIds)
    }

    private static var defaultLanguage: AppLanguage {
        guard let preferredLanguage = Locale.preferredLanguages.first else {
            return .english
        }
        return preferredLanguage.lowercased().hasPrefix("zh") ? .chinese : .english
    }

    private func persistFavoriteFilmIds() {
        UserDefaults.standard.set(favoriteFilmIds.sorted(), forKey: Self.favoriteFilmIdsKey)
    }
}
