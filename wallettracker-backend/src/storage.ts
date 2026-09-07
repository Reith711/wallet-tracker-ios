import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname } from "node:path";

export type TransactionRecord = {
  id: string;
  coinSymbol: string;
  amountPLN: number;
  buyPriceUSD: number;
  quantity: number;
  date: string;
};

const FILE_PATH = "data/transactions.json";

async function ensureFile() {
  await mkdir(dirname(FILE_PATH), { recursive: true });

  try {
    await readFile(FILE_PATH, "utf-8");
  } catch {
    await writeFile(FILE_PATH, "[]", "utf-8");
  }
}

export async function loadTransactions(): Promise<TransactionRecord[]> {
  await ensureFile();
  const raw = await readFile(FILE_PATH, "utf-8");
  return JSON.parse(raw) as TransactionRecord[];
}

export async function saveTransactions(transactions: TransactionRecord[]): Promise<void> {
  await ensureFile();
  await writeFile(FILE_PATH, JSON.stringify(transactions, null, 2), "utf-8");
}
