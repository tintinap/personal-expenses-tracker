import { Module } from '@nestjs/common';
import { ExpensesRepository } from './repositories/expenses.repository';
import { ExpensesService } from './services/expenses.service';
import { ExpensesController } from './controllers/expenses.controller';

@Module({
  controllers: [ExpensesController],
  providers: [ExpensesRepository, ExpensesService],
  exports: [ExpensesService],
})
export class ExpensesModule {}
