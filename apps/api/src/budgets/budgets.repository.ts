import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';

@Injectable()
export class BudgetsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(userId: string) {
    return this.prisma.budget.findMany({
      where: { userId },
      orderBy: [{ scopeType: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async findOne(id: string, userId: string) {
    return this.prisma.budget.findFirstOrThrow({
      where: { id, userId },
    });
  }

  async create(data: Prisma.BudgetUncheckedCreateInput) {
    return this.prisma.budget.create({ data });
  }

  async update(id: string, userId: string, data: Prisma.BudgetUpdateInput) {
    return this.prisma.budget.update({
      where: { id, userId },
      data,
    });
  }

  async delete(id: string, userId: string): Promise<void> {
    await this.prisma.budget.delete({
      where: { id, userId },
    });
  }
}
