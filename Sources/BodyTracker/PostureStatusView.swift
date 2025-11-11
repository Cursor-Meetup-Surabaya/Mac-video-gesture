import SwiftUI

struct PostureStatusView: View {
    let posture: PostureAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Posture icon
                Image(systemName: postureIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(postureColor)
                
                // Posture label
                Text(posture.posture.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Confidence indicator
                Text("\(Int(posture.confidence * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(postureColor.opacity(0.5), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            
            // Reasoning (optional, can be hidden if too verbose)
            if posture.confidence < 0.7 {
                Text(posture.reasoning)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.3))
                    )
            }
        }
    }
    
    private var postureIcon: String {
        switch posture.posture {
        case .standing:
            return "figure.stand"
        case .sitting:
            return "figure.seated.side"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var postureColor: Color {
        switch posture.posture {
        case .standing:
            return .green
        case .sitting:
            return .orange
        case .unknown:
            return .gray
        }
    }
}

