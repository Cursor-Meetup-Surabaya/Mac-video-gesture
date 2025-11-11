import SwiftUI
import Vision

struct FaceHandOverlayView: View {
    let pose: DetectedPose
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Draw hand skeletons
            ForEach(pose.hands.indices, id: \.self) { index in
                HandSkeletonView(hand: pose.hands[index], size: size)
            }
        }
    }
}

struct FaceLandmarksView: View {
    let face: DetectedFace
    let size: CGSize
    
    var body: some View {
        Canvas { context, _ in
            drawFaceLandmarks(context: context)
        }
    }
    
    private func drawFaceLandmarks(context: GraphicsContext) {
        // Group landmarks by region
        var landmarkGroups: [String: [FaceLandmark]] = [:]
        for landmark in face.landmarks {
            let groupName = landmark.name.components(separatedBy: "_").first ?? "unknown"
            if landmarkGroups[groupName] == nil {
                landmarkGroups[groupName] = []
            }
            landmarkGroups[groupName]?.append(landmark)
        }
        
        // Draw each landmark group
        for (groupName, landmarks) in landmarkGroups {
            guard landmarks.count > 1 else { continue }
            
            let color = colorForLandmarkGroup(groupName)
            
            // Draw connections between consecutive landmarks
            for i in 0..<landmarks.count - 1 {
                let start = landmarks[i]
                let end = landmarks[i + 1]
                
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
                
                context.stroke(
                    path,
                    with: .color(color.opacity(0.8)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
            
            // Draw landmark points
            for landmark in landmarks {
                let point = CGPoint(
                    x: landmark.point.x * size.width,
                    y: landmark.point.y * size.height
                )
                
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                    with: .color(color)
                )
            }
        }
    }
    
    private func colorForLandmarkGroup(_ groupName: String) -> Color {
        switch groupName {
        case "leftEye", "rightEye":
            return .cyan
        case "nose", "noseCrest":
            return .blue
        case "outerLips", "innerLips":
            return .red
        case "faceContour":
            return .yellow
        case "leftEyebrow", "rightEyebrow":
            return .orange
        default:
            return .white
        }
    }
}

struct HandSkeletonView: View {
    let hand: DetectedHand
    let size: CGSize
    
    var body: some View {
        Canvas { context, _ in
            drawHandSkeleton(context: context)
        }
    }
    
    private func drawHandSkeleton(context: GraphicsContext) {
        guard let jointsDict = jointsDictionary() else { return }
        
        let handColor = hand.chirality == .left ? Color.green : Color.red
        
        // Hand skeleton connections
        let connections: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            // Thumb
            (.wrist, .thumbCMC),
            (.thumbCMC, .thumbMP),
            (.thumbMP, .thumbIP),
            (.thumbIP, .thumbTip),
            
            // Index finger
            (.wrist, .indexMCP),
            (.indexMCP, .indexPIP),
            (.indexPIP, .indexDIP),
            (.indexDIP, .indexTip),
            
            // Middle finger
            (.wrist, .middleMCP),
            (.middleMCP, .middlePIP),
            (.middlePIP, .middleDIP),
            (.middleDIP, .middleTip),
            
            // Ring finger
            (.wrist, .ringMCP),
            (.ringMCP, .ringPIP),
            (.ringPIP, .ringDIP),
            (.ringDIP, .ringTip),
            
            // Little finger
            (.wrist, .littleMCP),
            (.littleMCP, .littlePIP),
            (.littlePIP, .littleDIP),
            (.littleDIP, .littleTip)
        ]
        
        // Draw connections
        for (startJoint, endJoint) in connections {
            guard let start = jointsDict[startJoint],
                  let end = jointsDict[endJoint],
                  start.confidence > 0.2 && end.confidence > 0.2 else { continue }
            
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
            
            let avgConfidence = (start.confidence + end.confidence) / 2.0
            let opacity = Double(avgConfidence)
            
            context.stroke(
                path,
                with: .color(handColor.opacity(0.9 * opacity)),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        
        // Draw joints
        for joint in hand.joints {
            guard joint.confidence > 0.2 else { continue }
            
            let point = CGPoint(
                x: joint.point.x * size.width,
                y: joint.point.y * size.height
            )
            
            let jointSize: CGFloat = joint.name == .wrist ? 10 : 6
            let opacity = Double(joint.confidence)
            
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - jointSize/2,
                    y: point.y - jointSize/2,
                    width: jointSize,
                    height: jointSize
                )),
                with: .color(handColor.opacity(opacity))
            )
            
            // White outline
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: point.x - jointSize/2,
                    y: point.y - jointSize/2,
                    width: jointSize,
                    height: jointSize
                )),
                with: .color(.white.opacity(opacity)),
                style: StrokeStyle(lineWidth: 1)
            )
        }
    }
    
    private func jointsDictionary() -> [VNHumanHandPoseObservation.JointName: HandJoint]? {
        var dict: [VNHumanHandPoseObservation.JointName: HandJoint] = [:]
        for joint in hand.joints {
            dict[joint.name] = joint
        }
        return dict.isEmpty ? nil : dict
    }
}

