import Foundation
import UIKit

public struct SetInfo: Codable, Identifiable {
    public let id: String
    public let name_it: String
    public let name_en: String
    public let official_count: Int?
    public let total_count: Int?
    public let symbol_url: String?
    public let local_symbol: String?
    public let logo_url: String?
    
    public func localizedName(language: String = "IT") -> String {
        if language.uppercased() == "EN" && !name_en.isEmpty {
            return name_en
        }
        return name_it.isEmpty ? name_en : name_it
    }
}

public struct CatalogData: Codable {
    public let sets: [String: SetInfo]
    public let abbreviations: [String: String]
    public let denominator_index: [String: [String]]
}

public class SetCatalog: ObservableObject {
    public static let shared = SetCatalog()
    
    @Published public var sets: [String: SetInfo] = [:]
    @Published public var abbreviations: [String: String] = [:]
    @Published public var denominatorIndex: [String: [String]] = [:]
    
    private var symbolCache: [String: UIImage] = [:]
    
    public init() {
        loadCatalog()
    }
    
    public func loadCatalog() {
        // Cerca sets_catalog.json nel Bundle
        guard let url = Bundle.main.url(forResource: "sets_catalog", withExtension: "json") else {
            print("[SetCatalog] Impossibile trovare sets_catalog.json nel bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(CatalogData.self, from: data)
            self.sets = decoded.sets
            self.abbreviations = decoded.abbreviations
            self.denominatorIndex = decoded.denominator_index
            print("[SetCatalog] Caricati \(sets.count) set e \(abbreviations.count) abbreviazioni con successo.")
        } catch {
            print("[SetCatalog] Errore decodifica catalogo: \(error)")
        }
    }
    
    /// Trova il set dato il codice abbreviazione letto (es. "SVI", "PAL", "SCR", "SSP")
    public func findSetByCode(_ code: String) -> SetInfo? {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let setId = abbreviations[cleaned], let setInfo = sets[setId] {
            return setInfo
        }
        // Tentativo con match diretto case-insensitive
        for (id, set) in sets {
            if id.uppercased() == cleaned {
                return set
            }
        }
        return nil
    }
    
    /// Trova i set candidati dato il denominatore/totale delle carte (es. 149 per Sole e Luna)
    public func findSetsByDenominator(_ denominator: String) -> [SetInfo] {
        let key = denominator.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let setIds = denominatorIndex[key] else { return [] }
        return setIds.compactMap { sets[$0] }
    }
    
    /// Recupera l'icona UIImage del simbolo per un dato set (dal bundle o dalla cache)
    public func getSymbolImage(for setId: String) -> UIImage? {
        if let cached = symbolCache[setId] {
            return cached
        }
        
        // Cerca nel bundle 'symbols/{setId}.png' o '{setId}.png'
        if let path = Bundle.main.path(forResource: setId, ofType: "png", inDirectory: "symbols") ??
                      Bundle.main.path(forResource: setId, ofType: "png") {
            if let image = UIImage(contentsOfFile: path) {
                symbolCache[setId] = image
                return image
            }
        }
        return nil
    }
    
    /// Recupera i bytes PNG del simbolo per l'esportazione Excel
    public func getSymbolData(for setId: String) -> Data? {
        if let img = getSymbolImage(for: setId) {
            return img.pngData()
        }
        return nil
    }
}
