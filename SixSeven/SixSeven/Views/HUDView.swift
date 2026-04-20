import SwiftUI

struct HUDView: View {
    @ObservedObject var viewModel: GameViewModel
    var onExit: () -> Void

    var body: some View {
        ZStack {
            // Top-left: Timer
            VStack {
                HStack {
                    TimerPill(timeLeft: viewModel.timeLeft)
                    Spacer()
                    HStack(spacing: 8) {
                        MuteButton(isMuted: viewModel.audio.isMuted) {
                            viewModel.audio.toggleMute()
                        }
                        ExitButton(action: onExit)
                    }
                }
                .padding(.top, 54)
                .padding(.horizontal, 20)
                Spacer()
            }

            // Center: Counter (original position)
            VStack {
                Spacer()
                CounterDisplay(
                    count: viewModel.count,
                    pop: viewModel.countPop,
                    fireMode: viewModel.fireMode
                )
                Spacer()
            }

            // Hand badges
            VStack {
                HStack {
                    HandBadge(label: "L", state: viewModel.leftBadgeState)
                    Spacer()
                    HandBadge(label: "R", state: viewModel.rightBadgeState)
                }
                .padding(.horizontal, 30)
                .padding(.top, 110)
                Spacer()
            }

            // Bottom: Prompt
            VStack {
                Spacer()

                // Streak badge
                if viewModel.streakCount >= 3 {
                    StreakBadge(count: viewModel.streakCount, fireMode: viewModel.fireMode)
                        .padding(.bottom, 8)
                }

                PromptPill(text: viewModel.promptText, state: viewModel.promptState, fireMode: viewModel.fireMode)
                    .padding(.bottom, 40)
                    .padding(.horizontal, 30)
            }
        }
    }
}

// MARK: - Timer Pill

struct TimerPill: View {
    let timeLeft: Int

    private var timeString: String {
        let mins = timeLeft / 60
        let secs = timeLeft % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    private var isWarning: Bool { timeLeft <= 5 }

    var body: some View {
        Text(timeString)
            .font(.system(size: 20, weight: .heavy, design: .monospaced))
            .foregroundColor(isWarning ? Color(hex: "F0997B") : Color(hex: "FAC775"))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial.opacity(0.8))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isWarning ?
                            Color(hex: "F0997B").opacity(0.6) :
                            Color(hex: "FAC775").opacity(0.4), lineWidth: 2)
            )
            .scaleEffect(isWarning ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                       value: isWarning)
    }
}

// MARK: - Counter Display (UNTOUCHED position — center of screen)

struct CounterDisplay: View {
    let count: Int
    let pop: Bool
    let fireMode: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 140, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Color(hex: "AFA9EC").opacity(0.8), radius: 40)
                .shadow(color: Color(hex: "FAC775").opacity(0.4), radius: 80)
                .scaleEffect(pop ? 1.4 : 1.0)
                .brightness(pop ? 0.5 : 0)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pop)

            Text("6 · 7")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .tracking(4)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Hand Badge

struct HandBadge: View {
    let label: String
    let state: BadgeState

    private var borderColor: Color {
        switch state {
        case .idle: return .white.opacity(0.15)
        case .waiting: return Color(hex: "AFA9EC").opacity(0.5)
        case .done: return Color(hex: "5DCAA5")
        case .next: return Color(hex: "FAC775")
        }
    }

    private var bgColor: Color {
        switch state {
        case .idle: return .black.opacity(0.5)
        case .waiting: return .black.opacity(0.5)
        case .done: return Color(hex: "5DCAA5").opacity(0.25)
        case .next: return Color(hex: "FAC775").opacity(0.2)
        }
    }

    private var textColor: Color {
        switch state {
        case .idle: return .white.opacity(0.3)
        case .waiting: return Color(hex: "AFA9EC")
        case .done: return Color(hex: "5DCAA5")
        case .next: return Color(hex: "FAC775")
        }
    }

    private var displayText: String {
        state == .done ? "✓" : label
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: state == .done ? 28 : 22, weight: .black))
            .foregroundColor(textColor)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(bgColor)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(Circle())
            )
            .overlay(Circle().stroke(borderColor, lineWidth: 2))
            .shadow(color: state == .done ? Color(hex: "5DCAA5").opacity(0.4) : .clear, radius: 10)
            .opacity(state == .idle ? 0.6 : 1.0)
            .scaleEffect(state == .next ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                       value: state == .next)
    }
}

// MARK: - Prompt Pill

struct PromptPill: View {
    let text: String
    let state: PromptStyle
    let fireMode: Bool

    private var bgColor: Color {
        switch state {
        case .raising, .almostB:
            return Color(hex: "5DCAA5").opacity(0.2)
        default:
            return fireMode ? Color(hex: "FF6B35").opacity(0.25) : Color(hex: "AFA9EC").opacity(0.15)
        }
    }

    private var borderColor: Color {
        switch state {
        case .raising, .almostB:
            return Color(hex: "5DCAA5").opacity(0.6)
        default:
            return fireMode ? Color(hex: "FF6B35") : Color(hex: "AFA9EC").opacity(0.4)
        }
    }

    private var textColor: Color {
        switch state {
        case .raising, .almostB:
            return Color(hex: "5DCAA5")
        default:
            return fireMode ? Color(hex: "FF6B35") : Color(hex: "AFA9EC")
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(textColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(bgColor)
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

// MARK: - Mute / Exit Buttons

struct MuteButton: View {
    let isMuted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 16))
                .foregroundColor(isMuted ? .white.opacity(0.3) : .white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Circle())
        }
    }
}

struct ExitButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Circle())
        }
    }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let count: Int
    let fireMode: Bool

    var body: some View {
        Text(fireMode ? "FIRE MODE x\(count)" : "STREAK x\(count)")
            .font(.system(size: 14, weight: .heavy))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundColor(fireMode ? Color(hex: "1a0a00") : Color(hex: "FAC775"))
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(
                fireMode ?
                AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(hex: "FF6B35"), Color(hex: "FAC775"), Color(hex: "FF6B35")],
                        startPoint: .leading, endPoint: .trailing
                    )
                ) :
                AnyShapeStyle(Color(hex: "FAC775").opacity(0.3))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    fireMode ? Color(hex: "FF6B35") : Color(hex: "FAC775").opacity(0.6),
                    lineWidth: fireMode ? 2 : 1
                )
            )
            .shadow(color: fireMode ? Color(hex: "FF6B35").opacity(0.6) : .clear, radius: 15)
    }
}

// MARK: - Countdown Overlay

struct CountdownOverlay: View {
    let text: String
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    private var isGo: Bool { text == "GO!" }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .background(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(text)
                    .font(.system(size: 160, weight: .black, design: .rounded))
                    .foregroundColor(isGo ? Color(hex: "5DCAA5") : Color(hex: "FAC775"))
                    .shadow(color: (isGo ? Color(hex: "5DCAA5") : Color(hex: "FAC775")).opacity(0.6),
                            radius: 40)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Text("get ready")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(3)
                    .textCase(.uppercase)
                    .opacity(isGo ? 0 : opacity)
            }
        }
        .onAppear { animate() }
        .onChange(of: text) { _, _ in animate() }
    }

    private func animate() {
        scale = 0.3
        opacity = 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
        }
    }
}
