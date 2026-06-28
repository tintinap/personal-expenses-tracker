import { Injectable, Logger } from '@nestjs/common';
import { SheetsService } from './sheets.service';

export interface SheetWriteJob {
  id: string; // job id
  userId: string;
  spreadsheetId: string;
  operation: 'append' | 'update' | 'delete' | 'append_income' | 'append_exchange';
  payload: any;
  attempts: number;
}

@Injectable()
export class SheetsProcessor {
  private readonly logger = new Logger(SheetsProcessor.name);
  private queue: SheetWriteJob[] = [];
  private isProcessing = false;

  constructor(private readonly sheetsService: SheetsService) {}

  enqueue(job: Omit<SheetWriteJob, 'id' | 'attempts'>) {
    const fullJob: SheetWriteJob = {
      ...job,
      id: Math.random().toString(36).substring(7),
      attempts: 0,
    };
    this.queue.push(fullJob);
    this.logger.debug(`Enqueued Sheet write job ${fullJob.id} for user ${fullJob.userId}`);
    this.processQueue().catch((err) => {
      this.logger.error(`Error processing Sheets queue: ${err.message}`, err.stack);
    });
  }

  private async processQueue() {
    if (this.isProcessing || this.queue.length === 0) return;
    this.isProcessing = true;

    try {
      while (this.queue.length > 0) {
        const job = this.queue[0];
        try {
          await this.processJob(job);
          // Success, remove from queue
          this.queue.shift();
        } catch (error: any) {
          job.attempts++;
          this.logger.error(`Sheet write job ${job.id} failed (attempt ${job.attempts}): ${error.message}`);
          
          if (job.attempts >= 5) {
            this.logger.error(`Sheet write job ${job.id} failed 5 times, discarding.`);
            this.queue.shift();
          } else {
            // Exponential backoff: 1s, 2s, 4s, 8s, 16s
            const backoff = Math.pow(2, job.attempts - 1) * 1000;
            this.logger.log(`Waiting ${backoff}ms before retrying...`);
            await new Promise((resolve) => setTimeout(resolve, backoff));
            // Break out of the loop and let the next call or this loop continue?
            // Since we wait, the loop can just continue to retry the same job.
            // But we don't want to block the thread forever. We can wait here.
          }
        }
      }
    } finally {
      this.isProcessing = false;
    }
  }

  private async processJob(job: SheetWriteJob) {
    switch (job.operation) {
      case 'append':
        await this.sheetsService.executeAppend(job.userId, job.spreadsheetId, job.payload);
        break;
      case 'update':
        await this.sheetsService.executeUpdate(job.userId, job.spreadsheetId, job.payload);
        break;
      case 'delete':
        await this.sheetsService.executeDelete(job.userId, job.spreadsheetId, job.payload.uuid);
        break;
      case 'append_income':
        await this.sheetsService.executeAppendIncome(job.userId, job.spreadsheetId, job.payload);
        break;
      case 'append_exchange':
        await this.sheetsService.executeAppendExchange(job.userId, job.spreadsheetId, job.payload);
        break;
      default:
        this.logger.warn(`Unknown operation ${job.operation}`);
    }
  }
}
