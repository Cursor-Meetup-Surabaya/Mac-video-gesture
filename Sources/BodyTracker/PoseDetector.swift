import Vision
import CoreVideo
import CoreImage

struct PoseJoint {
    let name: VNHumanBodyPoseObservation.JointName
    var point: CGPoint
    var confidence: Float
    
    init(name: VNHumanBodyPoseObservation.JointName, point: CGPoint, confidence: Float) {
        self.name = name
        self.point = point
        self.confidence = confidence
    }
}

struct DetectedPose {
    let joints: [PoseJoint]
    let timestamp: Date
    let segmentationMask: CIImage?
    let posture: PostureAnalysis?
    let face: DetectedFace?
    let hands: [DetectedHand]
    let detectionMode: DetectionMode
}

protocol PoseDetectorDelegate: AnyObject {
    func poseDetector(_ detector: PoseDetector, didDetectPose pose: DetectedPose?)
}

class PoseDetector: NSObject, ObservableObject, CameraManagerDelegate {
    weak var delegate: PoseDetectorDelegate?
    
    private let visionQueue = DispatchQueue(label: "pose.detection.queue", qos: .userInteractive)
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    private var segmentationRequest: VNGeneratePersonSegmentationRequest?
    private var faceRequest: VNDetectFaceLandmarksRequest?
    private var handRequest: VNDetectHumanHandPoseRequest?
    
    @Published private(set) var currentPose: DetectedPose?
    @Published private(set) var isProcessing = false
    
    // Face and hand smoothing
    private var faceHistory: [DetectedFace?] = []
    private var handsHistory: [[DetectedHand]] = []
    private let maxFaceHandHistorySize = 3
    
    // Throttling for performance
    private var lastProcessTime: Date = Date()
    private let minProcessingInterval: TimeInterval = 1.0 / 30.0 // ~30 FPS max
    
    // Pose smoothing
    private var poseHistory: [DetectedPose] = []
    private let maxHistorySize = 5
    private let smoothingAlpha: Float = 0.7 // Exponential moving average factor
    
    // Enhanced thresholds for critical body parts
    private let criticalPartThreshold: Float = 0.3 // Lower threshold for head, eyes, hands
    private let standardThreshold: Float = 0.1
    
    // Posture classification smoothing
    private var postureHistory: [PostureAnalysis] = []
    private let maxPostureHistorySize = 3
    
    override init() {
        super.init()
        setupVisionRequests()
    }
    
    private func setupVisionRequests() {
        // Setup pose detection request
        poseRequest = VNDetectHumanBodyPoseRequest()
        
        // Setup person segmentation request
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest?.qualityLevel = .balanced
        segmentationRequest?.outputPixelFormat = kCVPixelFormatType_OneComponent8
        
        // Setup face landmarks request
        faceRequest = VNDetectFaceLandmarksRequest()
        
        // Setup hand pose request (max 2 hands for performance)
        handRequest = VNDetectHumanHandPoseRequest()
        handRequest?.maximumHandCount = 2
    }
    
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer) {
        // Throttle processing for performance
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= minProcessingInterval else {
            return
        }
        lastProcessTime = now
        
        guard !isProcessing,
              let poseRequest = poseRequest,
              let segmentationRequest = segmentationRequest,
              let faceRequest = faceRequest,
              let handRequest = handRequest else { return }
        
        isProcessing = true
        
        visionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
            
            var detectedPose: VNHumanBodyPoseObservation?
            var segmentationMask: CIImage?
            var detectedFace: VNFaceObservation?
            var detectedHands: [VNHumanHandPoseObservation] = []
            
            do {
                // Perform all requests together for efficiency
                try handler.perform([poseRequest, segmentationRequest, faceRequest, handRequest])
                
                // Extract pose observation
                if let observations = poseRequest.results,
                   let observation = observations.first {
                    detectedPose = observation
                }
                
                // Extract segmentation mask
                if let segmentationResults = segmentationRequest.results,
                   let firstResult = segmentationResults.first {
                    let pixelBuffer = firstResult.pixelBuffer
                    var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    ciImage = ciImage.oriented(.up)
                    segmentationMask = ciImage
                }
                
                // Extract face observation
                if let faceObservations = faceRequest.results,
                   let faceObservation = faceObservations.first {
                    detectedFace = faceObservation
                }
                
                // Extract hand observations
                if let handObservations = handRequest.results {
                    detectedHands = handObservations
                }
                
                // Process and smooth the pose
                let processedPose = self.processPose(
                    observation: detectedPose,
                    segmentationMask: segmentationMask,
                    faceObservation: detectedFace,
                    handObservations: detectedHands
                )
                
                DispatchQueue.main.async {
                    self.currentPose = processedPose
                    self.isProcessing = false
                }
            } catch {
                print("Error performing vision requests: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func processPose(observation: VNHumanBodyPoseObservation?,
                            segmentationMask: CIImage?,
                            faceObservation: VNFaceObservation?,
                            handObservations: [VNHumanHandPoseObservation]) -> DetectedPose? {
        
        // Extract body joints
        let joints = observation != nil ? extractJoints(from: observation!) : []
        
        // Extract face landmarks
        let face = extractFaceLandmarks(from: faceObservation)
        
        // Extract hand joints
        let hands = extractHandJoints(from: handObservations)
        
        // Determine detection mode based on available data
        let detectionMode = determineDetectionMode(bodyJoints: joints, face: face, hands: hands)
        
        // If no body pose but we have face/hands, create a pose anyway
        guard observation != nil || face != nil || !hands.isEmpty else {
            // Use last known pose if available
            if let lastPose = poseHistory.last {
                return DetectedPose(
                    joints: lastPose.joints,
                    timestamp: Date(),
                    segmentationMask: segmentationMask,
                    posture: lastPose.posture,
                    face: lastPose.face,
                    hands: lastPose.hands,
                    detectionMode: lastPose.detectionMode
                )
            }
            return nil
        }
        
        // Classify posture (only if we have enough body joints)
        var postureAnalysis: PostureAnalysis?
        if joints.count >= 5 {
            let tempPose = DetectedPose(
                joints: joints,
                timestamp: Date(),
                segmentationMask: segmentationMask,
                posture: nil,
                face: nil,
                hands: [],
                detectionMode: detectionMode
            )
            postureAnalysis = PostureClassifier.classify(pose: tempPose)
            postureAnalysis = smoothPosture(currentPosture: postureAnalysis!)
        }
        
        // Smooth face and hands
        let smoothedFace = smoothFace(currentFace: face)
        let smoothedHands = smoothHands(currentHands: hands)
        
        // Apply smoothing to joints
        let smoothedJoints = smoothJoints(currentJoints: joints)
        
        let processedPose = DetectedPose(
            joints: smoothedJoints,
            timestamp: Date(),
            segmentationMask: segmentationMask,
            posture: postureAnalysis,
            face: smoothedFace,
            hands: smoothedHands,
            detectionMode: detectionMode
        )
        
        // Add to history
        poseHistory.append(processedPose)
        if poseHistory.count > maxHistorySize {
            poseHistory.removeFirst()
        }
        
        return processedPose
    }
    
    private func determineDetectionMode(bodyJoints: [PoseJoint], face: DetectedFace?, hands: [DetectedHand]) -> DetectionMode {
        // Check if we have sufficient body joints (at least 8 confident joints)
        let confidentBodyJoints = bodyJoints.filter { $0.confidence > 0.3 }
        
        if confidentBodyJoints.count >= 8 {
            // Check if we have lower body (hips/knees)
            let hasLowerBody = bodyJoints.contains { joint in
                [.leftHip, .rightHip, .leftKnee, .rightKnee].contains(joint.name) && joint.confidence > 0.3
            }
            return hasLowerBody ? .fullBody : .upperBody
        }
        
        // If we have face or hands but not enough body joints, use face/hands mode
        if face != nil || !hands.isEmpty {
            return .faceAndHands
        }
        
        // Default to upper body if we have some joints
        return confidentBodyJoints.count > 0 ? .upperBody : .faceAndHands
    }
    
    private func extractFaceLandmarks(from observation: VNFaceObservation?) -> DetectedFace? {
        guard let observation = observation,
              let landmarks = observation.landmarks else { return nil }
        
        var faceLandmarks: [FaceLandmark] = []
        var smileScore: Float = 0.0
        
        // Extract key facial landmarks
        let landmarkRegions: [(VNFaceLandmarkRegion2D?, String)] = [
            (landmarks.leftEye, "leftEye"),
            (landmarks.rightEye, "rightEye"),
            (landmarks.faceContour, "faceContour"),
            (landmarks.nose, "nose"),
            (landmarks.noseCrest, "noseCrest"),
            (landmarks.outerLips, "outerLips"),
            (landmarks.innerLips, "innerLips"),
            (landmarks.leftEyebrow, "leftEyebrow"),
            (landmarks.rightEyebrow, "rightEyebrow")
        ]
        
        for (region, name) in landmarkRegions {
            guard let region = region else { continue }
            
            // Get normalized points from the region
            let points = region.normalizedPoints
            for (index, point) in points.enumerated() {
                let landmark = FaceLandmark(
                    name: "\(name)_\(index)",
                    point: CGPoint(x: point.x, y: 1.0 - point.y), // Flip Y for SwiftUI
                    confidence: observation.confidence
                )
                faceLandmarks.append(landmark)
            }
        }
        
        // Compute a heuristic smile score from lips geometry (0..1)
        if let outer = landmarks.outerLips {
            let pts = outer.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat(1.0 - $0.y)) }
            if !pts.isEmpty {
                // Mouth width (corners)
                if let left = pts.min(by: { $0.x < $1.x }),
                   let right = pts.max(by: { $0.x < $1.x }) {
                    let width = max(0.0, right.x - left.x) // 0..1 within face
                    
                    // Mouth vertical gap (use inner lips if available)
                    var height: CGFloat = 0.0
                    if let inner = landmarks.innerLips {
                        let innerPts = inner.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat(1.0 - $0.y)) }
                        if let top = innerPts.min(by: { $0.y < $1.y }),
                           let bottom = innerPts.max(by: { $0.y < $1.y }) {
                            height = max(0.0, bottom.y - top.y)
                        }
                    } else {
                        if let top = pts.min(by: { $0.y < $1.y }),
                           let bottom = pts.max(by: { $0.y < $1.y }) {
                            height = max(0.0, bottom.y - top.y)
                        }
                    }
                    
                    // Mouth center vs corners (corner lift)
                    let centerY = pts.map({ $0.y }).reduce(0, +) / CGFloat(pts.count)
                    let avgCornerY = (left.y + right.y) / 2.0
                    let cornerLift = max(0.0, centerY - avgCornerY) // corners above center => positive
                    
                    // Normalize scores with empirically chosen baselines
                    // Width baseline ~0.40 neutral, 0.65 big smile
                    let widthScore = min(1.0, max(0.0, (width - 0.40) / 0.25))
                    // Corner lift baseline ~0.00 neutral, 0.12 strong smile
                    let cornerScore = min(1.0, max(0.0, Double(cornerLift / 0.12)))
                    // Penalize very large vertical mouth opening (talking vs smiling)
                    // Height baseline ~0.08 neutral closed, >0.22 likely open mouth
                    let openPenalty = min(1.0, max(0.0, (Double(height) - 0.22) / 0.10))
                    
                    // Final smile score: weighted combination minus penalty
                    let raw = 0.6 * Double(widthScore) + 0.5 * cornerScore - 0.3 * openPenalty
                    smileScore = Float(min(1.0, max(0.0, raw)))
                }
            }
        }
        
        guard !faceLandmarks.isEmpty else { return nil }
        
        return DetectedFace(
            landmarks: faceLandmarks,
            boundingBox: observation.boundingBox,
            confidence: observation.confidence,
            smileScore: smileScore
        )
    }
    
    private func extractHandJoints(from observations: [VNHumanHandPoseObservation]) -> [DetectedHand] {
        var detectedHands: [DetectedHand] = []
        
        for observation in observations {
            var handJoints: [HandJoint] = []
            
            // Extract all hand joints
            let jointNames: [VNHumanHandPoseObservation.JointName] = [
                .wrist,
                .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                .indexMCP, .indexPIP, .indexDIP, .indexTip,
                .middleMCP, .middlePIP, .middleDIP, .middleTip,
                .ringMCP, .ringPIP, .ringDIP, .ringTip,
                .littleMCP, .littlePIP, .littleDIP, .littleTip
            ]
            
            for jointName in jointNames {
                do {
                    let point = try observation.recognizedPoint(jointName)
                    if point.confidence > 0.2 { // Lower threshold for hands
                        handJoints.append(HandJoint(
                            name: jointName,
                            point: CGPoint(x: point.location.x, y: 1.0 - point.location.y), // Flip Y
                            confidence: point.confidence
                        ))
                    }
                } catch {
                    continue
                }
            }
            
            if !handJoints.isEmpty {
                // Determine chirality from observation
                let chirality: HandChirality = observation.chirality == .left ? .left : .right
                detectedHands.append(DetectedHand(
                    joints: handJoints,
                    chirality: chirality,
                    confidence: observation.confidence
                ))
            }
        }
        
        return detectedHands
    }
    
    private func smoothFace(currentFace: DetectedFace?) -> DetectedFace? {
        faceHistory.append(currentFace)
        if faceHistory.count > maxFaceHandHistorySize {
            faceHistory.removeFirst()
        }
        
        guard let currentFace = currentFace else {
            // Return last known face if available
            return faceHistory.last ?? nil
        }
        
        // Simple smoothing - return current if confident, otherwise blend with history
        if currentFace.confidence > 0.7 {
            return currentFace
        }
        
        // If low confidence, try to use last known
        if let lastFace = faceHistory.dropLast().last ?? nil,
           lastFace.confidence > currentFace.confidence {
            return lastFace
        }
        
        return currentFace
    }
    
    private func smoothHands(currentHands: [DetectedHand]) -> [DetectedHand] {
        handsHistory.append(currentHands)
        if handsHistory.count > maxFaceHandHistorySize {
            handsHistory.removeFirst()
        }
        
        // If current hands are confident, use them
        if currentHands.allSatisfy({ $0.confidence > 0.6 }) {
            return currentHands
        }
        
        // Otherwise, try to blend with history
        if let lastHands = handsHistory.dropLast().last,
           !lastHands.isEmpty {
            // Match hands by chirality and blend
            var blendedHands: [DetectedHand] = []
            
            for currentHand in currentHands {
                if let matchingHand = lastHands.first(where: { $0.chirality == currentHand.chirality }) {
                    // Blend joints
                    var blendedJoints: [HandJoint] = []
                    for currentJoint in currentHand.joints {
                        if let matchingJoint = matchingHand.joints.first(where: { $0.name == currentJoint.name }) {
                            let blendFactor: CGFloat = CGFloat(currentJoint.confidence)
                            let blendedPoint = CGPoint(
                                x: blendFactor * currentJoint.point.x + (1.0 - blendFactor) * matchingJoint.point.x,
                                y: blendFactor * currentJoint.point.y + (1.0 - blendFactor) * matchingJoint.point.y
                            )
                            blendedJoints.append(HandJoint(
                                name: currentJoint.name,
                                point: blendedPoint,
                                confidence: max(currentJoint.confidence, matchingJoint.confidence * 0.8)
                            ))
                        } else {
                            blendedJoints.append(currentJoint)
                        }
                    }
                    blendedHands.append(DetectedHand(
                        joints: blendedJoints,
                        chirality: currentHand.chirality,
                        confidence: max(currentHand.confidence, matchingHand.confidence * 0.8)
                    ))
                } else {
                    blendedHands.append(currentHand)
                }
            }
            
            return blendedHands.isEmpty ? currentHands : blendedHands
        }
        
        return currentHands
    }
    
    private func smoothPosture(currentPosture: PostureAnalysis) -> PostureAnalysis {
        postureHistory.append(currentPosture)
        if postureHistory.count > maxPostureHistorySize {
            postureHistory.removeFirst()
        }
        
        // If we have history, use majority voting
        if postureHistory.count >= 2 {
            let standingCount = postureHistory.filter { $0.posture == .standing }.count
            let sittingCount = postureHistory.filter { $0.posture == .sitting }.count
            
            if standingCount > sittingCount && standingCount > 0 {
                let avgConfidence = postureHistory.filter { $0.posture == .standing }.map { $0.confidence }.reduce(0, +) / Float(standingCount)
                return PostureAnalysis(posture: .standing, confidence: avgConfidence, reasoning: currentPosture.reasoning)
            } else if sittingCount > standingCount && sittingCount > 0 {
                let avgConfidence = postureHistory.filter { $0.posture == .sitting }.map { $0.confidence }.reduce(0, +) / Float(sittingCount)
                return PostureAnalysis(posture: .sitting, confidence: avgConfidence, reasoning: currentPosture.reasoning)
            }
        }
        
        return currentPosture
    }
    
    private func smoothJoints(currentJoints: [PoseJoint]) -> [PoseJoint] {
        guard !poseHistory.isEmpty, poseHistory.count > 1 else {
            return currentJoints
        }
        
        var smoothedJoints: [PoseJoint] = []
        
        for currentJoint in currentJoints {
            // Find corresponding joint in history
            var smoothedPoint = currentJoint.point
            var smoothedConfidence = currentJoint.confidence
            
            // Apply exponential moving average
            if let previousPose = poseHistory.last(where: { pose in
                pose.joints.contains(where: { $0.name == currentJoint.name })
            }),
               let previousJoint = previousPose.joints.first(where: { $0.name == currentJoint.name }) {
                // Smooth position
                smoothedPoint = CGPoint(
                    x: CGFloat(smoothingAlpha) * currentJoint.point.x + CGFloat(1.0 - smoothingAlpha) * previousJoint.point.x,
                    y: CGFloat(smoothingAlpha) * currentJoint.point.y + CGFloat(1.0 - smoothingAlpha) * previousJoint.point.y
                )
                
                // Smooth confidence
                smoothedConfidence = smoothingAlpha * currentJoint.confidence + (1.0 - smoothingAlpha) * previousJoint.confidence
            }
            
            smoothedJoints.append(PoseJoint(
                name: currentJoint.name,
                point: smoothedPoint,
                confidence: smoothedConfidence
            ))
        }
        
        return smoothedJoints
    }
    
    private func extractJoints(from observation: VNHumanBodyPoseObservation) -> [PoseJoint] {
        var joints: [PoseJoint] = []
        
        // Extract all available joints
        // Lower thresholds to capture more joints when sitting (legs may be partially occluded)
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .leftEye, .rightEye,
            .leftEar, .rightEar,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .neck,
            .root
        ]
        
        for jointName in jointNames {
            do {
                let point = try observation.recognizedPoint(jointName)
                
                // Use enhanced thresholds for critical body parts
                // Lower threshold for lower body when sitting (may be partially visible)
                var threshold = isCriticalBodyPart(jointName) ? criticalPartThreshold : standardThreshold
                
                // Lower threshold for legs/feet when they might be occluded
                if isLowerBodyPart(jointName) {
                    threshold = max(threshold - 0.05, 0.05) // Lower but not too low
                }
                
                if point.confidence > threshold {
                    // Try to use last known position if confidence is low but above threshold
                    var finalPoint = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
                    
                    if point.confidence < 0.5, let lastPose = poseHistory.last,
                       let lastJoint = lastPose.joints.first(where: { $0.name == jointName }) {
                        // Blend with last known position for stability
                        let blendFactor: CGFloat = CGFloat(point.confidence)
                        finalPoint = CGPoint(
                            x: blendFactor * finalPoint.x + (1.0 - blendFactor) * lastJoint.point.x,
                            y: blendFactor * finalPoint.y + (1.0 - blendFactor) * lastJoint.point.y
                        )
                    }
                    
                    joints.append(PoseJoint(
                        name: jointName,
                        point: finalPoint,
                        confidence: point.confidence
                    ))
                }
            } catch {
                // Joint not available - try to use last known position
                if let lastPose = poseHistory.last,
                   let lastJoint = lastPose.joints.first(where: { $0.name == jointName }),
                   lastJoint.confidence > 0.3 {
                    // Keep last known joint briefly (fade out)
                    joints.append(PoseJoint(
                        name: jointName,
                        point: lastJoint.point,
                        confidence: lastJoint.confidence * 0.7 // Reduce confidence
                    ))
                }
                continue
            }
        }
        
        return joints
    }
    
    private func isLowerBodyPart(_ jointName: VNHumanBodyPoseObservation.JointName) -> Bool {
        switch jointName {
        case .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .root:
            return true
        default:
            return false
        }
    }
    
    private func isCriticalBodyPart(_ jointName: VNHumanBodyPoseObservation.JointName) -> Bool {
        switch jointName {
        case .nose, .leftEye, .rightEye, .leftEar, .rightEar, .leftWrist, .rightWrist, .neck:
            return true
        default:
            return false
        }
    }
    
    // Public method for manipulation hooks
    func getCurrentPose() -> DetectedPose? {
        return currentPose
    }
}

