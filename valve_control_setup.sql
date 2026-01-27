-- Valve Control Table Setup
-- This script sets up the valve_control table with proper RLS policies

-- Create the valve_control table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS public.valve_control (
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

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow read access to valve control" ON public.valve_control;
DROP POLICY IF EXISTS "Allow insert access to valve control" ON public.valve_control;
DROP POLICY IF EXISTS "Allow update access to valve control" ON public.valve_control;

-- Create RLS policies
-- Allow all users to read valve control data
CREATE POLICY "Allow read access to valve control" ON public.valve_control
  FOR SELECT USING (true);

-- Allow all users to insert valve control data
CREATE POLICY "Allow insert access to valve control" ON public.valve_control
  FOR INSERT WITH CHECK (true);

-- Allow all users to update valve control data
CREATE POLICY "Allow update access to valve control" ON public.valve_control
  FOR UPDATE USING (true);

-- Insert initial valve control record (closed by default)
INSERT INTO public.valve_control (valve_status) 
VALUES ('closed')
ON CONFLICT DO NOTHING;

-- Grant necessary permissions
GRANT ALL ON public.valve_control TO authenticated;
GRANT ALL ON public.valve_control TO anon;
