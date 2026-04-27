import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, Transaction } from '@prisma/client';

@Injectable()
export class TransactionsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(where: Prisma.TransactionWhereInput, skip: number, take: number) {
    return this.prisma.transaction.findMany({
      where,
      orderBy: { transactionDate: 'desc' },
      skip,
      take,
      include: { category: true },
    });
  }

  async count(where: Prisma.TransactionWhereInput): Promise<number> {
    return this.prisma.transaction.count({ where });
  }

  async findOne(id: string, userId: string): Promise<Transaction | null> {
    return this.prisma.transaction.findFirstOrThrow({
      where: { id, userId, deletedAt: null },
      include: { category: true },
    });
  }

  async create(data: Prisma.TransactionUncheckedCreateInput) {
    return this.prisma.transaction.create({
      data,
      include: { category: true },
    });
  }

  async update(id: string, userId: string, data: Prisma.TransactionUpdateInput) {
    return this.prisma.transaction.update({
      where: { id, userId },
      data,
      include: { category: true },
    });
  }

  async softDelete(id: string, userId: string): Promise<void> {
    await this.prisma.transaction.update({
      where: { id, userId },
      data: { deletedAt: new Date() },
    });
  }

  async upsertCurrencyBalance(userId: string, currency: string, delta: number) {
    await this.prisma.currencyBalance.upsert({
      where: { userId_currency: { userId, currency } },
      create: { userId, currency, balance: delta },
      update: { balance: { increment: delta } },
    });
  }
}
