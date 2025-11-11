import Vision
import CoreGraphics

struct FaceLandmark {
    let name: String
    let point: CGPoint
    let confidence: Float
}

struct DetectedFace {
    let landmarks: [FaceLandmark]
    let boundingBox: CGRect
    let confidence: Float
    let smileScore: Float // 0.0 - 1.0
}

struct HandJoint {
    let name: VNHumanHandPoseObservation.JointName
    let point: CGPoint
    let confidence: Float
}

enum HandChirality {
    case left
    case right
}

struct DetectedHand {
    let joints: [HandJoint]
    let chirality: HandChirality // .left or .right
    let confidence: Float
}

enum DetectionMode {
    case fullBody
    case upperBody
    case faceAndHands
}

