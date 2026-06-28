import { Controller, Post, Delete, Body, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post('register-token')
  @ApiOperation({ summary: 'Register FCM token for push notifications' })
  async registerToken(@Req() req, @Body() body: { fcmToken: string }) {
    await this.prisma.user.update({
      where: { id: req.user.userId },
      data: { fcmToken: body.fcmToken }
    });
    return { success: true };
  }

  @Delete('unregister-token')
  @ApiOperation({ summary: 'Remove FCM token' })
  async unregisterToken(@Req() req) {
    await this.prisma.user.update({
      where: { id: req.user.userId },
      data: { fcmToken: null }
    });
    return { success: true };
  }
}
