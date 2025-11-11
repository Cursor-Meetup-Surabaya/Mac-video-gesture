import SwiftUI
import Vision
import CoreImage

struct PoseOverlayView: View {
    @ObservedObject var poseDetector: PoseDetector
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let pose = poseDetector.currentPose {
                    // Draw body skeleton (if we have body joints)
                    if !pose.joints.isEmpty {
                        PoseSkeletonView(pose: pose, size: geometry.size)
                        
                        // Draw body joint points using centralized style map
                        ForEach(pose.joints.indices, id: \.self) { index in
                            let joint = pose.joints[index]
                            let color = PoseStyle.color(for: joint.name)
                            let size = PoseStyle.size(for: joint.name)
                            
                            // Adjust opacity based on confidence for missing/low-confidence joints
                            let opacity = joint.confidence > 0.5 ? 1.0 : Double(joint.confidence)
                            let strokeWidth = joint.confidence > 0.5 ? 2.0 : 1.0
                            
                            Circle()
                                .fill(color.opacity(opacity))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(opacity), lineWidth: strokeWidth)
                                )
                                .shadow(color: color.opacity(0.8 * opacity), radius: 6)
                                .frame(width: size, height: size)
                                .position(
                                    x: joint.point.x * geometry.size.width,
                                    y: joint.point.y * geometry.size.height
                                )
                        }
                    }
                    
                    // Draw face landmarks and hand skeletons (always if available)
                    FaceHandOverlayView(pose: pose, size: geometry.size)
                    
                    // Display posture status and detection mode
                    VStack(spacing: 8) {
                        if let posture = pose.posture {
                            PostureStatusView(posture: posture)
                        }
                        
                        // Detection mode badge
                        DetectionModeBadge(mode: pose.detectionMode)
                        
                        // Smile badge if available
                        if let face = pose.face {
                            SmileBadgeView(score: face.smileScore)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct PoseSkeletonView: View {
    let pose: DetectedPose
    let size: CGSize
    
    var body: some View {
        Canvas { context, _ in
            drawSkeleton(context: context)
        }
    }
    
    private func drawSkeleton(context: GraphicsContext) {
        guard let jointsDict = jointsDictionary() else { return }
        
        // Skeleton connections following Create with Swift tutorial pattern
        // Organized by priority - draw visible parts first
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, Bool)] = [
            // Head (always visible when person is detected)
            (.nose, .leftEye, true),
            (.nose, .rightEye, true),
            (.leftEye, .leftEar, true),
            (.rightEye, .rightEar, true),
            
            // Upper body (usually visible)
            (.leftShoulder, .rightShoulder, true),
            (.leftShoulder, .leftElbow, true),
            (.leftElbow, .leftWrist, true),
            (.rightShoulder, .rightElbow, true),
            (.rightElbow, .rightWrist, true),
            (.leftShoulder, .neck, true),
            (.rightShoulder, .neck, true),
            (.neck, .root, true),
            
            // Torso to hips (usually visible)
            (.leftShoulder, .leftHip, true),
            (.rightShoulder, .rightHip, true),
            (.leftHip, .rightHip, true),
            
            // Lower body (may be occluded when sitting)
            (.leftHip, .leftKnee, false), // Optional when sitting
            (.leftKnee, .leftAnkle, false), // Optional when sitting
            (.rightHip, .rightKnee, false), // Optional when sitting
            (.rightKnee, .rightAnkle, false), // Optional when sitting
            (.root, .leftHip, true),
            (.root, .rightHip, true)
        ]
        
        for (startJoint, endJoint, isRequired) in connections {
            guard let start = jointsDict[startJoint],
                  let end = jointsDict[endJoint] else {
                // Skip if required connection is missing
                if isRequired { continue }
                // For optional connections, try to draw partial if one joint exists
                continue
            }
            
            // Check confidence - only draw if both joints are confident enough
            let minConfidence: Float = isRequired ? 0.3 : 0.2
            guard start.confidence > minConfidence && end.confidence > minConfidence else {
                continue
            }
            
            let startPoint = CGPoint(
                x: start.point.x * size.width,
                y: start.point.y * size.height
            )
            let endPoint = CGPoint(
                x: end.point.x * size.width,
                y: end.point.y * size.height
            )
            
            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)
            
            // Get colors from centralized style map
            let startColor = PoseStyle.color(for: startJoint)
            let endColor = PoseStyle.color(for: endJoint)
            let baseLineWidth = PoseStyle.lineWidth(for: startJoint, endJoint: endJoint)
            
            // Adjust opacity and style based on confidence
            let avgConfidence = (start.confidence + end.confidence) / 2.0
            let opacity = Double(avgConfidence)
            let lineWidth = baseLineWidth * CGFloat(avgConfidence)
            
            // Use dashed line for low-confidence connections
            let dashPattern: [CGFloat] = avgConfidence < 0.5 ? [5, 5] : []
            
            // Use gradient for smooth color transitions between joints
            let gradient = Gradient(colors: [
                startColor.opacity(0.95 * opacity),
                endColor.opacity(0.95 * opacity)
            ])
            
            context.stroke(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                ),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: dashPattern
                )
            )
        }
    }
    
    private func jointsDictionary() -> [VNHumanBodyPoseObservation.JointName: PoseJoint]? {
        var dict: [VNHumanBodyPoseObservation.JointName: PoseJoint] = [:]
        for joint in pose.joints {
            dict[joint.name] = joint
        }
        return dict.isEmpty ? nil : dict
    }
}

struct BackgroundSegmentationView: View {
    let mask: CIImage
    let size: CGSize
    
    var body: some View {
        // Background blur effect - handled by BackgroundEffectView in ContentView
        EmptyView()
    }
}

