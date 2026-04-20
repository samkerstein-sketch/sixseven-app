import SwiftUI

struct GameScreen: View {
    @ObservedObject var viewModel: GameViewModel
    var onGameEnd: () -> Void

    var body: some View {
        ZStack {
            // Camera feed — full screen
            CameraPreview(session: viewModel.camera.session)
                .ignoresSafeArea()

            // Action Zone overlay (drawn lines)
            ActionZoneOverlay(
                raiseY: viewModel.raiseLineY,
                dropY: viewModel.dropLineY,
                poseData: viewModel.poseData,
                leftHand: viewModel.leftBadgeState,
                rightHand: viewModel.rightBadgeState,
                fireMode: viewModel.fireMode
            )
            .ignoresSafeArea()

            // HUD elements
            HUDView(viewModel: viewModel, onExit: {
                viewModel.endGame()
            })

            // Fire mode border
            if viewModel.fireMode {
                FireBorder()
            }

            // Countdown overlay
            if viewModel.showCountdown {
                CountdownOverlay(text: viewModel.countdownText)
            }

            // Game over flash
            if viewModel.gameOver {
                GameOverFlash(count: viewModel.count)
            }
        }
        .offset(x: viewModel.shakeIntensity > 0 ?
                CGFloat.random(in: -viewModel.shakeIntensity...viewModel.shakeIntensity) : 0,
                y: viewModel.shakeIntensity > 0 ?
                CGFloat.random(in: -viewModel.shakeIntensity/2...viewModel.shakeIntensity/2) : 0)
        .onChange(of: viewModel.gameOver) { _, isOver in
            if isOver { onGameEnd() }
        }
    }
}

// MARK: - Action Zone Overlay (Canvas-based for 60 FPS)

struct ActionZoneOverlay: View {
    let raiseY: CGFloat
    let dropY: CGFloat
    let poseData: PoseData?
    let leftHand: BadgeState
    let rightHand: BadgeState
    let fireMode: Bool

    var body: some View {
        Canvas { context, size in
            let rY = raiseY * size.height
            let dY = dropY * size.height

            guard rY > 0 && dY > rY else { return }

            let anyActive = leftHand != .idle || rightHand != .idle

            // Zone fill
            let zoneRect = CGRect(x: 0, y: rY, width: size.width, height: dY - rY)
            let fillColor: Color = anyActive ?
                Color(hex: "5DCAA5").opacity(0.06) :
                Color(hex: "AFA9EC").opacity(0.04)
            context.fill(Path(zoneRect), with: .color(fillColor))

            // Raise line (neon green dashed)
            let raiseColor: Color = anyActive ?
                Color(hex: "5DCAA5").opacity(0.9) :
                Color(hex: "5DCAA5").opacity(0.5)
            var raisePath = Path()
            raisePath.move(to: CGPoint(x: 0, y: rY))
            raisePath.addLine(to: CGPoint(x: size.width, y: rY))
            context.stroke(raisePath, with: .color(raiseColor),
                          style: StrokeStyle(lineWidth: 3, dash: [10, 6]))

            // Drop line (neon gold dashed)
            let dropColor: Color = anyActive ?
                Color(hex: "FAC775").opacity(0.8) :
                Color(hex: "FAC775").opacity(0.5)
            var dropPath = Path()
            dropPath.move(to: CGPoint(x: 0, y: dY))
            dropPath.addLine(to: CGPoint(x: size.width, y: dY))
            context.stroke(dropPath, with: .color(dropColor),
                          style: StrokeStyle(lineWidth: 3, dash: [10, 6]))

            // Line labels
            context.draw(
                Text("▲ RAISE").font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "5DCAA5").opacity(0.7)),
                at: CGPoint(x: 40, y: rY - 10)
            )
            context.draw(
                Text("▼ DROP").font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "FAC775").opacity(0.7)),
                at: CGPoint(x: 36, y: dY + 12)
            )

            // Draw wrist indicators
            if let pose = poseData {
                drawWrist(context: context, size: size,
                         point: pose.leftWrist, state: leftHand, fireMode: fireMode)
                drawWrist(context: context, size: size,
                         point: pose.rightWrist, state: rightHand, fireMode: fireMode)

                // Arm skeleton lines
                let skeletonColor = Color.white.opacity(0.2)
                drawLine(context: context, from: pose.leftShoulder, to: pose.leftWrist,
                        size: size, color: skeletonColor)
                drawLine(context: context, from: pose.rightShoulder, to: pose.rightWrist,
                        size: size, color: skeletonColor)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawWrist(context: GraphicsContext, size: CGSize,
                           point: CGPoint, state: BadgeState, fireMode: Bool) {
        let x = point.x * size.width
        let y = point.y * size.height

        // Outer glow
        let glowColor: Color = {
            switch state {
            case .done: return Color(hex: "5DCAA5").opacity(0.5)
            case .waiting: return fireMode ?
                Color(hex: "FF6B35").opacity(0.5) : Color(hex: "5DCAA5").opacity(0.5)
            case .next: return Color(hex: "FAC775").opacity(0.4)
            case .idle: return Color(hex: "FAC775").opacity(0.3)
            }
        }()

        var glowPath = Path()
        glowPath.addEllipse(in: CGRect(x: x - 16, y: y - 16, width: 32, height: 32))
        context.fill(glowPath, with: .color(glowColor))

        // Inner solid
        let solidColor: Color = {
            switch state {
            case .done: return Color(hex: "5DCAA5")
            case .waiting: return fireMode ? Color(hex: "FF6B35") : Color(hex: "5DCAA5")
            case .next: return Color(hex: "FAC775")
            case .idle: return Color(hex: "FAC775")
            }
        }()

        var solidPath = Path()
        solidPath.addEllipse(in: CGRect(x: x - 8, y: y - 8, width: 16, height: 16))
        context.fill(solidPath, with: .color(solidColor))
    }

    private func drawLine(context: GraphicsContext, from: CGPoint, to: CGPoint,
                          size: CGSize, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: from.x * size.width, y: from.y * size.height))
        path.addLine(to: CGPoint(x: to.x * size.width, y: to.y * size.height))
        context.stroke(path, with: .color(color), lineWidth: 2)
    }
}

// MARK: - Fire Border

struct FireBorder: View {
    @State private var phase = false

    var body: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(phase ? Color(hex: "FAC775") : Color(hex: "FF6B35"), lineWidth: 3)
            .shadow(color: Color(hex: "FF6B35").opacity(0.4), radius: 20, x: 0, y: 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
    }
}

// MARK: - Game Over Flash

struct GameOverFlash: View {
    let count: Int
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("GAME OVER")
                    .font(.system(size: 60, weight: .black))
                    .foregroundColor(Color(hex: "FAC775"))
                    .shadow(color: Color(hex: "FAC775").opacity(0.6), radius: 30)
                Text("\(count) reps")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
