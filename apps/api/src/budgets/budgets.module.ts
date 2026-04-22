import { Module } from '@nestjs/common';
import { BudgetsController } from './budgets.controller';
import { BudgetsService } from './budgets.service';
import { BudgetsRepository } from './budgets.repository';
import { BudgetAlertsService } from './budget-alerts.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [BudgetsController],
  providers: [BudgetsService, BudgetsRepository, BudgetAlertsService],
  exports: [BudgetAlertsService],
})
export class BudgetsModule {}
