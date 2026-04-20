import SwiftUI

struct ResultsScreen: View {
    @ObservedObject var viewModel: GameViewModel
    var onHome: () -> Void
    var onPlayAgain: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "0a0a1a")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                if let results = viewModel.results {
                    // Results card
                    VStack(spacing: 0) {
                        Text("YOUR SCORE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(3)
                            .textCase(.uppercase)
                            .padding(.bottom, 12)

                        Text("\(results.count)")
                            .font(.system(size: 100, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "FAC775"))
                            .shadow(color: Color(hex: "FAC775").opacity(0.5), radius: 30)
                            .padding(.bottom, 8)

                        Text("6-7s in \(results.duration) seconds")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 24)

                        // Stats
                        VStack(spacing: 0) {
                            StatRow(label: "per second", value: String(format: "%.1f", results.perSecond))
                            StatRow(label: "best streak", value: "\(results.bestStreak)")
                            StatRow(label: "personal best", value: "\(results.personalBest)")
                            StatRow(label: "rank", value: results.rank, isLast: true)
                        }

                        if results.isNewBest {
                            Text("★ NEW BEST")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundColor(Color(hex: "26215C"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "FAC775"), Color(hex: "F0997B")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.top, 15)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 36)
                    .frame(maxWidth: 360)
                    .background(.ultraThinMaterial.opacity(0.15))
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }

                Spacer().frame(height: 25)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onPlayAgain) {
                        Text("PLAY AGAIN")
                            .font(.system(size: 18, weight: .heavy))
                            .tracking(1)
                            .foregroundColor(Color(hex: "26215C"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "FAC775"), Color(hex: "F0997B")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color(hex: "FAC775").opacity(0.4), radius: 15, y: 5)
                    }

                    Button(action: onHome) {
                        Text("BACK HOME")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "AFA9EC"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "AFA9EC").opacity(0.2))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color(hex: "AFA9EC").opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 30)

                Spacer()
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 30)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appear = true
            }
        }
        .onDisappear {
            appear = false
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var isLast: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
            }
        }
    }
}
