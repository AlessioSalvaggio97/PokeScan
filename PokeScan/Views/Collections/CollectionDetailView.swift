import SwiftUI

public struct CollectionDetailView: View {
    public let collectionId: UUID
    @ObservedObject var dataManager = DataManager.shared
    
    @State private var selectedFilter: CardVariant? = nil
    @State private var searchText = ""
    @State private var isGridView = true
    @State private var selectedCardFor3D: PokemonCard? = nil
    
    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false
    @State private var isExporting = false
    
    private var collection: CardCollection? {
        dataManager.collections.first(where: { $0.id == collectionId })
    }
    
    private var filteredCards: [PokemonCard] {
        guard let col = collection else { return [] }
        return col.cards.filter { card in
            let matchesFilter = (selectedFilter == nil || card.variant == selectedFilter)
            let matchesSearch = searchText.isEmpty ||
                card.name.localizedCaseInsensitiveContains(searchText) ||
                card.setName.localizedCaseInsensitiveContains(searchText) ||
                card.localId.contains(searchText)
            return matchesFilter && matchesSearch
        }
    }
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    public var body: some View {
        Group {
            if let col = collection {
                ZStack {
                    PokeTheme.bgDark.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header statistiche e pulsante Export Excel
                        statsAndExportHeader(col: col)
                        
                        // Barra Filtri e Switch Galleria / Lista
                        filtersAndLayoutBar(col: col)
                        
                        // Contenuto: Griglia o Lista
                        if filteredCards.isEmpty {
                            emptyStateView
                        } else {
                            ScrollView {
                                if isGridView {
                                    LazyVGrid(columns: gridColumns, spacing: 14) {
                                        ForEach(filteredCards) { card in
                                            CardGridItemView(
                                                card: card,
                                                onTap: {
                                                    selectedCardFor3D = card
                                                },
                                                onDelete: {
                                                    dataManager.deleteCard(collectionId: col.id, cardId: card.id)
                                                }
                                            )
                                            .contextMenu {
                                                cardContextMenu(card: card, col: col)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                } else {
                                    LazyVStack(spacing: 10) {
                                        ForEach(filteredCards) { card in
                                            Button {
                                                selectedCardFor3D = card
                                            } label: {
                                                CardRowView(
                                                    card: card,
                                                    onSelectVariant: { newVariant in
                                                        dataManager.updateCardVariant(collectionId: col.id, cardId: card.id, variant: newVariant)
                                                    },
                                                    onDelete: {
                                                        dataManager.deleteCard(collectionId: col.id, cardId: card.id)
                                                    }
                                                )
                                                .padding(12)
                                                .glassPanel(cornerRadius: 14)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Cerca Pokémon, Set o Numero...")
                .navigationTitle(col.name)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showShareSheet) {
                    if let url = exportURL {
                        ShareSheet(activityItems: [url])
                    }
                }
                .sheet(item: $selectedCardFor3D) { card in
                    HolographicCardView(
                        card: card,
                        onVariantChanged: { newVariant in
                            dataManager.updateCardVariant(collectionId: col.id, cardId: card.id, variant: newVariant)
                        },
                        onDelete: {
                            dataManager.deleteCard(collectionId: col.id, cardId: card.id)
                        }
                    )
                }
            } else {
                Text("Collezione non trovata")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Componenti UI
    
    private func statsAndExportHeader(col: CardCollection) -> some View {
        VStack(spacing: 14) {
            // Dashboard Metriche a Griglia 4 Colonne Glassmorphic
            HStack(spacing: 8) {
                StatCard(title: "Totale", value: "\(col.totalCards)", glowColor: PokeTheme.neonCyan)
                StatCard(title: "Regular", value: "\(col.regularCount)", glowColor: Color.blue)
                StatCard(title: "Reverse", value: "\(col.reverseCount)", glowColor: PokeTheme.neonPurple)
                StatCard(title: "Foil", value: "\(col.foilCount)", glowColor: PokeTheme.neonYellow)
            }
            
            // Pulsante Esporta in Excel (.xlsx) con gradiente e glow
            Button(action: {
                exportToExcel(col: col)
            }) {
                HStack(spacing: 10) {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "tablecells.badge.ellipsis")
                            .font(.system(size: 17, weight: .bold))
                    }
                    
                    Text("Esporta in Excel (.xlsx)")
                        .font(.system(size: 16, weight: .black))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PokeTheme.excelGradient)
                .foregroundColor(.white)
                .cornerRadius(14)
                .neonGlow(color: PokeTheme.neonGreen, radius: 8)
                .shadow(color: PokeTheme.neonGreen.opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .disabled(col.totalCards == 0 || isExporting)
            .opacity(col.totalCards == 0 ? 0.6 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
    
    private func filtersAndLayoutBar(col: CardCollection) -> some View {
        HStack(spacing: 12) {
            // Filtri Rapidi
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Tutte (\(col.totalCards))", isSelected: selectedFilter == nil) {
                        selectedFilter = nil
                    }
                    
                    ForEach(CardVariant.allCases) { variant in
                        let count = col.cards.filter { $0.variant == variant }.count
                        FilterChip(title: "\(variant.rawValue) (\(count))", isSelected: selectedFilter == variant) {
                            selectedFilter = variant
                        }
                    }
                }
            }
            
            // Toggle Griglia / Lista
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isGridView.toggle()
                }
            } label: {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .glassPanel(cornerRadius: 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 50))
                .foregroundColor(PokeTheme.neonCyan.opacity(0.6))
                .neonGlow(color: PokeTheme.neonCyan, radius: 8)
            
            Text("Nessuna carta trovata")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            
            Text("Inquadra le carte nella sezione Scansione per iniziare ad aggiungerle.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    @ViewBuilder
    private func cardContextMenu(card: PokemonCard, col: CardCollection) -> some View {
        ForEach(CardVariant.allCases) { v in
            Button {
                dataManager.updateCardVariant(collectionId: col.id, cardId: card.id, variant: v)
            } label: {
                HStack {
                    Text("Imposta come \(v.rawValue)")
                    if card.variant == v { Image(systemName: "checkmark") }
                }
            }
        }
        Divider()
        Button(role: .destructive) {
            dataManager.deleteCard(collectionId: col.id, cardId: card.id)
        } label: {
            Label("Elimina carta", systemImage: "trash")
        }
    }
    
    private func exportToExcel(col: CardCollection) {
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let url = ExcelExporter.shared.exportCollectionToXLSX(col)
            DispatchQueue.main.async {
                self.isExporting = false
                if let fileURL = url {
                    self.exportURL = fileURL
                    self.showShareSheet = true
                    
                    let haptic = UINotificationFeedbackGenerator()
                    haptic.notificationOccurred(.success)
                }
            }
        }
    }
}

// Scheda Metrica Singola
struct StatCard: View {
    let title: String
    let value: String
    let glowColor: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(glowColor)
                .neonGlow(color: glowColor, radius: 4)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassPanel(cornerRadius: 12, borderColor: glowColor.opacity(0.4))
    }
}

// ShareSheet nativo iOS
public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    
    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public struct FilterChip: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .black : .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? PokeTheme.neonCyan
                        : Color.white.opacity(0.1)
                )
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(18)
                .neonGlow(color: isSelected ? PokeTheme.neonCyan : Color.clear, radius: 4)
        }
    }
}
