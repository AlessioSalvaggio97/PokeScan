import SwiftUI

// MARK: - Angolari Decorativi per Mirino Laser (Definiti in cima al file per visibilità immediata nello scope)
public struct CornerBrackets: Shape {
    public let width: CGFloat
    public let height: CGFloat
    public let length: CGFloat
    
    public init(width: CGFloat, height: CGFloat, length: CGFloat = 26) {
        self.width = width
        self.height = height
        self.length = length
    }
    
    public func path(in rect: CGRect) -> Path {
        var p = Path()
        // Alto Sinistra
        p.move(to: CGPoint(x: 0, y: length))
        p.addLine(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: length, y: 0))
        
        // Alto Destra
        p.move(to: CGPoint(x: width - length, y: 0))
        p.addLine(to: CGPoint(x: width, y: 0))
        p.addLine(to: CGPoint(x: width, y: length))
        
        // Basso Sinistra
        p.move(to: CGPoint(x: 0, y: height - length))
        p.addLine(to: CGPoint(x: 0, y: height))
        p.addLine(to: CGPoint(x: length, y: height))
        
        // Basso Destra
        p.move(to: CGPoint(x: width - length, y: height))
        p.addLine(to: CGPoint(x: width, y: height))
        p.addLine(to: CGPoint(x: width, y: height - length))
        
        return p
    }
}

public struct ScannerHUDView: View {
    public let isTargetLocked: Bool
    public var isWaitingForNewCard: Bool = false
    
    @State private var laserOffset: CGFloat = -160
    @State private var pulseScale: CGFloat = 1.0
    
    let reticleWidth: CGFloat = 260
    let reticleHeight: CGFloat = 360
    
    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Riquadro guida trasparente con bordo neon
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isWaitingForNewCard ? PokeTheme.neonGreen.opacity(0.8) : (isTargetLocked ? PokeTheme.neonGreen.opacity(0.8) : Color.white.opacity(0.25)),
                        style: StrokeStyle(lineWidth: (isTargetLocked || isWaitingForNewCard) ? 2.5 : 1.5, dash: [10, 6])
                    )
                    .frame(width: reticleWidth, height: reticleHeight)
                    .neonGlow(color: (isTargetLocked || isWaitingForNewCard) ? PokeTheme.neonGreen : PokeTheme.neonCyan, radius: (isTargetLocked || isWaitingForNewCard) ? 12 : 4)
                
                // Angolari Hi-Tech con Glow
                CornerBrackets(width: reticleWidth, height: reticleHeight)
                    .stroke((isTargetLocked || isWaitingForNewCard) ? PokeTheme.neonGreen : PokeTheme.neonYellow, lineWidth: 3.5)
                    .frame(width: reticleWidth, height: reticleHeight)
                    .neonGlow(color: (isTargetLocked || isWaitingForNewCard) ? PokeTheme.neonGreen : PokeTheme.neonYellow, radius: 8)
                
                // Linea Laser Animata (in pausa quando la carta è agganciata)
                if !isTargetLocked {
                    laserBeamView
                        .transition(.opacity)
                }
                
                // Mirino centrale di puntamento
                centerCrosshair
                
                // Indicatore di puntamento per striscia inferiore
                bottomTargetZone
            }
            
            // Badge di Stato Hi-Tech
            HStack(spacing: 8) {
                let badgeColor = isWaitingForNewCard ? PokeTheme.neonGreen : (isTargetLocked ? PokeTheme.neonGreen : PokeTheme.neonCyan)
                Circle()
                    .fill(badgeColor)
                    .frame(width: 8, height: 8)
                    .neonGlow(color: badgeColor, radius: 6)
                
                Text(isWaitingForNewCard ? "IN ATTESA PROSSIMA CARTA" : (isTargetLocked ? "PREMI CONFERMA" : "ALLINEA LA CARTA"))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1.2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassPanel(cornerRadius: 12, borderColor: (isTargetLocked || isWaitingForNewCard) ? PokeTheme.neonGreen : PokeTheme.neonCyan)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                laserOffset = 160
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }
    
    private var laserBeamView: some View {
        VStack(spacing: 0) {
            // Coda della luce laser
            LinearGradient(
                colors: [
                    PokeTheme.neonCyan.opacity(0.0),
                    PokeTheme.neonCyan.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: reticleWidth - 10, height: 26)
            
            // Raggio laser orizzontale brillante
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            PokeTheme.neonCyan.opacity(0.0),
                            Color.white,
                            PokeTheme.neonCyan,
                            Color.white,
                            PokeTheme.neonCyan.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: reticleWidth - 10, height: 2.5)
                .neonGlow(color: PokeTheme.neonCyan, radius: 6)
        }
        .offset(y: laserOffset)
        .clipped()
    }
    
    private var centerCrosshair: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: 44, height: 44)
                .scaleEffect(pulseScale)
            
            Path { p in
                // Crocetta centrale
                p.move(to: CGPoint(x: -8, y: 0))
                p.addLine(to: CGPoint(x: 8, y: 0))
                p.move(to: CGPoint(x: 0, y: -8))
                p.addLine(to: CGPoint(x: 0, y: 8))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
        }
    }
    
    private var bottomTargetZone: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 11, weight: .bold))
                Text("STRISCIA CODICE & NUMERO")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.0)
            }
            .foregroundColor(PokeTheme.neonYellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.65))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(PokeTheme.neonYellow.opacity(0.5), lineWidth: 1)
            )
            .padding(.bottom, 14)
        }
        .frame(width: reticleWidth, height: reticleHeight)
    }
}
