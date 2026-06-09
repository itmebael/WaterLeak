-- ============================================
-- Add Sensor Data Column to water_connection_control
-- ============================================
-- This SQL adds a sensor_data JSONB column to store water sensor readings
-- Run this in your Supabase SQL Editor

-- Add sensor_data column to water_connection_control table
ALTER TABLE public.water_connection_control
ADD COLUMN IF NOT EXISTS sensor_data JSONB DEFAULT '{}'::JSONB;

-- Add index on sensor_data for better query performance
CREATE INDEX IF NOT EXISTS idx_water_control_sensor_data 
ON public.water_connection_control 
USING GIN (sensor_data);

-- Add comment to document the column
COMMENT ON COLUMN public.water_connection_control.sensor_data IS 
'JSONB field storing water sensor readings: {
  "water_sensor_1_value": integer (ADC 0-4095),
  "water_sensor_1_percent": numeric (0-100%),
  "water_sensor_1_detected": boolean (true if >= 25%),
  "water_sensor_2_value": integer (ADC 0-4095),
  "water_sensor_2_percent": numeric (0-100%),
  "water_sensor_2_detected": boolean (true if >= 25%),
  "water_leak_detected": boolean (overall leak status)
}';

-- ============================================
-- Optional: Also add sensor_data to history table
-- ============================================
-- If you want to track sensor readings in history as well

-- Check if water_connection_control_history table exists and add column
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'water_connection_control_history'
    ) THEN
        ALTER TABLE public.water_connection_control_history
        ADD COLUMN IF NOT EXISTS sensor_data JSONB DEFAULT '{}'::JSONB;
        
        CREATE INDEX IF NOT EXISTS idx_water_control_hist_sensor_data 
        ON public.water_connection_control_history 
        USING GIN (sensor_data);
        
        RAISE NOTICE 'Added sensor_data column to water_connection_control_history';
    ELSE
        RAISE NOTICE 'water_connection_control_history table does not exist, skipping';
    END IF;
END $$;

-- ============================================
-- Verify the column was added
-- ============================================
-- Run this to check:
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'water_connection_control' 
-- AND column_name = 'sensor_data';




