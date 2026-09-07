import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie")
                }

            AlertsView()
                .tabItem {
                    Label("Alerty", systemImage: "bell")
                }
        }
    }
}

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @StateObject private var pricesViewModel = PricesViewModel()

    @State private var showAddSheet = false
    @State private var portfolioErrorMessage: String?
    @State private var isSyncing = false
    @State private var didInitialLoad = false

    private var totalInvestedPLN: Double {
        transactions.reduce(0) { $0 + $1.amountPLN }
    }

    private var totalQuantity: Double {
        transactions.reduce(0) { $0 + $1.quantity }
    }

    private var averageBuyPriceUSD: Double {
        guard totalQuantity > 0 else { return 0 }
        let totalCostUSD = transactions.reduce(0) { $0 + ($1.buyPriceUSD * $1.quantity) }
        return totalCostUSD / totalQuantity
    }

    private var currentPortfolioValueUSD: Double {
        transactions.reduce(0) { partialResult, transaction in
            let livePrice = pricesViewModel.price(for: transaction.coinSymbol)?.priceUSD ?? 0
            return partialResult + (livePrice * transaction.quantity)
        }
    }

    private var investedValueUSD: Double {
        transactions.reduce(0) { $0 + ($1.buyPriceUSD * $1.quantity) }
    }

    private var unrealizedPnLUSD: Double {
        currentPortfolioValueUSD - investedValueUSD
    }

    private var uniqueSymbols: [String] {
        Array(Set(transactions.map { $0.coinSymbol.uppercased() })).sorted()
    }

    private var lastUpdatedDate: Date? {
        let latestTimestamp = pricesViewModel.prices.map(\.lastUpdatedAt).max() ?? 0
        guard latestTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(latestTimestamp))
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty && isSyncing {
                    ProgressView("Synchronizacja portfolio...")
                } else if transactions.isEmpty {
                    VStack(spacing: 16) {
                        summaryCard

                        if let portfolioErrorMessage {
                            Text(portfolioErrorMessage)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }

                        if let pricesError = pricesViewModel.errorMessage {
                            Text(pricesError)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }

                        ContentUnavailableView(
                            "Brak transakcji",
                            systemImage: "bitcoinsign.circle",
                            description: Text("Dodaj pierwszy zakup krypto.")
                        )
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            summaryCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        if let portfolioErrorMessage {
                            Section("Błąd") {
                                Text(portfolioErrorMessage)
                                    .foregroundStyle(.red)
                            }
                        }

                        if let pricesError = pricesViewModel.errorMessage {
                            Section("Ceny live") {
                                Text(pricesError)
                                    .foregroundStyle(.red)
                            }
                        }

                        Section("Transakcje") {
                            ForEach(transactions) { transaction in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(transaction.coinSymbol)
                                            .font(.headline)

                                        Spacer()

                                        Text(transaction.date, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text("Kwota: \(transaction.amountPLN, specifier: "%.2f") PLN")
                                    Text("Cena zakupu: \(transaction.buyPriceUSD, specifier: "%.2f") USD")
                                    Text("Ilość: \(transaction.quantity, specifier: "%.6f")")

                                    if let livePrice = pricesViewModel.price(for: transaction.coinSymbol) {
                                        Text("Cena live: \(livePrice.priceUSD, specifier: "%.2f") USD")
                                            .foregroundStyle(.blue)

                                        Text("24h: \(livePrice.change24h, specifier: "%.2f")%")
                                            .foregroundStyle(livePrice.change24h >= 0 ? .green : .red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deleteTransactions)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await refreshPortfolio(forcePrices: true)
                    }
                }
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSyncing || pricesViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddTransactionView(onSaved: {
                    Task {
                        pricesViewModel.invalidateCache()
                        await refreshPortfolio(forcePrices: true)
                    }
                })
            }
            .task {
                guard !didInitialLoad else { return }
                didInitialLoad = true
                await refreshPortfolio(forcePrices: false)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Podsumowanie")
                .font(.title2.bold())

            Text("Łącznie zainwestowano: \(totalInvestedPLN, specifier: "%.2f") PLN")
            Text("Łączna ilość: \(totalQuantity, specifier: "%.6f")")
            Text("Średnia cena wejścia: \(averageBuyPriceUSD, specifier: "%.2f") USD")
            Text("Wartość live: \(currentPortfolioValueUSD, specifier: "%.2f") USD")
            Text("Wynik niezrealizowany: \(unrealizedPnLUSD, specifier: "%.2f") USD")
                .foregroundStyle(unrealizedPnLUSD >= 0 ? .green : .red)

            if let lastUpdatedDate {
                HStack(spacing: 4) {
                    Text("Ceny zaktualizowano:")
                        .foregroundStyle(.secondary)
                    Text(lastUpdatedDate, style: .relative)
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func refreshPortfolio(forcePrices: Bool) async {
        await syncTransactionsFromBackend()
        await pricesViewModel.fetchPrices(for: uniqueSymbols, force: forcePrices)
    }

    @MainActor
    private func syncTransactionsFromBackend() async {
        if isSyncing { return }

        isSyncing = true
        portfolioErrorMessage = nil

        do {
            let remoteTransactions = try await PortfolioAPI.shared.fetchTransactions()
            let formatter = ISO8601DateFormatter()

            for dto in remoteTransactions {
                let alreadyExists = transactions.contains(where: { $0.remoteID == dto.id })
                if alreadyExists { continue }

                guard let parsedDate = formatter.date(from: dto.date) else { continue }

                let newTransaction = Transaction(
                    remoteID: dto.id,
                    coinSymbol: dto.coinSymbol,
                    amountPLN: dto.amountPLN,
                    buyPriceUSD: dto.buyPriceUSD,
                    quantity: dto.quantity,
                    date: parsedDate
                )

                modelContext.insert(newTransaction)
            }

            isSyncing = false
        } catch {
            portfolioErrorMessage = "Nie udało się pobrać transakcji z backendu."
            isSyncing = false
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { transactions[$0] }

        for transaction in itemsToDelete {
            modelContext.delete(transaction)
        }

        Task {
            for transaction in itemsToDelete {
                do {
                    try await PortfolioAPI.shared.deleteTransaction(id: transaction.remoteID)
                } catch {
                    await MainActor.run {
                        portfolioErrorMessage = "Nie udało się usunąć transakcji z backendu."
                    }
                }
            }

            pricesViewModel.invalidateCache()
            await refreshPortfolio(forcePrices: true)
        }
    }
}

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let onSaved: (() -> Void)?

    @State private var coinSymbol = "BTC"
    @State private var amountPLN = ""
    @State private var buyPriceUSD = ""
    @State private var quantity = ""
    @State private var date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transakcja") {
                    TextField("Symbol, np. BTC", text: $coinSymbol)
                        .textInputAutocapitalization(.characters)

                    TextField("Kwota w PLN", text: $amountPLN)
                        .keyboardType(.decimalPad)

                    TextField("Cena zakupu w USD", text: $buyPriceUSD)
                        .keyboardType(.decimalPad)

                    TextField("Ilość", text: $quantity)
                        .keyboardType(.decimalPad)

                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }

                if let errorMessage {
                    Section("Błąd") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nowa transakcja")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Zapisywanie..." : "Zapisz") {
                        Task {
                            await saveTransaction()
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !coinSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(amountPLN.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(buyPriceUSD.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(quantity.replacingOccurrences(of: ",", with: ".")) != nil
    }

    @MainActor
    private func saveTransaction() async {
        isSaving = true
        errorMessage = nil

        let parsedAmountPLN = Double(amountPLN.replacingOccurrences(of: ",", with: ".")) ?? 0
        let parsedBuyPriceUSD = Double(buyPriceUSD.replacingOccurrences(of: ",", with: ".")) ?? 0
        let parsedQuantity = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0

        let transaction = Transaction(
            coinSymbol: coinSymbol,
            amountPLN: parsedAmountPLN,
            buyPriceUSD: parsedBuyPriceUSD,
            quantity: parsedQuantity,
            date: date
        )

        do {
            modelContext.insert(transaction)
            try await PortfolioAPI.shared.saveTransaction(transaction)
            isSaving = false
            dismiss()
            onSaved?()
        } catch {
            errorMessage = "Nie udało się zapisać transakcji do backendu."
            isSaving = false
        }
    }
}

struct AlertsView: View {
    @StateObject private var viewModel = AlertsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Ładowanie alertów...")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Błąd połączenia",
                        systemImage: "wifi.slash",
                        description: Text(errorMessage)
                    )
                } else if viewModel.alerts.isEmpty {
                    ContentUnavailableView(
                        "Brak alertów",
                        systemImage: "bell.slash",
                        description: Text("Backend nie zwrócił alertów.")
                    )
                } else {
                    List {
                        Section("Aktywne alerty") {
                            ForEach(viewModel.alerts) { alert in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(alert.coin)
                                            .font(.headline)

                                        Spacer()

                                        Text(alert.typeLabel)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(alert.badgeColor.opacity(0.15))
                                            .foregroundStyle(alert.badgeColor)
                                            .clipShape(Capsule())
                                    }

                                    Text(alert.title)
                                        .font(.title3.bold())

                                    Text("Kiedy: \(alert.trigger)")
                                    Text("Dlaczego: \(alert.reason)")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await viewModel.fetchAlerts()
                    }
                }
            }
            .navigationTitle("Alerty")
            .task {
                await viewModel.fetchAlerts()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
