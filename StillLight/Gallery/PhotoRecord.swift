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

    init(
        id: UUID,
        originalPath: String?,
        processedPath: String,
        filmPresetId: String,
        filmName: String,
        aspectRatio: String,
        capturedAt: Date,
        width: Int,
        height: Int,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.originalPath = originalPath
        self.processedPath = processedPath
        self.filmPresetId = filmPresetId
        self.filmName = filmName
        self.aspectRatio = aspectRatio
        self.capturedAt = capturedAt
        self.width = width
        self.height = height
        self.isFavorite = isFavorite
    }

    var processedURL: URL {
        URL(fileURLWithPath: processedPath)
    }

    var originalURL: URL? {
        originalPath.map(URL.init(fileURLWithPath:))
    }
}

extension PhotoRecord {
    private enum CodingKeys: String, CodingKey {
        case id
        case originalPath
        case processedPath
        case filmPresetId
        case filmName
        case aspectRatio
        case capturedAt
        case width
        case height
        case isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        originalPath = try container.decodeIfPresent(String.self, forKey: .originalPath)
        processedPath = try container.decode(String.self, forKey: .processedPath)
        filmPresetId = try container.decode(String.self, forKey: .filmPresetId)
        filmName = try container.decode(String.self, forKey: .filmName)
        aspectRatio = try container.decode(String.self, forKey: .aspectRatio)
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}
