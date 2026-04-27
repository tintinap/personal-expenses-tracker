import { Injectable } from '@nestjs/common';
import { TransactionsRepository } from './transactions.repository';
import { CreateTransactionDto, UpdateTransactionDto } from './dto/transaction.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class TransactionsService {
  constructor(private readonly repository: TransactionsRepository) {}

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

    return transaction;
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
}
