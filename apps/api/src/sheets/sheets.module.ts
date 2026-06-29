import { Module } from '@nestjs/common';
import { SheetsController } from './sheets.controller';
import { SheetsService } from './sheets.service';
import { PrismaModule } from '../prisma/prisma.module';
import { SheetsProcessor } from './sheets.processor';

@Module({
  imports: [PrismaModule],
  controllers: [SheetsController],
  providers: [SheetsService, SheetsProcessor],
  exports: [SheetsService, SheetsProcessor],
})
export class SheetsModule {}
