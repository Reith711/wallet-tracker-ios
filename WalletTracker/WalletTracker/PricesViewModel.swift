import Foundation
import Combine

@MainActor
final class PricesViewModel: ObservableObject {
    @Published var prices: [CoinPrice] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var lastRequestedKey: String = ""

    func fetchPrices(for symbols: [String], force: Bool = false) async {
        let uniqueSymbols = Array(Set(symbols.map { $0.uppercased() })).sorted()

        guard !uniqueSymbols.isEmpty else {
            prices = []
            errorMessage = nil
            return
        }

        let requestKey = uniqueSymbols.joined(separator: ",")

        if isLoading { return }
        if !force && requestKey == lastRequestedKey && !prices.isEmpty { return }

        guard let encoded = requestKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://localhost:4000/prices?symbols=\(encoded)") else {
            errorMessage = "Niepoprawny URL cen."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Brak odpowiedzi HTTP z backendu cen."
                isLoading = false
                return
            }

            if httpResponse.statusCode == 429 {
                errorMessage = "Limit odświeżeń cen. Poczekaj chwilę i spróbuj ponownie."
                isLoading = false
                return
            }

            guard 200...299 ~= httpResponse.statusCode else {
                errorMessage = "Backend cen zwrócił błąd \(httpResponse.statusCode)."
                isLoading = false
                return
            }

            prices = try JSONDecoder().decode([CoinPrice].self, from: data)
            lastRequestedKey = requestKey
            isLoading = false
        } catch {
            errorMessage = "Nie udało się pobrać cen live."
            isLoading = false
        }
    }

    func invalidateCache() {
        lastRequestedKey = ""
    }

    func price(for symbol: String) -> CoinPrice? {
        prices.first { $0.symbol.uppercased() == symbol.uppercased() }
    }
}
