import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { SyncService } from './sync.service';

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  /**
   * POST /sync/push
   * Mobile sends pending local records to server.
   */
  @Post('push')
  @HttpCode(HttpStatus.OK)
  async push(
    @Req() req: any,
    @Body()
    body: {
      records: Array<{
        recordType: string; // transaction | budget | category
        recordId: string;
        operation: string; // insert | update | delete
        payload: any;
      }>;
      clientTimestamp: string;
    },
  ) {
    return this.syncService.processPush(req.user.userId, body.records);
  }

  /**
   * POST /sync/pull
   * Mobile requests records updated after the given timestamp.
   */
  @Post('pull')
  @HttpCode(HttpStatus.OK)
  async pull(
    @Req() req: any,
    @Body() body: { lastSyncTimestamp: string },
  ) {
    return this.syncService.processPull(
      req.user.userId,
      new Date(body.lastSyncTimestamp),
    );
  }
}
