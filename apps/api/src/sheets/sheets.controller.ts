import { Controller, Post, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { SheetsService } from './sheets.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('Sheets')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sheets')
export class SheetsController {
  constructor(private readonly sheetsService: SheetsService) {}

  @Post('setup')
  @ApiOperation({ summary: 'Setup Google Sheet sync for user' })
  async setup(@Req() req) {
    const userId = req.user.userId;
    return this.sheetsService.setupSheet(userId);
  }
}
