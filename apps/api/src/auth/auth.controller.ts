import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
  UnauthorizedException,
  Delete,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RefreshTokenDto } from './dto/auth-response.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

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
    const payload = await this.authService.verifyGoogleToken(body.idToken);
    
    const user = await this.authService.validateOrCreateUser({
      email: body.email,
      displayName: body.displayName,
      avatarUrl: body.avatarUrl,
      authProvider: 'google',
      providerId: payload.sub || body.providerId,
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
    const payload = await this.authService.verifyAppleToken(body.identityToken);
    
    const user = await this.authService.validateOrCreateUser({
      email: body.email,
      displayName: body.displayName,
      authProvider: 'apple',
      providerId: payload.sub || body.providerId,
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

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refreshToken(@Body('refreshToken') refreshToken: string) {
    if (!refreshToken) {
      throw new UnauthorizedException('Refresh token is required');
    }

    return this.authService.refreshAccessToken(refreshToken);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('account')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteAccount(@Req() req: any) {
    await this.authService.deleteAccount(req.user.userId);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout() {
    return;
  }
}
