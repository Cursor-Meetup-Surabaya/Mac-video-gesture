import SwiftUI

struct CameraSelectorView: View {
    @ObservedObject var cameraManager: CameraManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isExpanded {
                cameraList
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            cameraButton
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private var cameraButton: some View {
        Button(action: {
            isExpanded.toggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14))
                
                if let selectedCamera = cameraManager.selectedCamera {
                    Text(selectedCamera.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                } else {
                    Text("No Camera")
                        .font(.system(size: 12))
                }
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(cameraManager.availableCameras.isEmpty || cameraManager.isSwitchingCamera)
    }
    
    private var cameraList: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ForEach(cameraManager.availableCameras) { camera in
                CameraItemView(
                    camera: camera,
                    isSelected: cameraManager.selectedCamera?.id == camera.id,
                    isSwitching: cameraManager.isSwitchingCamera
                ) {
                    cameraManager.switchCamera(to: camera)
                    isExpanded = false
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
}

struct CameraItemView: View {
    let camera: CameraDevice
    let isSelected: Bool
    let isSwitching: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Camera position icon
                Image(systemName: cameraIconName)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(camera.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    Text(cameraPositionText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 200)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSwitching || isSelected)
    }
    
    private var cameraIconName: String {
        switch camera.position {
        case .front:
            return "person.fill.viewfinder"
        case .back:
            return "camera.fill"
        case .unspecified:
            return "video.fill"
        @unknown default:
            return "camera.fill"
        }
    }
    
    private var cameraPositionText: String {
        switch camera.position {
        case .front:
            return "Front Camera"
        case .back:
            return "Back Camera"
        case .unspecified:
            return "External Camera"
        @unknown default:
            return "Camera"
        }
    }
}

