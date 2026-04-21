import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SyncRepository {
  constructor(private readonly prisma: PrismaService) {}

  async pullRecords(userId: string, lastSync: Date) {
    const [transactions, categories, budgets] = await Promise.all([
      this.prisma.transaction.findMany({
        where: { userId, updatedAt: { gt: lastSync } },
        include: { category: true },
      }),
      this.prisma.category.findMany({
        where: { userId, updatedAt: { gt: lastSync } },
      }),
      this.prisma.budget.findMany({
        where: { userId, updatedAt: { gt: lastSync } },
      }),
    ]);
    return { transactions, categories, budgets };
  }

  async findTransactionById(recordId: string) {
    return this.prisma.transaction.findUnique({
      where: { id: recordId },
    });
  }

  async createTransaction(data: any) {
    return this.prisma.transaction.create({ data });
  }

  async updateTransaction(recordId: string, data: any) {
    return this.prisma.transaction.update({
      where: { id: recordId },
      data,
    });
  }

  async softDeleteTransaction(recordId: string) {
    return this.prisma.transaction.update({
      where: { id: recordId },
      data: { deletedAt: new Date() },
    });
  }

  async logConflict(data: any) {
    return this.prisma.conflictLog.create({ data });
  }

  async findCategoryById(recordId: string) {
    return this.prisma.category.findUnique({
      where: { id: recordId },
    });
  }

  async createCategory(data: any) {
    return this.prisma.category.create({ data });
  }

  async updateCategory(recordId: string, data: any) {
    return this.prisma.category.update({
      where: { id: recordId },
      data,
    });
  }

  async deleteCategory(recordId: string) {
    return this.prisma.category.delete({ where: { id: recordId } });
  }

  async findBudgetById(recordId: string) {
    return this.prisma.budget.findUnique({
      where: { id: recordId },
    });
  }

  async createBudget(data: any) {
    return this.prisma.budget.create({ data });
  }

  async updateBudget(recordId: string, data: any) {
    return this.prisma.budget.update({
      where: { id: recordId },
      data,
    });
  }

  async deleteBudget(recordId: string) {
    return this.prisma.budget.delete({ where: { id: recordId } });
  }
}
