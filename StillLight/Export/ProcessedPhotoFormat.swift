import UniformTypeIdentifiers

enum ProcessedPhotoFormat: String, CaseIterable, Identifiable, Codable {
    case pngLossless
    case jpegHighQuality

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .pngLossless:
            return "png"
        case .jpegHighQuality:
            return "jpg"
        }
    }

    var utType: UTType {
        switch self {
        case .pngLossless:
            return .png
        case .jpegHighQuality:
            return .jpeg
        }
    }
}
