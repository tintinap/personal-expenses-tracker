import { Injectable } from '@nestjs/common';
import { ExpensesRepository } from '../repositories/expenses.repository';
import { Expense } from '../models/expense.entity';
import { CreateExpenseDto, UpdateExpenseDto } from '../models/expense.dto';

@Injectable()
export class ExpensesService {
  constructor(private readonly expensesRepository: ExpensesRepository) {}

  async findAll(): Promise<Expense[]> {
    return this.expensesRepository.findAll();
  }

  async findOne(id: string): Promise<Expense | null> {
    return this.expensesRepository.findOne(id);
  }

  async create(createExpenseDto: CreateExpenseDto): Promise<Expense> {
    return this.expensesRepository.create(createExpenseDto);
  }

  async update(id: string, updateExpenseDto: UpdateExpenseDto): Promise<Expense | null> {
    return this.expensesRepository.update(id, updateExpenseDto);
  }

  async remove(id: string): Promise<void> {
    return this.expensesRepository.remove(id);
  }

  async clearAll(): Promise<void> {
    return this.expensesRepository.clearAll();
  }
}
