import SwiftUI

public struct CardGridItemView: View {
    public let card: PokemonCard
    public let onTap: () -> Void
    public var onDelete: (() -> Void)? = nil
    
    public init(card: PokemonCard, onTap: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.card = card
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Riquadro Immagine Carta
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let thumbData = card.thumbnailData, let uiImage = UIImage(data: thumbData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else if let imgUrl = card.imageURL, let url = URL(string: "\(imgUrl)/low.webp") {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fit)
                                default:
                                    ZStack {
                                        PokeTheme.bgCard
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                            }
                        } else {
                            ZStack {
                                PokeTheme.bgCard
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 190)
                    .cornerRadius(12)
                    
                    // Riflesso Foil sottile se Reverse o Foil
                    if card.variant != .regular {
                        PokeTheme.rainbowFoil
                            .frame(height: 190)
                            .cornerRadius(12)
                            .blendMode(.colorDodge)
                            .opacity(card.variant == .foil ? 0.45 : 0.25)
                    }
                    
                    // Badge Variante in alto a destra
                    Text(card.variant.rawValue)
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(card.variant.badgeColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .padding(6)
                        .neonGlow(color: card.variant.badgeColor, radius: 4)
                }
                .overlay(alignment: .topLeading) {
                    if let deleteAction = onDelete {
                        Button(action: deleteAction) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(6)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.red.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            card.variant == .foil
                                ? PokeTheme.rainbowFoil
                                : LinearGradient(colors: [glowColor.opacity(0.8), Color.white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: glowColor.opacity(0.25), radius: 6, x: 0, y: 3)
                
                // Informazioni Testuali
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let sym = SetCatalog.shared.getSymbolImage(for: card.setId) {
                            Image(uiImage: sym)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }
                        
                        Text(card.setName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text(card.formattedNumber)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(PokeTheme.neonCyan)
                        
                        Spacer()
                        
                        Text(card.rarity)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(10)
            .glassPanel(cornerRadius: 16, borderColor: glowColor.opacity(0.4))
        }
        .buttonStyle(.plain)
    }
}
