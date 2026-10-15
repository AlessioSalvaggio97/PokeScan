import Foundation
import UIKit
import Vision

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
    private var symbolFeaturePrintCache: [String: VNFeaturePrintObservation] = [:]
    
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
            
            // Inietta alias standard per Scarlatto & Violetto e MegaEvoluzioni
            let modernAliases: [String: String] = [
                // Scarlatto & Violetto
                "SVI": "sv01", "SV01": "sv01", "SV1": "sv01",
                "PAL": "sv02", "SV02": "sv02", "SV2": "sv02",
                "OBF": "sv03", "SV03": "sv03", "SV3": "sv03",
                "MEW": "sv03.5", "SV03.5": "sv03.5", "SV3.5": "sv03.5", "151": "sv03.5",
                "PAR": "sv04", "SV04": "sv04", "SV4": "sv04",
                "PAF": "sv04.5", "SV04.5": "sv04.5", "SV4.5": "sv04.5",
                "TEF": "sv05", "SV05": "sv05", "SV5": "sv05",
                "TWM": "sv06", "SV06": "sv06", "SV6": "sv06",
                "SFA": "sv06.5", "SV06.5": "sv06.5", "SV6.5": "sv06.5",
                "SCR": "sv07", "SV07": "sv07", "SV7": "sv07",
                "SSP": "sv08", "SV08": "sv08", "SV8": "sv08",
                "PRE": "sv08.5", "SV08.5": "sv08.5", "SV8.5": "sv08.5",
                "SV09": "sv09", "SV9": "sv09",
                "SV10": "sv10", "SV10.5": "sv10.5b",
                // Mega Evoluzioni
                "ASC": "me02.5", "ME02.5": "me02.5", "ME2.5": "me02.5",
                "ME01": "me01", "ME1": "me01",
                "ME02": "me02", "ME2": "me02",
                "ME03": "me03", "ME3": "me03",
                "ME04": "me04", "ME4": "me04",
                "ME05": "me05", "ME5": "me05",
                // Promo
                "SVP": "svp", "SWSHP": "swshp", "SMP": "smp", "XYP": "xyp", "BWP": "bwp", "DPP": "dpp"
            ]
            for (alias, setId) in modernAliases {
                if self.abbreviations[alias] == nil {
                    self.abbreviations[alias] = setId
                }
            }
            
            print("[SetCatalog] Caricati \(sets.count) set e \(abbreviations.count) abbreviazioni con successo.")
        } catch {
            print("[SetCatalog] Errore decodifica catalogo: \(error)")
        }
    }
    
    /// Trova il set dato il codice abbreviazione letto (es. "SVI", "PAL", "SCR", "SSP")
    public func findSetByCode(_ code: String) -> SetInfo? {
        var cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        cleaned = cleaned.replacingOccurrences(of: "[", with: "")
                         .replacingOccurrences(of: "]", with: "")
                         .replacingOccurrences(of: "(", with: "")
                         .replacingOccurrences(of: ")", with: "")
                         .trimmingCharacters(in: .whitespacesAndNewlines)
        
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
    
    /// Trova i set candidati dato il denominatore/totale delle carte (es. 149 per Sole e Luna, 091 -> 91)
    public func findSetsByDenominator(_ denominator: String) -> [SetInfo] {
        let key = denominator.trimmingCharacters(in: .whitespacesAndNewlines)
        var setIds = denominatorIndex[key] ?? []
        // Se non trova corrispondenza (es. "091"), prova convertendo ad intero e poi stringa ("91")
        if setIds.isEmpty, let intVal = Int(key) {
            setIds = denominatorIndex["\(intVal)"] ?? []
        }
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
    
    // MARK: - Template Matching Visivo dei Simboli (Pre-Scarlatto & Violetto)
    
    /// Restituisce l'embedding visivo (Feature Print) del simbolo per il dato set
    public func getSymbolFeaturePrint(for setId: String) -> VNFeaturePrintObservation? {
        if let cached = symbolFeaturePrintCache[setId] {
            return cached
        }
        guard let uiImg = getSymbolImage(for: setId),
              let cgImg = uiImg.cgImage else { return nil }
        
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
        try? handler.perform([request])
        
        if let printObs = request.results?.first as? VNFeaturePrintObservation {
            symbolFeaturePrintCache[setId] = printObs
            return printObs
        }
        return nil
    }
    
    /// Confronta un ritaglio della fotocamera (CGImage) con i simboli dei set candidati
    /// Restituisce il set ID con la minima distanza euclidea visiva
    public func matchBestCandidateSymbol(from croppedCGImage: CGImage, among candidateSetIds: [String]) -> (bestSetId: String, distance: Float)? {
        guard !candidateSetIds.isEmpty else { return nil }
        
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(cgImage: croppedCGImage, options: [:])
        try? handler.perform([request])
        
        guard let queryPrint = request.results?.first as? VNFeaturePrintObservation else {
            return nil
        }
        
        var bestId: String? = nil
        var minDistance: Float = Float.greatestFiniteMagnitude
        
        for candId in candidateSetIds {
            guard let candPrint = getSymbolFeaturePrint(for: candId) else { continue }
            var distance: Float = 0
            do {
                try queryPrint.computeDistance(&distance, to: candPrint)
                if distance < minDistance {
                    minDistance = distance
                    bestId = candId
                }
            } catch {
                continue
            }
        }
        
        if let best = bestId {
            return (best, minDistance)
        }
        return nil
    }
}
