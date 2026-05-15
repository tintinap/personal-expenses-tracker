import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import * as ExcelJS from 'exceljs';

import { PrismaService } from '../prisma/prisma.service';

type TransactionWithCategory = Prisma.TransactionGetPayload<{
  include: { category: { select: { name: true } } };
}>;

interface Period {
  start: string;
  end: string;
}

@Injectable()
export class ExportService {
  private readonly logger = new Logger(ExportService.name);

  private static readonly ROW_LIMIT = 50_000;
  /** Sheet-name reference for use inside Excel formulas. */
  private static readonly AT = "'All Transactions'";

  constructor(private readonly prisma: PrismaService) {}

  async generateExcel(
    userId: string,
    startDate?: Date,
    endDate?: Date,
  ): Promise<Buffer> {
    this.logger.log(`Generating Excel export for user ${userId}`);

    const transactions = await this.fetchTransactions(
      userId,
      startDate,
      endDate,
    );

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Project PET';

    this.buildAllTransactionsSheet(workbook, transactions);
    this.buildCurrencyIncomeSheet(workbook, transactions);
    this.buildCurrencyExchangesSheet(workbook, transactions);

    const categories = this.extractExpenseCategories(transactions);
    const range = this.resolveRange(transactions, startDate, endDate);

    if (range) {
      this.buildPeriodSheet(workbook, 'Daily', range, categories, 'daily');
      this.buildPeriodSheet(workbook, 'Weekly', range, categories, 'weekly');
      this.buildPeriodSheet(
        workbook,
        'Fortnightly',
        range,
        categories,
        'fortnightly',
      );
      this.buildPeriodSheet(workbook, 'Monthly', range, categories, 'monthly');
      this.buildPeriodSheet(workbook, 'Yearly', range, categories, 'yearly');
    } else {
      for (const name of [
        'Daily',
        'Weekly',
        'Fortnightly',
        'Monthly',
        'Yearly',
      ]) {
        const ws = workbook.addWorksheet(name);
        ws.addRow(['No transactions in range']);
      }
    }

    this.buildWalletsSheet(workbook, transactions);

    this.autoFitAllSheets(workbook);

    const buffer = await workbook.xlsx.writeBuffer();
    return buffer as Buffer;
  }

  /* ── Auto-fit column widths ───────────────────────────────── */

  private autoFitAllSheets(workbook: ExcelJS.Workbook): void {
    workbook.eachSheet((sheet) => {
      sheet.columns.forEach((column) => {
        let maxLength = column.header ? column.header.toString().length : 8;
        column.eachCell?.({ includeEmpty: false }, (cell) => {
          const val = cell.text || '';
          if (val.length > maxLength) maxLength = val.length;
        });
        column.width = Math.min(Math.max(maxLength * 1.2 + 2, 8), 50);
      });
    });
  }

  /* ── Data fetching ────────────────────────────────────────── */

  private async fetchTransactions(
    userId: string,
    startDate?: Date,
    endDate?: Date,
  ): Promise<TransactionWithCategory[]> {
    const where: Prisma.TransactionWhereInput = {
      userId,
      deletedAt: null,
    };

    if (startDate || endDate) {
      where.transactionDate = {
        ...(startDate && { gte: startDate }),
        ...(endDate && { lte: endDate }),
      };
    }

    return this.prisma.transaction.findMany({
      where,
      take: ExportService.ROW_LIMIT,
      include: { category: { select: { name: true } } },
      orderBy: { transactionDate: 'asc' },
    });
  }

  /* ── Sheet 1: All Transactions (raw data) ─────────────────── */

  private buildAllTransactionsSheet(
    wb: ExcelJS.Workbook,
    txs: TransactionWithCategory[],
  ) {
    const ws = wb.addWorksheet('All Transactions');
    ws.columns = [
      { header: 'Date', key: 'date', width: 12 },
      { header: 'Type', key: 'type', width: 24 },
      { header: 'Description', key: 'description', width: 30 },
      { header: 'Category', key: 'category', width: 20 },
      { header: 'Original Amount', key: 'originalAmount', width: 16 },
      { header: 'Original Currency', key: 'originalCurrency', width: 16 },
      { header: 'Base Amount', key: 'baseAmount', width: 14 },
      { header: 'Exchange Rate', key: 'exchangeRate', width: 14 },
      { header: 'Rate Source', key: 'rateSource', width: 14 },
      { header: 'UUID', key: 'uuid', width: 38 },
    ];
    this.styleHeaderRow(ws);

    for (const tx of txs) {
      ws.addRow({
        date: this.fmtDate(tx.transactionDate),
        type: tx.transactionType,
        description: tx.note ?? '',
        category: tx.category?.name ?? '',
        originalAmount: Number(tx.originalAmount),
        originalCurrency: tx.originalCurrency,
        baseAmount: Number(tx.amountBase),
        exchangeRate: Number(tx.exchangeRate),
        rateSource: tx.rateSource,
        uuid: tx.id,
      });
    }
  }

  /* ── Sheet 2: Currency Income ──────────────────────────────── */

  private buildCurrencyIncomeSheet(
    wb: ExcelJS.Workbook,
    txs: TransactionWithCategory[],
  ) {
    const ws = wb.addWorksheet('Currency Income');
    ws.columns = [
      { header: 'Date', key: 'date', width: 12 },
      { header: 'Currency', key: 'currency', width: 10 },
      { header: 'Amount', key: 'amount', width: 14 },
      { header: 'Source', key: 'source', width: 24 },
      { header: 'Base Currency Equivalent', key: 'baseEquiv', width: 22 },
      { header: 'UUID', key: 'uuid', width: 38 },
    ];
    this.styleHeaderRow(ws);

    for (const tx of txs) {
      if (tx.transactionType !== 'currency_income') continue;
      ws.addRow({
        date: this.fmtDate(tx.transactionDate),
        currency: tx.originalCurrency,
        amount: Number(tx.originalAmount),
        source: tx.sourceLabel ?? tx.note ?? '',
        baseEquiv: Number(tx.amountBase),
        uuid: tx.id,
      });
    }
  }

  /* ── Sheet 3: Currency Exchanges (one row per pair) ────────── */

  private buildCurrencyExchangesSheet(
    wb: ExcelJS.Workbook,
    txs: TransactionWithCategory[],
  ) {
    const ws = wb.addWorksheet('Currency Exchanges');
    ws.columns = [
      { header: 'Date', key: 'date', width: 12 },
      { header: 'From Currency', key: 'fromCurrency', width: 14 },
      { header: 'From Amount', key: 'fromAmount', width: 14 },
      { header: 'To Currency', key: 'toCurrency', width: 12 },
      { header: 'To Amount', key: 'toAmount', width: 12 },
      { header: 'Rate', key: 'rate', width: 12 },
      { header: 'Rate Source', key: 'rateSource', width: 14 },
      { header: 'Note', key: 'note', width: 24 },
      { header: 'UUID', key: 'uuid', width: 38 },
    ];
    this.styleHeaderRow(ws);

    const pairs = new Map<
      string,
      { out?: TransactionWithCategory; in?: TransactionWithCategory }
    >();

    for (const tx of txs) {
      if (!tx.exchangeEventId) continue;
      if (
        tx.transactionType !== 'currency_exchange_out' &&
        tx.transactionType !== 'currency_exchange_in'
      ) {
        continue;
      }
      const entry = pairs.get(tx.exchangeEventId) ?? {};
      if (tx.transactionType === 'currency_exchange_out') entry.out = tx;
      else entry.in = tx;
      pairs.set(tx.exchangeEventId, entry);
    }

    for (const [eventId, pair] of pairs) {
      const ref = pair.out ?? pair.in!;
      ws.addRow({
        date: this.fmtDate(ref.transactionDate),
        fromCurrency: pair.out?.originalCurrency ?? '',
        fromAmount: pair.out ? Number(pair.out.originalAmount) : '',
        toCurrency: pair.in?.originalCurrency ?? '',
        toAmount: pair.in ? Number(pair.in.originalAmount) : '',
        rate: Number(ref.exchangeRate),
        rateSource: ref.rateSource,
        note: ref.note ?? '',
        uuid: eventId,
      });
    }
  }

  /* ── Sheets 4-8: Period summaries (SUMIFS formula-driven) ──── */

  private buildPeriodSheet(
    wb: ExcelJS.Workbook,
    name: string,
    range: { start: Date; end: Date },
    categories: string[],
    period: 'daily' | 'weekly' | 'fortnightly' | 'monthly' | 'yearly',
  ) {
    const ws = wb.addWorksheet(name);
    const periods = this.generatePeriods(range, period);
    const singleCol = period === 'daily';
    const AT = ExportService.AT;

    const headers = singleCol
      ? ['Date', 'Total', ...categories]
      : ['Period Start', 'Period End', 'Total', ...categories];
    ws.addRow(headers);
    this.styleHeaderRow(ws);
    ws.getColumn(1).width = 12;
    if (!singleCol) ws.getColumn(2).width = 12;

    for (let i = 0; i < periods.length; i++) {
      const r = i + 2; // row number (1-indexed, header is row 1)
      const row = ws.getRow(r);

      if (singleCol) {
        row.getCell(1).value = periods[i].start;

        row.getCell(2).value = {
          formula: `SUMIFS(${AT}!G:G,${AT}!A:A,A${r},${AT}!B:B,"expense")`,
        };

        for (let c = 0; c < categories.length; c++) {
          const cat = this.escExcel(categories[c]);
          row.getCell(c + 3).value = {
            formula:
              `SUMIFS(${AT}!G:G,${AT}!A:A,A${r},` +
              `${AT}!B:B,"expense",${AT}!D:D,"${cat}")`,
          };
        }
      } else {
        row.getCell(1).value = periods[i].start;
        row.getCell(2).value = periods[i].end;

        row.getCell(3).value = {
          formula:
            `SUMIFS(${AT}!G:G,${AT}!A:A,">="&A${r},` +
            `${AT}!A:A,"<="&B${r},${AT}!B:B,"expense")`,
        };

        for (let c = 0; c < categories.length; c++) {
          const cat = this.escExcel(categories[c]);
          row.getCell(c + 4).value = {
            formula:
              `SUMIFS(${AT}!G:G,${AT}!A:A,">="&A${r},` +
              `${AT}!A:A,"<="&B${r},${AT}!B:B,"expense",${AT}!D:D,"${cat}")`,
          };
        }
      }

      row.commit();
    }
  }

  /* ── Sheet 9: Wallets ──────────────────────────────────────── */

  private buildWalletsSheet(
    wb: ExcelJS.Workbook,
    txs: TransactionWithCategory[],
  ) {
    const ws = wb.addWorksheet('Wallets');
    ws.columns = [
      { header: 'Currency', key: 'currency', width: 12 },
      { header: 'Total Income', key: 'income', width: 16 },
      { header: 'Total Spent', key: 'spent', width: 16 },
      { header: 'Net Exchanged', key: 'exchanged', width: 16 },
      { header: 'Running Balance', key: 'balance', width: 18 },
    ];
    this.styleHeaderRow(ws);

    const currencies = [
      ...new Set(txs.map((tx) => tx.originalCurrency)),
    ].sort((a, b) => a.localeCompare(b));
    const AT = ExportService.AT;

    for (let i = 0; i < currencies.length; i++) {
      const r = i + 2;
      const row = ws.getRow(r);

      row.getCell(1).value = currencies[i];

      row.getCell(2).value = {
        formula: `SUMIFS(${AT}!E:E,${AT}!F:F,A${r},${AT}!B:B,"currency_income")`,
      };

      row.getCell(3).value = {
        formula: `SUMIFS(${AT}!E:E,${AT}!F:F,A${r},${AT}!B:B,"expense")`,
      };

      row.getCell(4).value = {
        formula:
          `SUMIFS(${AT}!E:E,${AT}!F:F,A${r},${AT}!B:B,"currency_exchange_in")` +
          `-SUMIFS(${AT}!E:E,${AT}!F:F,A${r},${AT}!B:B,"currency_exchange_out")`,
      };

      row.getCell(5).value = { formula: `B${r}-C${r}+D${r}` };

      row.commit();
    }
  }

  /* ── Helpers ──────────────────────────────────────────────── */

  private extractExpenseCategories(
    txs: TransactionWithCategory[],
  ): string[] {
    const names = new Set<string>();
    for (const tx of txs) {
      if (tx.transactionType === 'expense' && tx.category?.name) {
        names.add(tx.category.name);
      }
    }
    return [...names].sort((a, b) => a.localeCompare(b));
  }

  private resolveRange(
    txs: TransactionWithCategory[],
    startDate?: Date,
    endDate?: Date,
  ): { start: Date; end: Date } | null {
    if (txs.length === 0 && !startDate && !endDate) return null;

    const timestamps = txs.map((tx) => tx.transactionDate.getTime());
    const minTx = timestamps.length
      ? new Date(Math.min(...timestamps))
      : new Date();
    const maxTx = timestamps.length
      ? new Date(Math.max(...timestamps))
      : new Date();

    return {
      start: startDate ?? minTx,
      end: endDate ?? maxTx,
    };
  }

  private generatePeriods(
    range: { start: Date; end: Date },
    period: 'daily' | 'weekly' | 'fortnightly' | 'monthly' | 'yearly',
  ): Period[] {
    const result: Period[] = [];
    const sY = range.start.getUTCFullYear();
    const sM = range.start.getUTCMonth();
    const sD = range.start.getUTCDate();
    const end = range.end;

    switch (period) {
      case 'daily': {
        const d = this.utc(sY, sM, sD);
        while (d <= end) {
          const s = this.fmtDate(d);
          result.push({ start: s, end: s });
          d.setUTCDate(d.getUTCDate() + 1);
        }
        break;
      }

      case 'weekly':
      case 'fortnightly': {
        const step = period === 'weekly' ? 7 : 14;
        const d = this.utc(sY, sM, sD);
        const dow = d.getUTCDay(); // 0=Sun … 6=Sat
        d.setUTCDate(d.getUTCDate() - ((dow + 6) % 7)); // roll back to Monday

        while (d <= end) {
          const pEnd = new Date(d);
          pEnd.setUTCDate(pEnd.getUTCDate() + step - 1);
          result.push({
            start: this.fmtDate(d),
            end: this.fmtDate(pEnd),
          });
          d.setUTCDate(d.getUTCDate() + step);
        }
        break;
      }

      case 'monthly': {
        let y = sY;
        let m = sM;
        while (this.utc(y, m, 1) <= end) {
          const mStart = this.utc(y, m, 1);
          const mEnd = this.utc(y, m + 1, 0); // last day of month
          result.push({
            start: this.fmtDate(mStart),
            end: this.fmtDate(mEnd),
          });
          m++;
          if (m > 11) {
            y++;
            m = 0;
          }
        }
        break;
      }

      case 'yearly': {
        const endY = end.getUTCFullYear();
        for (let y = sY; y <= endY; y++) {
          result.push({
            start: this.fmtDate(this.utc(y, 0, 1)),
            end: this.fmtDate(this.utc(y, 11, 31)),
          });
        }
        break;
      }
    }

    return result;
  }

  private utc(year: number, month: number, day: number): Date {
    return new Date(Date.UTC(year, month, day));
  }

  private fmtDate(d: Date): string {
    return d.toISOString().slice(0, 10);
  }

  /** Escape double-quotes inside a string used in an Excel formula literal. */
  private escExcel(value: string): string {
    return value.replaceAll('"', '""');
  }

  private styleHeaderRow(ws: ExcelJS.Worksheet) {
    const row = ws.getRow(1);
    row.font = { bold: true };
    row.alignment = { vertical: 'middle' };
  }
}
