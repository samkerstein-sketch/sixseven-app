import Vision
import CoreMedia
import simd

/// Body landmark indices we care about
enum BodyJoint {
    static let nose = VNHumanBodyPoseObservation.JointName.nose
    static let leftShoulder = VNHumanBodyPoseObservation.JointName.leftShoulder
    static let rightShoulder = VNHumanBodyPoseObservation.JointName.rightShoulder
    static let leftWrist = VNHumanBodyPoseObservation.JointName.leftWrist
    static let rightWrist = VNHumanBodyPoseObservation.JointName.rightWrist
}

/// Extracted pose points (normalized 0-1, Vision coords: origin bottom-left)
struct PoseData {
    let nose: CGPoint
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    let leftWrist: CGPoint
    let rightWrist: CGPoint

    /// Convert Vision coords (origin bottom-left) to screen coords (origin top-left)
    var flipped: PoseData {
        PoseData(
            nose: CGPoint(x: nose.x, y: 1 - nose.y),
            leftShoulder: CGPoint(x: leftShoulder.x, y: 1 - leftShoulder.y),
            rightShoulder: CGPoint(x: rightShoulder.x, y: 1 - rightShoulder.y),
            leftWrist: CGPoint(x: leftWrist.x, y: 1 - leftWrist.y),
            rightWrist: CGPoint(x: rightWrist.x, y: 1 - rightWrist.y)
        )
    }
}

/// Processes camera frames through Apple Vision body pose detection.
/// Runs inference on the Neural Engine via a background serial queue.
final class PoseProcessor {
    private let inferenceQueue = DispatchQueue(label: "com.sixseven.pose", qos: .userInitiated)
    private var request: VNDetectHumanBodyPoseRequest?
    private var isProcessing = false

    var onPoseDetected: ((PoseData) -> Void)?
    var onPoseLost: (() -> Void)?

    init() {
        request = VNDetectHumanBodyPoseRequest()
        // Use revision 1 which leverages ANE
        request?.revision = VNDetectHumanBodyPoseRequestRevision1
    }

    /// Process a camera frame. Drops frames if still processing previous one.
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isProcessing else { return } // drop frame if busy
        isProcessing = true

        inferenceQueue.async { [weak self] in
            defer { self?.isProcessing = false }
            self?.runInference(sampleBuffer)
        }
    }

    private func runInference(_ sampleBuffer: CMSampleBuffer) {
        guard let request,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])

            guard let observation = request.results?.first else {
                DispatchQueue.main.async { [weak self] in
                    self?.onPoseLost?()
                }
                return
            }

            guard let poseData = extractPose(from: observation) else {
                DispatchQueue.main.async { [weak self] in
                    self?.onPoseLost?()
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.onPoseDetected?(poseData)
            }
        } catch {
            // Silently drop failed frames
        }
    }

    private func extractPose(from observation: VNHumanBodyPoseObservation) -> PoseData? {
        let confidenceThreshold: Float = 0.3

        guard let nose = try? observation.recognizedPoint(BodyJoint.nose),
              let lShoulder = try? observation.recognizedPoint(BodyJoint.leftShoulder),
              let rShoulder = try? observation.recognizedPoint(BodyJoint.rightShoulder),
              let lWrist = try? observation.recognizedPoint(BodyJoint.leftWrist),
              let rWrist = try? observation.recognizedPoint(BodyJoint.rightWrist),
              nose.confidence > confidenceThreshold,
              lShoulder.confidence > confidenceThreshold,
              rShoulder.confidence > confidenceThreshold,
              lWrist.confidence > confidenceThreshold,
              rWrist.confidence > confidenceThreshold
        else { return nil }

        return PoseData(
            nose: nose.location,
            leftShoulder: lShoulder.location,
            rightShoulder: rShoulder.location,
            leftWrist: lWrist.location,
            rightWrist: rWrist.location
        )
    }
}
