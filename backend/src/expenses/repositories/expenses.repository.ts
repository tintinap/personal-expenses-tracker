import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Expense } from '../models/expense.entity';
import { CreateExpenseDto, UpdateExpenseDto } from '../models/expense.dto';

@Injectable()
export class ExpensesRepository {
  constructor(
    @InjectRepository(Expense)
    private readonly repository: Repository<Expense>,
  ) {}

  async findAll(): Promise<Expense[]> {
    return this.repository.find({
      order: { date: 'DESC' },
    });
  }

  async findOne(id: string): Promise<Expense | null> {
    return this.repository.findOne({ where: { id } });
  }

  async create(expenseDto: CreateExpenseDto): Promise<Expense> {
    const entity = this.repository.create(expenseDto);
    return this.repository.save(entity);
  }

  async update(id: string, expenseDto: UpdateExpenseDto): Promise<Expense | null> {
    await this.repository.update(id, expenseDto);
    return this.repository.findOne({ where: { id } });
  }

  async remove(id: string): Promise<void> {
    await this.repository.delete(id);
  }

  async clearAll(): Promise<void> {
    await this.repository.clear();
  }
}
