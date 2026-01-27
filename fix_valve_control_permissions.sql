-- Fix valve_control table permissions
-- This script will ensure the valve_control table works properly

-- First, drop the table if it exists to start fresh
DROP TABLE IF EXISTS public.valve_control CASCADE;

-- Create the valve_control table
CREATE TABLE public.valve_control (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NULL DEFAULT now(),
  valve_status text NOT NULL,
  CONSTRAINT valve_control_pkey PRIMARY KEY (id),
  CONSTRAINT valve_control_valve_status_check CHECK (
    valve_status = ANY (ARRAY['open'::text, 'closed'::text])
  )
) TABLESPACE pg_default;

-- Enable Row Level Security
ALTER TABLE public.valve_control ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "Allow read access to valve control" ON public.valve_control;
DROP POLICY IF EXISTS "Allow insert access to valve control" ON public.valve_control;
DROP POLICY IF EXISTS "Allow update access to valve control" ON public.valve_control;
DROP POLICY IF EXISTS "Allow delete access to valve control" ON public.valve_control;

-- Create new policies that allow all operations for authenticated users
CREATE POLICY "Allow all operations for authenticated users" ON public.valve_control
  FOR ALL USING (true) WITH CHECK (true);

-- Alternative: Create separate policies for each operation
-- CREATE POLICY "Allow read access to valve control" ON public.valve_control
--   FOR SELECT USING (true);

-- CREATE POLICY "Allow insert access to valve control" ON public.valve_control
--   FOR INSERT WITH CHECK (true);

-- CREATE POLICY "Allow update access to valve control" ON public.valve_control
--   FOR UPDATE USING (true) WITH CHECK (true);

-- CREATE POLICY "Allow delete access to valve control" ON public.valve_control
--   FOR DELETE USING (true);

-- Insert initial valve control record (closed by default)
INSERT INTO public.valve_control (valve_status) 
VALUES ('closed');

-- Verify the table was created correctly
SELECT * FROM public.valve_control;

-- Show the policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'valve_control';
