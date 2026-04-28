import CoreMotion
import SwiftUI

struct CameraAssistOverlay: View {
    let showGrid: Bool
    let showLevel: Bool
    let rollAngle: Double

    var body: some View {
        ZStack {
            if showGrid {
                RuleOfThirdsGrid()
                    .opacity(0.46)
            }

            if showLevel {
                HorizonLevel(rollAngle: rollAngle)
                    .frame(width: 126, height: 36)
            }
        }
    }
}

private struct RuleOfThirdsGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                for multiplier in [1.0 / 3.0, 2.0 / 3.0] {
                    let x = width * multiplier
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))

                    let y = height * multiplier
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(StillLightTheme.text.opacity(0.34), lineWidth: 0.7)
        }
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
