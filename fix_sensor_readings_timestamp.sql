-- ============================================
-- FIX SENSOR_READINGS TIMESTAMP ISSUE
-- This allows reading_timestamp to use database default
-- Run this in Supabase SQL Editor
-- ============================================

BEGIN;

-- Option 1: Make reading_timestamp nullable (if it doesn't have a default)
-- ALTER TABLE public.sensor_readings 
-- ALTER COLUMN reading_timestamp DROP NOT NULL;

-- Option 2: Ensure it has a default (better solution)
-- Check if default exists, if not add it
DO $$
BEGIN
  -- Check if column has a default
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'sensor_readings' 
      AND column_name = 'reading_timestamp'
      AND column_default IS NOT NULL
  ) THEN
    -- Add default if it doesn't exist
    ALTER TABLE public.sensor_readings 
    ALTER COLUMN reading_timestamp SET DEFAULT NOW();
  END IF;
  
  -- Make it nullable so default can work with REST API
  ALTER TABLE public.sensor_readings 
  ALTER COLUMN reading_timestamp DROP NOT NULL;
END $$;

COMMIT;

-- Verify the change
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'sensor_readings'
  AND column_name = 'reading_timestamp';



