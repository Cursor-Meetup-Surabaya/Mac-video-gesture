import SwiftUI

struct DetectionModeBadge: View {
    let mode: DetectionMode
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: modeIcon)
                .font(.system(size: 12))
                .foregroundColor(modeColor)
            
            Text(modeText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(modeColor.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var modeIcon: String {
        switch mode {
        case .fullBody:
            return "figure.stand"
        case .upperBody:
            return "figure.arms.open"
        case .faceAndHands:
            return "face.smiling"
        }
    }
    
    private var modeText: String {
        switch mode {
        case .fullBody:
            return "Full Body"
        case .upperBody:
            return "Upper Body"
        case .faceAndHands:
            return "Face & Hands"
        }
    }
    
    private var modeColor: Color {
        switch mode {
        case .fullBody:
            return .green
        case .upperBody:
            return .yellow
        case .faceAndHands:
            return .cyan
        }
    }
}

