# WalletTracker — jak wgrać

## 1) Backend
1. Skopiuj folder `backend/wallettracker-backend` gdziekolwiek chcesz.
2. W terminalu, w tym folderze:
   ```
   npm install
   npm run dev
   ```
3. Powinieneś zobaczyć: `API działa na http://localhost:4000`

## 2) iOS w Xcode
1. W Xcode: Create New Project -> iOS -> App.
   - Product Name: WalletTracker
   - Interface: SwiftUI
   - Language: Swift
   - zaznacz "Use SwiftData"
2. Usuń domyślne pliki (ContentView.swift wygenerowany przez Xcode, App.swift).
3. Przeciągnij (drag & drop) wszystkie pliki z folderu `iOS/WalletTracker` z tego archiwum
   do swojego projektu w Xcode (upewnij się, że masz zaznaczone "Copy items if needed"
   i target WalletTracker).
4. Zbuduj i uruchom: Cmd + R.

## Co powinieneś zobaczyć
- Zakładka **Portfolio**: dodawanie transakcji (+), podsumowanie z wartością live
  i wynikiem niezrealizowanym, ceny live z 24h zmianą, pull-to-refresh.
- Zakładka **Alerty**: alerty liczone dynamicznie z Twoich transakcji i cen live
  (nie mocki).

## Stan projektu / czego brakuje
- Warstwa AI (`/ai-alerts`) — obecnie alerty liczone są regułami procentowymi,
  nie modelem AI.
- Powiadomienia push na iPhone.
- Priorytet/sortowanie alertów, ekran ustawień progów.

Backend musi działać (`npm run dev`) zanim uruchomisz appkę — inaczej zobaczysz
błędy połączenia w obu zakładkach.
