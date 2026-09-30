import Foundation
import Observation
import SwiftUI

/// Shared, observable state that the SpriteKit scene writes to and the SwiftUI
/// overlay reads from.
@MainActor
@Observable
final class GameState {

    enum Phase {
        /// Bird bobbing in place, waiting for the first tap.
        case ready
        /// Pipes are moving and the bird is under gravity.
        case playing
        /// The bird has hit something and is falling; input is ignored.
        case dying
        /// Round is over and the results card is showing.
        case gameOver
    }

    enum Medal: CaseIterable {
        case bronze, silver, gold, platinum

        var threshold: Int {
            switch self {
            case .bronze: 10
            case .silver: 20
            case .gold: 30
            case .platinum: 40
            }
        }

        var title: String {
            switch self {
            case .bronze: "Bronze"
            case .silver: "Silver"
            case .gold: "Gold"
            case .platinum: "Platinum"
            }
        }

        var color: Color {
            switch self {
            case .bronze: Color(red: 0.80, green: 0.50, blue: 0.20)
            case .silver: Color(red: 0.75, green: 0.75, blue: 0.78)
            case .gold: Color(red: 0.98, green: 0.78, blue: 0.18)
            case .platinum: Color(red: 0.55, green: 0.85, blue: 0.95)
            }
        }
    }

    private static let bestScoreKey = "bestScore"

    var phase: Phase = .ready
    private(set) var score = 0
    private(set) var bestScore: Int
    private(set) var isNewBest = false

    init() {
        bestScore = UserDefaults.standard.integer(forKey: Self.bestScoreKey)
    }

    var medal: Medal? {
        Medal.allCases.last { score >= $0.threshold }
    }

    func addPoint() {
        score += 1
    }

    /// Called once the bird has finished falling after a crash.
    func finishRound() {
        guard phase != .gameOver else { return }
        phase = .gameOver
        if score > bestScore {
            bestScore = score
            isNewBest = true
            UserDefaults.standard.set(bestScore, forKey: Self.bestScoreKey)
        }
    }

    func reset() {
        score = 0
        isNewBest = false
        phase = .ready
    }
}
