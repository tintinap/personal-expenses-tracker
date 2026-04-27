import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as ExcelJS from 'exceljs';

@Injectable()
export class ExportService {
  private readonly logger = new Logger(ExportService.name);

  constructor(private readonly prisma: PrismaService) {}

  async generateExcel(userId: string, startDate?: Date, endDate?: Date): Promise<Buffer> {
    this.logger.log(`Generating Excel export for user ${userId}`);

    const whereClause: any = { userId };
    if (startDate || endDate) {
      whereClause.transactionDate = {};
      if (startDate) whereClause.transactionDate.gte = startDate;
      if (endDate) whereClause.transactionDate.lte = endDate;
    }

    const transactions = await this.prisma.transaction.findMany({
      where: whereClause,
      take: 50000, // Export hard limit to prevent OOM
      include: {
        category: true,
      },
      orderBy: {
        transactionDate: 'desc',
      },
    });

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Project PET';
    
    // 1. Raw Data Sheet
    const rawSheet = workbook.addWorksheet('Raw Data');
    rawSheet.columns = [
      { header: 'ID', key: 'id', width: 36 },
      { header: 'Date', key: 'date', width: 20 },
      { header: 'Type', key: 'type', width: 15 },
      { header: 'Category', key: 'category', width: 20 },
      { header: 'Amount (Base)', key: 'amountBase', width: 15 },
      { header: 'Original Amount', key: 'originalAmount', width: 15 },
      { header: 'Original Currency', key: 'originalCurrency', width: 15 },
      { header: 'Exchange Rate', key: 'rate', width: 15 },
      { header: 'Note', key: 'note', width: 30 },
    ];

    for (const tx of transactions) {
      rawSheet.addRow({
        id: tx.id,
        date: tx.transactionDate.toISOString().split('T')[0],
        type: tx.transactionType,
        category: tx.category?.name || 'Uncategorized',
        amountBase: tx.amountBase,
        originalAmount: tx.originalAmount,
        originalCurrency: tx.originalCurrency,
        rate: tx.exchangeRate,
        note: tx.note || '',
      });
    }

    // 2. Summary Sheet (Pivot-like)
    const summarySheet = workbook.addWorksheet('Summary');
    summarySheet.columns = [
      { header: 'Category', key: 'category', width: 20 },
      { header: 'Total Spent', key: 'total', width: 15 },
    ];

    const categorySums: Record<string, number> = {};
    for (const tx of transactions) {
      if (tx.transactionType === 'expense') {
        const catName = tx.category?.name || 'Uncategorized';
        categorySums[catName] = (categorySums[catName] || 0) + Number(tx.amountBase);
      }
    }

    for (const [catName, total] of Object.entries(categorySums)) {
      summarySheet.addRow({ category: catName, total });
    }

    const buffer = await workbook.xlsx.writeBuffer();
    return buffer as unknown as Buffer;
  }
}
