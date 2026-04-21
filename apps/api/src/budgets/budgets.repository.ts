import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, Budget } from '@prisma/client';

@Injectable()
export class BudgetsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(userId: string) {
    return this.prisma.budget.findMany({
      where: { userId },
      include: { category: true },
      orderBy: [{ scope: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async findOne(id: string, userId: string) {
    return this.prisma.budget.findFirstOrThrow({
      where: { id, userId },
      include: { category: true },
    });
  }

  async create(data: Prisma.BudgetUncheckedCreateInput) {
    return this.prisma.budget.create({
      data,
      include: { category: true },
    });
  }

  async update(id: string, userId: string, data: Prisma.BudgetUpdateInput) {
    return this.prisma.budget.update({
      where: { id, userId },
      data,
      include: { category: true },
    });
  }

  async delete(id: string, userId: string): Promise<void> {
    await this.prisma.budget.delete({
      where: { id, userId },
    });
  }
}
