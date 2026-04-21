// DTOs
export class AuthResponseDto {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    email: string;
    displayName: string;
    avatarUrl: string | null;
    baseCurrency: string;
    authProvider: string;
  };
}

export class RefreshTokenDto {
  refreshToken: string;
}
