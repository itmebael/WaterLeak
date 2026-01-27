-- Water Connection Control History (time-series) from water_connection_control
-- This enables: Water Consumption, High Water Usage Analysis, Water Savings
-- Run in Supabase SQL editor.

BEGIN;

-- 1) History table (append-only)
CREATE TABLE IF NOT EXISTS public.water_connection_control_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id character varying(100) NOT NULL,
  device_name text NULL,
  valve_status text NULL,
  water_flow numeric(10, 2) NULL DEFAULT 0.00,
  pressure numeric(5, 2) NULL DEFAULT 0.00,
  temperature numeric(4, 2) NULL DEFAULT 0.00,
  is_online boolean NULL DEFAULT false,
  last_heartbeat timestamp with time zone NULL,
  location text NULL,
  user_id uuid NULL REFERENCES public.users(id) ON DELETE SET NULL,
  property_id uuid NULL REFERENCES public.properties(id) ON DELETE SET NULL,
  total_water_used numeric(10, 2) NULL DEFAULT 0.00,
  recorded_at timestamp with time zone NOT NULL DEFAULT now(),
  source text NULL DEFAULT 'trigger'
);

CREATE INDEX IF NOT EXISTS idx_water_control_hist_device_id
  ON public.water_connection_control_history(device_id);
CREATE INDEX IF NOT EXISTS idx_water_control_hist_recorded_at_desc
  ON public.water_connection_control_history(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_water_control_hist_property_id
  ON public.water_connection_control_history(property_id);
CREATE INDEX IF NOT EXISTS idx_water_control_hist_user_id
  ON public.water_connection_control_history(user_id);

-- 2) Trigger function to copy snapshots
CREATE OR REPLACE FUNCTION public.log_water_connection_control_history()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.water_connection_control_history (
    device_id,
    device_name,
    valve_status,
    water_flow,
    pressure,
    temperature,
    is_online,
    last_heartbeat,
    location,
    user_id,
    property_id,
    total_water_used,
    recorded_at,
    source
  )
  VALUES (
    NEW.device_id,
    NEW.device_name,
    NEW.valve_status,
    NEW.water_flow,
    NEW.pressure,
    NEW.temperature,
    NEW.is_online,
    NEW.last_heartbeat,
    NEW.location,
    NEW.user_id,
    NEW.property_id,
    NEW.total_water_used,
    COALESCE(NEW.updated_at, now()),
    TG_OP
  );

  RETURN NEW;
END;
$$;

-- 3) Trigger (log on insert/update)
DROP TRIGGER IF EXISTS trigger_log_water_control_history ON public.water_connection_control;
CREATE TRIGGER trigger_log_water_control_history
AFTER INSERT OR UPDATE ON public.water_connection_control
FOR EACH ROW
EXECUTE FUNCTION public.log_water_connection_control_history();

-- 4) RLS: match your permissive setup (ESP32 uses anon)
ALTER TABLE public.water_connection_control_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view water control history" ON public.water_connection_control_history;
DROP POLICY IF EXISTS "Anyone can insert water control history" ON public.water_connection_control_history;
DROP POLICY IF EXISTS "Anyone can update water control history" ON public.water_connection_control_history;
DROP POLICY IF EXISTS "Anyone can delete water control history" ON public.water_connection_control_history;

CREATE POLICY "Anyone can view water control history"
  ON public.water_connection_control_history
  FOR SELECT
  USING (true);

CREATE POLICY "Anyone can insert water control history"
  ON public.water_connection_control_history
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Anyone can update water control history"
  ON public.water_connection_control_history
  FOR UPDATE
  USING (true);

CREATE POLICY "Anyone can delete water control history"
  ON public.water_connection_control_history
  FOR DELETE
  USING (true);

GRANT ALL ON public.water_connection_control_history TO anon;
GRANT ALL ON public.water_connection_control_history TO authenticated;
GRANT ALL ON public.water_connection_control_history TO service_role;

COMMIT;


