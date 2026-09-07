import Foundation

struct CoinPrice: Identifiable, Decodable {
    var id: String { symbol }

    let symbol: String
    let priceUSD: Double
    let change24h: Double
    let lastUpdatedAt: Int
}
