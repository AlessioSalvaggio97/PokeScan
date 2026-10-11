import SwiftUI

public struct ScannedCardBannerView: View {
    public let card: PokemonCard
    public let countdown: Double
    public let onSelectVariant: (CardVariant) -> Void
    public let onCommit: () -> Void
    public let onDiscard: () -> Void
    
    public var body: some View {
        VStack(spacing: 10) {
            // Barra di progressione auto-save (3 secondi)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(countdown / 3.0)), height: 4)
                        .animation(.linear(duration: 0.1), value: countdown)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 4)
            
            HStack(alignment: .top, spacing: 14) {
                // Miniatura Carta
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 58, height: 80)
                    
                    if let thumbData = card.thumbnailData, let uiImage = UIImage(data: thumbData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 58, height: 80)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else if let imgUrl = card.imageURL, let url = URL(string: "\(imgUrl)/low.webp") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 58, height: 80)
                                    .cornerRadius(8)
                            default:
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    } else {
                        VStack(spacing: 2) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                            Text("TCG")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                // Dettagli Carta
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(card.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Pulsante Scarta (X)
                        Button(action: onDiscard) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
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
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    
                    // Badges: Numero, Rarità, Lingua
                    HStack(spacing: 6) {
                        Text(card.formattedNumber)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.18))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                        
                        Text(card.rarity)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.35))
                            .cornerRadius(5)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(card.language)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.35))
                            .cornerRadius(5)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 2)
            
            // Selettore Rapido Variante (Regular / Reverse / Foil)
            HStack(spacing: 8) {
                ForEach(CardVariant.allCases) { variant in
                    Button(action: {
                        onSelectVariant(variant)
                    }) {
                        HStack(spacing: 4) {
                            if card.variant == variant {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                            }
                            Text(variant.rawValue)
                                .font(.system(size: 13, weight: card.variant == variant ? .bold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            card.variant == variant
                                ? variant.badgeColor
                                : Color.white.opacity(0.12)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                // Pulsante Conferma / Salva Subito
                Button(action: onCommit) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.11, green: 0.13, blue: 0.18).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
        )
    }
}
