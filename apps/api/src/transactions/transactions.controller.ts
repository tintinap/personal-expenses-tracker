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
import { TransactionsService } from './transactions.service';
import { BudgetAlertsService } from '../budgets/budget-alerts.service';
import { CreateTransactionDto, UpdateTransactionDto } from './dto/transaction.dto';

@Controller('transactions')
@UseGuards(JwtAuthGuard)
export class TransactionsController {
  constructor(
    private readonly transactionsService: TransactionsService,
    private readonly budgetAlertsService: BudgetAlertsService,
  ) {}

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
    return this.transactionsService.findAll(
      req.user.userId,
      page,
      limit,
      type,
      from,
      to,
      categoryId,
    );
  }

  @Get(':id')
  async findOne(@Req() req: any, @Param('id') id: string) {
    return this.transactionsService.findOne(id, req.user.userId);
  }

  @Post()
  async create(@Req() req: any, @Body() body: CreateTransactionDto) {
    const result = await this.transactionsService.create(req.user.userId, body);
    await this.budgetAlertsService.evaluateUserBudgets(req.user.userId).catch(() => {});
    return result;
  }

  @Post('bulk')
  async createBulk(@Req() req: any, @Body() body: { transactions: CreateTransactionDto[] }) {
    const result = await this.transactionsService.bulkInsert(req.user.userId, body);
    await this.budgetAlertsService.evaluateUserBudgets(req.user.userId).catch(() => {});
    return result;
  }

  @Patch(':id')
  async update(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: UpdateTransactionDto,
  ) {
    const result = await this.transactionsService.update(id, req.user.userId, body);
    await this.budgetAlertsService.evaluateUserBudgets(req.user.userId).catch(() => {});
    return result;
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Req() req: any, @Param('id') id: string) {
    await this.transactionsService.remove(id, req.user.userId);
  }
}
