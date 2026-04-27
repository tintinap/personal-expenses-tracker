import { Controller, Get, Post, Param, Query, Body, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ExchangeRatesService } from './exchange-rates.service';
import { CacheRateDto } from './dto/cache-rate.dto';

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

  /**
   * POST /exchange-rates
   * Accepts a rate from the mobile client for caching in the BE database.
   * Used when the mobile fetched directly from Frankfurter (BE was down at that time).
   */
  @Post()
  async cacheRate(@Body() dto: CacheRateDto) {
    return this.exchangeRatesService.cacheRate(dto.from, dto.to, dto.date, dto.rate);
  }
}
