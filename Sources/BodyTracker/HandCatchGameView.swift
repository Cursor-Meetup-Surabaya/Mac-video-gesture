import SwiftUI
import Vision

struct HandCatchGameView: View {
    @ObservedObject var poseDetector: PoseDetector
    
    @State private var boxPosition: CGPoint = .zero
    @State private var boxVelocity: CGFloat = 280 // px/sec
    @State private var boxSize: CGFloat = 40
    @State private var lastTime: TimeInterval = Date().timeIntervalSince1970
    @State private var score: Int = 0
    private let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Falling box
                Rectangle()
                    .fill(Color.blue.opacity(0.9))
                    .frame(width: boxSize, height: boxSize)
                    .position(boxPosition == .zero ? initialSpawn(in: geo.size) : boxPosition)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Hand debug (optional small circles at palm centers)
                if let pose = poseDetector.currentPose {
                    let centers = handCenters(pose: pose, in: geo.size)
                    ForEach(centers.indices, id: \.self) { i in
                        Circle()
                            .stroke(centers[i].color.opacity(0.6), lineWidth: 2)
                            .background(Circle().fill(centers[i].color.opacity(0.15)))
                            .frame(width: centers[i].radius * 2, height: centers[i].radius * 2)
                            .position(centers[i].point)
                    }
                }
                
                // Score
                Text("Score: \(score)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
            }
            .onAppear {
                boxPosition = initialSpawn(in: geo.size)
                lastTime = Date().timeIntervalSince1970
            }
            .onReceive(timer) { _ in
                let now = Date().timeIntervalSince1970
                let dt = max(0.0, now - lastTime)
                lastTime = now
                updateGame(in: geo.size, dt: dt)
            }
        }
    }
    
    private func initialSpawn(in size: CGSize) -> CGPoint {
        let x = CGFloat.random(in: boxSize...(size.width - boxSize))
        return CGPoint(x: x, y: -boxSize)
    }
    
    private func updateGame(in size: CGSize, dt: TimeInterval) {
        guard dt > 0 else { return }
        var pos = boxPosition == .zero ? initialSpawn(in: size) : boxPosition
        pos.y += boxVelocity * CGFloat(dt)
        
        // Collision with hands
        if let pose = poseDetector.currentPose {
            let centers = handCenters(pose: pose, in: size)
            let boxRect = CGRect(x: pos.x - boxSize/2, y: pos.y - boxSize/2, width: boxSize, height: boxSize)
            for center in centers {
                let circleCenter = center.point
                let radius = center.radius
                if intersects(circleCenter: circleCenter, radius: radius, rect: boxRect) {
                    // Caught!
                    score += 1
                    pos = initialSpawn(in: size)
                    // Slightly increase difficulty
                    boxVelocity = min(520, boxVelocity + 10)
                    break
                }
            }
        }
        
        // Out of screen -> respawn
        if pos.y - boxSize/2 > size.height {
            pos = initialSpawn(in: size)
            // Optional: reduce score or keep same
        }
        
        boxPosition = pos
    }
    
    private func handCenters(pose: DetectedPose, in size: CGSize) -> [(point: CGPoint, radius: CGFloat, color: Color)] {
        guard !pose.hands.isEmpty else { return [] }
        var results: [(CGPoint, CGFloat, Color)] = []
        for hand in pose.hands {
            // Center: average wrist + MCP joints
            let importantJoints: [VNHumanHandPoseObservation.JointName] = [
                .wrist, .indexMCP, .middleMCP, .ringMCP, .littleMCP, .thumbCMC
            ]
            let pts = hand.joints.filter { importantJoints.contains($0.name) }.map {
                CGPoint(x: $0.point.x * size.width, y: $0.point.y * size.height)
            }
            guard !pts.isEmpty else { continue }
            let cx = pts.map({ $0.x }).reduce(0, +) / CGFloat(pts.count)
            let cy = pts.map({ $0.y }).reduce(0, +) / CGFloat(pts.count)
            let center = CGPoint(x: cx, y: cy)
            
            // Radius: max distance to fingertip joints (approx palm size)
            let tips: [VNHumanHandPoseObservation.JointName] = [
                .indexTip, .middleTip, .ringTip, .littleTip, .thumbTip
            ]
            let tipPts = hand.joints.filter { tips.contains($0.name) }.map {
                CGPoint(x: $0.point.x * size.width, y: $0.point.y * size.height)
            }
            let maxDist = tipPts.map { hypot($0.x - cx, $0.y - cy) }.max() ?? 30
            let radius = max(28, min(80, maxDist * 0.8))
            let color: Color = (hand.chirality == .left) ? .green : .red
            results.append((center, radius, color))
        }
        return results
    }
    
    private func intersects(circleCenter: CGPoint, radius: CGFloat, rect: CGRect) -> Bool {
        let closestX = max(rect.minX, min(circleCenter.x, rect.maxX))
        let closestY = max(rect.minY, min(circleCenter.y, rect.maxY))
        let dx = circleCenter.x - closestX
        let dy = circleCenter.y - closestY
        return (dx*dx + dy*dy) <= radius * radius
    }
}


