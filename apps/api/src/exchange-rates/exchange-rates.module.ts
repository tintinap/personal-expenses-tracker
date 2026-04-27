import { Module } from '@nestjs/common';
import { ExchangeRatesController } from './exchange-rates.controller';
import { ExchangeRatesService } from './exchange-rates.service';
import { ExchangeRatesRepository } from './exchange-rates.repository';

@Module({
  controllers: [ExchangeRatesController],
  providers: [ExchangeRatesService, ExchangeRatesRepository],
  exports: [ExchangeRatesService],
})
export class ExchangeRatesModule {}
