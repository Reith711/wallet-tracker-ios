import Foundation
import SwiftUI

struct AlertItem: Identifiable, Decodable {
    let id: String
    let coin: String
    let title: String
    let trigger: String
    let reason: String
    let type: String

    var badgeColor: Color {
        switch type {
        case "takeProfit":
            return .green
        case "risk":
            return .red
        default:
            return .blue
        }
    }

    var typeLabel: String {
        switch type {
        case "takeProfit":
            return "Take Profit"
        case "risk":
            return "Risk"
        default:
            return type
        }
    }
}
