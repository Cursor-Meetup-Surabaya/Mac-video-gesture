import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var poseDetector = PoseDetector()
    
    var body: some View {
        ZStack {
            CameraView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Only draw hands and game overlay
            PoseOverlayView(poseDetector: poseDetector)
                .ignoresSafeArea()
            
            HandCatchGameView(poseDetector: poseDetector)
                .ignoresSafeArea()
            
            // Camera selection UI
            VStack {
                HStack {
                    Spacer()
                    CameraSelectorView(cameraManager: cameraManager)
                        .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            cameraManager.delegate = poseDetector
            // Wait a moment for cameras to be discovered, then setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                cameraManager.setupCamera()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

