import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}

@Injectable()
export class OptionalAuthGuard extends AuthGuard('jwt') {
  handleRequest(err: any, user: any) {
    // Don't throw on missing/invalid token — just return null
    return user || null;
  }

  canActivate(context: ExecutionContext) {
    // Always allow the request through, even without a token
    return super.canActivate(context);
  }
}
