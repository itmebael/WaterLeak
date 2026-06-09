-- ============================================
-- FIX WATER_CONNECTION_CONTROL RLS PERMISSIONS
-- This script fixes RLS policies to allow ESP32 to save data
-- Run this in Supabase SQL Editor
-- ============================================

BEGIN;

-- ============================================
-- 1. DISABLE RLS TEMPORARILY (to fix policies)
-- ============================================
ALTER TABLE IF EXISTS public.water_connection_control DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.water_connection_commands DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.sensor_readings DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.water_leak_detections DISABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. DROP ALL EXISTING POLICIES
-- ============================================
DROP POLICY IF EXISTS "Anyone can view water connection control" ON public.water_connection_control;
DROP POLICY IF EXISTS "Anyone can insert water connection control" ON public.water_connection_control;
DROP POLICY IF EXISTS "Anyone can update water connection control" ON public.water_connection_control;
DROP POLICY IF EXISTS "Anyone can delete water connection control" ON public.water_connection_control;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.water_connection_control;
DROP POLICY IF EXISTS "Enable update for all users" ON public.water_connection_control;
DROP POLICY IF EXISTS "Enable select for all users" ON public.water_connection_control;

DROP POLICY IF EXISTS "Anyone can view water connection commands" ON public.water_connection_commands;
DROP POLICY IF EXISTS "Anyone can insert water connection commands" ON public.water_connection_commands;
DROP POLICY IF EXISTS "Anyone can update water connection commands" ON public.water_connection_commands;

DROP POLICY IF EXISTS "Anyone can view sensor readings" ON public.sensor_readings;
DROP POLICY IF EXISTS "Anyone can insert sensor readings" ON public.sensor_readings;
DROP POLICY IF EXISTS "Anyone can update sensor readings" ON public.sensor_readings;

DROP POLICY IF EXISTS "Anyone can view leak detections" ON public.water_leak_detections;
DROP POLICY IF EXISTS "Anyone can insert leak detections" ON public.water_leak_detections;
DROP POLICY IF EXISTS "Anyone can update leak detections" ON public.water_leak_detections;

-- ============================================
-- 3. RE-ENABLE RLS
-- ============================================
ALTER TABLE IF EXISTS public.water_connection_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.water_connection_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.water_leak_detections ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. CREATE NEW PERMISSIVE POLICIES
-- ============================================

-- WATER_CONNECTION_CONTROL POLICIES
CREATE POLICY "Allow all SELECT on water_connection_control"
  ON public.water_connection_control
  FOR SELECT
  USING (true);

CREATE POLICY "Allow all INSERT on water_connection_control"
  ON public.water_connection_control
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow all UPDATE on water_connection_control"
  ON public.water_connection_control
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow all DELETE on water_connection_control"
  ON public.water_connection_control
  FOR DELETE
  USING (true);

-- WATER_CONNECTION_COMMANDS POLICIES
CREATE POLICY "Allow all SELECT on water_connection_commands"
  ON public.water_connection_commands
  FOR SELECT
  USING (true);

CREATE POLICY "Allow all INSERT on water_connection_commands"
  ON public.water_connection_commands
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow all UPDATE on water_connection_commands"
  ON public.water_connection_commands
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- SENSOR_READINGS POLICIES
CREATE POLICY "Allow all SELECT on sensor_readings"
  ON public.sensor_readings
  FOR SELECT
  USING (true);

CREATE POLICY "Allow all INSERT on sensor_readings"
  ON public.sensor_readings
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow all UPDATE on sensor_readings"
  ON public.sensor_readings
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- WATER_LEAK_DETECTIONS POLICIES
CREATE POLICY "Allow all SELECT on water_leak_detections"
  ON public.water_leak_detections
  FOR SELECT
  USING (true);

CREATE POLICY "Allow all INSERT on water_leak_detections"
  ON public.water_leak_detections
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow all UPDATE on water_leak_detections"
  ON public.water_leak_detections
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- ============================================
-- 5. GRANT EXPLICIT PERMISSIONS
-- ============================================
GRANT ALL ON public.water_connection_control TO anon;
GRANT ALL ON public.water_connection_control TO authenticated;
GRANT ALL ON public.water_connection_control TO service_role;

GRANT ALL ON public.water_connection_commands TO anon;
GRANT ALL ON public.water_connection_commands TO authenticated;
GRANT ALL ON public.water_connection_commands TO service_role;

GRANT ALL ON public.sensor_readings TO anon;
GRANT ALL ON public.sensor_readings TO authenticated;
GRANT ALL ON public.sensor_readings TO service_role;

GRANT ALL ON public.water_leak_detections TO anon;
GRANT ALL ON public.water_leak_detections TO authenticated;
GRANT ALL ON public.water_leak_detections TO service_role;

-- ============================================
-- 6. GRANT USAGE ON SEQUENCES (if using serial IDs)
-- ============================================
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO service_role;

COMMIT;

-- ============================================
-- VERIFICATION QUERIES (Run these after the script)
-- ============================================

-- Check if RLS is enabled
-- SELECT tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE schemaname = 'public' 
--   AND tablename IN ('water_connection_control', 'water_connection_commands', 'sensor_readings', 'water_leak_detections');

-- Check policies
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies 
-- WHERE tablename IN ('water_connection_control', 'water_connection_commands', 'sensor_readings', 'water_leak_detections')
-- ORDER BY tablename, policyname;

-- Test insert (should work now)
-- INSERT INTO public.water_connection_control (device_id, device_name, valve_status, water_flow, is_online)
-- VALUES ('ESP_KITCHEN_001', 'Kitchen Water Line', 'closed', 0.00, false)
-- ON CONFLICT (device_id) DO UPDATE SET
--   water_flow = EXCLUDED.water_flow,
--   is_online = EXCLUDED.is_online,
--   last_heartbeat = NOW();

-- Check the inserted/updated data
-- SELECT * FROM public.water_connection_control WHERE device_id = 'ESP_KITCHEN_001';












