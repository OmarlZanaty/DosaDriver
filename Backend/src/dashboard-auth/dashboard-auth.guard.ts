import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../prisma/prisma.service';
import { getFirebaseAdminApp } from '../auth/firebase-admin';

export type DashboardRole = 'SUPER_ADMIN' | 'DASHBOARD_USER';

export interface DashboardRequest extends Request {
  dashboardUser?: {
    id: number;
    firebaseUid: string;
    email: string;
    name: string | null;
    role: DashboardRole;
    isActive: boolean;
    permissions: string[];
  };
}

@Injectable()
export class DashboardAuthGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<DashboardRequest>();

    const auth = req.headers.authorization || '';
    if (!auth.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing Bearer token');
    }

    const token = auth.substring('Bearer '.length).trim();
    if (!token) throw new UnauthorizedException('Empty Bearer token');

    // 1) Verify Firebase token
    let decoded: any;
    try {
      decoded = await getFirebaseAdminApp().auth().verifyIdToken(token, true);
    } catch (e: any) {
      throw new UnauthorizedException(e?.message ?? 'Invalid Firebase token');
    }

    const uid = decoded?.uid || decoded?.user_id;
    if (!uid) throw new UnauthorizedException('Invalid token (missing uid)');

    // Optional hard check: require admin custom claim
    // (your make-super-admin.ts sets admin:true)
    if (decoded.admin !== true && decoded.role !== 'SUPER_ADMIN') {
      // still allow if user exists in DB (some teams prefer DB source of truth)
      // but we’ll keep a strict rule:
      // throw new ForbiddenException('Not an admin (missing custom claim)');
    }

    // 2) Load DashboardUser from DB
    const du = await this.prisma.dashboardUser.findUnique({
      where: { firebaseUid: uid },
      include: { permissions: true },
    });

    if (!du) {
      throw new ForbiddenException('Not registered as dashboard admin');
    }

    if (!du.isActive) {
      throw new ForbiddenException('Dashboard user is disabled');
    }

    req.dashboardUser = {
      id: du.id,
      firebaseUid: du.firebaseUid,
      email: du.email,
      name: du.name ?? null,
      role: du.role as any,
      isActive: du.isActive,
      permissions: du.permissions.map((p) => p.key),
    };

    return true;
  }
}