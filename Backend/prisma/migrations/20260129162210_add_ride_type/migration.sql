/*
  Fixed for shadow DB replay:
  - Don't DROP COLUMN type if it doesn't exist.
  - Ensure enum exists.
  - Ensure column exists with correct type/default.
*/

-- CreateEnum (safe if rerun)
DO $$ BEGIN
  CREATE TYPE "RideType" AS ENUM ('FAIR_VALUE', 'PREMIUM', 'ECONOMIC', 'SCOOTER');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Ensure column exists (safe in shadow DB)
ALTER TABLE "Ride"
ADD COLUMN IF NOT EXISTS "type" "RideType" NOT NULL DEFAULT 'FAIR_VALUE';