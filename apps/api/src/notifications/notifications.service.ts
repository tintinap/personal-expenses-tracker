import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { initializeApp, cert } from 'firebase-admin/app';
import { getMessaging, Message } from 'firebase-admin/messaging';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private isInitialized = false;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

    if (projectId && clientEmail && privateKey) {
      try {
        initializeApp({
          credential: cert({
            projectId,
            clientEmail,
            privateKey,
          }),
        });
        this.isInitialized = true;
        this.logger.log('Firebase Admin initialized successfully');
      } catch (error: any) {
        this.logger.error(`Failed to initialize Firebase Admin: ${error.message}`);
      }
    } else {
      this.logger.warn('Firebase Admin credentials missing from environment. Push notifications are disabled.');
    }
  }

  async sendPushNotification(userId: string, title: string, body: string) {
    if (!this.isInitialized) {
      this.logger.debug(`[FCM PUSH to ${userId} (disabled)] ${title} - ${body}`);
      return;
    }

    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { fcmToken: true }
      });

      if (!user || !user.fcmToken) {
        this.logger.debug(`[FCM PUSH to ${userId} (skipped)] No FCM token found`);
        return;
      }

      const message: Message = {
        token: user.fcmToken,
        notification: {
          title,
          body,
        },
      };

      const response = await getMessaging().send(message);
      this.logger.log(`Successfully sent message to ${userId}: ${response}`);
    } catch (error: any) {
      this.logger.error(`Error sending message to ${userId}: ${error.message}`);
    }
  }
}
