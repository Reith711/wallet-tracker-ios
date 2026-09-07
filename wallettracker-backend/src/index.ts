import express from "express";
import cors from "cors";
import { loadTransactions, saveTransactions, type TransactionRecord } from "./storage";

const app = express();
const PORT = 4000;
const PRICE_CACHE_TTL_MS = 60_000;

app.use(cors());
app.use(express.json());

type AlertType = "takeProfit" | "risk";

type Alert = {
  id: string;
  coin: string;
  title: string;
  trigger: string;
  reason: string;
  type: AlertType;
};

type PriceResponseItem = {
  symbol: string;
  priceUSD: number;
  change24h: number;
  lastUpdatedAt: number;
};

const coinIdMap: Record<string, string> = {
  BTC: "bitcoin",
  ETH: "ethereum",
  SOL: "solana",
  XRP: "ripple",
  ADA: "cardano",
  DOGE: "dogecoin",
  AVAX: "avalanche-2",
  DOT: "polkadot",
  LINK: "chainlink",
  MATIC: "matic-network"
};

const priceCache = new Map<string, { timestamp: number; data: PriceResponseItem[] }>();

app.get("/", (_req, res) => {
  res.json({
    name: "WalletTracker API",
    status: "ok"
  });
});

app.get("/transactions", async (_req, res) => {
  const transactions = await loadTransactions();
  res.json(transactions);
});

app.post("/transactions", async (req, res) => {
  const { id, coinSymbol, amountPLN, buyPriceUSD, quantity, date } = req.body;

  if (
    !id ||
    !coinSymbol ||
    amountPLN === undefined ||
    buyPriceUSD === undefined ||
    quantity === undefined ||
    !date
  ) {
    return res.status(400).json({
      message: "Brakuje pól transakcji."
    });
  }

  const newTransaction: TransactionRecord = {
    id: String(id),
    coinSymbol: String(coinSymbol).toUpperCase(),
    amountPLN: Number(amountPLN),
    buyPriceUSD: Number(buyPriceUSD),
    quantity: Number(quantity),
    date: String(date)
  };

  const transactions = await loadTransactions();
  transactions.push(newTransaction);
  await saveTransactions(transactions);

  return res.status(201).json(newTransaction);
});

app.delete("/transactions/:id", async (req, res) => {
  const id = req.params.id;
  const transactions = await loadTransactions();
  const updated = transactions.filter((item) => item.id !== id);

  await saveTransactions(updated);

  res.json({
    success: true
  });
});

app.get("/prices", async (req, res) => {
  const rawSymbols = String(req.query.symbols ?? "");
  const symbols = rawSymbols
    .split(",")
    .map((item) => item.trim().toUpperCase())
    .filter(Boolean)
    .sort();

  const prices = await getPricesForSymbols(symbols);
  res.status(prices.status).json(prices.data);
});

app.get("/alerts", async (_req, res) => {
  const transactions = await loadTransactions();

  if (transactions.length === 0) {
    return res.json([]);
  }

  const grouped = groupTransactionsByCoin(transactions);
  const symbols = Object.keys(grouped).sort();
  const pricesResult = await getPricesForSymbols(symbols);

  const priceMap = new Map(
    pricesResult.data.map((item) => [item.symbol.toUpperCase(), item])
  );

  const alerts: Alert[] = [];

  for (const symbol of symbols) {
    const items = grouped[symbol];
    const totalQuantity = items.reduce((sum, item) => sum + item.quantity, 0);
    const totalCostUSD = items.reduce((sum, item) => sum + item.buyPriceUSD * item.quantity, 0);

    if (totalQuantity <= 0) {
      continue;
    }

    const averageEntryUSD = totalCostUSD / totalQuantity;
    const livePrice = priceMap.get(symbol)?.priceUSD ?? 0;

    if (livePrice <= 0) {
      continue;
    }

    const changePercent = ((livePrice - averageEntryUSD) / averageEntryUSD) * 100;

    if (changePercent >= 15) {
      const sellPercent = 20;
      const sellQuantity = totalQuantity * (sellPercent / 100);

      alerts.push({
        id: `${symbol}-tp-1`,
        coin: symbol,
        title: `Sprzedaj ${sellPercent}% (${formatQuantity(sellQuantity)} ${symbol})`,
        trigger: `Cena jest ${changePercent.toFixed(2)}% powyżej średniej wejścia`,
        reason: `Live ${livePrice.toFixed(2)} USD vs średnia ${averageEntryUSD.toFixed(2)} USD, realizacja części zysku z pozycji ${formatQuantity(totalQuantity)} ${symbol}`,
        type: "takeProfit"
      });
    } else if (changePercent >= 8) {
      const sellPercent = 10;
      const sellQuantity = totalQuantity * (sellPercent / 100);

      alerts.push({
        id: `${symbol}-tp-2`,
        coin: symbol,
        title: `Przygotuj sprzedaż ${sellPercent}% (${formatQuantity(sellQuantity)} ${symbol})`,
        trigger: `Cena jest ${changePercent.toFixed(2)}% powyżej średniej wejścia`,
        reason: `Blisko pierwszej strefy realizacji zysku dla pozycji ${formatQuantity(totalQuantity)} ${symbol}`,
        type: "takeProfit"
      });
    } else if (changePercent <= -10) {
      const sellPercent = 25;
      const sellQuantity = totalQuantity * (sellPercent / 100);

      alerts.push({
        id: `${symbol}-risk-1`,
        coin: symbol,
        title: `Rozważ sprzedaż ${sellPercent}% (${formatQuantity(sellQuantity)} ${symbol})`,
        trigger: `Cena jest ${Math.abs(changePercent).toFixed(2)}% poniżej średniej wejścia`,
        reason: `Pozycja traci względem średniej ${averageEntryUSD.toFixed(2)} USD, rozważ ograniczenie ryzyka`,
        type: "risk"
      });
    } else if (changePercent <= -5) {
      const sellPercent = 10;
      const sellQuantity = totalQuantity * (sellPercent / 100);

      alerts.push({
        id: `${symbol}-risk-2`,
        coin: symbol,
        title: `Uwaga na pozycję, możliwa sprzedaż ${sellPercent}% (${formatQuantity(sellQuantity)} ${symbol})`,
        trigger: `Cena jest ${Math.abs(changePercent).toFixed(2)}% poniżej średniej wejścia`,
        reason: `Ryzyko pogłębienia straty, obserwuj pozycję ${formatQuantity(totalQuantity)} ${symbol}`,
        type: "risk"
      });
    }
  }

  res.json(alerts);
});

app.listen(PORT, () => {
  console.log(`API działa na http://localhost:${PORT}`);
});

function formatQuantity(value: number): string {
  return value.toFixed(6).replace(/\.?0+$/, "");
}

function groupTransactionsByCoin(transactions: TransactionRecord[]) {
  return transactions.reduce<Record<string, TransactionRecord[]>>((acc, item) => {
    const symbol = item.coinSymbol.toUpperCase();
    if (!acc[symbol]) {
      acc[symbol] = [];
    }
    acc[symbol].push(item);
    return acc;
  }, {});
}

async function getPricesForSymbols(
  symbols: string[]
): Promise<{ status: number; data: PriceResponseItem[] }> {
  if (symbols.length === 0) {
    return { status: 200, data: [] };
  }

  const cacheKey = symbols.join(",");
  const cached = priceCache.get(cacheKey);

  if (cached && Date.now() - cached.timestamp < PRICE_CACHE_TTL_MS) {
    return { status: 200, data: cached.data };
  }

  const matched = symbols
    .map((symbol) => ({
      symbol,
      coinId: coinIdMap[symbol]
    }))
    .filter((item) => item.coinId);

  if (matched.length === 0) {
    return { status: 200, data: [] };
  }

  const ids = matched.map((item) => item.coinId).join(",");
  const url =
    `https://api.coingecko.com/api/v3/simple/price?ids=${encodeURIComponent(ids)}` +
    `&vs_currencies=usd&include_24hr_change=true&include_last_updated_at=true`;

  try {
    const response = await fetch(url);

    if (response.status === 429) {
      const fallback = priceCache.get(cacheKey);
      if (fallback) {
        return { status: 200, data: fallback.data };
      }
      return { status: 429, data: [] };
    }

    if (!response.ok) {
      const fallback = priceCache.get(cacheKey);
      if (fallback) {
        return { status: 200, data: fallback.data };
      }
      return { status: 502, data: [] };
    }

    const data = await response.json();

    const result: PriceResponseItem[] = matched.map((item) => ({
      symbol: item.symbol,
      priceUSD: data[item.coinId]?.usd ?? 0,
      change24h: data[item.coinId]?.usd_24h_change ?? 0,
      lastUpdatedAt: data[item.coinId]?.last_updated_at ?? 0
    }));

    priceCache.set(cacheKey, {
      timestamp: Date.now(),
      data: result
    });

    return { status: 200, data: result };
  } catch {
    const fallback = priceCache.get(cacheKey);
    if (fallback) {
      return { status: 200, data: fallback.data };
    }
    return { status: 500, data: [] };
  }
}
