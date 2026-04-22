import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  async sendPushNotification(userId: string, title: string, body: string) {
    // In a real app, this would integrate with firebase-admin
    this.logger.log(`[FCM PUSH to ${userId}] ${title} - ${body}`);
    // Simulated delay
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}
