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
  ConflictException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';

@Controller('categories')
@UseGuards(JwtAuthGuard)
export class CategoriesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async findAll(@Req() req: any) {
    return this.prisma.category.findMany({
      where: { userId: req.user.userId },
      orderBy: { sortOrder: 'asc' },
    });
  }

  @Post()
  async create(
    @Req() req: any,
    @Body() body: { name: string; colourHex: string },
  ) {
    const maxSort = await this.prisma.category.aggregate({
      where: { userId: req.user.userId },
      _max: { sortOrder: true },
    });

    return this.prisma.category.create({
      data: {
        userId: req.user.userId,
        name: body.name,
        colourHex: body.colourHex,
        isDefault: false,
        sortOrder: (maxSort._max.sortOrder ?? -1) + 1,
      },
    });
  }

  @Patch(':id')
  async update(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { name?: string; colourHex?: string; isHidden?: boolean },
  ) {
    return this.prisma.category.update({
      where: { id, userId: req.user.userId },
      data: {
        ...(body.name !== undefined && { name: body.name }),
        ...(body.colourHex !== undefined && { colourHex: body.colourHex }),
        ...(body.isHidden !== undefined && { isHidden: body.isHidden }),
      },
    });
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Req() req: any, @Param('id') id: string) {
    // Check if category has associated expenses
    const count = await this.prisma.transaction.count({
      where: {
        categoryId: id,
        userId: req.user.userId,
        deletedAt: null,
      },
    });

    if (count > 0) {
      throw new ConflictException(
        `Category has ${count} associated expenses. Reassign them before deleting.`,
      );
    }

    await this.prisma.category.delete({
      where: { id, userId: req.user.userId },
    });
  }
}
