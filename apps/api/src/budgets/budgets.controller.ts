import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';

@Controller('budgets')
@UseGuards(JwtAuthGuard)
export class BudgetsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async findAll(@Req() req: any) {
    return this.prisma.budget.findMany({
      where: { userId: req.user.userId },
      include: { category: true },
      orderBy: [{ scope: 'asc' }, { createdAt: 'desc' }],
    });
  }

  @Get(':id')
  async findOne(@Req() req: any, @Param('id') id: string) {
    return this.prisma.budget.findFirstOrThrow({
      where: { id, userId: req.user.userId },
      include: { category: true },
    });
  }

  @Post()
  async create(
    @Req() req: any,
    @Body()
    body: {
      scope: string;
      categoryId?: string;
      amountBase: number;
      periodType: string;
      startDate: string;
      endDate?: string;
    },
  ) {
    return this.prisma.budget.create({
      data: {
        userId: req.user.userId,
        scope: body.scope,
        categoryId: body.categoryId || null,
        amountBase: body.amountBase,
        periodType: body.periodType,
        startDate: new Date(body.startDate),
        endDate: body.endDate ? new Date(body.endDate) : null,
      },
      include: { category: true },
    });
  }

  @Patch(':id')
  async update(
    @Req() req: any,
    @Param('id') id: string,
    @Body()
    body: {
      amountBase?: number;
      periodType?: string;
      startDate?: string;
      endDate?: string;
      isActive?: boolean;
    },
  ) {
    return this.prisma.budget.update({
      where: { id, userId: req.user.userId },
      data: {
        ...(body.amountBase !== undefined && { amountBase: body.amountBase }),
        ...(body.periodType && { periodType: body.periodType }),
        ...(body.startDate && { startDate: new Date(body.startDate) }),
        ...(body.endDate !== undefined && {
          endDate: body.endDate ? new Date(body.endDate) : null,
        }),
        ...(body.isActive !== undefined && { isActive: body.isActive }),
      },
      include: { category: true },
    });
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Req() req: any, @Param('id') id: string) {
    await this.prisma.budget.delete({
      where: { id, userId: req.user.userId },
    });
  }
}
