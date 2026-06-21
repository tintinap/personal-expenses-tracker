import { Controller, Post, UseGuards, Req, Body } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ImportService } from './import.service';
import { ImportTransactionsDto } from './dto/import-transaction.dto';

@ApiTags('Import')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('import')
export class ImportController {
  constructor(private readonly importService: ImportService) {}

  @Post('transactions')
  @ApiOperation({ summary: 'Import transactions from parsed JSON' })
  async importTransactions(@Req() req, @Body() importDto: ImportTransactionsDto) {
    const userId = req.user.userId;
    const importedCount = await this.importService.importTransactions(userId, importDto.transactions);
    return {
      success: true,
      importedCount,
    };
  }
}
