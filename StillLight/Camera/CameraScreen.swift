import SwiftUI
import UIKit

struct CameraScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var levelMonitor = LevelMonitor()
    @State private var showsFilmPicker = false
    @State private var showsGallery = false
    @State private var showsImportLab = false
    @State private var shutterFlash = false
    @State private var focusIndicator: FocusIndicator?
    @State private var pinchStartZoomFactor: CGFloat?
    @State private var zoomControlDragStartFactor: CGFloat?
    @State private var isDraggingZoomControl = false
    @State private var showsWhiteBalanceControl = false
    @State private var selfTimerSeconds = 0

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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsGallery) {
            GalleryScreen()
        }
        .sheet(isPresented: $showsImportLab) {
            ImportLabScreen()
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
                whiteBalanceControl
                creativeAccessoryPanel
                exposureControl
                accessoryDock
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
                guard !isCaptureContextLocked else { return }
                showsFilmPicker = true
            } label: {
                FilmRollBadge(
                    title: appState.selectedFilm.displayCameraName(language: appState.language),
                    subtitle: appState.selectedFilm.displayShortName(language: appState.language),
                    remainingShots: appState.currentRoll.remainingShots
                )
            }
            .buttonStyle(.plain)
            .disabled(isCaptureContextLocked)
            .opacity(isCaptureContextLocked ? 0.54 : 1)
            .accessibilityLabel("\(appState.selectedFilm.displayShortName(language: appState.language)), \(appState.currentRoll.remainingShots)")

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
            .disabled(isCaptureContextLocked)
            .opacity(isCaptureContextLocked ? 0.54 : 1)

            cameraAccessoryStatus
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private var cameraAccessoryStatus: some View {
        HStack(spacing: 6) {
            AccessoryStatusDot(isOn: viewModel.creativeCaptureMode == .doubleExposure, iconName: "square.on.square")
            AccessoryStatusDot(isOn: viewModel.creativeCaptureMode == .longExposure, iconName: "timer")
            AccessoryStatusDot(isOn: viewModel.starburstIntensity > 0.01, iconName: "sparkles")
        }
        .padding(.horizontal, 8)
        .frame(height: 38)
        .background(Color.black.opacity(0.32))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var exposureControl: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("EV")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(StillLightTheme.secondaryText)
                Slider(value: Binding(
                    get: { viewModel.exposureBias },
                    set: { viewModel.updateExposureBias($0) }
                ), in: -2...2, step: 0.1)
                .tint(NativeCameraChrome.active)
                Text(String(format: "%+.1f", viewModel.exposureBias))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(StillLightTheme.secondaryText)
                    .frame(width: 42, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.38))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .opacity(viewModel.isRecording ? 0.52 : 1)
    }

    @ViewBuilder
    private var creativeAccessoryPanel: some View {
        switch viewModel.creativeCaptureMode {
        case .standard:
            if viewModel.starburstIntensity > 0.01 {
                starburstControl
            }
        case .doubleExposure:
            doubleExposureControl
        case .longExposure:
            longExposureControl
        }
    }

    private var doubleExposureControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                doubleExposurePreview

                VStack(alignment: .leading, spacing: 5) {
                    Text(doubleExposureTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(StillLightTheme.text)
                    Text(doubleExposureSubtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(StillLightTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if viewModel.doubleExposureState.hasBufferedFirstShot {
                    Button {
                        viewModel.resetDoubleExposureBuffer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(StillLightTheme.text)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appState.language == .chinese ? "取消第一张" : "Cancel first shot")
                }
            }

            HStack(spacing: 7) {
                ForEach(CameraDoubleExposureBlendMode.allCases) { mode in
                    Button {
                        viewModel.updateDoubleExposureBlendMode(mode)
                    } label: {
                        Text(doubleExposureBlendTitle(mode))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .foregroundStyle(viewModel.doubleExposureState.blendMode == mode ? StillLightTheme.background : StillLightTheme.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(viewModel.doubleExposureState.blendMode == mode ? NativeCameraChrome.active : Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var doubleExposurePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .frame(width: 52, height: 52)

            if let preview = viewModel.doubleExposureState.firstShotPreview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(NativeCameraChrome.active.opacity(0.70), lineWidth: 1)
                    }
            } else {
                Image(systemName: "1.circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(StillLightTheme.secondaryText)
            }
        }
    }

    private var longExposureControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NativeCameraChrome.active)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.t(.longExposure))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(StillLightTheme.text)
                    Text(longExposureSubtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(StillLightTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Text(longExposureProgressText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(NativeCameraChrome.active)
            }

            ProgressView(value: longExposureProgressValue)
                .tint(NativeCameraChrome.active)
                .opacity(viewModel.longExposureState.phase == .idle ? 0.34 : 1)

            HStack(spacing: 7) {
                longExposureStepButton(title: "0.8s", duration: 0.8, frames: 3)
                longExposureStepButton(title: "1.2s", duration: 1.2, frames: 4)
                longExposureStepButton(title: "2s", duration: 2.0, frames: 6)
                longExposureStepButton(title: "4s", duration: 4.0, frames: 8)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func longExposureStepButton(title: String, duration: TimeInterval, frames: Int) -> some View {
        let isSelected = abs(viewModel.longExposureState.request.duration - duration) < 0.05
        return Button {
            viewModel.updateLongExposureDuration(duration)
            viewModel.updateLongExposureFrameCount(frames)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? StillLightTheme.background : StillLightTheme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(isSelected ? NativeCameraChrome.active : Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isProcessing)
        .opacity(viewModel.isProcessing ? 0.54 : 1)
    }

    private var starburstControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeCameraChrome.active)
                .frame(width: 24)

            Slider(
                value: Binding(
                    get: { viewModel.starburstIntensity },
                    set: { viewModel.updateStarburstIntensity($0) }
                ),
                in: 0...1,
                step: 0.05
            )
            .tint(NativeCameraChrome.active)

            Text("\(Int((viewModel.starburstIntensity * 100).rounded()))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(NativeCameraChrome.active)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private var whiteBalanceControl: some View {
        if showsWhiteBalanceControl {
            HStack(spacing: 10) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NativeCameraChrome.active.opacity(0.88))
                    .frame(width: 22)

                Slider(
                    value: Binding(
                        get: { Double(viewModel.whiteBalanceState.kelvin) },
                        set: { viewModel.updateWhiteBalanceKelvin($0) }
                    ),
                    in: Double(viewModel.whiteBalanceState.minKelvin)...Double(viewModel.whiteBalanceState.maxKelvin),
                    step: 50
                )
                    .tint(NativeCameraChrome.active)
                    .disabled(!viewModel.whiteBalanceState.isSupported)
                    .opacity(viewModel.whiteBalanceState.isSupported ? 1 : 0.42)

                Button {
                    viewModel.resetWhiteBalance()
                } label: {
                    Text(whiteBalanceLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)
                        .foregroundStyle(NativeCameraChrome.active)
                        .frame(width: 58, height: 26)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var accessoryDock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                CameraAccessoryButton(
                    iconName: "photo.badge.plus",
                    isOn: false,
                    statusText: nil,
                    accessibilityLabel: appState.t(.importPhoto)
                ) {
                    showsImportLab = true
                }

                CameraAccessoryButton(
                    iconName: "square.on.square",
                    isOn: viewModel.creativeCaptureMode == .doubleExposure,
                    statusText: nil,
                    accessibilityLabel: appState.t(.doubleExposure)
                ) {
                    viewModel.setCreativeCaptureMode(viewModel.creativeCaptureMode == .doubleExposure ? .standard : .doubleExposure)
                }

                CameraAccessoryButton(
                    iconName: "camera.aperture",
                    isOn: viewModel.creativeCaptureMode == .longExposure,
                    statusText: nil,
                    accessibilityLabel: appState.t(.longExposure)
                ) {
                    viewModel.setCreativeCaptureMode(viewModel.creativeCaptureMode == .longExposure ? .standard : .longExposure)
                }

                CameraAccessoryButton(
                    iconName: "sparkles",
                    isOn: viewModel.starburstIntensity > 0.01,
                    statusText: viewModel.starburstIntensity > 0.01 ? "ON" : nil,
                    accessibilityLabel: appState.t(.starFilter)
                ) {
                    viewModel.updateStarburstIntensity(viewModel.starburstIntensity > 0.01 ? 0 : 0.70)
                }

                CameraAccessoryButton(
                    iconName: "thermometer.medium",
                    isOn: showsWhiteBalanceControl || viewModel.whiteBalanceState.isLocked,
                    statusText: whiteBalanceDockText,
                    accessibilityLabel: appState.t(.whiteBalance)
                ) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showsWhiteBalanceControl.toggle()
                    }
                }
                .disabled(!viewModel.whiteBalanceState.isSupported)
                .opacity(viewModel.whiteBalanceState.isSupported ? 1 : 0.42)

                CameraAccessoryButton(
                    iconName: "timer",
                    isOn: selfTimerSeconds > 0,
                    statusText: selfTimerSeconds == 0 ? nil : "\(selfTimerSeconds)s",
                    accessibilityLabel: appState.t(.timer)
                ) {
                    cycleSelfTimer()
                }

                CameraAccessoryButton(
                    iconName: "arrow.triangle.2.circlepath.camera",
                    isOn: false,
                    statusText: nil,
                    accessibilityLabel: appState.t(.camera)
                ) {
                    viewModel.switchCamera()
                }
                .disabled(viewModel.isProcessing || viewModel.isRecording)
                .opacity(viewModel.isProcessing || viewModel.isRecording ? 0.42 : 1)

                CameraAccessoryButton(
                    iconName: viewModel.flashMode.iconName,
                    isOn: viewModel.flashMode != .off,
                    statusText: flashDockText,
                    accessibilityLabel: "Flash"
                ) {
                    viewModel.toggleFlash()
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 54)
        .padding(.bottom, 12)
        .opacity(viewModel.isRecording ? 0.45 : 1)
    }

    private var bottomControls: some View {
        HStack(alignment: .center) {
            Button {
                showsGallery = true
            } label: {
                recentCaptureThumbnail
            }
            .disabled(viewModel.isRecording)

            Spacer()

            Button {
                runSelfTimerIfNeeded {
                    capturePrimaryAction()
                }
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

    private func capturePrimaryAction() {
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
    }

    private func runSelfTimerIfNeeded(_ action: @escaping () -> Void) {
        guard viewModel.captureMode == .photo, selfTimerSeconds > 0 else {
            action()
            return
        }

        let delay = DispatchTime.now() + .seconds(selfTimerSeconds)
        DispatchQueue.main.asyncAfter(deadline: delay) {
            action()
        }
    }

    private func cycleSelfTimer() {
        switch selfTimerSeconds {
        case 0:
            selfTimerSeconds = 3
        case 3:
            selfTimerSeconds = 10
        default:
            selfTimerSeconds = 0
        }
    }

    private var whiteBalanceLabel: String {
        if !viewModel.whiteBalanceState.isLocked {
            return "AUTO"
        }
        return viewModel.whiteBalanceState.kelvinText
    }

    private var whiteBalanceDockText: String? {
        guard showsWhiteBalanceControl || viewModel.whiteBalanceState.isLocked else { return nil }
        return whiteBalanceLabel
    }

    private var flashDockText: String? {
        switch viewModel.flashMode {
        case .off:
            return nil
        case .on:
            return "ON"
        case .auto:
            return "A"
        }
    }

    private var doubleExposureTitle: String {
        appState.language == .chinese ? "双重曝光" : "Double Exposure"
    }

    private var doubleExposureSubtitle: String {
        if viewModel.doubleExposureState.hasBufferedFirstShot {
            return appState.language == .chinese ? "第一张已缓存。调整混合方式后拍第二张。" : "First frame is buffered. Pick a blend mode, then shoot again."
        }
        return appState.language == .chinese ? "先拍第一张，相机会保留它等待第二次曝光。" : "Shoot the first frame. The camera will hold it for the second exposure."
    }

    private func doubleExposureBlendTitle(_ mode: CameraDoubleExposureBlendMode) -> String {
        switch (mode, appState.language) {
        case (.screen, .chinese):
            return "滤色"
        case (.multiply, .chinese):
            return "正片"
        case (.softLight, .chinese):
            return "柔光"
        case (.screen, _):
            return "Screen"
        case (.multiply, _):
            return "Multiply"
        case (.softLight, _):
            return "Soft"
        }
    }

    private var longExposureSubtitle: String {
        let request = viewModel.longExposureState.request.normalized
        let framesText = appState.language == .chinese ? "\(request.frameCount) 帧合成" : "\(request.frameCount) frames blended"
        return "\(String(format: "%.1fs", request.duration)) · \(framesText)"
    }

    private var longExposureProgressText: String {
        switch viewModel.longExposureState.phase {
        case .idle:
            return appState.language == .chinese ? "待拍" : "READY"
        case .collectingFrames:
            return "\(viewModel.longExposureState.capturedFrameCount)/\(viewModel.longExposureState.totalFrameCount)"
        case .processingFrames:
            return appState.language == .chinese ? "合成中" : "MERGE"
        case .completed:
            return appState.language == .chinese ? "完成" : "DONE"
        }
    }

    private var longExposureProgressValue: Double {
        switch viewModel.longExposureState.phase {
        case .idle:
            return 0
        case .collectingFrames:
            return viewModel.longExposureState.progress
        case .processingFrames:
            return max(viewModel.longExposureState.progress, 0.94)
        case .completed:
            return 1
        }
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
            } else if let recentImage = recentStoredImage {
                Image(uiImage: recentImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
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
            if viewModel.zoomState.lensOptions.count > 1 {
                ForEach(viewModel.zoomState.lensOptions) { option in
                    ZoomLensButton(
                        option: option,
                        isSelected: abs(viewModel.zoomState.displayFactor - option.displayFactor) < 0.08
                    ) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            viewModel.setZoomFactor(option.displayFactor)
                        }
                    }
                    .simultaneousGesture(zoomControlDragGesture)
                }
            } else {
                ZoomDisplayChip(text: viewModel.zoomState.displayFactorText)
                    .simultaneousGesture(zoomControlDragGesture)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.42))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            if isDraggingZoomControl {
                ZoomScrubRuler(state: viewModel.zoomState)
                    .offset(y: -48)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .simultaneousGesture(zoomControlDragGesture)
        .padding(.bottom, 10)
        .opacity(viewModel.isRecording ? 0.72 : 1)
        .animation(.easeOut(duration: 0.14), value: isDraggingZoomControl)
    }

    private var recentStoredImage: UIImage? {
        guard let latestRecord = appState.photoStore.records.first else { return nil }
        return UIImage(contentsOfFile: latestRecord.processedPath)
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
        .disabled(isCaptureContextLocked)
        .opacity(viewModel.isRecording || isCaptureContextLocked ? 0.45 : 1)
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

    private var isCaptureContextLocked: Bool {
        viewModel.doubleExposureState.phase == .waitingForSecondShot
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

    private var zoomControlDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                let startFactor = zoomControlDragStartFactor ?? viewModel.zoomState.displayFactor
                if zoomControlDragStartFactor == nil {
                    zoomControlDragStartFactor = startFactor
                    withAnimation(.easeOut(duration: 0.12)) {
                        isDraggingZoomControl = true
                    }
                }

                let minFactor = max(viewModel.zoomState.minDisplayFactor, 0.1)
                let maxFactor = max(viewModel.zoomState.maxDisplayFactor, minFactor)
                let range = max(maxFactor / minFactor, 1.01)
                let normalizedTravel = min(max(value.translation.width / 180, -1.15), 1.15)
                let multiplier = CGFloat(pow(Double(range), Double(normalizedTravel)))
                let nextFactor = min(max(startFactor * multiplier, minFactor), maxFactor)
                viewModel.setZoomFactor(nextFactor)
            }
            .onEnded { _ in
                zoomControlDragStartFactor = nil
                withAnimation(.easeOut(duration: 0.16)) {
                    isDraggingZoomControl = false
                }
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

private struct FilmRollBadge: View {
    let title: String
    let subtitle: String
    let remainingShots: Int

    var body: some View {
        HStack(spacing: 9) {
            MiniCameraIcon()

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .truncationMode(.tail)
                    .foregroundStyle(StillLightTheme.text)
                Text(subtitle.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .foregroundStyle(StillLightTheme.secondaryText.opacity(0.82))
            }
            .frame(maxWidth: 92, alignment: .leading)
            .layoutPriority(1)

            Text("\(remainingShots)")
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(StillLightTheme.background)
                .frame(minWidth: 28)
                .frame(height: 22)
                .padding(.horizontal, 3)
                .background(StillLightTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                }
        }
        .padding(.leading, 8)
        .padding(.trailing, 9)
        .frame(height: 44)
        .frame(maxWidth: 166, alignment: .leading)
        .background(StillLightTheme.panel.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MiniCameraIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.21, green: 0.20, blue: 0.17),
                            Color(red: 0.08, green: 0.08, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(StillLightTheme.accent.opacity(0.94))
                .frame(width: 15, height: 4)
                .offset(x: -5, y: -13)

            Circle()
                .fill(StillLightTheme.panelElevated)
                .frame(width: 17, height: 17)
                .overlay {
                    Circle()
                        .stroke(StillLightTheme.accent.opacity(0.72), lineWidth: 2)
                }
                .overlay {
                    Circle()
                        .fill(StillLightTheme.text.opacity(0.58))
                        .frame(width: 3, height: 3)
                }

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(StillLightTheme.text.opacity(0.38))
                .frame(width: 7, height: 4)
                .offset(x: 11, y: -9)
        }
        .frame(width: 36, height: 28)
        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
    }
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

private struct AccessoryStatusDot: View {
    let isOn: Bool
    let iconName: String

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isOn ? NativeCameraChrome.active : StillLightTheme.secondaryText.opacity(0.72))
            .frame(width: 22, height: 22)
            .background(Color.white.opacity(isOn ? 0.10 : 0.04))
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(isOn ? NativeCameraChrome.active.opacity(0.40) : Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}

private struct CameraAccessoryButton: View {
    let iconName: String
    let isOn: Bool
    let statusText: String?
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black.opacity(isOn ? 0.50 : 0.32))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isOn ? NativeCameraChrome.active.opacity(0.44) : Color.white.opacity(0.09), lineWidth: 1)
                        }

                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isOn ? NativeCameraChrome.active : StillLightTheme.text.opacity(0.86))

                    if isOn {
                        Circle()
                            .fill(NativeCameraChrome.active)
                            .frame(width: 5, height: 5)
                            .padding(5)
                    }
                }
                .frame(width: 38, height: 36)

                Text(statusText ?? " ")
                    .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .foregroundStyle(NativeCameraChrome.active.opacity(0.92))
                    .frame(width: 39, height: 10)
                    .opacity(statusText == nil ? 0 : 1)
            }
            .frame(width: 39, height: 50)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private enum NativeCameraChrome {
    static let active = Color(red: 1.0, green: 0.80, blue: 0.38)
}

private struct ZoomLensButton: View {
    let option: CameraLensOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(option.label)
                    .font(.system(size: isSelected ? 13 : 12, weight: .bold, design: .rounded).monospacedDigit())
                Text("x")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .baselineOffset(1)
            }
            .foregroundStyle(isSelected ? NativeCameraZoomColors.selected : StillLightTheme.text.opacity(0.76))
            .frame(width: 36, height: 30)
            .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? NativeCameraZoomColors.selected.opacity(0.48) : Color.white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ZoomDisplayChip: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
            Text("x")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .baselineOffset(1)
        }
        .foregroundStyle(NativeCameraZoomColors.selected)
        .frame(minWidth: 36, minHeight: 30)
        .padding(.horizontal, 2)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(NativeCameraZoomColors.selected.opacity(0.48), lineWidth: 1)
        }
    }
}

private enum NativeCameraZoomColors {
    static let selected = NativeCameraChrome.active
}

private struct ZoomScrubRuler: View {
    let state: CameraZoomState

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(state.displayFactorText)
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                Text("x")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .baselineOffset(1)
            }
            .foregroundStyle(NativeCameraZoomColors.selected)

            ZStack {
                HStack(alignment: .center, spacing: 5) {
                    ForEach(0..<23, id: \.self) { index in
                        Capsule()
                            .fill(tickColor(index))
                            .frame(width: index == 11 ? 2 : 1, height: tickHeight(index))
                    }
                }

                Capsule()
                    .fill(NativeCameraZoomColors.selected)
                    .frame(width: 2, height: 20)
                    .shadow(color: NativeCameraZoomColors.selected.opacity(0.24), radius: 4, y: 1)
            }
            .frame(height: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.46))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 10, y: 6)
        .allowsHitTesting(false)
    }

    private func tickHeight(_ index: Int) -> CGFloat {
        if index == 11 {
            return 20
        }
        return index.isMultiple(of: 4) ? 15 : 8
    }

    private func tickColor(_ index: Int) -> Color {
        if index == 11 {
            return NativeCameraZoomColors.selected
        }
        let distance = abs(index - 11)
        return StillLightTheme.text.opacity(distance < 4 ? 0.52 : 0.30)
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
