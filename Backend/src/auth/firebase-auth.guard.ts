import {
  CanActivate, ExecutionContext, Injectable, UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { getFirebaseAdminApp } from './firebase-admin';
import { UsersService } from '../users/users.service';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from './public.decorator';

const VERIFY_TIMEOUT_MS = 8000;

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(
    private readonly usersService: UsersService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();

    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(), context.getClass(),
    ]);
    if (isPublic) return true;

    const auth = req.headers.authorization || '';
    if (!auth.startsWith('Bearer ')) throw new UnauthorizedException('Missing Bearer token');

    const token = auth.substring(7).trim();
    if (!token) throw new UnauthorizedException('Empty Bearer token');

    try {
      const app = getFirebaseAdminApp();

      // FIX: Add timeout to prevent hanging requests when Firebase is degraded
      const decoded = await Promise.race([
        app.auth().verifyIdToken(token, true),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error('Firebase auth timeout')), VERIFY_TIMEOUT_MS)
        ),
      ]);

      (req as any).user = decoded;
      const dbUser = await this.usersService.upsertFromFirebase(decoded as any);
      (req as any).dbUser = dbUser;
      return true;
    } catch (err: any) {
      throw new UnauthorizedException(err?.message ?? 'Invalid Firebase token');
    }
  }
}
