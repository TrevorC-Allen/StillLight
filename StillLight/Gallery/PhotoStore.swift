import Foundation

@MainActor
final class PhotoStore: ObservableObject {
    @Published private(set) var records: [PhotoRecord] = []

    func load() {
        do {
            let url = try storeURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            records = try JSONDecoder.stillLight.decode([PhotoRecord].self, from: data)
        } catch {
            records = []
        }
    }

    func add(_ record: PhotoRecord) {
        records.insert(record, at: 0)
        save()
    }

    func record(id: UUID) -> PhotoRecord? {
        records.first { $0.id == id }
    }

    func isFavorite(_ record: PhotoRecord) -> Bool {
        self.record(id: record.id)?.isFavorite ?? record.isFavorite
    }

    func toggleFavorite(_ record: PhotoRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index].isFavorite.toggle()
        save()
    }

    private func save() {
        do {
            let url = try storeURL()
            let data = try JSONEncoder.stillLight.encode(records)
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
        return directory.appendingPathComponent("photo_records.json")
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
