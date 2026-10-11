import SwiftUI

public struct CardRowView: View {
    public let card: PokemonCard
    public let onSelectVariant: (CardVariant) -> Void
    public let onDelete: () -> Void
    
    public var body: some View {
        HStack(spacing: 12) {
            // Miniatura
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray6))
                    .frame(width: 44, height: 60)
                
                if let thumbData = card.thumbnailData, let uiImage = UIImage(data: thumbData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 60)
                        .cornerRadius(6)
                } else if let imgUrl = card.imageURL, let url = URL(string: "\(imgUrl)/low.webp") {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 60)
                                .cornerRadius(6)
                        default:
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }
            }
            
            // Informazioni carta
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let sym = SetCatalog.shared.getSymbolImage(for: card.setId) {
                        Image(uiImage: sym)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    }
                    
                    Text(card.setName)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    Text(card.formattedNumber)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Text(card.rarity)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Badge Variante
            Menu {
                ForEach(CardVariant.allCases) { variant in
                    Button(action: {
                        onSelectVariant(variant)
                    }) {
                        HStack {
                            Text(variant.rawValue)
                            if card.variant == variant {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Elimina carta", systemImage: "trash")
                }
            } label: {
                Text(card.variant.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(card.variant.badgeColor.opacity(0.2))
                    .foregroundColor(card.variant.badgeColor)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}
