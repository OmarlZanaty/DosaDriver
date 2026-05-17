-- Align Prisma migration history with existing DB changes (already applied manually)
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "pushToken" TEXT;
ALTER TABLE "Ride" ADD COLUMN IF NOT EXISTS "stateVersion" INTEGER NOT NULL DEFAULT 0;