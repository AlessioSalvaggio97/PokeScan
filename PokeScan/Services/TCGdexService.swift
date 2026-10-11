import Foundation
import UIKit

public struct TCGdexCardResponse: Codable {
    public let id: String?
    public let localId: String?
    public let name: String?
    public let image: String?
    public let rarity: String?
}

public class TCGdexService {
    public static let shared = TCGdexService()
    
    private let session: URLSession
    private var memoryCache: [String: TCGdexCardResponse] = [:]
    private var imageCache: [String: Data] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }
    
    /// Recupera i dettagli della carta da TCGdex
    public func fetchCard(setId: String, localId: String, language: String = "IT") async -> (name: String, rarity: String, imageURL: String?, thumbnailData: Data?) {
        let cleanLocalId = localId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSetId = setId.trimmingCharacters(in: .whitespacesAndNewlines)
        let lang = language.lowercased()
        
        var cardName = "Carta \(cleanLocalId)"
        var cardRarity = "Comune"
        var cardImageURL: String? = nil
        var thumbnailData: Data? = nil
        
        // Formatta localId: prova sia numero secco che con zero padding (es. "25" o "025")
        let paddedId = String(format: "%03d", Int(cleanLocalId) ?? 0)
        let candidates = [cleanLocalId, paddedId]
        
        for cand in candidates {
            let urlString = "https://api.tcgdex.net/v2/\(lang)/sets/\(cleanSetId)/\(cand)"
            guard let url = URL(string: urlString) else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.setValue("PokeScan/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue
                }
                
                let decoded = try JSONDecoder().decode(TCGdexCardResponse.self, from: data)
                if let name = decoded.name, !name.isEmpty {
                    cardName = name
                }
                if let rarity = decoded.rarity, !rarity.isEmpty {
                    cardRarity = rarity
                }
                if let img = decoded.image {
                    cardImageURL = img
                    // Scarica miniatura
                    thumbnailData = await downloadThumbnail(baseURL: img)
                }
                break
            } catch {
                continue
            }
        }
        
        return (cardName, cardRarity, cardImageURL, thumbnailData)
    }
    
    /// Scarica e converte la miniatura in PNG data
    public func downloadThumbnail(baseURL: String) async -> Data? {
        if let cached = imageCache[baseURL] {
            return cached
        }
        
        // TCGdex supporta /low.webp e /high.webp
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
