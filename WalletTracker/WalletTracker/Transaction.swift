import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var remoteID: String
    var coinSymbol: String
    var amountPLN: Double
    var buyPriceUSD: Double
    var quantity: Double
    var date: Date

    init(
        id: UUID = UUID(),
        remoteID: String = UUID().uuidString,
        coinSymbol: String,
        amountPLN: Double,
        buyPriceUSD: Double,
        quantity: Double,
        date: Date
    ) {
        self.id = id
        self.remoteID = remoteID
        self.coinSymbol = coinSymbol.uppercased()
        self.amountPLN = amountPLN
        self.buyPriceUSD = buyPriceUSD
        self.quantity = quantity
        self.date = date
    }
}
