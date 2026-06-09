-- Create water_connection_control table
CREATE TABLE IF NOT EXISTS public.water_connection_control (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    device_id character varying(100) NOT NULL,
    device_name text NOT NULL,
    valve_status text NOT NULL DEFAULT 'closed'::text,
    water_flow numeric(10, 2) NULL DEFAULT 0.00,
    pressure numeric(5, 2) NULL DEFAULT 0.00,
    temperature numeric(4, 2) NULL DEFAULT 0.00,
    is_online boolean NULL DEFAULT false,
    last_heartbeat timestamp with time zone NULL DEFAULT now(),
    location text NULL,
    user_id uuid NULL,
    property_id uuid NULL,
    created_at timestamp with time zone NULL DEFAULT now(),
    updated_at timestamp with time zone NULL DEFAULT now(),
    total_water_used numeric(10, 2) NULL DEFAULT 0.00,
    sensor_data jsonb NULL DEFAULT '{}'::jsonb,
    CONSTRAINT water_connection_control_pkey PRIMARY KEY (id),
    CONSTRAINT water_connection_control_device_id_key UNIQUE (device_id),
    CONSTRAINT water_connection_control_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE SET NULL,
    CONSTRAINT water_connection_control_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT water_connection_control_valve_status_check CHECK (valve_status = ANY (ARRAY['open'::text, 'closed'::text]))
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_water_control_device_id ON public.water_connection_control USING btree (device_id);
CREATE INDEX IF NOT EXISTS idx_water_control_location ON public.water_connection_control USING btree (location);
CREATE INDEX IF NOT EXISTS idx_water_control_is_online ON public.water_connection_control USING btree (is_online);
CREATE INDEX IF NOT EXISTS idx_water_control_sensor_data ON public.water_connection_control USING gin (sensor_data);

-- Enable RLS for water_connection_control
ALTER TABLE public.water_connection_control ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid errors
DROP POLICY IF EXISTS "Anyone can view water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can insert water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can update water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can delete water connection control" ON water_connection_control;

-- Create permissive RLS policies (adjust as needed for production)
CREATE POLICY "Anyone can view water connection control" ON water_connection_control FOR SELECT USING (true);
CREATE POLICY "Anyone can insert water connection control" ON water_connection_control FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update water connection control" ON water_connection_control FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete water connection control" ON water_connection_control FOR DELETE USING (true);

-- Ensure water_connection_control_history has sensor_data
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
  source text NULL DEFAULT 'trigger',
  sensor_data jsonb NULL DEFAULT '{}'::jsonb
);

-- Add sensor_data column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'water_connection_control_history' AND column_name = 'sensor_data') THEN
        ALTER TABLE public.water_connection_control_history ADD COLUMN sensor_data jsonb NULL DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- Enable RLS for history
ALTER TABLE public.water_connection_control_history ENABLE ROW LEVEL SECURITY;
-- (Policies for history omitted for brevity, but table creation implies default deny if not added. 
--  However, since we are just creating the table, let's add basic policies to be safe.)
DROP POLICY IF EXISTS "Anyone can view water control history" ON public.water_connection_control_history;
CREATE POLICY "Anyone can view water control history" ON public.water_connection_control_history FOR SELECT USING (true);
-- (Other history policies can be added as needed)

-- Update updated_at function (alias)
CREATE OR REPLACE FUNCTION update_water_control_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Update log_water_connection_control_history function
CREATE OR REPLACE FUNCTION public.log_water_connection_control_history()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    sensor_key text;
    leak_message text := '';
    new_leak_id uuid;
BEGIN
    -- 1. Insert into history
    INSERT INTO public.water_connection_control_history (
        device_id, device_name, valve_status, water_flow, pressure, temperature,
        is_online, last_heartbeat, location, user_id, property_id,
        total_water_used, recorded_at, source, sensor_data
    )
    VALUES (
        NEW.device_id, NEW.device_name, NEW.valve_status, NEW.water_flow, NEW.pressure, NEW.temperature,
        NEW.is_online, NEW.last_heartbeat, NEW.location, NEW.user_id, NEW.property_id,
        NEW.total_water_used, COALESCE(NEW.updated_at, now()), TG_OP, NEW.sensor_data
    );

    -- 2. Check for leaks in sensor_data (where value is true)
    FOR sensor_key IN
        SELECT key
        FROM jsonb_each(NEW.sensor_data)
        WHERE value = 'true'::jsonb
    LOOP
        IF leak_message = '' THEN
            leak_message := sensor_key || ' leak';
        ELSE
            leak_message := leak_message || ', ' || sensor_key || ' leak';
        END IF;
    END LOOP;

    -- If leaks found, insert into notifications and leak history
    IF leak_message <> '' THEN
        -- Create a leak detection entry
        INSERT INTO public.water_leak_detections (
            property_id, detection_date, leak_type, severity, status, location_description, sensor_data
        ) VALUES (
            NEW.property_id, NOW(), 'sensor_detected', 'high', 'active', NEW.location, NEW.sensor_data
        ) RETURNING id INTO new_leak_id;

        -- Insert notification
        INSERT INTO public.leak_notifications (
            leak_detection_id, user_id, notification_type, title, message, severity
        ) VALUES (
            new_leak_id, NEW.user_id, 'in_app', 'Water Leak Detected', 'Leak detected: ' || leak_message, 'high'
        );

        -- Insert leak history
        INSERT INTO public.leak_history (
            leak_detection_id, action_taken, action_description, action_date, performed_by, notes
        ) VALUES (
            new_leak_id, 'detection', 'Leak detected by sensors: ' || leak_message, NOW(), 'system', leak_message
        );
    END IF;

    RETURN NEW;
END;
$$;

-- Create trigger for history logging
DROP TRIGGER IF EXISTS trigger_log_water_control_history ON public.water_connection_control;
CREATE TRIGGER trigger_log_water_control_history
AFTER INSERT OR UPDATE ON public.water_connection_control
FOR EACH ROW
EXECUTE FUNCTION public.log_water_connection_control_history();

-- Create trigger for updating updated_at
DROP TRIGGER IF EXISTS trigger_update_water_control_updated_at ON public.water_connection_control;
CREATE TRIGGER trigger_update_water_control_updated_at
BEFORE UPDATE ON public.water_connection_control
FOR EACH ROW
EXECUTE FUNCTION update_water_control_updated_at();

-- Grant permissions
GRANT ALL ON public.water_connection_control TO authenticated;
GRANT ALL ON public.water_connection_control TO anon;
GRANT ALL ON public.water_connection_control_history TO authenticated;
GRANT ALL ON public.water_connection_control_history TO anon;
