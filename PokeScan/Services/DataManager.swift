import Foundation
import Combine

public class DataManager: ObservableObject {
    public static let shared = DataManager()
    
    @Published public var collections: [CardCollection] = []
    @Published public var activeCollectionId: UUID?
    
    private let fileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pokeScanDir = appSupport.appendingPathComponent("PokeScan", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: pokeScanDir, withIntermediateDirectories: true)
        self.fileURL = pokeScanDir.appendingPathComponent("collections.json")
        
        load()
        
        // Se non ci sono collezioni, ne creiamo una predefinita
        if collections.isEmpty {
            let defaultCol = CardCollection(name: "Bulk Scarlatto & Violetto")
            collections.append(defaultCol)
            activeCollectionId = defaultCol.id
            save()
        } else if activeCollectionId == nil {
            activeCollectionId = collections.first?.id
        }
    }
    
    public var activeCollection: CardCollection? {
        guard let id = activeCollectionId else { return collections.first }
        return collections.first(where: { $0.id == id })
    }
    
    public func createCollection(name: String) -> CardCollection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Nuova Collezione" : trimmed
        let newCol = CardCollection(name: finalName)
        collections.insert(newCol, at: 0)
        activeCollectionId = newCol.id
        save()
        return newCol
    }
    
    public func selectActiveCollection(_ id: UUID) {
        if collections.contains(where: { $0.id == id }) {
            activeCollectionId = id
        }
    }
    
    public func addCardToActiveCollection(_ card: PokemonCard) {
        guard let activeId = activeCollectionId,
              let index = collections.firstIndex(where: { $0.id == activeId }) else {
            return
        }
        
        // Aggiunge in testa alla collezione attiva
        collections[index].cards.insert(card, at: 0)
        save()
    }
    
    public func updateLastCardVariant(variant: CardVariant) {
        guard let activeId = activeCollectionId,
              let colIndex = collections.firstIndex(where: { $0.id == activeId }),
              !collections[colIndex].cards.isEmpty else {
            return
        }
        
        collections[colIndex].cards[0].variant = variant
        save()
    }
    
    public func updateCardVariant(collectionId: UUID, cardId: UUID, variant: CardVariant) {
        guard let colIndex = collections.firstIndex(where: { $0.id == collectionId }),
              let cardIndex = collections[colIndex].cards.firstIndex(where: { $0.id == cardId }) else {
            return
        }
        
        collections[colIndex].cards[cardIndex].variant = variant
        save()
    }
    
    public func deleteCard(collectionId: UUID, cardId: UUID) {
        guard let colIndex = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        collections[colIndex].cards.removeAll(where: { $0.id == cardId })
        save()
    }
    
    public func deleteCollection(id: UUID) {
        collections.removeAll(where: { $0.id == id })
        if activeCollectionId == id {
            activeCollectionId = collections.first?.id
        }
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(collections)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[DataManager] Errore salvataggio collezioni: \(error)")
        }
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            self.collections = try JSONDecoder().decode([CardCollection].self, from: data)
        } catch {
            print("[DataManager] Errore caricamento collezioni: \(error)")
        }
    }
}
