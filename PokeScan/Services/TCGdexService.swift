import Foundation
import UIKit

public struct TCGdexCardResponse: Codable {
    public let id: String?
    public let localId: String?
    public let name: String?
    public let image: String?
    public let rarity: String?
    public let set: TCGdexSetBrief?
}

public struct TCGdexSetBrief: Codable {
    public let id: String?
    public let name: String?
}

public struct TCGdexCardSearchItem: Codable {
    public let id: String?
    public let localId: String?
    public let name: String?
    public let image: String?
}

public class TCGdexService {
    public static let shared = TCGdexService()
    
    private let session: URLSession
    private var memoryCache: [String: TCGdexCardResponse] = [:]
    private var imageCache: [String: Data] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 12
        self.session = URLSession(configuration: config)
    }
    
    /// Risolve in modo intelligente la carta incrociando Nome Pokémon, Set e Numero (con supporto per Full Art e Promo)
    public func resolveCard(
        pokemonName: String?,
        setId: String?,
        localId: String,
        totalCards: String?,
        candidateSetIds: [String] = [],
        language: String = "IT"
    ) async -> (setId: String, setName: String, localId: String, name: String, rarity: String, imageURL: String?, thumbnailData: Data?) {
        
        let cleanLocalId = localId.trimmingCharacters(in: .whitespacesAndNewlines)
        let lang = language.lowercased()
        
        // 1. TENTATIVO CON SET ID SPECIFICO (Lookup Diretto e Univoco)
        if let sId = setId, !sId.isEmpty {
            var res = await fetchCardDirect(setId: sId, localId: cleanLocalId, language: lang)
            if !res.found && lang != "en" {
                res = await fetchCardDirect(setId: sId, localId: cleanLocalId, language: "en")
            }
            if res.found {
                let setInfo = SetCatalog.shared.sets[sId]
                let sName = setInfo?.localizedName(language: language) ?? res.setName ?? sId.uppercased()
                return (sId, sName, cleanLocalId, res.name, res.rarity, res.imageURL, res.thumbnailData)
            }
        }
        
        // 1B. VERIFICA DEI SET CANDIDATI (Se condividono lo stesso totale carte, es. 217 -> me02.5 vs swsh11)
        for candId in candidateSetIds where candId != setId {
            let res = await fetchCardDirect(setId: candId, localId: cleanLocalId, language: lang)
            if let pName = pokemonName, !pName.isEmpty {
                let recognizedClean = pName.lowercased().trimmingCharacters(in: .whitespaces)
                let returnedClean = res.name.lowercased()
                if returnedClean.contains(recognizedClean) || recognizedClean.contains(returnedClean) {
                    let setInfo = SetCatalog.shared.sets[candId]
                    let sName = setInfo?.localizedName(language: language) ?? res.setName ?? candId.uppercased()
                    return (candId, sName, cleanLocalId, res.name, res.rarity, res.imageURL, res.thumbnailData)
                }
            }
        }
        
        // 2. DISAMBIGUAZIONE CON NOME POKÉMON + NUMERO CARTA (Infallibile per Full Art, Ascesa Eroica, ecc.)
        if let pName = pokemonName, !pName.isEmpty {
            var match = await searchByNameAndNumber(name: pName, localId: cleanLocalId, language: lang)
            if match == nil {
                match = await searchByNameAndNumber(name: pName, localId: cleanLocalId, language: "en")
            }
            if let found = match {
                let extractedSetId = found.setId
                let setInfo = SetCatalog.shared.sets[extractedSetId]
                let sName = setInfo?.localizedName(language: language) ?? extractedSetId.uppercased()
                let thumb = found.imageURL != nil ? await downloadThumbnail(baseURL: found.imageURL!) : nil
                return (extractedSetId, sName, found.localId, found.name, found.rarity, found.imageURL, thumb)
            }
        }
        
        // 3. FALLBACK PROMOZIONALI (SVP, SWSHP, SMP, XYP, BWP, DPP)
        let promoSets = ["svp", "swshp", "smp", "xyp", "bwp", "dpp"]
        for pSet in promoSets {
            let res = await fetchCardDirect(setId: pSet, localId: cleanLocalId, language: lang)
            if res.found {
                let setInfo = SetCatalog.shared.sets[pSet]
                let sName = setInfo?.localizedName(language: language) ?? res.setName ?? pSet.uppercased()
                return (pSet, sName, cleanLocalId, res.name, res.rarity, res.imageURL, res.thumbnailData)
            }
        }
        
        // 4. Fallback base
        let finalSetId = candidateSetIds.first ?? setId ?? "sv01"
        let setInfo = SetCatalog.shared.sets[finalSetId]
        let sName = setInfo?.localizedName(language: language) ?? finalSetId.uppercased()
        let fallbackName = pokemonName?.capitalized ?? "Carta \(cleanLocalId)"
        return (finalSetId, sName, cleanLocalId, fallbackName, "Comune", nil, nil)
    }
    
    /// Ricerca carta tramite endpoint /cards?name=X e matching per numero locale
    public func searchByNameAndNumber(name: String, localId: String, language: String) async -> (setId: String, localId: String, name: String, rarity: String, imageURL: String?)? {
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlString = "https://api.tcgdex.net/v2/\(language)/cards?name=\(encodedName)"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("PokeScan/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            let list = try JSONDecoder().decode([TCGdexCardSearchItem].self, from: data)
            let targetClean = localId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let targetInt = Int(targetClean)
            
            for item in list {
                guard let cId = item.localId?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
                let cInt = Int(cId)
                
                // Match sia per stringa ("025" == "025" o "tg05" == "tg05") sia per intero (25 == 25 o 123 == 123)
                let isMatch = (cId == targetClean) || (targetInt != nil && cInt == targetInt)
                if isMatch, let fullId = item.id {
                    let parts = fullId.split(separator: "-")
                    let extractedSetId = parts.count > 1 ? String(parts[0]) : ""
                    
                    let details = await fetchCardDirect(setId: extractedSetId, localId: item.localId ?? localId, language: language)
                    return (
                        setId: extractedSetId,
                        localId: item.localId ?? localId,
                        name: item.name ?? name,
                        rarity: details.rarity,
                        imageURL: item.image
                    )
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    /// Chiamata diretta per setId + localId
    public func fetchCardDirect(setId: String, localId: String, language: String = "it") async -> (found: Bool, name: String, setName: String?, rarity: String, imageURL: String?, thumbnailData: Data?) {
        let cleanLocalId = localId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSetId = setId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var candidates = [cleanLocalId]
        if let intVal = Int(cleanLocalId) {
            let unpadded = "\(intVal)"
            let padded = String(format: "%03d", intVal)
            if !candidates.contains(unpadded) { candidates.append(unpadded) }
            if !candidates.contains(padded) { candidates.append(padded) }
        }
        
        for cand in candidates {
            let urlString = "https://api.tcgdex.net/v2/\(language)/sets/\(cleanSetId)/\(cand)"
            guard let url = URL(string: urlString) else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.setValue("PokeScan/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { continue }
                
                let decoded = try JSONDecoder().decode(TCGdexCardResponse.self, from: data)
                let name = decoded.name ?? "Carta \(cleanLocalId)"
                let rarity = decoded.rarity ?? "Comune"
                let imageURL = decoded.image
                let setName = decoded.set?.name
                let thumb = imageURL != nil ? await downloadThumbnail(baseURL: imageURL!) : nil
                return (true, name, setName, rarity, imageURL, thumb)
            } catch {
                continue
            }
        }
        return (false, "Carta \(cleanLocalId)", nil, "Comune", nil, nil)
    }
    
    /// Scarica e converte la miniatura in PNG data
    public func downloadThumbnail(baseURL: String) async -> Data? {
        if let cached = imageCache[baseURL] {
            return cached
        }
        let candidates = ["\(baseURL)/low.webp", "\(baseURL)/low.png", "\(baseURL)/high.webp"]
        for cand in candidates {
            guard let url = URL(string: cand) else { continue }
            do {
                var request = URLRequest(url: url)
                request.setValue("PokeScan/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let uiImage = UIImage(data: data), let pngData = uiImage.pngData() {
                        imageCache[baseURL] = pngData
                        return pngData
                    }
                }
            } catch {
                continue
            }
        }
        return nil
    }
}
