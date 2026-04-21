import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { CreateTransactionDto, UpdateTransactionDto } from './dto/transaction.dto';

@Controller('transactions')
@UseGuards(JwtAuthGuard)
export class TransactionsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async findAll(
    @Req() req: any,
    @Query('page') page = '1',
    @Query('limit') limit = '50',
    @Query('type') type?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('categoryId') categoryId?: string,
  ) {
    const pageNum = Math.max(1, parseInt(page, 10));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10)));
    const skip = (pageNum - 1) * limitNum;

    const where: Prisma.TransactionWhereInput = {
      userId: req.user.userId,
      deletedAt: null,
      ...(type && { transactionType: type }),
      ...(categoryId && { categoryId }),
      ...(from || to
        ? {
            transactionDate: {
              ...(from && { gte: new Date(from) }),
              ...(to && { lte: new Date(to) }),
            },
          }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.transaction.findMany({
        where,
        orderBy: { transactionDate: 'desc' },
        skip,
        take: limitNum,
        include: { category: true },
      }),
      this.prisma.transaction.count({ where }),
    ]);

    return {
      data,
      meta: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum),
      },
    };
  }

  @Get(':id')
  async findOne(@Req() req: any, @Param('id') id: string) {
    return this.prisma.transaction.findFirstOrThrow({
      where: { id, userId: req.user.userId, deletedAt: null },
      include: { category: true },
    });
  }

  @Post()
  async create(@Req() req: any, @Body() body: CreateTransactionDto) {
    const transaction = await this.prisma.transaction.create({
      data: {
        ...(body.id && { id: body.id }),
        userId: req.user.userId,
        transactionType: body.transactionType,
        amountBase: body.amountBase,
        originalAmount: body.originalAmount,
        originalCurrency: body.originalCurrency,
        exchangeRate: body.exchangeRate,
        rateDate: new Date(body.rateDate),
        rateEstimated: body.rateEstimated ?? false,
        rateSource: body.rateSource ?? 'frankfurter',
        exchangeEventId: body.exchangeEventId ?? null,
        categoryId: body.categoryId ?? null,
        note: body.note ?? null,
        sourceLabel: body.sourceLabel ?? null,
        transactionDate: new Date(body.transactionDate),
        isRecurring: body.isRecurring ?? false,
        recurrenceType: body.recurrenceType ?? null,
      },
      include: { category: true },
    });

    // Update currency balance
    await this.updateCurrencyBalance(
      req.user.userId,
      body.originalCurrency,
      body.transactionType,
      Number(body.originalAmount),
    );

    return transaction;
  }

  @Patch(':id')
  async update(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: UpdateTransactionDto,
  ) {
    return this.prisma.transaction.update({
      where: { id, userId: req.user.userId },
      data: {
        ...(body.amountBase !== undefined && { amountBase: body.amountBase }),
        ...(body.originalAmount !== undefined && { originalAmount: body.originalAmount }),
        ...(body.originalCurrency !== undefined && { originalCurrency: body.originalCurrency }),
        ...(body.exchangeRate !== undefined && { exchangeRate: body.exchangeRate }),
        ...(body.rateDate !== undefined && { rateDate: new Date(body.rateDate) }),
        ...(body.rateEstimated !== undefined && { rateEstimated: body.rateEstimated }),
        ...(body.rateSource !== undefined && { rateSource: body.rateSource }),
        ...(body.categoryId !== undefined && { categoryId: body.categoryId }),
        ...(body.note !== undefined && { note: body.note }),
        ...(body.transactionDate !== undefined && { transactionDate: new Date(body.transactionDate) }),
      },
      include: { category: true },
    });
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Req() req: any, @Param('id') id: string) {
    // Soft delete
    await this.prisma.transaction.update({
      where: { id, userId: req.user.userId },
      data: { deletedAt: new Date() },
    });
  }

  private async updateCurrencyBalance(
    userId: string,
    currency: string,
    transactionType: string,
    amount: number,
  ) {
    let delta = 0;
    switch (transactionType) {
      case 'expense':
        delta = -amount;
        break;
      case 'currency_income':
      case 'currency_exchange_in':
        delta = amount;
        break;
      case 'currency_exchange_out':
        delta = -amount;
        break;
    }

    await this.prisma.currencyBalance.upsert({
      where: { userId_currency: { userId, currency } },
      create: { userId, currency, balance: delta },
      update: { balance: { increment: delta } },
    });
  }
}
