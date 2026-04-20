import SwiftUI
import Combine

/// Central game coordinator. Owns all managers and state.
@MainActor
final class GameViewModel: ObservableObject {
    // MARK: - Published State
    @Published var count = 0
    @Published var timeLeft = 30
    @Published var selectedDuration = GameConfig.defaultDuration
    @Published var isTracking = false
    @Published var gameOver = false
    @Published var promptText = "raise one hand up"
    @Published var promptState: PromptStyle = .idle
    @Published var handDetected = false
    @Published var showCountdown = false
    @Published var countdownText = "3"

    // Pose visualization data
    @Published var poseData: PoseData?
    @Published var raiseLineY: CGFloat = 0.35
    @Published var dropLineY: CGFloat = 0.55

    // Hand badge states
    @Published var leftBadgeState: BadgeState = .idle
    @Published var rightBadgeState: BadgeState = .idle

    // Streak
    @Published var streakCount = 0
    @Published var fireMode = false

    // Screen shake trigger
    @Published var shakeIntensity: CGFloat = 0
    @Published var countPop = false

    // Results
    @Published var results: GameResults?

    // MARK: - Managers
    let camera = CameraManager()
    let poseProcessor = PoseProcessor()
    let audio = AudioEngine()

    // MARK: - Internal State
    private var leftHand = HandState()
    private var rightHand = HandState()
    private var phase: SequencePhase = .phaseA
    private var completedHand: WhichHand?
    private var phaseBStart: TimeInterval = 0
    private var lastCountTime: TimeInterval = 0
    private var lostFrames = 0

    // Smoothing
    private var smoothLWristY: CGFloat?
    private var smoothRWristY: CGFloat?
    private var prevSmoothLY: CGFloat?
    private var prevSmoothRY: CGFloat?
    private let wristSmooth: CGFloat = 0.25

    // Streak tracking
    private var streakTimestamps: [TimeInterval] = []
    private var bestStreak = 0
    private var fireModeEnd: TimeInterval = 0

    // Timer
    private var gameTimer: Timer?
    private var gameStartTime: Date?

    // MARK: - Init

    init() {
        camera.configure()
        setupPoseCallbacks()
    }

    private func setupPoseCallbacks() {
        poseProcessor.onPoseDetected = { [weak self] pose in
            Task { @MainActor in
                self?.handlePose(pose)
            }
        }
        poseProcessor.onPoseLost = { [weak self] in
            Task { @MainActor in
                self?.handlePoseLost()
            }
        }
        camera.onFrame = { [weak self] buffer in
            self?.poseProcessor.processFrame(buffer)
        }
    }

    // MARK: - Game Flow

    func startGame() {
        resetState()
        camera.start()
        audio.setup()

        // Run countdown first
        showCountdown = true
        runCountdown { [weak self] in
            self?.beginTracking()
        }
    }

    func endGame() {
        guard isTracking else { return }
        isTracking = false
        gameTimer?.invalidate()
        gameTimer = nil
        audio.stopBGM()
        audio.setMuffled(false)
        audio.playVictorySFX()

        gameOver = true
        results = GameResults.compute(
            count: count,
            duration: selectedDuration,
            bestStreak: bestStreak
        )

        // Camera stops after delay (results screen transition)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.camera.stop()
        }
    }

    func cleanup() {
        camera.stop()
        audio.shutdown()
        gameTimer?.invalidate()
    }

    // MARK: - Reset

    private func resetState() {
        count = 0
        timeLeft = selectedDuration
        gameOver = false
        isTracking = false
        handDetected = false
        promptText = "raise one hand up"
        promptState = .idle
        leftBadgeState = .idle
        rightBadgeState = .idle
        streakCount = 0
        fireMode = false
        shakeIntensity = 0
        countPop = false
        results = nil

        leftHand.reset()
        rightHand.reset()
        phase = .phaseA
        completedHand = nil
        phaseBStart = 0
        lastCountTime = 0
        lostFrames = 0
        smoothLWristY = nil
        smoothRWristY = nil
        prevSmoothLY = nil
        prevSmoothRY = nil
        streakTimestamps = []
        bestStreak = 0
        fireModeEnd = 0
    }

    // MARK: - Countdown

    private func runCountdown(completion: @escaping () -> Void) {
        let steps = ["3", "2", "1", "GO!"]
        var index = 0

        func showNext() {
            guard index < steps.count else {
                showCountdown = false
                completion()
                return
            }
            let step = steps[index]
            countdownText = step
            audio.playCountdownBeep(isGo: step == "GO!")
            index += 1
            let delay: TimeInterval = step == "GO!" ? 0.6 : 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                showNext()
            }
        }
        showNext()
    }

    private func beginTracking() {
        isTracking = true
        gameStartTime = Date()
        lastCountTime = 0

        audio.startBGM()

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isTracking else { return }
                self.timeLeft -= 1
                if self.timeLeft <= 0 {
                    self.endGame()
                }
            }
        }
    }

    // MARK: - Pose Processing

    private func handlePose(_ rawPose: PoseData) {
        guard isTracking else {
            poseData = rawPose.flipped
            return
        }

        let pose = rawPose.flipped
        poseData = pose
        lostFrames = 0
        handDetected = true

        let shoulderY = (pose.leftShoulder.y + pose.rightShoulder.y) / 2
        let noseY = pose.nose.y
        let bodyUnit = shoulderY - noseY
        guard bodyUnit > 0.01 else { return }

        let raiseThreshold = noseY + bodyUnit * GameConfig.raiseZone
        let dropThreshold = shoulderY + bodyUnit * GameConfig.dropZone

        raiseLineY = raiseThreshold
        dropLineY = dropThreshold

        // Smooth wrist Y + velocity
        prevSmoothLY = smoothLWristY
        prevSmoothRY = smoothRWristY
        smoothLWristY = lowPass(prev: smoothLWristY, raw: pose.leftWrist.y)
        smoothRWristY = lowPass(prev: smoothRWristY, raw: pose.rightWrist.y)

        let velL = prevSmoothLY != nil ? (smoothLWristY! - prevSmoothLY!) : 0
        let velR = prevSmoothRY != nil ? (smoothRWristY! - prevSmoothRY!) : 0

        let now = CACurrentMediaTime()

        // ANTI-CHEAT: both hands above raise line → reject
        let leftAbove = (smoothLWristY ?? 1) < raiseThreshold
        let rightAbove = (smoothRWristY ?? 1) < raiseThreshold
        if leftAbove && rightAbove {
            leftHand.reset()
            rightHand.reset()
            if phase == .phaseA { setPrompt(.idle) }
            updateBadges()
            return
        }

        // Phase B timeout
        if phase == .phaseB && (now - phaseBStart) > GameConfig.phaseBTimeout {
            phase = .phaseA
            completedHand = nil
            leftHand.reset()
            rightHand.reset()
            setPrompt(.idle)
            updateBadges()
            return
        }

        // Process each hand
        let leftDone = leftHand.process(
            smoothY: smoothLWristY ?? 1, velocity: velL,
            raiseThreshold: raiseThreshold, dropThreshold: dropThreshold, now: now
        )
        let rightDone = rightHand.process(
            smoothY: smoothRWristY ?? 1, velocity: velR,
            raiseThreshold: raiseThreshold, dropThreshold: dropThreshold, now: now
        )

        // Phase A: waiting for first hand
        if phase == .phaseA {
            if leftDone || rightDone {
                let which: WhichHand = leftDone ? .left : .right
                phase = .phaseB
                completedHand = which
                phaseBStart = now

                // Reset opposite hand
                if which == .left { rightHand.reset() } else { leftHand.reset() }

                setPrompt(.half(which))
                audio.triggerHalfwayHaptic()
                audio.setMuffled(false)
            } else if leftHand.phase == .raised || rightHand.phase == .raised {
                setPrompt(.raising)
                audio.setMuffled(true)
            }
            updateBadges()
            return
        }

        // Phase B: waiting for opposite hand
        if phase == .phaseB {
            let needed: WhichHand = completedHand == .left ? .right : .left
            let neededDone = needed == .left ? leftDone : rightDone

            if neededDone && (now - lastCountTime) >= GameConfig.minCycleInterval {
                lastCountTime = now
                phase = .phaseA
                completedHand = nil
                leftHand.reset()
                rightHand.reset()
                triggerCount()
            } else {
                let neededHand = needed == .left ? leftHand : rightHand
                if neededHand.phase == .raised {
                    setPrompt(.almostB(needed))
                    audio.setMuffled(true)
                }
            }
            updateBadges()
        }
    }

    private func handlePoseLost() {
        lostFrames += 1
        if lostFrames > 15 {
            handDetected = false
        }
        if lostFrames > 60 {
            leftHand.reset()
            rightHand.reset()
            phase = .phaseA
            completedHand = nil
            smoothLWristY = nil
            smoothRWristY = nil
            prevSmoothLY = nil
            prevSmoothRY = nil
        }
    }

    // MARK: - Count

    private func triggerCount() {
        count += 1
        registerStreak()

        audio.setMuffled(false)
        audio.playSnapSFX()
        audio.triggerCountHaptic()

        setPrompt(.idle)

        // Screen shake
        withAnimation(.easeOut(duration: 0.35)) {
            shakeIntensity = fireMode ? 14 : 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.shakeIntensity = 0
        }

        // Count pop
        countPop = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.countPop = false
        }
    }

    // MARK: - Streak

    private func registerStreak() {
        let now = CACurrentMediaTime()
        streakTimestamps.append(now)
        streakTimestamps = streakTimestamps.filter { now - $0 < GameConfig.streakWindowSeconds }
        streakCount = streakTimestamps.count
        if streakCount > bestStreak { bestStreak = streakCount }

        if streakCount >= GameConfig.streakThreshold {
            fireMode = true
            fireModeEnd = now + GameConfig.fireModeDuration
        }
    }

    func updateFireMode() {
        if fireMode && CACurrentMediaTime() > fireModeEnd {
            fireMode = false
            streakCount = 0
        }
    }

    // MARK: - Helpers

    private func lowPass(prev: CGFloat?, raw: CGFloat) -> CGFloat {
        guard let prev else { return raw }
        return prev * wristSmooth + raw * (1 - wristSmooth)
    }

    private func setPrompt(_ style: PromptStyle) {
        promptState = style
        switch style {
        case .idle:
            promptText = "raise one hand up"
        case .raising:
            promptText = "now drop it!"
        case .half(let hand):
            promptText = "\(hand.label) done — now \(hand.opposite.label)!"
        case .almostB(let hand):
            promptText = "DROP \(hand.label)!"
        }
    }

    private func updateBadges() {
        if phase == .phaseA {
            leftBadgeState = leftHand.phase == .raised ? .waiting : .idle
            rightBadgeState = rightHand.phase == .raised ? .waiting : .idle
        } else if phase == .phaseB {
            if completedHand == .left {
                leftBadgeState = .done
                rightBadgeState = .next
            } else {
                rightBadgeState = .done
                leftBadgeState = .next
            }
        }
    }
}

// MARK: - Supporting Types

enum PromptStyle {
    case idle, raising
    case half(WhichHand)
    case almostB(WhichHand)
}

enum BadgeState {
    case idle, waiting, done, next
}
