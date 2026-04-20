import Foundation

// MARK: - Per-Hand State Machine
enum HandPhase: String {
    case idle
    case raised
    case dropped
}

struct HandState {
    var phase: HandPhase = .idle
    var raisedFrames: Int = 0
    var dropFrames: Int = 0
    var raisedAt: TimeInterval = 0

    mutating func reset() {
        phase = .idle
        raisedFrames = 0
        dropFrames = 0
        raisedAt = 0
    }

    /// Process a single hand's raise→drop cycle.
    /// Returns true when the hand completes a full raise→drop.
    mutating func process(
        smoothY: CGFloat,
        velocity: CGFloat,
        raiseThreshold: CGFloat,
        dropThreshold: CGFloat,
        now: TimeInterval
    ) -> Bool {
        switch phase {
        case .idle:
            if smoothY < raiseThreshold {
                raisedFrames += 1
                if raisedFrames >= GameConfig.armConfirmFrames {
                    phase = .raised
                    raisedAt = now
                    dropFrames = 0
                }
            } else {
                raisedFrames = 0
            }
            return false

        case .raised:
            // Still above raise line — not dropping yet
            if smoothY < raiseThreshold {
                dropFrames = 0
                return false
            }

            let positionDrop = smoothY > dropThreshold
            let velocitySnap = velocity > GameConfig.snapVelocity

            if positionDrop || velocitySnap {
                dropFrames += 1
                if dropFrames >= GameConfig.fireConfirmFrames {
                    phase = .dropped
                    return true
                }
            } else {
                dropFrames = 0
            }
            return false

        case .dropped:
            return false
        }
    }
}

// MARK: - Which Hand
enum WhichHand: String {
    case left, right

    var opposite: WhichHand {
        self == .left ? .right : .left
    }

    var label: String { rawValue.uppercased() }
}
