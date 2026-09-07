import Foundation
import Combine

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published var alerts: [AlertItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchAlerts() async {
        guard let url = URL(string: "http://localhost:4000/alerts") else {
            errorMessage = "Niepoprawny URL backendu."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                errorMessage = "Backend zwrócił błąd."
                isLoading = false
                return
            }

            alerts = try JSONDecoder().decode([AlertItem].self, from: data)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
