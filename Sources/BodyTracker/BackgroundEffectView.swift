import SwiftUI
import CoreImage
import AppKit

struct BackgroundEffectView: View {
    let mask: CIImage
    
    var body: some View {
        GeometryReader { geometry in
            // Blur and darken background to make person stand out
            // Vision segmentation mask: white = person, black = background
            // We want to blur the background (black areas), so we invert the mask
            ZStack {
                // Dark overlay for background
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .blur(radius: 25)
                
                // Additional desaturation layer
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .blur(radius: 30)
            }
            .compositingGroup()
            .mask(
                // Convert CIImage to SwiftUI Image for masking
                // Invert mask: person is white in mask, we want to blur background (black areas)
                MaskImageSwiftUIView(ciImage: mask, size: geometry.size)
                    .colorInvert()
            )
        }
    }
}

struct MaskImageSwiftUIView: View {
    let ciImage: CIImage
    let size: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            if let cgImage = createCGImage(from: ciImage, size: geometry.size) {
                Image(nsImage: NSImage(cgImage: cgImage, size: geometry.size))
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
    
    private func createCGImage(from ciImage: CIImage, size: CGSize) -> CGImage? {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        // Scale mask to match view size
        let scaleTransform = CGAffineTransform(
            scaleX: size.width / ciImage.extent.width,
            y: size.height / ciImage.extent.height
        )
        let scaledImage = ciImage.transformed(by: scaleTransform)
        
        // Crop to exact size
        let croppedRect = CGRect(origin: .zero, size: size)
        let croppedImage = scaledImage.cropped(to: croppedRect)
        
        return context.createCGImage(croppedImage, from: croppedRect)
    }
}

