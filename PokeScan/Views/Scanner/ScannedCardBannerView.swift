import SwiftUI

public struct ScannedCardBannerView: View {
    public let card: PokemonCard
    public let countdown: Double
    public let onSelectVariant: (CardVariant) -> Void
    public let onCommit: () -> Void
    public let onDiscard: () -> Void
    
    private var glowColor: Color {
        switch card.variant {
        case .regular:
            return PokeTheme.neonCyan
        case .reverse:
            return PokeTheme.neonPurple
        case .foil:
            return PokeTheme.neonYellow
        }
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Barra di progressione auto-save (3 secondi)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 5)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [PokeTheme.neonCyan, PokeTheme.neonGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(countdown / 3.0)), height: 5)
                        .neonGlow(color: PokeTheme.neonGreen, radius: 4)
                        .animation(.linear(duration: 0.1), value: countdown)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 2)
            
            HStack(alignment: .top, spacing: 14) {
                // Miniatura Carta con Bordo e Ombra Olografica
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(PokeTheme.bgCard)
                        .frame(width: 62, height: 86)
                    
                    if let thumbData = card.thumbnailData, let uiImage = UIImage(data: thumbData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 62, height: 86)
                            .cornerRadius(10)
                    } else if let imgUrl = card.imageURL, let url = URL(string: "\(imgUrl)/low.webp") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 62, height: 86)
                                    .cornerRadius(10)
                            default:
                                ProgressView().tint(.white)
                            }
                        }
                    } else {
                        VStack(spacing: 2) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.6))
                            Text("TCG")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    // Bordo illuminato della miniatura
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            card.variant == .foil ? PokeTheme.rainbowFoil : LinearGradient(colors: [glowColor, Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                        .frame(width: 62, height: 86)
                }
                .shadow(color: glowColor.opacity(0.5), radius: 8, x: 0, y: 3)
                
                // Dettagli Carta
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(card.name)
                            .font(.system(size: 19, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Pulsante Scarta (X)
                        Button(action: onDiscard) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    // Set + Simbolo
                    HStack(spacing: 6) {
                        if let symImg = SetCatalog.shared.getSymbolImage(for: card.setId) {
                            Image(uiImage: symImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                        }
                        
                        Text(card.setName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    
                    // Badges: Numero, Rarità, Lingua
                    HStack(spacing: 6) {
                        Text(card.formattedNumber)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                        
                        Text(card.rarity)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(PokeTheme.neonCyan.opacity(0.25))
                            .foregroundColor(PokeTheme.neonCyan)
                            .cornerRadius(6)
                        
                        Text(card.language)
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(PokeTheme.neonPurple.opacity(0.3))
                            .foregroundColor(PokeTheme.neonPurple)
                            .cornerRadius(6)
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Selettore Rapido Variante (Regular / Reverse / Foil)
            HStack(spacing: 8) {
                ForEach(CardVariant.allCases) { variant in
                    Button {
                        onSelectVariant(variant)
                    } label: {
                        HStack(spacing: 5) {
                            if card.variant == variant {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text(variant.rawValue)
                                .font(.system(size: 13, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            card.variant == variant
                                ? variant.badgeColor
                                : Color.white.opacity(0.08)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    card.variant == variant ? Color.white.opacity(0.4) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .neonGlow(color: card.variant == variant ? variant.badgeColor : Color.clear, radius: 4)
                    }
                }
                
                // Pulsante Salva Subito
                Button(action: onCommit) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(PokeTheme.neonGreen)
                        .clipShape(Circle())
                        .neonGlow(color: PokeTheme.neonGreen, radius: 6)
                }
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: 20, borderColor: glowColor)
    }
}
