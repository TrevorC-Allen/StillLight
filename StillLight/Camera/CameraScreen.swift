import SwiftUI
import UIKit

struct CameraScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var levelMonitor = LevelMonitor()
    @State private var showsFilmPicker = false
    @State private var showsGallery = false
    @State private var reviewResult: CaptureResult?
    @State private var shutterFlash = false
    @State private var focusIndicator: FocusIndicator?
    @State private var pinchStartZoomFactor: CGFloat?

    var body: some View {
        ZStack {
            StillLightTheme.background.ignoresSafeArea()

            switch viewModel.permissionState {
            case .authorized:
                cameraExperience
            case .denied:
                permissionMessage(
                    title: appState.t(.cameraAccessNeeded),
                    message: appState.t(.cameraAccessMessage),
                    buttonTitle: appState.t(.openSettings),
                    action: openAppSettings
                )
            case .unavailable:
                permissionMessage(
                    title: appState.t(.cameraUnavailable),
                    message: appState.t(.cameraUnavailableMessage),
                    buttonTitle: appState.t(.tryAgain),
                    action: viewModel.start
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
        .sheet(item: $reviewResult) { result in
            ResultView(result: result)
        }
    }

    private var cameraExperience: some View {
        ZStack {
            CameraPreview(session: viewModel.cameraService.session) { point, viewPoint in
                viewModel.focus(at: point)
                updateFocusIndicator(viewPoint)
            }
            .ignoresSafeArea()
            .simultaneousGesture(zoomGesture)
            .overlay {
                if let focusIndicator {
                    FocusReticle()
                        .position(focusIndicator.point)
                        .id(focusIndicator.id)
                        .transition(.opacity)
                }
            }

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
                aspectRatio: appState.selectedAspectRatio.value,
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
                zoomControl
                exposureControl
                captureModeControl
                bottomControls
            }

            if viewModel.isRecording {
                recordingBadge
            }

            if viewModel.isProcessing {
                processingOverlay
            }

            if viewModel.errorMessage != nil || viewModel.statusMessage != nil {
                VStack {
                    Spacer()
                    Text(viewModel.errorMessage ?? viewModel.statusMessage ?? "")
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
                    Text(appState.selectedFilm.displayShortName(language: appState.language))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("\(appState.currentRoll.remainingShots)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(StillLightTheme.secondaryText)
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
                if let latestResult = viewModel.latestResult {
                    reviewResult = latestResult
                } else {
                    showsGallery = true
                }
            } label: {
                recentCaptureThumbnail
            }
            .disabled(viewModel.isRecording)

            Spacer()

            Button {
                if viewModel.captureMode == .photo {
                    withAnimation(.easeOut(duration: 0.10)) {
                        shutterFlash = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            shutterFlash = false
                        }
                    }
                }
                viewModel.primaryAction(appState: appState)
            } label: {
                shutterButton
            }
            .disabled(viewModel.isProcessing && !viewModel.isRecording)

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

    private var recentCaptureThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(StillLightTheme.panel.opacity(0.92))
                .frame(width: 58, height: 58)

            if let latestImage = viewModel.latestResult?.image {
                Image(uiImage: latestImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.34), lineWidth: 1)
                    }
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(StillLightTheme.text.opacity(0.88))
            }
        }
        .frame(width: 72, height: 72)
    }

    private var zoomControl: some View {
        HStack(spacing: 7) {
            ForEach(viewModel.zoomState.lensOptions) { option in
                ZoomLensButton(
                    option: option,
                    isSelected: abs(viewModel.zoomState.displayFactor - option.displayFactor) < 0.08
                ) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        viewModel.setZoomFactor(option.displayFactor)
                    }
                }
            }

            if viewModel.zoomState.lensOptions.count < 2 {
                Text("\(viewModel.zoomState.displayFactorText)x")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(StillLightTheme.text)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
            }
        }
        .padding(5)
        .background(StillLightTheme.panel.opacity(0.70))
        .clipShape(Capsule())
        .padding(.bottom, 12)
        .opacity(viewModel.isRecording ? 0.72 : 1)
    }

    private var captureModeControl: some View {
        HStack(spacing: 8) {
            CameraModeButton(
                title: appState.t(.photoMode),
                isSelected: viewModel.captureMode == .photo
            ) {
                viewModel.setCaptureMode(.photo)
            }

            CameraModeButton(
                title: appState.t(.videoMode),
                isSelected: viewModel.captureMode == .video
            ) {
                viewModel.setCaptureMode(.video)
            }
        }
        .padding(5)
        .background(StillLightTheme.panel.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.bottom, 16)
        .opacity(viewModel.isRecording ? 0.45 : 1)
    }

    private var shutterButton: some View {
        ZStack {
            Circle()
                .strokeBorder(shutterColor.opacity(0.95), lineWidth: 4)
                .frame(width: 78, height: 78)

            if viewModel.captureMode == .video && viewModel.isRecording {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(shutterColor.opacity(0.94))
                    .frame(width: 35, height: 35)
            } else {
                Circle()
                    .fill(shutterColor.opacity(0.92))
                    .frame(width: viewModel.captureMode == .video ? 56 : 62, height: viewModel.captureMode == .video ? 56 : 62)
            }
        }
    }

    private var shutterColor: Color {
        viewModel.captureMode == .video ? Color(red: 0.88, green: 0.16, blue: 0.13) : StillLightTheme.text
    }

    private var recordingBadge: some View {
        VStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.92, green: 0.10, blue: 0.08))
                    .frame(width: 8, height: 8)
                Text(appState.t(.recording))
                Text(recordingDurationText)
                    .font(.caption.monospacedDigit())
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(StillLightTheme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(StillLightTheme.panel.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 72)

            Spacer()
        }
    }

    private var processingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(StillLightTheme.accent)
            Text(appState.t(.developing))
                .font(.caption.monospaced())
                .foregroundStyle(StillLightTheme.secondaryText)
        }
        .stillLightPanel()
    }

    private var recordingDurationText: String {
        let totalSeconds = max(0, Int(viewModel.recordingDuration.rounded(.down)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                let startFactor = pinchStartZoomFactor ?? viewModel.zoomState.displayFactor
                if pinchStartZoomFactor == nil {
                    pinchStartZoomFactor = startFactor
                }
                viewModel.zoomByPinch(magnification, from: startFactor)
            }
            .onEnded { _ in
                pinchStartZoomFactor = nil
            }
    }

    private func permissionMessage(
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
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

            if let buttonTitle, let action {
                Button(buttonTitle) {
                    action()
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(StillLightTheme.background)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(StillLightTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 6)
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func updateFocusIndicator(_ point: CGPoint) {
        let indicator = FocusIndicator(point: point)
        withAnimation(.easeOut(duration: 0.10)) {
            focusIndicator = indicator
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            guard focusIndicator?.id == indicator.id else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                focusIndicator = nil
            }
        }
    }
}

private struct FocusIndicator: Identifiable {
    let id = UUID()
    let point: CGPoint
}

private struct CameraModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? StillLightTheme.background : StillLightTheme.text)
                .frame(width: 70, height: 30)
                .background(isSelected ? StillLightTheme.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ZoomLensButton: View {
    let option: CameraLensOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(option.label)x")
                .font(.system(size: isSelected ? 13 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? StillLightTheme.background : StillLightTheme.text)
                .frame(width: isSelected ? 42 : 34, height: isSelected ? 34 : 30)
                .background(isSelected ? StillLightTheme.accent : StillLightTheme.panelElevated.opacity(0.86))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct FocusReticle: View {
    @State private var isSettled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(StillLightTheme.accent.opacity(0.96), lineWidth: 1.4)
            .frame(width: 74, height: 74)
            .overlay {
                Circle()
                    .fill(StillLightTheme.accent.opacity(0.95))
                    .frame(width: 4, height: 4)
            }
            .scaleEffect(isSettled ? 0.76 : 1.08)
            .opacity(isSettled ? 0.86 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    isSettled = true
                }
            }
    }
}
