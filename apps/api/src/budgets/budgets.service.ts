import { Injectable } from '@nestjs/common';
import { BudgetsRepository } from './budgets.repository';
import { CreateBudgetDto, UpdateBudgetDto } from './budgets.model';

@Injectable()
export class BudgetsService {
  constructor(private readonly repository: BudgetsRepository) {}

  async findAll(userId: string) {
    return this.repository.findAll(userId);
  }

  async findOne(id: string, userId: string) {
    return this.repository.findOne(id, userId);
  }

  async create(userId: string, data: CreateBudgetDto) {
    return this.repository.create({
      userId,
      name: data.name ?? null,
      scopeType: data.scopeType,
      categoryIds: data.categoryIds ?? null,
      currency: data.currency,
      amountBase: data.amountBase,
      periodType: data.periodType,
      isRecurring: data.isRecurring ?? true,
      startDate: new Date(data.startDate),
      endDate: data.endDate ? new Date(data.endDate) : null,
    });
  }

  async update(id: string, userId: string, data: UpdateBudgetDto) {
    return this.repository.update(id, userId, {
      ...(data.name !== undefined && { name: data.name }),
      ...(data.scopeType && { scopeType: data.scopeType }),
      ...(data.categoryIds !== undefined && { categoryIds: data.categoryIds }),
      ...(data.currency && { currency: data.currency }),
      ...(data.amountBase !== undefined && { amountBase: data.amountBase }),
      ...(data.periodType && { periodType: data.periodType }),
      ...(data.isRecurring !== undefined && { isRecurring: data.isRecurring }),
      ...(data.startDate && { startDate: new Date(data.startDate) }),
      ...(data.endDate !== undefined && {
        endDate: data.endDate ? new Date(data.endDate) : null,
      }),
      ...(data.isActive !== undefined && { isActive: data.isActive }),
    });
  }

  async remove(id: string, userId: string): Promise<void> {
    await this.repository.delete(id, userId);
  }
}
