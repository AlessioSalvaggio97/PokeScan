import Foundation

public struct CardCollection: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var cards: [PokemonCard]
    
    public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), cards: [PokemonCard] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.cards = cards
    }
    
    public var totalCards: Int {
        cards.count
    }
    
    public var regularCount: Int {
        cards.filter { $0.variant == .regular }.count
    }
    
    public var reverseCount: Int {
        cards.filter { $0.variant == .reverse }.count
    }
    
    public var foilCount: Int {
        cards.filter { $0.variant == .foil }.count
    }
    
    public var uniqueCardsCount: Int {
        Set(cards.map { "\($0.setId)_\($0.localId)" }).count
    }
}
