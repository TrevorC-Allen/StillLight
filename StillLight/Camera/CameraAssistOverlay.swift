import CoreMotion
import SwiftUI

struct CameraAssistOverlay: View {
    let showGrid: Bool
    let showLevel: Bool
    let aspectRatio: CGFloat
    let rollAngle: Double

    var body: some View {
        ZStack {
            CaptureFrameGuide(showGrid: showGrid, aspectRatio: aspectRatio)

            if showLevel {
                HorizonLevel(rollAngle: rollAngle)
                    .frame(width: 126, height: 36)
            }
        }
    }
}

private struct CaptureFrameGuide: View {
    let showGrid: Bool
    let aspectRatio: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let frame = guideFrame(in: geometry.size)

            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                path.addRoundedRect(in: frame, cornerSize: CGSize(width: 8, height: 8))
            }
            .fill(.black.opacity(0.16), style: FillStyle(eoFill: true))

            Path { path in
                path.addRoundedRect(in: frame, cornerSize: CGSize(width: 8, height: 8))
            }
            .stroke(StillLightTheme.text.opacity(0.40), lineWidth: 0.9)

            if showGrid {
                Path { path in
                for multiplier in [1.0 / 3.0, 2.0 / 3.0] {
                        let x = frame.minX + frame.width * multiplier
                        path.move(to: CGPoint(x: x, y: frame.minY))
                        path.addLine(to: CGPoint(x: x, y: frame.maxY))

                        let y = frame.minY + frame.height * multiplier
                        path.move(to: CGPoint(x: frame.minX, y: y))
                        path.addLine(to: CGPoint(x: frame.maxX, y: y))
                    }
                }
                .stroke(StillLightTheme.text.opacity(0.34), lineWidth: 0.7)
            }
        }
    }

    private func guideFrame(in size: CGSize) -> CGRect {
        let horizontalInset: CGFloat = 18
        let topInset: CGFloat = 96
        let bottomInset: CGFloat = 172
        let available = CGRect(
            x: horizontalInset,
            y: topInset,
            width: max(1, size.width - horizontalInset * 2),
            height: max(1, size.height - topInset - bottomInset)
        )

        var width = available.width
        var height = width / max(aspectRatio, 0.01)
        if height > available.height {
            height = available.height
            width = height * aspectRatio
        }

        return CGRect(
            x: available.midX - width / 2,
            y: available.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private struct HorizonLevel: View {
    let rollAngle: Double

    private var isLevel: Bool {
        abs(rollAngle) < 1.2
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.22))
                .frame(width: 104, height: 2)

            Capsule()
                .fill((isLevel ? StillLightTheme.accent : StillLightTheme.text).opacity(0.9))
                .frame(width: 72, height: 3)
                .rotationEffect(.degrees(rollAngle))

            Circle()
                .stroke((isLevel ? StillLightTheme.accent : StillLightTheme.text).opacity(0.85), lineWidth: 1)
                .frame(width: 7, height: 7)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: rollAngle)
    }
}

@MainActor
final class LevelMonitor: ObservableObject {
    @Published var rollAngle: Double = 0

    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 24.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            self?.rollAngle = motion.attitude.roll * 180.0 / .pi
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
