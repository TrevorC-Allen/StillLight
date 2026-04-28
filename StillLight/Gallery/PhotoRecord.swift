import Foundation

struct PhotoRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let originalPath: String?
    let processedPath: String
    let filmPresetId: String
    let filmName: String
    let aspectRatio: String
    let capturedAt: Date
    let width: Int
    let height: Int
    var isFavorite: Bool

    var processedURL: URL {
        URL(fileURLWithPath: processedPath)
    }

    var originalURL: URL? {
        originalPath.map(URL.init(fileURLWithPath:))
    }
}
