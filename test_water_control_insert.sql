-- ============================================
-- TEST WATER_CONNECTION_CONTROL INSERT/UPDATE
-- Run this to test if ESP32 can save data
-- ============================================

-- Test 1: Check if table exists and structure
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'water_connection_control'
ORDER BY ordinal_position;

-- Test 2: Check RLS status
SELECT 
  tablename, 
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename = 'water_connection_control';

-- Test 3: Check existing policies
SELECT 
  policyname, 
  permissive,
  roles,
  cmd as command,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename = 'water_connection_control';

-- Test 4: Try to insert/update (simulating ESP32)
-- This should work if RLS is configured correctly
INSERT INTO public.water_connection_control (
  device_id,
  device_name,
  valve_status,
  water_flow,
  is_online,
  location
)
VALUES (
  'ESP_KITCHEN_001',
  'Kitchen Water Line',
  'closed',
  123.45,
  true,
  'Kitchen'
)
ON CONFLICT (device_id) 
DO UPDATE SET
  device_name = EXCLUDED.device_name,
  valve_status = EXCLUDED.valve_status,
  water_flow = EXCLUDED.water_flow,
  is_online = EXCLUDED.is_online,
  location = EXCLUDED.location,
  last_heartbeat = NOW(),
  updated_at = NOW();

-- Test 5: Verify the data was saved
SELECT 
  device_id,
  device_name,
  valve_status,
  water_flow,
  is_online,
  location,
  last_heartbeat,
  updated_at
FROM public.water_connection_control
WHERE device_id = 'ESP_KITCHEN_001';

-- Test 6: Check for any errors in the last operation
-- If you see any errors above, check:
-- 1. Is RLS enabled? (should be true)
-- 2. Are there policies allowing INSERT/UPDATE? (should be yes)
-- 3. Are permissions granted to 'anon' role? (should be yes)



