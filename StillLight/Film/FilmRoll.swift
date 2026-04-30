import Foundation

struct FilmRoll: Identifiable, Codable, Hashable {
    let id: UUID
    let filmPresetId: String
    let filmName: String
    let totalShots: Int
    var usedShots: Int
    var status: FilmRollStatus
    let createdAt: Date
    var finishedAt: Date?

    var remainingShots: Int {
        max(totalShots - usedShots, 0)
    }
}

enum FilmRollStatus: String, Codable, Hashable {
    case active
    case finished
}
