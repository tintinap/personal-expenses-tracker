import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, Category } from '@prisma/client';

@Injectable()
export class CategoriesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(userId: string): Promise<Category[]> {
    return this.prisma.category.findMany({
      where: { userId },
      orderBy: { sortOrder: 'asc' },
    });
  }

  async getMaxSortOrder(userId: string): Promise<number | null> {
    const maxSort = await this.prisma.category.aggregate({
      where: { userId },
      _max: { sortOrder: true },
    });
    return maxSort._max.sortOrder;
  }

  async create(data: Prisma.CategoryUncheckedCreateInput): Promise<Category> {
    return this.prisma.category.create({ data });
  }

  async update(
    id: string,
    userId: string,
    data: Prisma.CategoryUpdateInput,
  ): Promise<Category> {
    return this.prisma.category.update({
      where: { id, userId },
      data,
    });
  }

  async countAssociatedExpenses(id: string, userId: string): Promise<number> {
    return this.prisma.transaction.count({
      where: {
        categoryId: id,
        userId,
        deletedAt: null,
      },
    });
  }

  async delete(id: string, userId: string): Promise<void> {
    await this.prisma.category.delete({
      where: { id, userId },
    });
  }
}
