import SwiftUI
import AVFoundation

struct CameraView: NSViewRepresentable {
    let cameraManager: CameraManager
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        cameraManager.setupPreviewLayer(in: view)
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update if needed
    }
}

