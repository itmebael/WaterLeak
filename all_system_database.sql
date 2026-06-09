-- Water Leak Detection System - Complete Supabase SQL
-- Paste this whole file into the Supabase SQL Editor and run it once.
-- It is written to be safe to run again for updates/fixes.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Core helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_updated_at_trigger(p_table regclass)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  table_name text;
  trigger_name text;
BEGIN
  table_name := split_part(p_table::text, '.', 2);
  IF table_name = '' THEN
    table_name := p_table::text;
  END IF;
  trigger_name := 'update_' || table_name || '_updated_at';

  EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', trigger_name, p_table);
  EXECUTE format(
    'CREATE TRIGGER %I BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column()',
    trigger_name,
    p_table
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Users and custom auth
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email varchar(255) UNIQUE NOT NULL,
  password_hash text NOT NULL DEFAULT '',
  first_name varchar(100) NOT NULL DEFAULT '',
  last_name varchar(100) NOT NULL DEFAULT '',
  full_name text,
  username text UNIQUE,
  phone varchar(20),
  phone_number varchar(20),
  address text,
  city varchar(100),
  state varchar(100),
  zip_code varchar(20),
  country varchar(100) DEFAULT 'Philippines',
  profile_image_url text,
  role text NOT NULL DEFAULT 'user',
  is_active boolean DEFAULT true,
  is_verified boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT users_role_check CHECK (role IN ('user', 'admin', 'moderator'))
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password_hash text NOT NULL DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS first_name varchar(100) NOT NULL DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_name varchar(100) NOT NULL DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS username text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone varchar(20);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone_number varchar(20);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'user';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT true;

CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_idx ON public.users (lower(email));
CREATE INDEX IF NOT EXISTS users_role_idx ON public.users (role);

CREATE TABLE IF NOT EXISTS public.user_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  session_token text UNIQUE NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON public.user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions(user_id);

CREATE OR REPLACE FUNCTION public.register_user(
  user_email text,
  user_password text,
  user_full_name text DEFAULT NULL,
  user_username text DEFAULT NULL,
  user_phone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  clean_email text := lower(trim(user_email));
  clean_full_name text := nullif(trim(coalesce(user_full_name, '')), '');
  first_part text := '';
  last_part text := '';
  new_user_id uuid;
  new_token text;
BEGIN
  IF clean_email IS NULL OR clean_email = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Email is required');
  END IF;

  IF user_password IS NULL OR length(user_password) < 6 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Password must be at least 6 characters');
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE lower(email) = clean_email) THEN
    SELECT id INTO new_user_id FROM public.users WHERE lower(email) = clean_email LIMIT 1;
    new_token := encode(gen_random_bytes(32), 'hex');
    INSERT INTO public.user_sessions (user_id, session_token) VALUES (new_user_id, new_token);
    RETURN jsonb_build_object(
      'success', true,
      'user_id', new_user_id,
      'session_token', new_token,
      'message', 'User already exists'
    );
  END IF;

  IF clean_full_name IS NOT NULL THEN
    first_part := split_part(clean_full_name, ' ', 1);
    last_part := trim(regexp_replace(clean_full_name, '^\S+\s*', ''));
  END IF;

  INSERT INTO public.users (
    email,
    password_hash,
    first_name,
    last_name,
    full_name,
    username,
    phone,
    phone_number,
    is_active,
    is_verified,
    role
  )
  VALUES (
    clean_email,
    crypt(user_password, gen_salt('bf')),
    coalesce(nullif(first_part, ''), clean_email),
    coalesce(nullif(last_part, ''), ''),
    clean_full_name,
    nullif(trim(coalesce(user_username, '')), ''),
    user_phone,
    user_phone,
    true,
    true,
    CASE WHEN clean_email IN ('admin@waterleak.com', 'admin@example.com', 'admin@localhost') THEN 'admin' ELSE 'user' END
  )
  RETURNING id INTO new_user_id;

  new_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO public.user_sessions (user_id, session_token) VALUES (new_user_id, new_token);

  RETURN jsonb_build_object(
    'success', true,
    'user_id', new_user_id,
    'session_token', new_token,
    'message', 'Registration successful'
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'Email or username already exists');
  WHEN others THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.login_user(user_email text, user_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  clean_email text := lower(trim(user_email));
  found_user public.users%rowtype;
  new_token text;
BEGIN
  SELECT * INTO found_user
  FROM public.users
  WHERE lower(email) = clean_email AND is_active = true
  LIMIT 1;

  IF found_user.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid email or password');
  END IF;

  IF found_user.password_hash IS NULL
     OR found_user.password_hash = ''
     OR found_user.password_hash <> crypt(user_password, found_user.password_hash) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid email or password');
  END IF;

  UPDATE public.user_sessions SET is_active = false, updated_at = now() WHERE user_id = found_user.id;
  new_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO public.user_sessions (user_id, session_token) VALUES (found_user.id, new_token);

  RETURN jsonb_build_object(
    'success', true,
    'user_id', found_user.id,
    'session_token', new_token,
    'message', 'Login successful'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.logout_user(session_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.user_sessions
  SET is_active = false, updated_at = now()
  WHERE user_sessions.session_token = logout_user.session_token;
  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_session(session_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  found_user jsonb;
BEGIN
  SELECT to_jsonb(u) - 'password_hash'
  INTO found_user
  FROM public.user_sessions s
  JOIN public.users u ON u.id = s.user_id
  WHERE s.session_token = validate_session.session_token
    AND s.is_active = true
    AND s.expires_at > now()
    AND u.is_active = true
  LIMIT 1;

  IF found_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'valid', false, 'error', 'Invalid or expired session');
  END IF;

  RETURN jsonb_build_object('success', true, 'valid', true, 'user', found_user);
END;
$$;

-- ---------------------------------------------------------------------------
-- Properties, pipelines, consumption, leaks
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.properties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  property_name varchar(255) NOT NULL,
  property_type varchar(100) NOT NULL DEFAULT 'residential',
  address text NOT NULL DEFAULT 'Unknown Address',
  city varchar(100) NOT NULL DEFAULT 'Catbalogan',
  state varchar(100) NOT NULL DEFAULT 'Samar',
  zip_code varchar(20) NOT NULL DEFAULT '6700',
  total_area numeric(10,2),
  number_of_floors integer DEFAULT 1,
  year_built integer,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pipeline_segments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  segment_name varchar(255) NOT NULL,
  segment_type varchar(100) NOT NULL,
  location_description text,
  material varchar(100),
  diameter varchar(50),
  age_years integer,
  installation_date date,
  coordinates jsonb,
  status varchar(50) DEFAULT 'active',
  pressure_threshold_min numeric(5,2),
  pressure_threshold_max numeric(5,2),
  flow_threshold_min numeric(5,2),
  flow_threshold_max numeric(5,2),
  last_inspection_date date,
  next_inspection_date date,
  is_monitored boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.water_consumption_daily (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  segment_id uuid REFERENCES public.pipeline_segments(id) ON DELETE SET NULL,
  consumption_date date NOT NULL,
  total_consumption_liters numeric(10,2) NOT NULL DEFAULT 0,
  peak_consumption_liters numeric(10,2),
  average_flow_rate numeric(5,2),
  peak_flow_rate numeric(5,2),
  number_of_usage_events integer DEFAULT 0,
  duration_minutes integer DEFAULT 0,
  cost_php numeric(10,2) DEFAULT 0,
  is_anomaly boolean DEFAULT false,
  anomaly_score numeric(3,2),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(property_id, segment_id, consumption_date)
);

CREATE TABLE IF NOT EXISTS public.water_consumption_weekly (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  week_start_date date NOT NULL,
  week_end_date date NOT NULL,
  total_consumption_liters numeric(10,2) NOT NULL DEFAULT 0,
  average_daily_consumption numeric(10,2),
  peak_daily_consumption numeric(10,2),
  total_cost_php numeric(10,2) DEFAULT 0,
  number_of_anomaly_days integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(property_id, week_start_date)
);

CREATE TABLE IF NOT EXISTS public.water_consumption_monthly (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  year integer NOT NULL,
  month integer NOT NULL CHECK (month BETWEEN 1 AND 12),
  total_consumption_liters numeric(12,2) NOT NULL DEFAULT 0,
  average_daily_consumption numeric(10,2),
  peak_daily_consumption numeric(10,2),
  total_cost_php numeric(10,2) DEFAULT 0,
  number_of_anomaly_days integer DEFAULT 0,
  water_savings_liters numeric(10,2) DEFAULT 0,
  money_saved_php numeric(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(property_id, year, month)
);

CREATE TABLE IF NOT EXISTS public.water_leak_detections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  segment_id uuid REFERENCES public.pipeline_segments(id) ON DELETE SET NULL,
  detection_date timestamptz NOT NULL DEFAULT now(),
  leak_type varchar(100) NOT NULL DEFAULT 'unknown',
  severity varchar(50) NOT NULL DEFAULT 'medium',
  status varchar(50) DEFAULT 'active',
  location_description text,
  estimated_water_loss_liters numeric(10,2),
  estimated_water_loss_rate numeric(5,2),
  pressure_drop numeric(5,2),
  flow_rate_anomaly numeric(5,2),
  sensor_data jsonb DEFAULT '{}'::jsonb,
  confidence_score numeric(3,2),
  is_false_positive boolean DEFAULT false,
  resolved_date timestamptz,
  resolution_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.leak_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  leak_detection_id uuid REFERENCES public.water_leak_detections(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  notification_type varchar(100) NOT NULL DEFAULT 'in_app',
  title varchar(255) NOT NULL,
  message text NOT NULL,
  severity varchar(50) NOT NULL DEFAULT 'medium',
  is_read boolean DEFAULT false,
  is_sent boolean DEFAULT false,
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.leak_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  leak_detection_id uuid REFERENCES public.water_leak_detections(id) ON DELETE CASCADE,
  action_taken varchar(255) NOT NULL,
  action_description text,
  action_date timestamptz NOT NULL DEFAULT now(),
  performed_by varchar(255),
  cost_php numeric(10,2) DEFAULT 0,
  repair_duration_minutes integer,
  parts_replaced text,
  notes text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sensor_readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  segment_id uuid REFERENCES public.pipeline_segments(id) ON DELETE CASCADE,
  reading_timestamp timestamptz NOT NULL DEFAULT now(),
  pressure_psi numeric(5,2),
  flow_rate_lpm numeric(5,2),
  temperature_celsius numeric(4,2),
  humidity_percent numeric(4,2),
  vibration_level numeric(4,2),
  sensor_status varchar(50) DEFAULT 'normal',
  battery_level numeric(3,2),
  signal_strength integer,
  raw_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Controls, devices, water data, history
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.water_switch_controls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  segment_id uuid REFERENCES public.pipeline_segments(id) ON DELETE CASCADE,
  switch_name varchar(255) NOT NULL,
  switch_type varchar(100) NOT NULL DEFAULT 'manual',
  current_status varchar(50) DEFAULT 'off',
  last_activated timestamptz,
  last_deactivated timestamptz,
  activation_reason text,
  deactivation_reason text,
  is_auto_shutoff_enabled boolean DEFAULT true,
  auto_shutoff_threshold numeric(5,2),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  device_name text NOT NULL,
  device_status text DEFAULT 'active',
  valve_status text DEFAULT 'CLOSED',
  water_flow numeric(10,2) DEFAULT 0.00,
  device_location text,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  segment_id uuid REFERENCES public.pipeline_segments(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.kitchen_valve_control (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  valve_status text NOT NULL DEFAULT 'closed',
  created_at timestamptz DEFAULT now(),
  CONSTRAINT kitchen_valve_control_valve_status_check CHECK (valve_status IN ('open', 'closed'))
);

CREATE TABLE IF NOT EXISTS public.water_data (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flow_rate numeric(12,6),
  total_used numeric(12,6),
  pressure numeric(5,2),
  temperature numeric(4,2),
  timestamp timestamptz DEFAULT now(),
  sensor_id varchar(100),
  location varchar(255),
  leak_detected boolean DEFAULT false,
  valve_status boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.device_status (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_name text NOT NULL,
  valve_status text NOT NULL DEFAULT 'CLOSED',
  water_flow numeric(6,2) DEFAULT 0.00,
  status text NOT NULL DEFAULT 'OFFLINE',
  last_update timestamptz DEFAULT now(),
  CONSTRAINT unique_device_name UNIQUE (device_name)
);

CREATE TABLE IF NOT EXISTS public.water_connection_control (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id varchar(100) NOT NULL UNIQUE,
  device_name text NOT NULL,
  valve_status text NOT NULL DEFAULT 'closed',
  water_flow numeric(10,2) DEFAULT 0.00,
  pressure numeric(5,2) DEFAULT 0.00,
  temperature numeric(4,2) DEFAULT 0.00,
  is_online boolean DEFAULT false,
  last_heartbeat timestamptz DEFAULT now(),
  location text,
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  total_water_used numeric(10,2) DEFAULT 0.00,
  sensor_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT water_connection_control_valve_status_check CHECK (valve_status IN ('open', 'closed'))
);

CREATE TABLE IF NOT EXISTS public.water_connection_commands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id varchar(100) NOT NULL,
  command_type text NOT NULL,
  command_data jsonb,
  status text NOT NULL DEFAULT 'pending',
  executed_at timestamptz,
  error_message text,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT water_connection_commands_status_check CHECK (status IN ('pending', 'executed', 'failed'))
);

CREATE TABLE IF NOT EXISTS public.water_connection_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id varchar(100) NOT NULL,
  event_type text NOT NULL,
  event_data jsonb,
  valve_status text,
  water_flow numeric(10,2),
  pressure numeric(5,2),
  temperature numeric(4,2),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.water_connection_control_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id varchar(100) NOT NULL,
  device_name text,
  valve_status text,
  water_flow numeric(10,2) DEFAULT 0.00,
  pressure numeric(5,2) DEFAULT 0.00,
  temperature numeric(4,2) DEFAULT 0.00,
  is_online boolean DEFAULT false,
  last_heartbeat timestamptz,
  location text,
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  total_water_used numeric(10,2) DEFAULT 0.00,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  source text DEFAULT 'manual',
  sensor_data jsonb DEFAULT '{}'::jsonb
);

-- Legacy table used by one sample-data path in the Flutter service.
CREATE TABLE IF NOT EXISTS public.water_control_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id varchar(100) NOT NULL,
  timestamp timestamptz DEFAULT now(),
  water_flow numeric(10,2) DEFAULT 0.00,
  pressure numeric(5,2) DEFAULT 0.00,
  temperature numeric(4,2) DEFAULT 0.00,
  valve_status text,
  is_online boolean DEFAULT false,
  total_water_used numeric(10,2) DEFAULT 0.00,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Admin/content/support tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.emergency_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  contact_type varchar(100) NOT NULL DEFAULT 'emergency',
  name varchar(255) NOT NULL,
  phone varchar(20) NOT NULL,
  email varchar(255),
  company varchar(255),
  address text,
  is_primary boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.system_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  setting_key varchar(255) NOT NULL,
  setting_value text,
  setting_type varchar(50) DEFAULT 'string',
  description text,
  is_system_setting boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS system_settings_user_key_idx
ON public.system_settings (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), setting_key);

CREATE TABLE IF NOT EXISTS public.announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  message text NOT NULL,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.water_savings_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  target_type varchar(100) NOT NULL,
  target_period_start date NOT NULL,
  target_period_end date NOT NULL,
  target_consumption_liters numeric(10,2) NOT NULL,
  actual_consumption_liters numeric(10,2) DEFAULT 0,
  target_savings_percent numeric(5,2),
  target_savings_liters numeric(10,2),
  is_achieved boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.maintenance_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  segment_id uuid REFERENCES public.pipeline_segments(id) ON DELETE SET NULL,
  maintenance_type varchar(100) NOT NULL,
  scheduled_date date NOT NULL,
  completed_date date,
  status varchar(50) DEFAULT 'scheduled',
  description text,
  assigned_to varchar(255),
  cost_php numeric(10,2) DEFAULT 0,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Repair columns when this is run on an older/partial database.
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES public.users(id) ON DELETE CASCADE;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS property_name varchar(255);
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS property_type varchar(100) DEFAULT 'residential';
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS address text DEFAULT 'Unknown Address';
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS city varchar(100) DEFAULT 'Catbalogan';
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS state varchar(100) DEFAULT 'Samar';
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS zip_code varchar(20) DEFAULT '6700';
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE;
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS segment_id uuid REFERENCES public.pipeline_segments(id) ON DELETE SET NULL;
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS detection_date timestamptz DEFAULT now();
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS leak_type varchar(100) DEFAULT 'unknown';
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS severity varchar(50) DEFAULT 'medium';
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS status varchar(50) DEFAULT 'active';
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS location_description text;
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS sensor_data jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS confidence_score numeric(3,2);
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS resolved_date timestamptz;
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS resolution_notes text;
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.water_leak_detections ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS flow_rate numeric(12,6);
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS total_used numeric(12,6);
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS pressure numeric(5,2);
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS temperature numeric(4,2);
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS timestamp timestamptz DEFAULT now();
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS sensor_id varchar(100);
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS location varchar(255);
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS leak_detected boolean DEFAULT false;
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS valve_status boolean DEFAULT true;
ALTER TABLE public.water_data ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS device_id varchar(100);
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS device_name text;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS valve_status text DEFAULT 'closed';
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS water_flow numeric(10,2) DEFAULT 0.00;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS pressure numeric(5,2) DEFAULT 0.00;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS temperature numeric(4,2) DEFAULT 0.00;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT false;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS last_heartbeat timestamptz DEFAULT now();
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS total_water_used numeric(10,2) DEFAULT 0.00;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS sensor_data jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.water_connection_control ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS device_id varchar(100);
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS device_name text;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS valve_status text;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS water_flow numeric(10,2) DEFAULT 0.00;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS pressure numeric(5,2) DEFAULT 0.00;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS temperature numeric(4,2) DEFAULT 0.00;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT false;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS last_heartbeat timestamptz;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS total_water_used numeric(10,2) DEFAULT 0.00;
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS recorded_at timestamptz DEFAULT now();
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS source text DEFAULT 'manual';
ALTER TABLE public.water_connection_control_history ADD COLUMN IF NOT EXISTS sensor_data jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS message text;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ---------------------------------------------------------------------------
-- History/leak automation
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.log_water_connection_control_history()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  sensor_key text;
  leak_message text := '';
  new_leak_id uuid;
BEGIN
  INSERT INTO public.water_connection_control_history (
    device_id, device_name, valve_status, water_flow, pressure, temperature,
    is_online, last_heartbeat, location, user_id, property_id, total_water_used,
    recorded_at, source, sensor_data
  )
  VALUES (
    NEW.device_id, NEW.device_name, NEW.valve_status, NEW.water_flow, NEW.pressure,
    NEW.temperature, NEW.is_online, NEW.last_heartbeat, NEW.location, NEW.user_id,
    NEW.property_id, NEW.total_water_used, coalesce(NEW.updated_at, now()), TG_OP,
    coalesce(NEW.sensor_data, '{}'::jsonb)
  );

  FOR sensor_key IN
    SELECT key
    FROM jsonb_each(coalesce(NEW.sensor_data, '{}'::jsonb))
    WHERE value = 'true'::jsonb
  LOOP
    leak_message := concat_ws(', ', nullif(leak_message, ''), sensor_key || ' leak');
  END LOOP;

  IF leak_message <> '' THEN
    INSERT INTO public.water_leak_detections (
      property_id, detection_date, leak_type, severity, status, location_description, sensor_data, confidence_score
    )
    VALUES (
      NEW.property_id, now(), 'sensor_detected', 'high', 'active', NEW.location, NEW.sensor_data, 0.95
    )
    RETURNING id INTO new_leak_id;

    INSERT INTO public.leak_notifications (
      leak_detection_id, user_id, notification_type, title, message, severity
    )
    VALUES (
      new_leak_id, NEW.user_id, 'in_app', 'Water Leak Detected', 'Leak detected: ' || leak_message, 'high'
    );

    INSERT INTO public.leak_history (
      leak_detection_id, action_taken, action_description, action_date, performed_by, notes
    )
    VALUES (
      new_leak_id, 'detection', 'Leak detected by sensors: ' || leak_message, now(), 'system', leak_message
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_log_water_control_history ON public.water_connection_control;
CREATE TRIGGER trigger_log_water_control_history
AFTER INSERT OR UPDATE ON public.water_connection_control
FOR EACH ROW
EXECUTE FUNCTION public.log_water_connection_control_history();

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_properties_user_id ON public.properties(user_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_segments_property_id ON public.pipeline_segments(property_id);
CREATE INDEX IF NOT EXISTS idx_water_consumption_daily_property_date ON public.water_consumption_daily(property_id, consumption_date);
CREATE INDEX IF NOT EXISTS idx_water_consumption_weekly_property_week ON public.water_consumption_weekly(property_id, week_start_date);
CREATE INDEX IF NOT EXISTS idx_water_consumption_monthly_property_year_month ON public.water_consumption_monthly(property_id, year, month);
CREATE INDEX IF NOT EXISTS idx_water_leak_detections_property_date ON public.water_leak_detections(property_id, detection_date);
CREATE INDEX IF NOT EXISTS idx_water_leak_detections_status ON public.water_leak_detections(status);
CREATE INDEX IF NOT EXISTS idx_leak_notifications_user_id ON public.leak_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_segment_timestamp ON public.sensor_readings(segment_id, reading_timestamp);
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON public.emergency_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON public.devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_created_at ON public.devices(created_at);
CREATE INDEX IF NOT EXISTS idx_kitchen_valve_control_status ON public.kitchen_valve_control(valve_status);
CREATE INDEX IF NOT EXISTS idx_water_data_created_at ON public.water_data(created_at);
CREATE INDEX IF NOT EXISTS idx_water_data_location ON public.water_data(location);
CREATE INDEX IF NOT EXISTS idx_water_data_sensor_id ON public.water_data(sensor_id);
CREATE INDEX IF NOT EXISTS idx_water_control_device_id ON public.water_connection_control(device_id);
CREATE INDEX IF NOT EXISTS idx_water_control_location ON public.water_connection_control(location);
CREATE INDEX IF NOT EXISTS idx_water_control_is_online ON public.water_connection_control(is_online);
CREATE INDEX IF NOT EXISTS idx_water_control_sensor_data ON public.water_connection_control USING gin(sensor_data);
CREATE INDEX IF NOT EXISTS idx_water_connection_commands_device_id ON public.water_connection_commands(device_id);
CREATE INDEX IF NOT EXISTS idx_water_connection_commands_status ON public.water_connection_commands(status);
CREATE INDEX IF NOT EXISTS idx_water_connection_logs_device_id ON public.water_connection_logs(device_id);
CREATE INDEX IF NOT EXISTS idx_water_connection_logs_created_at ON public.water_connection_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_water_control_hist_device_id ON public.water_connection_control_history(device_id);
CREATE INDEX IF NOT EXISTS idx_water_control_hist_recorded_at_desc ON public.water_connection_control_history(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_water_control_hist_property_id ON public.water_connection_control_history(property_id);
CREATE INDEX IF NOT EXISTS idx_water_control_hist_user_id ON public.water_connection_control_history(user_id);
CREATE INDEX IF NOT EXISTS idx_water_control_hist_sensor_data ON public.water_connection_control_history USING gin(sensor_data);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

SELECT public.set_updated_at_trigger('public.users');
SELECT public.set_updated_at_trigger('public.user_sessions');
SELECT public.set_updated_at_trigger('public.properties');
SELECT public.set_updated_at_trigger('public.pipeline_segments');
SELECT public.set_updated_at_trigger('public.water_consumption_daily');
SELECT public.set_updated_at_trigger('public.water_consumption_weekly');
SELECT public.set_updated_at_trigger('public.water_consumption_monthly');
SELECT public.set_updated_at_trigger('public.water_leak_detections');
SELECT public.set_updated_at_trigger('public.water_switch_controls');
SELECT public.set_updated_at_trigger('public.devices');
SELECT public.set_updated_at_trigger('public.water_connection_control');
SELECT public.set_updated_at_trigger('public.emergency_contacts');
SELECT public.set_updated_at_trigger('public.system_settings');
SELECT public.set_updated_at_trigger('public.announcements');
SELECT public.set_updated_at_trigger('public.water_savings_targets');
SELECT public.set_updated_at_trigger('public.maintenance_schedules');

-- ---------------------------------------------------------------------------
-- RLS and permissive policies for this app's custom auth and ESP devices
-- ---------------------------------------------------------------------------

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_consumption_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_consumption_weekly ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_consumption_monthly ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_leak_detections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leak_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leak_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_switch_controls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchen_valve_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_connection_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_connection_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_connection_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_connection_control_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_control_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_savings_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_schedules ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'users','user_sessions','properties','pipeline_segments','water_consumption_daily',
    'water_consumption_weekly','water_consumption_monthly','water_leak_detections',
    'leak_notifications','leak_history','sensor_readings','water_switch_controls',
    'devices','kitchen_valve_control','water_data','device_status',
    'water_connection_control','water_connection_commands','water_connection_logs',
    'water_connection_control_history','water_control_history','emergency_contacts',
    'system_settings','announcements','water_savings_targets','maintenance_schedules'
  ]
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS app_select ON public.%I', tbl);
    EXECUTE format('DROP POLICY IF EXISTS app_insert ON public.%I', tbl);
    EXECUTE format('DROP POLICY IF EXISTS app_update ON public.%I', tbl);
    EXECUTE format('DROP POLICY IF EXISTS app_delete ON public.%I', tbl);
    EXECUTE format('CREATE POLICY app_select ON public.%I FOR SELECT USING (true)', tbl);
    EXECUTE format('CREATE POLICY app_insert ON public.%I FOR INSERT WITH CHECK (true)', tbl);
    EXECUTE format('CREATE POLICY app_update ON public.%I FOR UPDATE USING (true) WITH CHECK (true)', tbl);
    EXECUTE format('CREATE POLICY app_delete ON public.%I FOR DELETE USING (true)', tbl);
  END LOOP;
END $$;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Default data
-- ---------------------------------------------------------------------------

INSERT INTO public.system_settings (setting_key, setting_value, setting_type, description, is_system_setting)
SELECT *
FROM (VALUES
  ('default_pressure_threshold_min', '30.0', 'number', 'Minimum pressure threshold in PSI', true),
  ('default_pressure_threshold_max', '80.0', 'number', 'Maximum pressure threshold in PSI', true),
  ('default_flow_threshold_min', '0.5', 'number', 'Minimum flow rate threshold in LPM', true),
  ('default_flow_threshold_max', '50.0', 'number', 'Maximum flow rate threshold in LPM', true),
  ('leak_detection_sensitivity', '0.7', 'number', 'Leak detection sensitivity (0.0-1.0)', true),
  ('notification_cooldown_minutes', '30', 'number', 'Minutes between notifications for same leak', true),
  ('auto_shutoff_enabled', 'true', 'boolean', 'Enable automatic water shutoff on leak detection', true),
  ('water_rate_per_liter', '0.05', 'number', 'Water rate per liter in PHP', true)
) AS v(setting_key, setting_value, setting_type, description, is_system_setting)
WHERE NOT EXISTS (
  SELECT 1 FROM public.system_settings s
  WHERE s.user_id IS NULL AND s.setting_key = v.setting_key
);

INSERT INTO public.emergency_contacts (user_id, contact_type, name, phone, email, company, is_primary, is_active)
SELECT *
FROM (VALUES
  (NULL::uuid, 'plumber', 'Juan Dela Cruz', '+63 912 345 6789', 'juan.delacruz@email.com', 'Catbalogan Plumbing Services', true, true),
  (NULL::uuid, 'emergency', 'Catbalogan Water District', '+63 55 251 2345', 'info@catbaloganwater.gov.ph', 'Catbalogan Water District', true, true),
  (NULL::uuid, 'developer', 'Tech Solutions Inc.', '+63 917 123 4567', 'support@techsolutions.ph', 'Tech Solutions Inc.', true, true)
) AS v(user_id, contact_type, name, phone, email, company, is_primary, is_active)
WHERE NOT EXISTS (
  SELECT 1 FROM public.emergency_contacts e
  WHERE e.user_id IS NULL AND e.name = v.name AND e.phone = v.phone
);

INSERT INTO public.kitchen_valve_control (valve_status)
SELECT 'closed'
WHERE NOT EXISTS (SELECT 1 FROM public.kitchen_valve_control);

INSERT INTO public.device_status (device_name, valve_status, water_flow, status)
VALUES
  ('Main Line', 'OPEN', 12.00, 'ONLINE'),
  ('Kitchen Line', 'OPEN', 5.50, 'ONLINE'),
  ('Bathroom Line', 'OPEN', 4.20, 'ONLINE'),
  ('Device 1', 'CLOSED', 0.00, 'ONLINE'),
  ('Device 2', 'CLOSED', 0.00, 'OFFLINE'),
  ('Device 3', 'CLOSED', 0.00, 'OFFLINE')
ON CONFLICT (device_name) DO NOTHING;

INSERT INTO public.water_connection_control (
  device_id, device_name, location, valve_status, water_flow, pressure,
  temperature, is_online, last_heartbeat, total_water_used, sensor_data
)
VALUES
  ('ESP_KITCHEN_001', 'Kitchen Valve', 'Kitchen', 'closed', 0.00, 45.00, 25.00, true, now(), 0.00, '{}'::jsonb),
  ('ESP_BATHROOM_001', 'Bathroom Valve', 'Bathroom', 'closed', 0.00, 42.00, 24.50, true, now(), 0.00, '{}'::jsonb),
  ('ESP_GARDEN_001', 'Garden Valve', 'Garden', 'closed', 0.00, 40.00, 25.20, true, now(), 0.00, '{}'::jsonb)
ON CONFLICT (device_id) DO NOTHING;

INSERT INTO public.water_data (flow_rate, total_used, pressure, temperature, sensor_id, location, valve_status)
SELECT *
FROM (VALUES
  (2.5::numeric, 150.25::numeric, 45.0::numeric, 25.0::numeric, 'sensor_001', 'Kitchen', true),
  (1.8::numeric, 89.75::numeric, 42.0::numeric, 24.5::numeric, 'sensor_002', 'Bathroom', true),
  (0.0::numeric, 0.0::numeric, 40.0::numeric, 25.2::numeric, 'sensor_003', 'Garden', false)
) AS v(flow_rate, total_used, pressure, temperature, sensor_id, location, valve_status)
WHERE NOT EXISTS (SELECT 1 FROM public.water_data);

UPDATE public.users
SET role = 'admin'
WHERE lower(email) IN ('admin@waterleak.com', 'admin@example.com', 'admin@localhost');

-- Done.
