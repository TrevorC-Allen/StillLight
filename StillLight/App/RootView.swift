import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            CameraScreen()
                .tabItem {
                    Label("Camera", systemImage: "camera.viewfinder")
                }

            GalleryScreen()
                .tabItem {
                    Label("Roll", systemImage: "rectangle.grid.3x2")
                }

            ImportLabScreen()
                .tabItem {
                    Label("Lab", systemImage: "wand.and.stars")
                }

            SettingsScreen()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .tint(StillLightTheme.accent)
    }
}
