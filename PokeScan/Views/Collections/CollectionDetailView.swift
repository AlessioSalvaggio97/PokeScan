import SwiftUI

public struct CollectionDetailView: View {
    public let collectionId: UUID
    @ObservedObject var dataManager = DataManager.shared
    
    @State private var selectedFilter: CardVariant? = nil
    @State private var searchText = ""
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
    
    public var body: some View {
        Group {
            if let col = collection {
                VStack(spacing: 0) {
                    // Header statistiche e pulsante Export Excel
                    statsAndExportHeader(col: col)
                    
                    // Filtri rapidi
                    filtersBar
                    
                    // Lista carte
                    if filteredCards.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "tray.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Nessuna carta trovata")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(filteredCards) { card in
                                CardRowView(
                                    card: card,
                                    onSelectVariant: { newVariant in
                                        dataManager.updateCardVariant(collectionId: col.id, cardId: card.id, variant: newVariant)
                                    },
                                    onDelete: {
                                        dataManager.deleteCard(collectionId: col.id, cardId: card.id)
                                    }
                                )
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let card = filteredCards[index]
                                    dataManager.deleteCard(collectionId: col.id, cardId: card.id)
                                }
                            }
                        }
                        .listStyle(.plain)
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
            } else {
                Text("Collezione non trovata")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Componenti UI
    
    private func statsAndExportHeader(col: CardCollection) -> some View {
        VStack(spacing: 12) {
            // Schede metriche
            HStack(spacing: 8) {
                StatPill(title: "Totale", value: "\(col.totalCards)", color: .blue)
                StatPill(title: "Regular", value: "\(col.regularCount)", color: .gray)
                StatPill(title: "Reverse", value: "\(col.reverseCount)", color: .purple)
                StatPill(title: "Foil", value: "\(col.foilCount)", color: .orange)
            }
            
            // Pulsante Esporta in Excel (.xlsx)
            Button(action: {
                exportToExcel(col: col)
            }) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "tablecells.badge.ellipsis")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("Esporta in Excel (.xlsx)")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.53, blue: 0.28), Color(red: 0.15, green: 0.68, blue: 0.37)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .disabled(col.totalCards == 0 || isExporting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var filtersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Tutte (\(collection?.totalCards ?? 0))", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                
                ForEach(CardVariant.allCases) { variant in
                    let count = collection?.cards.filter { $0.variant == variant }.count ?? 0
                    FilterChip(title: "\(variant.rawValue) (\(count))", isSelected: selectedFilter == variant) {
                        selectedFilter = variant
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color(.systemGray6).opacity(0.5))
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

// ShareSheet nativo iOS
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct StatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}
