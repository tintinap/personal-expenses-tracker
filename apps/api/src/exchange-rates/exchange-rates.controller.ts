import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ExchangeRatesService } from './exchange-rates.service';

@Controller('exchange-rates')
@UseGuards(JwtAuthGuard)
export class ExchangeRatesController {
  constructor(private readonly exchangeRatesService: ExchangeRatesService) {}

  /**
   * GET /exchange-rates/latest?from=THB&to=AUD
   */
  @Get('latest')
  async getLatest(
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    return this.exchangeRatesService.getRate(from, to);
  }

  /**
   * GET /exchange-rates/:date?from=THB&to=AUD
   */
  @Get(':date')
  async getHistorical(
    @Param('date') date: string,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    return this.exchangeRatesService.getRate(from, to, date);
  }
}
