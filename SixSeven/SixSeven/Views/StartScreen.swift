import SwiftUI

struct StartScreen: View {
    @ObservedObject var viewModel: GameViewModel
    var onStart: () -> Void

    @State private var glowPhase = false

    var body: some View {
        ZStack {
            // Background
            RadialGradient(
                colors: [Color(hex: "3C3489"), Color(hex: "0a0a1a")],
                center: .center,
                startRadius: 0, endRadius: UIScreen.main.bounds.height * 0.5
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Logo
                HStack(spacing: -6) {
                    Text("6")
                        .foregroundColor(Color(hex: "AFA9EC"))
                    Text("7")
                        .foregroundColor(Color(hex: "FAC775"))
                }
                .font(.system(size: 120, weight: .black, design: .rounded))
                .shadow(color: Color(hex: "AFA9EC").opacity(glowPhase ? 0.7 : 0.4), radius: glowPhase ? 80 : 50)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        glowPhase = true
                    }
                }

                Text("67 COUNTER")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)

                Text("raise one hand, then the other\nalternating 6-7 style!")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Spacer().frame(height: 50)

                // Duration selector
                HStack(spacing: 12) {
                    ForEach(GameConfig.durations, id: \.self) { dur in
                        DurationButton(
                            seconds: dur,
                            isSelected: viewModel.selectedDuration == dur
                        ) {
                            viewModel.selectedDuration = dur
                            viewModel.timeLeft = dur
                        }
                    }
                }
                .padding(.bottom, 24)

                // Start button
                Button(action: {
                    onStart()
                    viewModel.startGame()
                }) {
                    Text("START")
                        .font(.system(size: 20, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(Color(hex: "26215C"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FAC775"), Color(hex: "F0997B")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "FAC775").opacity(glowPhase ? 0.5 : 0.3),
                                radius: glowPhase ? 30 : 15, y: 5)
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 50)

                // How to play
                VStack(spacing: 10) {
                    HowToRow(step: 1, text: "allow camera — upper body visible")
                    HowToRow(step: 2, text: "raise one hand up, then drop it")
                    HowToRow(step: 3, text: "other hand within 2s — that's a 6-7!")
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
    }
}

// MARK: - Duration Button

struct DurationButton: View {
    let seconds: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(seconds)s")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isSelected ? Color(hex: "FAC775") : Color(hex: "AFA9EC"))
                .frame(minWidth: 70)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(isSelected ?
                              Color(hex: "FAC775").opacity(0.2) :
                              Color(hex: "AFA9EC").opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isSelected ?
                                Color(hex: "FAC775") :
                                Color(hex: "AFA9EC").opacity(0.3), lineWidth: 2)
                )
                .shadow(color: isSelected ? Color(hex: "FAC775").opacity(0.25) : .clear, radius: 10)
        }
    }
}

// MARK: - How To Row

struct HowToRow: View {
    let step: Int
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(step)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "AFA9EC"))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color(hex: "AFA9EC").opacity(0.2)))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
