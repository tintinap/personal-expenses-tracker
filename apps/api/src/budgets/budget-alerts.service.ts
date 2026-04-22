import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class BudgetAlertsService {
  private readonly logger = new Logger(BudgetAlertsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async evaluateUserBudgets(userId: string) {
    const activeBudgets = await this.prisma.budget.findMany({
      where: {
        userId,
        isActive: true,
      },
      include: {
        category: true,
      },
    });

    for (const budget of activeBudgets) {
      // Find sum of expenses strictly in the budget period
      const start = budget.startDate;
      const end = budget.endDate || new Date();

      let spendResult;

      if (budget.scope === 'global') {
        spendResult = await this.prisma.transaction.aggregate({
          _sum: { amountBase: true },
          where: {
            userId,
            transactionType: 'expense',
            transactionDate: { gte: start, lte: end },
          },
        });
      } else if (budget.scope === 'category' && budget.categoryId) {
        spendResult = await this.prisma.transaction.aggregate({
          _sum: { amountBase: true },
          where: {
            userId,
            transactionType: 'expense',
            categoryId: budget.categoryId,
            transactionDate: { gte: start, lte: end },
          },
        });
      }

      const spent = Number(spendResult?._sum?.amountBase || 0);
      const limit = Number(budget.amountBase);
      const percentage = spent / limit;

      const title = budget.scope === 'global' ? 'Global Budget Alert' : `${budget.category?.name} Budget Alert`;

      if (percentage >= 1.0 && !budget.notified100) {
        await this.notifications.sendPushNotification(
          userId,
          title,
          `You have exceeded your limit of ${limit.toFixed(2)}.`,
        );
        await this.prisma.budget.update({
          where: { id: budget.id },
          data: { notified100: true, notified80: true }, // also set 80 to true to avoid double sending
        });
      } else if (percentage >= 0.8 && percentage < 1.0 && !budget.notified80) {
        await this.notifications.sendPushNotification(
          userId,
          title,
          `You have used ${(percentage * 100).toFixed(0)}% of your ${limit.toFixed(2)} budget.`,
        );
        await this.prisma.budget.update({
          where: { id: budget.id },
          data: { notified80: true },
        });
      }

      // If a new cycle starts and we are below 80% again, reset the flags.
      // (Usually this is better done by cron creating new budgets, or rotating, 
      // but if the budget is long-running and expenses are deleted, we check here)
      if (percentage < 0.8 && (budget.notified80 || budget.notified100)) {
        await this.prisma.budget.update({
          where: { id: budget.id },
          data: { notified80: false, notified100: false },
        });
      }
    }
  }
}
