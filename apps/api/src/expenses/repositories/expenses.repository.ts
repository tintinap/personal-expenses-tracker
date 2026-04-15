import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Expense } from '@prisma/client';
import { CreateExpenseDto, UpdateExpenseDto } from '../models/expense.dto';

@Injectable()
export class ExpensesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(): Promise<Expense[]> {
    return this.prisma.expense.findMany({
      orderBy: { date: 'desc' },
    });
  }

  async findOne(id: string): Promise<Expense | null> {
    return this.prisma.expense.findUnique({ where: { id } });
  }

  async create(dto: CreateExpenseDto): Promise<Expense> {
    return this.prisma.expense.create({
      data: {
        id: dto.id,
        amount: dto.amount,
        date: dto.date,
        categoryIndex: dto.categoryIndex,
        note: dto.note ?? null,
        isIncome: dto.isIncome ?? false,
        currencyCode: dto.currencyCode ?? 'USD',
      },
    });
  }

  async update(id: string, dto: UpdateExpenseDto): Promise<Expense | null> {
    return this.prisma.expense.update({
      where: { id },
      data: dto,
    });
  }

  async remove(id: string): Promise<void> {
    await this.prisma.expense.delete({ where: { id } });
  }

  async clearAll(): Promise<void> {
    await this.prisma.expense.deleteMany();
  }
}
