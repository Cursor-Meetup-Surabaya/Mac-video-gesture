import SwiftUI
import Vision

/// Centralized style configuration for pose visualization
/// Based on Apple Vision best practices and Create with Swift tutorial
struct PoseStyle {
    /// Joint style configuration: (color, size)
    static let jointStyles: [VNHumanBodyPoseObservation.JointName: (Color, CGFloat)] = [
        // Head - Bright Blue, larger size
        .nose: (Color(red: 0.0, green: 0.5, blue: 1.0), 16),
        .leftEar: (Color(red: 0.0, green: 0.5, blue: 1.0), 14),
        .rightEar: (Color(red: 0.0, green: 0.5, blue: 1.0), 14),
        
        // Eyes - Bright Cyan, largest size
        .leftEye: (Color(red: 0.0, green: 1.0, blue: 1.0), 18),
        .rightEye: (Color(red: 0.0, green: 1.0, blue: 1.0), 18),
        
        // Hands - Green (left) and Red (right), largest size
        .leftWrist: (Color(red: 0.0, green: 1.0, blue: 0.0), 18),
        .rightWrist: (Color(red: 1.0, green: 0.0, blue: 0.0), 18),
        
        // Arms - Yellow (left) and Orange (right)
        .leftShoulder: (Color(red: 1.0, green: 1.0, blue: 0.0), 12),
        .leftElbow: (Color(red: 1.0, green: 1.0, blue: 0.0), 12),
        .rightShoulder: (Color(red: 1.0, green: 0.65, blue: 0.0), 12),
        .rightElbow: (Color(red: 1.0, green: 0.65, blue: 0.0), 12),
        
        // Torso - Purple
        .neck: (Color(red: 0.8, green: 0.0, blue: 1.0), 14),
        .root: (Color(red: 0.8, green: 0.0, blue: 1.0), 14),
        
        // Legs - Indigo (left) and Magenta (right)
        .leftHip: (Color(red: 0.3, green: 0.0, blue: 1.0), 12),
        .leftKnee: (Color(red: 0.3, green: 0.0, blue: 1.0), 12),
        .leftAnkle: (Color(red: 0.3, green: 0.0, blue: 1.0), 12),
        .rightHip: (Color(red: 1.0, green: 0.0, blue: 1.0), 12),
        .rightKnee: (Color(red: 1.0, green: 0.0, blue: 1.0), 12),
        .rightAnkle: (Color(red: 1.0, green: 0.0, blue: 1.0), 12)
    ]
    
    /// Get color for a joint
    static func color(for jointName: VNHumanBodyPoseObservation.JointName) -> Color {
        jointStyles[jointName]?.0 ?? Color.white
    }
    
    /// Get size for a joint
    static func size(for jointName: VNHumanBodyPoseObservation.JointName) -> CGFloat {
        jointStyles[jointName]?.1 ?? 10
    }
    
    /// Check if joint is critical (head, eyes, hands)
    static func isCritical(_ jointName: VNHumanBodyPoseObservation.JointName) -> Bool {
        switch jointName {
        case .nose, .leftEye, .rightEye, .leftEar, .rightEar, .leftWrist, .rightWrist, .neck:
            return true
        default:
            return false
        }
    }
    
    /// Get line width for skeleton connections
    static func lineWidth(for startJoint: VNHumanBodyPoseObservation.JointName, 
                         endJoint: VNHumanBodyPoseObservation.JointName) -> CGFloat {
        if isCritical(startJoint) || isCritical(endJoint) {
            return 5.0
        }
        return 3.0
    }
}

