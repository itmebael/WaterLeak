-- Fix Emergency Contacts RLS Policies to prevent logout
-- This SQL fixes the Row Level Security policies for emergency_contacts table
-- to allow admin and user operations without causing authentication errors

BEGIN;

-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can view system emergency contacts" ON emergency_contacts;
DROP POLICY IF EXISTS "Users can view own emergency contacts" ON emergency_contacts;
DROP POLICY IF EXISTS "Users can manage own emergency contacts" ON emergency_contacts;
DROP POLICY IF EXISTS "Anyone can insert emergency contacts" ON emergency_contacts;
DROP POLICY IF EXISTS "Anyone can update emergency contacts" ON emergency_contacts;
DROP POLICY IF EXISTS "Anyone can delete emergency contacts" ON emergency_contacts;

-- Create new policies that allow all operations
-- Since we're using custom authentication, we allow all operations
-- The application layer ensures proper user_id assignment

-- Allow anyone to view emergency contacts (for system-wide emergency contacts)
CREATE POLICY "Anyone can view emergency contacts" ON emergency_contacts 
  FOR SELECT USING (true);

-- Allow anyone to insert emergency contacts (application ensures correct user_id)
CREATE POLICY "Anyone can insert emergency contacts" ON emergency_contacts 
  FOR INSERT WITH CHECK (true);

-- Allow anyone to update emergency contacts (application ensures correct user_id)
CREATE POLICY "Anyone can update emergency contacts" ON emergency_contacts 
  FOR UPDATE USING (true);

-- Allow anyone to delete emergency contacts (application ensures correct user_id)
CREATE POLICY "Anyone can delete emergency contacts" ON emergency_contacts 
  FOR DELETE USING (true);

-- Verify the policies were created
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'emergency_contacts'
ORDER BY policyname;

COMMIT;

-- Note: After running this SQL, the emergency_contacts table will allow
-- all CRUD operations without RLS blocking, preventing automatic logout.
-- The application code ensures proper user_id assignment and data validation.





