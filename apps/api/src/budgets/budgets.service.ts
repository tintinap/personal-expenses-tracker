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
      scope: data.scope,
      categoryId: data.categoryId || null,
      amountBase: data.amountBase,
      periodType: data.periodType,
      startDate: new Date(data.startDate),
      endDate: data.endDate ? new Date(data.endDate) : null,
    });
  }

  async update(id: string, userId: string, data: UpdateBudgetDto) {
    return this.repository.update(id, userId, {
      ...(data.amountBase !== undefined && { amountBase: data.amountBase }),
      ...(data.periodType && { periodType: data.periodType }),
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
