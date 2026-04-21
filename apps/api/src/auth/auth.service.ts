import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';

export interface JwtPayload {
  sub: string; // user ID
  email: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async validateOrCreateUser(profile: {
    email: string;
    displayName: string;
    avatarUrl?: string;
    authProvider: 'google' | 'apple';
    providerId: string;
    googleRefreshToken?: string;
  }) {
    let user = await this.prisma.user.findFirst({
      where: {
        authProvider: profile.authProvider,
        providerId: profile.providerId,
      },
    });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email: profile.email,
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl || null,
          authProvider: profile.authProvider,
          providerId: profile.providerId,
          googleRefreshToken: profile.googleRefreshToken || null,
        },
      });

      // Seed default categories for new user
      await this.seedDefaultCategories(user.id);
    } else if (profile.googleRefreshToken) {
      // Update refresh token on re-auth
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { googleRefreshToken: profile.googleRefreshToken },
      });
    }

    return user;
  }

  async generateTokens(userId: string, email: string) {
    const payload: JwtPayload = { sub: userId, email };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, { expiresIn: '15m' }),
      this.jwtService.signAsync(payload, { expiresIn: '7d' }),
    ]);

    return { accessToken, refreshToken };
  }

  async refreshAccessToken(refreshToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync<JwtPayload>(
        refreshToken,
      );
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
      });

      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      return this.generateTokens(user.id, user.email);
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async getUserById(userId: string) {
    return this.prisma.user.findUnique({ where: { id: userId } });
  }

  private async seedDefaultCategories(userId: string) {
    const defaults = [
      { name: 'Food & dining', colourHex: '#378ADD', sortOrder: 0 },
      { name: 'Groceries', colourHex: '#4CAF50', sortOrder: 1 },
      { name: 'Transport', colourHex: '#FF7043', sortOrder: 2 },
      { name: 'Health & medical', colourHex: '#E91E8C', sortOrder: 3 },
      { name: 'Shopping & retail', colourHex: '#9C27B0', sortOrder: 4 },
      { name: 'Bills & utilities', colourHex: '#009688', sortOrder: 5 },
      { name: 'Entertainment', colourHex: '#FFC107', sortOrder: 6 },
      { name: 'Travel', colourHex: '#FF8F00', sortOrder: 7 },
      { name: 'Subscriptions', colourHex: '#F44336', sortOrder: 8 },
      { name: 'Education', colourHex: '#455A64', sortOrder: 9 },
      { name: 'Personal care', colourHex: '#4FC3F7', sortOrder: 10 },
      { name: 'Other / uncategorised', colourHex: '#9E9E9E', sortOrder: 11 },
    ];

    await this.prisma.category.createMany({
      data: defaults.map((cat) => ({
        userId,
        name: cat.name,
        colourHex: cat.colourHex,
        isDefault: true,
        sortOrder: cat.sortOrder,
      })),
    });
  }
}
