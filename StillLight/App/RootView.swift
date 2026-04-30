import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            CameraScreen()
                .tabItem {
                    Label(appState.t(.camera), systemImage: "camera.viewfinder")
                }

            GalleryScreen()
                .tabItem {
                    Label(appState.t(.rollTitle), systemImage: "rectangle.grid.3x2")
                }

            ImportLabScreen()
                .tabItem {
                    Label(appState.t(.lab), systemImage: "wand.and.stars")
                }

            SettingsScreen()
                .tabItem {
                    Label(appState.t(.settings), systemImage: "slider.horizontal.3")
                }
        }
        .tint(StillLightTheme.accent)
    }
}
