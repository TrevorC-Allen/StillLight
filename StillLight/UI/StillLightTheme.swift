import SwiftUI

enum StillLightTheme {
    static let background = Color(red: 0.055, green: 0.059, blue: 0.063)
    static let panel = Color(red: 0.102, green: 0.106, blue: 0.114)
    static let panelElevated = Color(red: 0.145, green: 0.149, blue: 0.157)
    static let text = Color(red: 0.957, green: 0.945, blue: 0.918)
    static let secondaryText = Color(red: 0.655, green: 0.635, blue: 0.604)
    static let accent = Color(red: 0.847, green: 0.635, blue: 0.290)
    static let quietGreen = Color(red: 0.373, green: 0.463, blue: 0.380)
}

extension View {
    func stillLightPanel() -> some View {
        self
            .padding(14)
            .background(StillLightTheme.panel.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
