import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { REQUIRE_PERMISSION_KEY } from './require-permission.decorator';
import type { DashboardRequest } from './dashboard-auth.guard';

@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<DashboardRequest>();
    const needed = this.reflector.getAllAndOverride<string[]>(
      REQUIRE_PERMISSION_KEY,
      [ctx.getHandler(), ctx.getClass()],
    ) ?? [];

    // no permission required
    if (needed.length === 0) return true;

    const du = req.dashboardUser;
    if (!du) throw new ForbiddenException('Missing dashboard user');

    // super admin bypass
    if (du.role === 'SUPER_ADMIN') return true;

    const have = new Set(du.permissions ?? []);
    for (const p of needed) {
      if (!have.has(p)) throw new ForbiddenException(`Missing permission: ${p}`);
    }

    return true;
  }
}