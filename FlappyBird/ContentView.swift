import SpriteKit
import SwiftUI

struct ContentView: View {
    @State private var state: GameState
    @State private var scene: GameScene

    init() {
        let state = GameState()
        _state = State(initialValue: state)
        _scene = State(initialValue: GameScene(state: state))
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 120)
                .ignoresSafeArea()

            overlay
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .animation(.bouncy(duration: 0.45), value: state.phase)
    }

    @ViewBuilder
    private var overlay: some View {
        switch state.phase {
        case .ready:
            VStack {
                ScoreLabel(score: state.score)
                Spacer()
                TapHint()
                Spacer()
                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.opacity)

        case .playing, .dying:
            VStack {
                ScoreLabel(score: state.score)
                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.opacity)

        case .gameOver:
            GameOverCard(state: state) {
                scene.restart()
            }
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }
}

// MARK: - Overlay pieces

private struct ScoreLabel: View {
    let score: Int

    var body: some View {
        Text(score, format: .number)
            .font(.system(size: 72, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 3, y: 3)
            .contentTransition(.numericText(value: Double(score)))
            .animation(.snappy, value: score)
            .padding(.top, 16)
    }
}

private struct TapHint: View {
    var body: some View {
        Label("Tap to flap", systemImage: "hand.tap.fill")
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 0, x: 2, y: 2)
            .phaseAnimator([1.0, 1.08]) { content, scale in
                content.scaleEffect(scale)
            } animation: { _ in
                .easeInOut(duration: 0.6)
            }
    }
}

private struct GameOverCard: View {
    let state: GameState
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Game Over")
                .font(.system(size: 36, weight: .heavy, design: .rounded))

            HStack(spacing: 36) {
                stat("Score", value: state.score)
                stat("Best", value: state.bestScore)
            }

            if let medal = state.medal {
                Label(medal.title, systemImage: "medal.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(medal.color)
            }

            if state.isNewBest {
                Text("New best!")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.white)
            }

            Button(action: onRestart) {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(28)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(32)
    }

    private func stat(_ title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
        }
    }
}

#Preview {
    ContentView()
}
