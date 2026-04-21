import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RefreshTokenDto } from './dto/auth-response.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  /**
   * POST /auth/google
   * Receives Google OAuth token from client, validates, creates/finds user, returns JWT pair.
   * In production, this would validate the Google ID token server-side.
   */
  @Post('google')
  @HttpCode(HttpStatus.OK)
  async googleAuth(
    @Body()
    body: {
      idToken: string;
      email: string;
      displayName: string;
      avatarUrl?: string;
      providerId: string;
      refreshToken?: string;
    },
  ) {
    // TODO: Validate Google ID token server-side with Google's tokeninfo endpoint
    const user = await this.authService.validateOrCreateUser({
      email: body.email,
      displayName: body.displayName,
      avatarUrl: body.avatarUrl,
      authProvider: 'google',
      providerId: body.providerId,
      googleRefreshToken: body.refreshToken,
    });

    const tokens = await this.authService.generateTokens(user.id, user.email);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        baseCurrency: user.baseCurrency,
        authProvider: user.authProvider,
      },
    };
  }

  /**
   * POST /auth/apple
   * Receives Apple Sign-In token from client, validates, creates/finds user, returns JWT pair.
   */
  @Post('apple')
  @HttpCode(HttpStatus.OK)
  async appleAuth(
    @Body()
    body: {
      identityToken: string;
      email: string;
      displayName: string;
      providerId: string;
    },
  ) {
    // TODO: Validate Apple identity token server-side
    const user = await this.authService.validateOrCreateUser({
      email: body.email,
      displayName: body.displayName,
      authProvider: 'apple',
      providerId: body.providerId,
    });

    const tokens = await this.authService.generateTokens(user.id, user.email);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        baseCurrency: user.baseCurrency,
        authProvider: user.authProvider,
      },
    };
  }

  /**
   * POST /auth/refresh
   * Exchange a valid refresh token for new access + refresh token pair.
   */
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() body: RefreshTokenDto) {
    return this.authService.refreshAccessToken(body.refreshToken);
  }

  /**
   * POST /auth/logout
   * Invalidate the current session (client-side token discard).
   */
  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout() {
    // JWT is stateless — client discards tokens.
    // Future: add token blocklist for immediate revocation.
    return;
  }
}
