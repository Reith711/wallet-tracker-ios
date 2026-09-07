import Foundation

struct TransactionDTO: Codable {
    let id: String
    let coinSymbol: String
    let amountPLN: Double
    let buyPriceUSD: Double
    let quantity: Double
    let date: String
}
