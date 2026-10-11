import SwiftUI

public enum PokeTheme {
    // Colori Iconici PokéScan
    public static let bgDark = Color(red: 0.06, green: 0.07, blue: 0.10)
    public static let bgCard = Color(red: 0.11, green: 0.13, blue: 0.18)
    
    public static let neonCyan = Color(red: 0.00, green: 0.95, blue: 1.00)
    public static let neonYellow = Color(red: 1.00, green: 0.84, blue: 0.00)
    public static let neonPurple = Color(red: 0.65, green: 0.35, blue: 1.00)
    public static let neonRed = Color(red: 1.00, green: 0.23, blue: 0.28)
    public static let neonGreen = Color(red: 0.18, green: 0.85, blue: 0.45)
    
    // Gradienti
    public static let rainbowFoil = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.2, blue: 0.4),
            Color(red: 1.0, green: 0.6, blue: 0.0),
            Color(red: 1.0, green: 0.9, blue: 0.1),
            Color(red: 0.2, green: 0.9, blue: 0.4),
            Color(red: 0.0, green: 0.8, blue: 1.0),
            Color(red: 0.5, green: 0.3, blue: 1.0),
            Color(red: 1.0, green: 0.2, blue: 0.6)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let laserGradient = LinearGradient(
        colors: [
            neonCyan.opacity(0.0),
            neonCyan.opacity(0.8),
            Color.white,
            neonCyan.opacity(0.8),
            neonCyan.opacity(0.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public static let excelGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.55, blue: 0.30),
            Color(red: 0.13, green: 0.72, blue: 0.38)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - View Modifiers per Effetti Grafici

public struct GlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var borderColor: Color = Color.white.opacity(0.18)
    
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.45))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                borderColor.opacity(0.6),
                                Color.white.opacity(0.1),
                                borderColor.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

public struct NeonGlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 8
    
    public func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius * 1.8, x: 0, y: 0)
    }
}

public extension View {
    func glassPanel(cornerRadius: CGFloat = 16, borderColor: Color = Color.white.opacity(0.18)) -> some View {
        self.modifier(GlassPanelModifier(cornerRadius: cornerRadius, borderColor: borderColor))
    }
    
    func neonGlow(color: Color, radius: CGFloat = 8) -> some View {
        self.modifier(NeonGlowModifier(color: color, radius: radius))
    }
}
