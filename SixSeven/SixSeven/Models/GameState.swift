import Foundation

// MARK: - Game Configuration
struct GameConfig {
    static let durations: [Int] = [15, 30, 60]
    static let defaultDuration: Int = 30
    static let phaseBTimeout: TimeInterval = 2.0
    static let minCycleInterval: TimeInterval = 0.05

    // Action Zone thresholds (fractions of bodyUnit = shoulderY - noseY)
    static let raiseZone: CGFloat = 0.55
    static let dropZone: CGFloat = 0.40

    // Velocity snap threshold (normalized Y units per frame, positive = downward)
    static let snapVelocity: CGFloat = 0.006
    static let armConfirmFrames: Int = 2
    static let fireConfirmFrames: Int = 1

    // Streak
    static let streakWindowSeconds: TimeInterval = 4.0
    static let streakThreshold: Int = 5
    static let fireModeDuration: TimeInterval = 4.0
}

// MARK: - Sequence Phase
enum SequencePhase {
    case phaseA  // waiting for first hand
    case phaseB  // waiting for opposite hand
}

// MARK: - Game Results
struct GameResults {
    let count: Int
    let duration: Int
    let bestStreak: Int
    let perSecond: Double
    let personalBest: Int
    let isNewBest: Bool
    let rank: String

    static func compute(count: Int, duration: Int, bestStreak: Int) -> GameResults {
        let perSec = Double(count) / Double(duration)
        let bestKey = "sixseven_best"
        let prevBest = UserDefaults.standard.integer(forKey: bestKey)
        let isNew = count > prevBest
        if isNew { UserDefaults.standard.set(count, forKey: bestKey) }

        let rate = Double(count) / Double(duration) * 30.0
        let rank: String
        switch rate {
        case 50...: rank = "legend"
        case 35..<50: rank = "pro"
        case 20..<35: rank = "solid"
        case 10..<20: rank = "warming up"
        default: rank = "rookie"
        }

        return GameResults(
            count: count, duration: duration, bestStreak: bestStreak,
            perSecond: perSec, personalBest: isNew ? count : prevBest,
            isNewBest: isNew, rank: rank
        )
    }
}
