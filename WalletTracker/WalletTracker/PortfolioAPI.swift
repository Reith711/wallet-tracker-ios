import Foundation

final class PortfolioAPI {
    static let shared = PortfolioAPI()

    private init() {}

    func fetchTransactions() async throws -> [TransactionDTO] {
        guard let url = URL(string: "http://localhost:4000/transactions") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([TransactionDTO].self, from: data)
    }

    func saveTransaction(_ transaction: Transaction) async throws {
        guard let url = URL(string: "http://localhost:4000/transactions") else {
            throw URLError(.badURL)
        }

        let dto = TransactionDTO(
            id: transaction.remoteID,
            coinSymbol: transaction.coinSymbol,
            amountPLN: transaction.amountPLN,
            buyPriceUSD: transaction.buyPriceUSD,
            quantity: transaction.quantity,
            date: ISO8601DateFormatter().string(from: transaction.date)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(dto)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }

    func deleteTransaction(id: String) async throws {
        guard let url = URL(string: "http://localhost:4000/transactions/\(id)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }
}
