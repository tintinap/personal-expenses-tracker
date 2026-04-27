import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthRepository } from './auth.repository';

export interface JwtPayload {
  sub: string; // user ID
  email: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly repository: AuthRepository,
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
    let user = await this.repository.findUserByProvider(
      profile.authProvider,
      profile.providerId,
    );

    if (!user) {
      user = await this.repository.createUser({
        email: profile.email,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl || null,
        authProvider: profile.authProvider,
        providerId: profile.providerId,
        googleRefreshToken: profile.googleRefreshToken || null,
      });

      // Seed default categories for new user
      await this.repository.seedDefaultCategories(user.id);
    } else if (profile.googleRefreshToken) {
      // Update refresh token on re-auth
      user = await this.repository.updateUser(user.id, {
        googleRefreshToken: profile.googleRefreshToken,
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
      const user = await this.repository.findUserById(payload.sub);

      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      return this.generateTokens(user.id, user.email);
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async getUserById(userId: string) {
    return this.repository.findUserById(userId);
  }
}
