import SwiftUI

struct SmileBadgeView: View {
    let score: Float // 0.0 - 1.0
    
    private var percentageText: String {
        "\(Int(max(0, min(100, score * 100))))%"
    }
    
    private var color: Color {
        switch score {
        case 0.75...:
            return .green
        case 0.45..<0.75:
            return .yellow
        default:
            return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "face.smiling")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text("Smile")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            Text(percentageText)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .circular)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .circular)
                        .stroke(color.opacity(0.6), lineWidth: 1)
                )
        )
    }
}


