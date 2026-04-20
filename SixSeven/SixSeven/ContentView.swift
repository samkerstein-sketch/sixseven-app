import SwiftUI

enum AppScreen {
    case start, game, results
}

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @State private var currentScreen: AppScreen = .start

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch currentScreen {
            case .start:
                StartScreen(viewModel: viewModel) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .game
                    }
                }
                .transition(.opacity)

            case .game:
                GameScreen(viewModel: viewModel) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        currentScreen = .results
                    }
                }
                .transition(.opacity)

            case .results:
                ResultsScreen(viewModel: viewModel) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .start
                    }
                } onPlayAgain: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .game
                    }
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onChange(of: viewModel.gameOver) { _, isOver in
            if isOver {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        currentScreen = .results
                    }
                }
            }
        }
    }
}
