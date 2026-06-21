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
      where: { userId, isActive: true },
    });

    for (const budget of activeBudgets) {
      const start = budget.startDate;
      const end = budget.endDate || new Date();

      // Build the category filter based on scopeType
      let categoryFilter: object | undefined;
      if (budget.scopeType === 'include' && budget.categoryIds) {
        const ids: string[] = this.parseCategoryIds(budget.categoryIds);
        if (ids.length > 0) {
          categoryFilter = { categoryId: { in: ids } };
        }
      } else if (budget.scopeType === 'exclude' && budget.categoryIds) {
        const ids: string[] = this.parseCategoryIds(budget.categoryIds);
        if (ids.length > 0) {
          categoryFilter = { NOT: { categoryId: { in: ids } } };
        }
      }
      // scopeType === 'all' → no category filter

      const spendResult = await this.prisma.transaction.aggregate({
        _sum: { amountBase: true },
        where: {
          userId,
          transactionType: 'expense',
          originalCurrency: budget.currency,
          transactionDate: { gte: start, lte: end },
          deletedAt: null,
          ...categoryFilter,
        },
      });

      const spent = Number(spendResult._sum?.amountBase || 0);
      const limit = Number(budget.amountBase);
      const percentage = limit > 0 ? spent / limit : 0;

      const title = budget.name?.trim()
        ? `${budget.name} Alert`
        : budget.scopeType === 'all'
          ? 'Global Budget Alert'
          : 'Category Budget Alert';

      if (percentage >= 1.0 && !budget.notified100) {
        await this.notifications.sendPushNotification(
          userId,
          title,
          `You have exceeded your ${budget.currency} limit of ${limit.toFixed(2)}.`,
        );
        await this.prisma.budget.update({
          where: { id: budget.id },
          data: { notified100: true, notified75: true, notified90: true },
        });
      } else if (percentage >= 0.9 && percentage < 1.0 && !budget.notified90) {
        await this.notifications.sendPushNotification(
          userId,
          title,
          `You have used ${(percentage * 100).toFixed(0)}% of your ${budget.currency} ${limit.toFixed(2)} budget.`,
        );
        await this.prisma.budget.update({
          where: { id: budget.id },
          data: { notified90: true, notified75: true },
        });
      } else if (percentage >= 0.75 && percentage < 0.9 && !budget.notified75) {
        await this.notifications.sendPushNotification(
          userId,
          title,
          `You have used ${(percentage * 100).toFixed(0)}% of your ${budget.currency} ${limit.toFixed(2)} budget.`,
        );
        await this.prisma.budget.update({
          where: { id: budget.id },
          data: { notified75: true },
        });
      }

      // Reset flags if spend drops back below 75% (e.g. after a transaction deletion)
      if (percentage < 0.75 && (budget.notified75 || budget.notified90 || budget.notified100)) {
        await this.prisma.budget.update({
          where: { id: budget.id },
          data: { notified75: false, notified90: false, notified100: false },
        });
      }
    }
  }

  private parseCategoryIds(json: string): string[] {
    try {
      const parsed = JSON.parse(json);
      return Array.isArray(parsed) ? parsed.filter((v) => typeof v === 'string') : [];
    } catch {
      this.logger.warn(`Failed to parse categoryIds JSON: ${json}`);
      return [];
    }
  }
}
