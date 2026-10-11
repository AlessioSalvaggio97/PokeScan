import Foundation
import SwiftUI

public enum CardVariant: String, CaseIterable, Codable, Identifiable {
    case regular = "Regular"
    case reverse = "Reverse"
    case foil = "Foil"
    
    public var id: String { rawValue }
    
    public var badgeColor: Color {
        switch self {
        case .regular:
            return Color.blue
        case .reverse:
            return Color.purple
        case .foil:
            return Color.orange
        }
    }
}

public struct PokemonCard: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var localId: String
    public var setId: String
    public var setName: String
    public var totalCards: String?
    public var rarity: String
    public var variant: CardVariant
    public var language: String
    public var imageURL: String?
    public var thumbnailData: Data?
    public var symbolData: Data?
    public var scannedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        localId: String,
        setId: String,
        setName: String,
        totalCards: String? = nil,
        rarity: String = "Comune",
        variant: CardVariant = .regular,
        language: String = "IT",
        imageURL: String? = nil,
        thumbnailData: Data? = nil,
        symbolData: Data? = nil,
        scannedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.localId = localId
        self.setId = setId
        self.setName = setName
        self.totalCards = totalCards
        self.rarity = rarity
        self.variant = variant
        self.language = language
        self.imageURL = imageURL
        self.thumbnailData = thumbnailData
        self.symbolData = symbolData
        self.scannedAt = scannedAt
    }
    
    public var formattedNumber: String {
        if let total = totalCards, !total.isEmpty {
            return "\(localId)/\(total)"
        }
        return localId
    }
}
