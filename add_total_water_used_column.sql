-- ============================================
-- ADD TOTAL_WATER_USED COLUMN TO WATER_CONNECTION_CONTROL
-- Run this in Supabase SQL Editor
-- ============================================

BEGIN;

-- Add total_water_used column if it doesn't exist
ALTER TABLE public.water_connection_control 
ADD COLUMN IF NOT EXISTS total_water_used DECIMAL(10, 2) DEFAULT 0.00;

-- Add comment to the column
COMMENT ON COLUMN public.water_connection_control.total_water_used IS 'Total water used in liters (cumulative)';

COMMIT;

-- Verify the column was added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'water_connection_control'
  AND column_name = 'total_water_used';












