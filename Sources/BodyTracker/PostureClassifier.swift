import Foundation
import Vision

enum Posture: String {
    case standing = "Standing"
    case sitting = "Sitting"
    case unknown = "Unknown"
}

struct PostureAnalysis {
    let posture: Posture
    let confidence: Float
    let reasoning: String
}

/// Classifies human posture (sitting vs standing) based on joint positions and angles
/// Based on Apple Vision framework best practices
class PostureClassifier {
    
    /// Analyze posture from detected joints
    static func classify(pose: DetectedPose) -> PostureAnalysis {
        let jointsDict = Dictionary(uniqueKeysWithValues: pose.joints.map { ($0.name, $0) })
        
        // Check multiple indicators for robust classification
        var indicators: [(Posture, Float, String)] = []
        
        // Indicator 1: Knee angle (most reliable for sitting vs standing)
        if let kneeAngle = calculateKneeAngle(jointsDict: jointsDict) {
            if kneeAngle < 120 { // Bent knees indicate sitting
                indicators.append((.sitting, 0.8, "Knee angle: \(Int(kneeAngle))° (bent)"))
            } else {
                indicators.append((.standing, 0.7, "Knee angle: \(Int(kneeAngle))° (straight)"))
            }
        }
        
        // Indicator 2: Hip-to-knee vertical distance
        if let hipKneeDistance = calculateHipKneeVerticalDistance(jointsDict: jointsDict) {
            if hipKneeDistance < 0.15 { // Short distance indicates sitting
                indicators.append((.sitting, 0.7, "Hip-knee distance: \(String(format: "%.2f", hipKneeDistance))"))
            } else {
                indicators.append((.standing, 0.6, "Hip-knee distance: \(String(format: "%.2f", hipKneeDistance))"))
            }
        }
        
        // Indicator 3: Torso verticality (shoulder-hip alignment)
        if let torsoAngle = calculateTorsoAngle(jointsDict: jointsDict) {
            if abs(torsoAngle) < 15 { // Vertical torso indicates standing
                indicators.append((.standing, 0.6, "Torso angle: \(Int(torsoAngle))°"))
            } else {
                indicators.append((.sitting, 0.5, "Torso angle: \(Int(torsoAngle))°"))
            }
        }
        
        // Indicator 4: Overall body height ratio
        if let heightRatio = calculateBodyHeightRatio(jointsDict: jointsDict) {
            if heightRatio < 0.4 { // Short overall height indicates sitting
                indicators.append((.sitting, 0.6, "Body height ratio: \(String(format: "%.2f", heightRatio))"))
            } else {
                indicators.append((.standing, 0.5, "Body height ratio: \(String(format: "%.2f", heightRatio))"))
            }
        }
        
        // Indicator 5: Ankle visibility (ankles often hidden when sitting)
        let ankleVisibility = calculateAnkleVisibility(jointsDict: jointsDict)
        if ankleVisibility < 0.3 {
            indicators.append((.sitting, 0.5, "Ankles not visible"))
        } else {
            indicators.append((.standing, 0.4, "Ankles visible"))
        }
        
        // Weighted voting system
        if indicators.isEmpty {
            return PostureAnalysis(
                posture: .unknown,
                confidence: 0.0,
                reasoning: "Insufficient joint data"
            )
        }
        
        // Calculate weighted scores
        var sittingScore: Float = 0.0
        var standingScore: Float = 0.0
        var totalWeight: Float = 0.0
        var reasoningParts: [String] = []
        
        for (posture, weight, reason) in indicators {
            totalWeight += weight
            reasoningParts.append(reason)
            
            if posture == .sitting {
                sittingScore += weight
            } else if posture == .standing {
                standingScore += weight
            }
        }
        
        // Normalize scores
        if totalWeight > 0 {
            sittingScore /= totalWeight
            standingScore /= totalWeight
        }
        
        // Determine final posture
        let finalPosture: Posture
        let confidence: Float
        
        if sittingScore > standingScore && sittingScore > 0.5 {
            finalPosture = .sitting
            confidence = min(sittingScore, 0.95)
        } else if standingScore > sittingScore && standingScore > 0.5 {
            finalPosture = .standing
            confidence = min(standingScore, 0.95)
        } else {
            finalPosture = .unknown
            confidence = max(sittingScore, standingScore)
        }
        
        return PostureAnalysis(
            posture: finalPosture,
            confidence: confidence,
            reasoning: reasoningParts.joined(separator: "; ")
        )
    }
    
    // MARK: - Helper Methods
    
    /// Calculate knee angle (hip-knee-ankle)
    private static func calculateKneeAngle(jointsDict: [VNHumanBodyPoseObservation.JointName: PoseJoint]) -> CGFloat? {
        // Try left leg first
        if let hip = jointsDict[.leftHip],
           let knee = jointsDict[.leftKnee],
           let ankle = jointsDict[.leftAnkle],
           hip.confidence > 0.3 && knee.confidence > 0.3 && ankle.confidence > 0.3 {
            return angleBetweenThreePoints(
                p1: hip.point,
                p2: knee.point,
                p3: ankle.point
            )
        }
        
        // Try right leg
        if let hip = jointsDict[.rightHip],
           let knee = jointsDict[.rightKnee],
           let ankle = jointsDict[.rightAnkle],
           hip.confidence > 0.3 && knee.confidence > 0.3 && ankle.confidence > 0.3 {
            return angleBetweenThreePoints(
                p1: hip.point,
                p2: knee.point,
                p3: ankle.point
            )
        }
        
        return nil
    }
    
    /// Calculate vertical distance between hip and knee
    private static func calculateHipKneeVerticalDistance(jointsDict: [VNHumanBodyPoseObservation.JointName: PoseJoint]) -> CGFloat? {
        // Try left leg
        if let hip = jointsDict[.leftHip],
           let knee = jointsDict[.leftKnee],
           hip.confidence > 0.3 && knee.confidence > 0.3 {
            return abs(hip.point.y - knee.point.y)
        }
        
        // Try right leg
        if let hip = jointsDict[.rightHip],
           let knee = jointsDict[.rightKnee],
           hip.confidence > 0.3 && knee.confidence > 0.3 {
            return abs(hip.point.y - knee.point.y)
        }
        
        return nil
    }
    
    /// Calculate torso angle (shoulder-hip alignment)
    private static func calculateTorsoAngle(jointsDict: [VNHumanBodyPoseObservation.JointName: PoseJoint]) -> CGFloat? {
        if let shoulder = jointsDict[.leftShoulder],
           let hip = jointsDict[.leftHip],
           shoulder.confidence > 0.3 && hip.confidence > 0.3 {
            let dx = hip.point.x - shoulder.point.x
            let dy = hip.point.y - shoulder.point.y
            return atan2(dx, dy) * 180 / .pi
        }
        
        if let shoulder = jointsDict[.rightShoulder],
           let hip = jointsDict[.rightHip],
           shoulder.confidence > 0.3 && hip.confidence > 0.3 {
            let dx = hip.point.x - shoulder.point.x
            let dy = hip.point.y - shoulder.point.y
            return atan2(dx, dy) * 180 / .pi
        }
        
        return nil
    }
    
    /// Calculate body height ratio (head to hip vs hip to ankle)
    private static func calculateBodyHeightRatio(jointsDict: [VNHumanBodyPoseObservation.JointName: PoseJoint]) -> CGFloat? {
        guard let head = jointsDict[.nose] ?? jointsDict[.neck],
              let hip = jointsDict[.leftHip] ?? jointsDict[.rightHip],
              let ankle = jointsDict[.leftAnkle] ?? jointsDict[.rightAnkle],
              head.confidence > 0.3 && hip.confidence > 0.3 && ankle.confidence > 0.3 else {
            return nil
        }
        
        let headToHip = abs(head.point.y - hip.point.y)
        let hipToAnkle = abs(hip.point.y - ankle.point.y)
        
        if hipToAnkle > 0 {
            return headToHip / (headToHip + hipToAnkle)
        }
        
        return nil
    }
    
    /// Calculate ankle visibility (confidence average)
    private static func calculateAnkleVisibility(jointsDict: [VNHumanBodyPoseObservation.JointName: PoseJoint]) -> Float {
        let leftAnkle = jointsDict[.leftAnkle]?.confidence ?? 0.0
        let rightAnkle = jointsDict[.rightAnkle]?.confidence ?? 0.0
        return (leftAnkle + rightAnkle) / 2.0
    }
    
    /// Calculate angle between three points (p1-p2-p3)
    private static func angleBetweenThreePoints(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        if mag1 > 0 && mag2 > 0 {
            let cosAngle = dot / (mag1 * mag2)
            let angle = acos(max(-1.0, min(1.0, cosAngle)))
            return angle * 180 / .pi
        }
        
        return 180.0
    }
}

