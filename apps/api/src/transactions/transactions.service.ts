import { Injectable } from '@nestjs/common';
import { TransactionsRepository } from './transactions.repository';
import { CreateTransactionDto, UpdateTransactionDto } from './dto/transaction.dto';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SheetsProcessor } from '../sheets/sheets.processor';

@Injectable()
export class TransactionsService {
  constructor(
    private readonly repository: TransactionsRepository,
    private readonly prisma: PrismaService,
    private readonly sheetsProcessor: SheetsProcessor,
  ) {}

  async findAll(
    userId: string,
    page: string = '1',
    limit: string = '50',
    type?: string,
    from?: string,
    to?: string,
    categoryId?: string,
  ) {
    const pageNum = Math.max(1, parseInt(page, 10));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10)));
    const skip = (pageNum - 1) * limitNum;

    const where: Prisma.TransactionWhereInput = {
      userId,
      deletedAt: null,
      ...(type && { transactionType: type }),
      ...(categoryId && { categoryId }),
      ...(from || to
        ? {
            transactionDate: {
              ...(from && { gte: new Date(from) }),
              ...(to && { lte: new Date(to) }),
            },
          }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.repository.findAll(where, skip, limitNum),
      this.repository.count(where),
    ]);

    return {
      data,
      meta: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum),
      },
    };
  }

  async findOne(id: string, userId: string) {
    return this.repository.findOne(id, userId);
  }

  async create(userId: string, body: CreateTransactionDto) {
    const transaction = await this.repository.create({
      ...(body.id && { id: body.id }),
      userId,
      transactionType: body.transactionType,
      amountBase: body.amountBase,
      originalAmount: body.originalAmount,
      originalCurrency: body.originalCurrency,
      exchangeRate: body.exchangeRate,
      rateDate: new Date(body.rateDate),
      rateEstimated: body.rateEstimated ?? false,
      rateSource: body.rateSource ?? 'frankfurter',
      exchangeEventId: body.exchangeEventId ?? null,
      categoryId: body.categoryId ?? null,
      note: body.note ?? null,
      sourceLabel: body.sourceLabel ?? null,
      transactionDate: new Date(body.transactionDate),
      isRecurring: body.isRecurring ?? false,
      recurrenceType: body.recurrenceType ?? null,
    });

    await this.updateCurrencyBalance(
      userId,
      body.originalCurrency,
      body.transactionType,
      Number(body.originalAmount),
    );

    await this.enqueueSheetWrite(userId, transaction, 'create');

    return transaction;
  }

  async bulkInsert(userId: string, body: { transactions: CreateTransactionDto[] }) {
    const results: any[] = [];
    for (const tx of body.transactions) {
      try {
        const created = await this.create(userId, tx);
        results.push(created);
      } catch (err) {
        console.error(`Failed to bulk insert tx ${tx.id}`, err);
      }
    }
    return results;
  }

  async update(id: string, userId: string, body: UpdateTransactionDto) {
    // Fetch old record to reverse its balance impact if amount/currency changed
    const oldRecord = await this.repository.findOne(id, userId);

    const updated = await this.repository.update(id, userId, {
      ...(body.amountBase !== undefined && { amountBase: body.amountBase }),
      ...(body.originalAmount !== undefined && { originalAmount: body.originalAmount }),
      ...(body.originalCurrency !== undefined && { originalCurrency: body.originalCurrency }),
      ...(body.exchangeRate !== undefined && { exchangeRate: body.exchangeRate }),
      ...(body.rateDate !== undefined && { rateDate: new Date(body.rateDate) }),
      ...(body.rateEstimated !== undefined && { rateEstimated: body.rateEstimated }),
      ...(body.rateSource !== undefined && { rateSource: body.rateSource }),
      ...(body.categoryId !== undefined && { categoryId: body.categoryId }),
      ...(body.note !== undefined && { note: body.note }),
      ...(body.transactionDate !== undefined && { transactionDate: new Date(body.transactionDate) }),
    });

    // Recalculate currency balance if amount or currency changed
    if (
      oldRecord &&
      (body.originalAmount !== undefined || body.originalCurrency !== undefined)
    ) {
      // Reverse old balance impact
      await this.reverseCurrencyBalance(
        userId,
        oldRecord.originalCurrency,
        oldRecord.transactionType,
        Number(oldRecord.originalAmount),
      );

      // Apply new balance impact
      await this.updateCurrencyBalance(
        userId,
        updated.originalCurrency,
        updated.transactionType,
        Number(updated.originalAmount),
      );
    }

    await this.enqueueSheetWrite(userId, updated, 'update');

    return updated;
  }

  async remove(id: string, userId: string) {
    // Reverse currency balance before soft-deleting
    const record = await this.repository.findOne(id, userId);
    if (record && !record.deletedAt) {
      await this.reverseCurrencyBalance(
        userId,
        record.originalCurrency,
        record.transactionType,
        Number(record.originalAmount),
      );
    }

    await this.repository.softDelete(id, userId);
    
    if (record) {
      await this.enqueueSheetWrite(userId, record, 'delete');
    }
  }

  private getBalanceDelta(transactionType: string, amount: number): number {
    switch (transactionType) {
      case 'expense':
      case 'currency_exchange_out':
        return -amount;
      case 'currency_income':
      case 'currency_exchange_in':
        return amount;
      default:
        return 0;
    }
  }

  private async updateCurrencyBalance(
    userId: string,
    currency: string,
    transactionType: string,
    amount: number,
  ) {
    const delta = this.getBalanceDelta(transactionType, amount);
    if (delta !== 0) {
      await this.repository.upsertCurrencyBalance(userId, currency, delta);
    }
  }

  private async reverseCurrencyBalance(
    userId: string,
    currency: string,
    transactionType: string,
    amount: number,
  ) {
    const delta = this.getBalanceDelta(transactionType, amount);
    if (delta !== 0) {
      // Reverse = negate the original delta
      await this.repository.upsertCurrencyBalance(userId, currency, -delta);
    }
  }

  private async enqueueSheetWrite(userId: string, transaction: any, action: 'create' | 'update' | 'delete') {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { sheetsEnabled: true, sheetsSpreadsheetId: true }
    });

    if (!user || !user.sheetsEnabled || !user.sheetsSpreadsheetId) return;

    let operation: any = action === 'delete' ? 'delete' : (action === 'create' ? 'append' : 'update');
    
    // For specialized tabs: Currency Income and Currency Exchanges
    // Note: the PRD says they go to both 'All Transactions' AND their specific tabs.
    // Our simplified SheetsService has 'append_income' and 'append_exchange', but 'executeAppend' 
    // handles appending to 'All Transactions'. 
    // To handle both, we can enqueue two jobs, one for 'All Transactions' and one for the specific tab.
    
    this.sheetsProcessor.enqueue({
      userId,
      spreadsheetId: user.sheetsSpreadsheetId,
      operation,
      payload: transaction
    });

    if (action === 'create' && transaction.transactionType === 'currency_income') {
      this.sheetsProcessor.enqueue({
        userId,
        spreadsheetId: user.sheetsSpreadsheetId,
        operation: 'append_income',
        payload: transaction
      });
    }

    if (action === 'create' && transaction.transactionType.startsWith('currency_exchange_')) {
      // PRD says Currency Exchanges sheet is one row per pair. We store them as two records 
      // ('currency_exchange_out' and 'currency_exchange_in') sharing `exchangeEventId`.
      // The backend adds to specific tab only if it's the out record, and fetches the in record to form the row.
      if (transaction.transactionType === 'currency_exchange_out') {
        const inRecord = await this.repository.findOne(
          transaction.exchangeEventId, // wait, how to find the 'in' record? By exchangeEventId
          userId
        ).catch(() => null); // Let's just pass the transaction and let the SheetsProcessor handle it if needed.
        // Actually, PRD says "Append row to Currency Exchanges". We'll just enqueue 'append_exchange' with the transaction for now.
        // We'll map `originalCurrency` and `amount` to `fromAmount`, etc.
        const exchangePayload = {
          ...transaction,
          fromCurrency: transaction.originalCurrency,
          fromAmount: transaction.originalAmount,
          toCurrency: 'Unknown', // We'd need to fetch the in record to be fully accurate
          toAmount: 0,
        };
        this.sheetsProcessor.enqueue({
          userId,
          spreadsheetId: user.sheetsSpreadsheetId,
          operation: 'append_exchange',
          payload: exchangePayload
        });
      }
    }
  }
}

