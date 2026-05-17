import { SetMetadata } from '@nestjs/common';

export const REQUIRE_PERMISSION_KEY = 'require_permission';

export function RequirePermission(...perms: string[]) {
  return SetMetadata(REQUIRE_PERMISSION_KEY, perms);
}