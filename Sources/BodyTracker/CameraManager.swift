import AVFoundation
import CoreVideo
import AppKit

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer)
}

struct CameraDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let device: AVCaptureDevice
    let position: AVCaptureDevice.Position
    
    static func == (lhs: CameraDevice, rhs: CameraDevice) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class CameraManager: NSObject, ObservableObject {
    weak var delegate: CameraManagerDelegate?
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentVideoInput: AVCaptureDeviceInput?
    
    @Published var availableCameras: [CameraDevice] = []
    @Published var selectedCamera: CameraDevice?
    @Published var isSwitchingCamera = false
    
    override init() {
        super.init()
        discoverCameras()
    }
    
    func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func discoverCameras() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        
        let cameras = discoverySession.devices.map { device -> CameraDevice in
            let position = device.position
            let name = device.localizedName
            let uniqueID = device.uniqueID
            
            return CameraDevice(
                id: uniqueID,
                name: name,
                device: device,
                position: position
            )
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.availableCameras = cameras
            // Select first camera by default, or front-facing if available
            if let frontCamera = cameras.first(where: { $0.position == .front }) {
                self?.selectedCamera = frontCamera
            } else if let firstCamera = cameras.first {
                self?.selectedCamera = firstCamera
            }
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        // Use high quality preset for better Vision tracking accuracy
        // According to Apple Vision best practices, .high provides good balance
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        } else {
            captureSession.sessionPreset = .medium
        }
        
        // Remove existing input if any
        if let existingInput = currentVideoInput {
            captureSession.removeInput(existingInput)
            currentVideoInput = nil
        }
        
        guard let selectedCamera = selectedCamera else {
            print("No camera selected")
            captureSession.commitConfiguration()
            return
        }
        
        let videoDevice = selectedCamera.device
        
        do {
            // Configure device for optimal Vision tracking
            try videoDevice.lockForConfiguration()
            
            // Enable auto-focus for better tracking
            if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoDevice.focusMode = .continuousAutoFocus
            }
            
            // Enable auto-exposure for consistent lighting
            if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                videoDevice.exposureMode = .continuousAutoExposure
            }
            
            // Enable auto white balance
            if videoDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            videoDevice.unlockForConfiguration()
            
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                currentVideoInput = videoInput
            }
            
            // Setup output if not already added
            // Vision framework works best with BGRA format (as per Apple docs)
            if !captureSession.outputs.contains(videoOutput) {
                videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                
                // Use BGRA format - optimal for Vision framework
                // Always discard late frames for real-time performance
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                
                if captureSession.canAddOutput(videoOutput) {
                    captureSession.addOutput(videoOutput)
                }
            }
            
            // Configure video connection for optimal performance
            // Per Apple Vision documentation, ensure proper orientation
            if let connection = videoOutput.connection(with: .video) {
                // Mirror front-facing cameras for natural user experience
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (videoDevice.position == .front)
                }
                
                // Set orientation - Vision expects .up orientation
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                
                if #available(macOS 14.0, *) {
                    if connection.isVideoRotationAngleSupported(0) {
                        connection.videoRotationAngle = 0
                    }
                }
            }
            
        } catch {
            print("Error setting up camera input: \(error)")
        }
        
        captureSession.commitConfiguration()
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func switchCamera(to camera: CameraDevice) {
        guard camera != selectedCamera else { return }
        
        isSwitchingCamera = true
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Remove current input
            if let existingInput = self.currentVideoInput {
                self.captureSession.removeInput(existingInput)
                self.currentVideoInput = nil
            }
            
            // Update selected camera
            DispatchQueue.main.async {
                self.selectedCamera = camera
            }
            
            // Add new input
            do {
                let videoInput = try AVCaptureDeviceInput(device: camera.device)
                
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                    self.currentVideoInput = videoInput
                    
                    // Update video connection settings
                    if let connection = self.videoOutput.connection(with: .video) {
                        if connection.isVideoMirroringSupported {
                            connection.isVideoMirrored = (camera.position == .front)
                        }
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                    }
                    
                    // Configure device settings for optimal tracking
                    do {
                        try camera.device.lockForConfiguration()
                        if camera.device.isFocusModeSupported(.continuousAutoFocus) {
                            camera.device.focusMode = .continuousAutoFocus
                        }
                        if camera.device.isExposureModeSupported(.continuousAutoExposure) {
                            camera.device.exposureMode = .continuousAutoExposure
                        }
                        camera.device.unlockForConfiguration()
                    } catch {
                        print("Error configuring camera device: \(error)")
                    }
                }
            } catch {
                print("Error switching camera: \(error)")
            }
            
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.isSwitchingCamera = false
            }
        }
    }
    
    func setupPreviewLayer(in view: NSView) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            
            view.layer = previewLayer
            view.wantsLayer = true
            
            self.previewLayer = previewLayer
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraManager(self, didOutput: sampleBuffer)
    }
}

