import SwiftUI

public struct ScannedCardBannerView: View {
    public let card: PokemonCard
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
            // Intestazione stato carta rilevata (In attesa di conferma)
            HStack(spacing: 6) {
                Circle()
                    .fill(PokeTheme.neonGreen)
                    .frame(width: 7, height: 7)
                    .neonGlow(color: PokeTheme.neonGreen, radius: 4)
                
                Text("CARTA RILEVATA")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(PokeTheme.neonGreen)
                    .tracking(1.0)
                
                Spacer()
                
                Text("SCEGLI VARIANTE & CONFERMA")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.65))
                    .tracking(0.6)
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)
            
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
                
                // Pulsante Conferma Carta
                Button(action: onCommit) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Conferma")
                            .font(.system(size: 12, weight: .black))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [PokeTheme.neonGreen, Color(red: 0.05, green: 0.8, blue: 0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .neonGlow(color: PokeTheme.neonGreen, radius: 6)
                }
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: 20, borderColor: glowColor)
    }
}
