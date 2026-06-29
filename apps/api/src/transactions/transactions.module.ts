import { Module } from '@nestjs/common';
import { BudgetsModule } from '../budgets/budgets.module';
import { SheetsModule } from '../sheets/sheets.module';
import { TransactionsController } from './transactions.controller';
import { TransactionsService } from './transactions.service';
import { TransactionsRepository } from './transactions.repository';

@Module({
  imports: [BudgetsModule, SheetsModule],
  controllers: [TransactionsController],
  providers: [TransactionsService, TransactionsRepository],
})
export class TransactionsModule {}
