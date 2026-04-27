import { Controller, Get, UseGuards, Req, Res, Query, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import type { Response } from 'express';
import { ExportService } from './export.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('Export')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('export')
export class ExportController {
  constructor(private readonly exportService: ExportService) {}

  @Get('excel')
  @ApiOperation({ summary: 'Export user data to Excel' })
  @ApiQuery({ name: 'startDate', required: false, type: String })
  @ApiQuery({ name: 'endDate', required: false, type: String })
  async exportExcel(
    @Req() req,
    @Res() res: Response,
    @Query('startDate') startDateString?: String,
    @Query('endDate') endDateString?: String,
  ) {
    const userId = req.user.userId;
    
    let startDate: Date | undefined;
    let endDate: Date | undefined;
    
    if (startDateString) {
      const d = new Date(startDateString as string);
      if (isNaN(d.getTime())) throw new BadRequestException('Invalid startDate format');
      startDate = d;
    }
    
    if (endDateString) {
      const d = new Date(endDateString as string);
      if (isNaN(d.getTime())) throw new BadRequestException('Invalid endDate format');
      endDate = d;
    }

    const buffer = await this.exportService.generateExcel(userId, startDate, endDate);

    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    res.setHeader('Content-Disposition', 'attachment; filename=ProjectPET_Export.xlsx');
    
    res.send(buffer);
  }
}
