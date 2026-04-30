import Foundation

struct FilmRollStore {
    func loadOrCreate(for film: FilmPreset) -> FilmRoll {
        if let roll = load(), roll.filmPresetId == film.id, roll.status == .active {
            return roll
        }
        let roll = newRoll(for: film)
        save(roll)
        return roll
    }

    func switchRoll(to film: FilmPreset) -> FilmRoll {
        if let roll = load(), roll.filmPresetId == film.id, roll.status == .active {
            return roll
        }
        let roll = newRoll(for: film)
        save(roll)
        return roll
    }

    func recordShot(for film: FilmPreset) -> FilmRoll {
        var roll = loadOrCreate(for: film)
        if roll.remainingShots == 0 {
            roll = newRoll(for: film)
        }

        roll.usedShots = min(roll.usedShots + 1, roll.totalShots)
        if roll.remainingShots == 0 {
            roll.status = .finished
            roll.finishedAt = Date()
        }
        save(roll)
        return roll
    }

    private func newRoll(for film: FilmPreset) -> FilmRoll {
        FilmRoll(
            id: UUID(),
            filmPresetId: film.id,
            filmName: film.name,
            totalShots: film.defaultShotCount,
            usedShots: 0,
            status: .active,
            createdAt: Date(),
            finishedAt: nil
        )
    }

    private func load() -> FilmRoll? {
        do {
            let url = try storeURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder.stillLight.decode(FilmRoll.self, from: data)
        } catch {
            return nil
        }
    }

    private func save(_ roll: FilmRoll) {
        do {
            let url = try storeURL()
            let data = try JSONEncoder.stillLight.encode(roll)
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    private func storeURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("StillLight", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("current_roll.json")
    }
}

private extension JSONEncoder {
    static var stillLight: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var stillLight: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
