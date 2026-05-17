-- Align Prisma migration history with DB (already applied manually / idempotent)
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "pushToken" TEXT;
ALTER TABLE "Ride" ADD COLUMN IF NOT EXISTS "stateVersion" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Ride" ADD COLUMN IF NOT EXISTS "type" TEXT;