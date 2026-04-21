import { Injectable, Logger } from '@nestjs/common';
import { SyncRepository } from './sync.repository';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(private readonly repository: SyncRepository) {}

  /**
   * Process push from mobile: handle insert/update/delete for each record.
   * Uses last-write-wins conflict resolution based on updatedAt timestamp.
   */
  async processPush(
    userId: string,
    records: Array<{
      recordType: string;
      recordId: string;
      operation: string;
      payload: any;
    }>,
  ) {
    let accepted = 0;
    const conflicts: any[] = [];

    for (const record of records) {
      try {
        switch (record.recordType) {
          case 'transaction':
            await this.syncTransaction(userId, record);
            break;
          case 'category':
            await this.syncCategory(userId, record);
            break;
          case 'budget':
            await this.syncBudget(userId, record);
            break;
          default:
            this.logger.warn(`Unknown record type: ${record.recordType}`);
            continue;
        }
        accepted++;
      } catch (error) {
        this.logger.error(
          `Sync error for ${record.recordType}/${record.recordId}: ${error.message}`,
        );
        conflicts.push({
          recordType: record.recordType,
          recordId: record.recordId,
          error: error.message,
        });
      }
    }

    return {
      accepted,
      conflicts,
      serverTimestamp: new Date().toISOString(),
    };
  }

  /**
   * Process pull: return all records updated after the given timestamp.
   */
  async processPull(userId: string, lastSync: Date) {
    const data = await this.repository.pullRecords(userId, lastSync);

    return {
      ...data,
      serverTimestamp: new Date().toISOString(),
      conflicts: [],
    };
  }

  private async syncTransaction(
    userId: string,
    record: { recordId: string; operation: string; payload: any },
  ) {
    const { recordId, operation, payload } = record;

    switch (operation) {
      case 'insert': {
        // UUID deduplication — check if record already exists
        const existing = await this.repository.findTransactionById(recordId);
        if (existing) return; // Already synced

        await this.repository.createTransaction({
          id: recordId,
          userId,
          transactionType: payload.transactionType,
          amountBase: payload.amountBase,
          originalAmount: payload.originalAmount,
          originalCurrency: payload.originalCurrency,
          exchangeRate: payload.exchangeRate,
          rateDate: new Date(payload.rateDate),
          rateEstimated: payload.rateEstimated || false,
          rateSource: payload.rateSource || 'frankfurter',
          exchangeEventId: payload.exchangeEventId || null,
          categoryId: payload.categoryId || null,
          note: payload.note || null,
          sourceLabel: payload.sourceLabel || null,
          transactionDate: new Date(payload.transactionDate),
          isRecurring: payload.isRecurring || false,
          recurrenceType: payload.recurrenceType || null,
        });
        break;
      }

      case 'update': {
        // Last-write-wins: compare updatedAt
        const existing = await this.repository.findTransactionById(recordId);

        if (existing) {
          const clientUpdated = new Date(payload.updatedAt);
          if (clientUpdated > existing.updatedAt) {
            await this.repository.updateTransaction(recordId, {
              amountBase: payload.amountBase,
              originalAmount: payload.originalAmount,
              originalCurrency: payload.originalCurrency,
              exchangeRate: payload.exchangeRate,
              rateDate: new Date(payload.rateDate),
              rateEstimated: payload.rateEstimated || false,
              rateSource: payload.rateSource || 'frankfurter',
              categoryId: payload.categoryId || null,
              note: payload.note || null,
              transactionDate: new Date(payload.transactionDate),
            });
          } else {
            // Server version is newer — log conflict
            await this.repository.logConflict({
              userId,
              recordType: 'transaction',
              recordId,
              winningVersion: existing as any,
              losingVersion: payload,
            });
          }
        }
        break;
      }

      case 'delete': {
        await this.repository.softDeleteTransaction(recordId);
        break;
      }
    }
  }

  private async syncCategory(
    userId: string,
    record: { recordId: string; operation: string; payload: any },
  ) {
    const { recordId, operation, payload } = record;

    switch (operation) {
      case 'insert': {
        const existing = await this.repository.findCategoryById(recordId);
        if (existing) return;

        await this.repository.createCategory({
          id: recordId,
          userId,
          name: payload.name,
          colourHex: payload.colourHex,
          isDefault: payload.isDefault || false,
          isHidden: payload.isHidden || false,
          sortOrder: payload.sortOrder || 0,
        });
        break;
      }

      case 'update': {
        await this.repository.updateCategory(recordId, {
          name: payload.name,
          colourHex: payload.colourHex,
          isHidden: payload.isHidden,
        });
        break;
      }

      case 'delete': {
        await this.repository.deleteCategory(recordId);
        break;
      }
    }
  }

  private async syncBudget(
    userId: string,
    record: { recordId: string; operation: string; payload: any },
  ) {
    const { recordId, operation, payload } = record;

    switch (operation) {
      case 'insert': {
        const existing = await this.repository.findBudgetById(recordId);
        if (existing) return;

        await this.repository.createBudget({
          id: recordId,
          userId,
          scope: payload.scope,
          categoryId: payload.categoryId || null,
          amountBase: payload.amountBase,
          periodType: payload.periodType,
          startDate: new Date(payload.startDate),
          endDate: payload.endDate ? new Date(payload.endDate) : null,
          isActive: payload.isActive ?? true,
        });
        break;
      }

      case 'update': {
        await this.repository.updateBudget(recordId, {
          amountBase: payload.amountBase,
          periodType: payload.periodType,
          startDate: new Date(payload.startDate),
          endDate: payload.endDate ? new Date(payload.endDate) : null,
          isActive: payload.isActive,
          notified80: payload.notified80 ?? false,
          notified100: payload.notified100 ?? false,
        });
        break;
      }

      case 'delete': {
        await this.repository.deleteBudget(recordId);
        break;
      }
    }
  }
}
