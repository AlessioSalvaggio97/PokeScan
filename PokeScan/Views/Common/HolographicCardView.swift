import SwiftUI

public struct HolographicCardView: View {
    public let card: PokemonCard
    public var onVariantChanged: ((CardVariant) -> Void)?
    public var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    // Gestione Inclinazione 3D (Parallasse)
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    private var rotateX: Double {
        Double(-dragOffset.height / 10).clamped(to: -25...25)
    }
    
    private var rotateY: Double {
        Double(dragOffset.width / 10).clamped(to: -25...25)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                PokeTheme.bgDark.ignoresSafeArea()
                
                // Luce radiale d'atmosfera dietro la carta
                RadialGradient(
                    colors: [
                        glowColor.opacity(0.35),
                        PokeTheme.bgDark
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 350
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Carta 3D Interattiva
                    card3DView
                        .padding(.top, 20)
                    
                    // Scheda Dettagli Carta
                    detailsCard
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
        }
    }
    
    // MARK: - Carta 3D con Effetto Foil Arcobaleno
    
    private var card3DView: some View {
        ZStack {
            // Immagine Carta
            Group {
                if let thumbData = card.thumbnailData, let uiImage = UIImage(data: thumbData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let imgUrl = card.imageURL, let url = URL(string: "\(imgUrl)/high.webp") {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                        default:
                            cardPlaceholder
                        }
                    }
                } else {
                    cardPlaceholder
                }
            }
            .frame(width: 240, height: 335)
            .cornerRadius(14)
            .shadow(color: glowColor.opacity(0.5), radius: isDragging ? 28 : 16, x: 0, y: isDragging ? 18 : 8)
            
            // Overlay Olografico per Reverse e Foil
            if card.variant != .regular {
                holographicFoilOverlay
                    .frame(width: 240, height: 335)
                    .cornerRadius(14)
                    .blendMode(.colorDodge)
                    .opacity(card.variant == .foil ? 0.75 : 0.45)
            }
            
            // Riflesso Speculare Lucido (Shine)
            specularShineOverlay
                .frame(width: 240, height: 335)
                .cornerRadius(14)
                .blendMode(.screen)
                .opacity(0.4)
            
            // Bordo Olografico Esterno
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: card.variant == .regular
                            ? [Color.white.opacity(0.4), Color.clear]
                            : [Color.yellow, Color.pink, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 240, height: 335)
        }
        // Applicazione Rotazione 3D dinamica
        .rotation3DEffect(
            .degrees(rotateX),
            axis: (x: 1.0, y: 0.0, z: 0.0),
            perspective: 0.8
        )
        .rotation3DEffect(
            .degrees(rotateY),
            axis: (x: 0.0, y: 1.0, z: 0.0),
            perspective: 0.8
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                        dragOffset = .zero
                        isDragging = false
                    }
                }
        )
    }
    
    private var holographicFoilOverlay: some View {
        LinearGradient(
            colors: [
                Color.red.opacity(0.7),
                Color.yellow.opacity(0.7),
                Color.green.opacity(0.7),
                Color.cyan.opacity(0.7),
                Color.purple.opacity(0.7),
                Color.red.opacity(0.7)
            ],
            startPoint: UnitPoint(x: 0.5 + Double(dragOffset.width / 400), y: 0.0),
            endPoint: UnitPoint(x: 0.5 - Double(dragOffset.width / 400), y: 1.0)
        )
    }
    
    private var specularShineOverlay: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.8),
                Color.white.opacity(0.0)
            ],
            startPoint: UnitPoint(x: 0.0, y: 0.5 + Double(dragOffset.height / 300)),
            endPoint: UnitPoint(x: 1.0, y: 0.5 - Double(dragOffset.height / 300))
        )
    }
    
    private var cardPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(PokeTheme.bgCard)
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(glowColor)
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
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
    
    // MARK: - Scheda Dettagli
    
    private var detailsCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                if let sym = SetCatalog.shared.getSymbolImage(for: card.setId) {
                    Image(uiImage: sym)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                }
                
                Text(card.setName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(card.formattedNumber)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(PokeTheme.neonCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PokeTheme.neonCyan.opacity(0.15))
                    .cornerRadius(6)
            }
            
            HStack(spacing: 8) {
                Text(card.rarity)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
                
                Text("Lingua: \(card.language)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
                
                Spacer()
            }
            
            Divider().background(Color.white.opacity(0.15))
            
            // Selettore Rapido Variante
            VStack(alignment: .leading, spacing: 6) {
                Text("Cambia Finitura:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 8) {
                    ForEach(CardVariant.allCases) { variant in
                        Button {
                            onVariantChanged?(variant)
                            let haptic = UISelectionFeedbackGenerator()
                            haptic.selectionChanged()
                        } label: {
                            HStack(spacing: 4) {
                                if card.variant == variant {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                }
                                Text(variant.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                card.variant == variant
                                    ? variant.badgeColor
                                    : Color.white.opacity(0.1)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.15))
            
            // Pulsante Elimina Carta
            if let deleteAction = onDelete {
                Button(role: .destructive) {
                    deleteAction()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text("Elimina Carta dalla Collezione")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.25))
                    .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 18, borderColor: glowColor)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
