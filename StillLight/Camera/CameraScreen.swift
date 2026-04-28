import SwiftUI

struct CameraScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var levelMonitor = LevelMonitor()
    @State private var showsFilmPicker = false
    @State private var showsGallery = false
    @State private var shutterFlash = false

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            switch viewModel.permissionState {
            case .authorized:
                cameraExperience
            case .denied:
                permissionMessage(
                    title: "Camera Access Needed",
                    message: "Enable camera permission in Settings to shoot with StillLight."
                )
            case .unavailable:
                permissionMessage(
                    title: "Camera Unavailable",
                    message: "This device or simulator cannot open a live camera right now."
                )
            case .unknown:
                ProgressView()
                    .tint(StillLightTheme.accent)
            }
        }
        .onAppear { viewModel.start() }
        .onAppear { levelMonitor.start() }
        .onDisappear {
            viewModel.stop()
            levelMonitor.stop()
        }
        .sheet(isPresented: $showsFilmPicker) {
            FilmPickerSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsGallery) {
            GalleryScreen()
        }
        .sheet(item: $viewModel.result) { result in
            ResultView(result: result)
        }
    }

    private var cameraExperience: some View {
        ZStack {
            CameraPreview(session: viewModel.cameraService.session) { point in
                viewModel.focus(at: point)
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.60), .clear, .black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            CameraAssistOverlay(
                showGrid: appState.showGrid,
                showLevel: appState.showLevel,
                rollAngle: levelMonitor.rollAngle
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if shutterFlash {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
                exposureControl
                bottomControls
            }

            if viewModel.isProcessing {
                processingOverlay
            }

            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(StillLightTheme.text)
                        .stillLightPanel()
                        .padding(.bottom, 112)
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                showsFilmPicker = true
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(StillLightTheme.accent)
                        .frame(width: 8, height: 8)
                    Text(appState.selectedFilm.shortName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(StillLightTheme.text)
                .stillLightPanel()
            }

            Spacer()

            Menu {
                ForEach(CaptureAspectRatio.allCases) { ratio in
                    Button(ratio.label) {
                        appState.selectedAspectRatio = ratio
                    }
                }
            } label: {
                Text(appState.selectedAspectRatio.label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(StillLightTheme.text)
                    .stillLightPanel()
            }

            Button {
                viewModel.toggleFlash()
            } label: {
                Image(systemName: viewModel.flashMode.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(StillLightTheme.panel.opacity(0.92))
                    .clipShape(Circle())
                    .foregroundStyle(StillLightTheme.text)
            }

            Button {
                viewModel.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(StillLightTheme.panel.opacity(0.92))
                    .clipShape(Circle())
                    .foregroundStyle(StillLightTheme.text)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private var exposureControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text("EV")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(StillLightTheme.secondaryText)
                Slider(value: Binding(
                    get: { viewModel.exposureBias },
                    set: { viewModel.updateExposureBias($0) }
                ), in: -2...2, step: 0.1)
                .tint(StillLightTheme.accent)
                Text(String(format: "%+.1f", viewModel.exposureBias))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(StillLightTheme.secondaryText)
                    .frame(width: 42, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(StillLightTheme.panel.opacity(0.74))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }

    private var bottomControls: some View {
        HStack(alignment: .center) {
            Button {
                showsFilmPicker = true
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "film")
                        .font(.system(size: 21, weight: .medium))
                    Text("\(appState.selectedFilm.iso)")
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(StillLightTheme.text)
                .frame(width: 72, height: 72)
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.10)) {
                    shutterFlash = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        shutterFlash = false
                    }
                }
                viewModel.capture(appState: appState)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(StillLightTheme.text.opacity(0.95), lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(StillLightTheme.text.opacity(0.92))
                        .frame(width: 62, height: 62)
                }
            }
            .disabled(viewModel.isProcessing)

            Spacer()

            Button {
                showsGallery = true
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 21, weight: .medium))
                    Text("\(appState.photoStore.records.count)")
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(StillLightTheme.text)
                .frame(width: 72, height: 72)
            }
            .opacity(0.8)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
    }

    private var processingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(StillLightTheme.accent)
            Text("Developing")
                .font(.caption.monospaced())
                .foregroundStyle(StillLightTheme.secondaryText)
        }
        .stillLightPanel()
    }

    private func permissionMessage(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(StillLightTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(StillLightTheme.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(StillLightTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
        }
    }
}
