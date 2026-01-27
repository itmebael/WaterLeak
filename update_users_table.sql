-- Update users table to include role column if it doesn't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';

-- Add check constraint for valid roles
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'admin', 'moderator'));

-- Update existing admin users
-- Replace with your admin email if different
UPDATE public.users
SET role = 'admin'
WHERE lower(email) IN (
  'admin@waterleak.com',
  'admin@example.com',
  'admin@localhost'
);

-- Create an index on role for faster lookups
CREATE INDEX IF NOT EXISTS users_role_idx ON public.users (role);

-- Ensure RLS policies allow reading own user data
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE lower(u.email) = lower((auth.jwt() ->> 'email'))
      AND u.role = 'admin'
  );
$$;

DROP POLICY IF EXISTS "Users can view their own data" ON public.users;
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;

CREATE POLICY "Users can view their own data" ON public.users
  FOR SELECT
  USING (
    public.is_admin()
    OR lower(email) = lower((auth.jwt() ->> 'email'))
  );

CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE
  USING (
    public.is_admin()
    OR lower(email) = lower((auth.jwt() ->> 'email'))
  )
  WITH CHECK (
    public.is_admin()
    OR lower(email) = lower((auth.jwt() ->> 'email'))
  );

CREATE POLICY "Admins can view all users" ON public.users
  FOR SELECT
  USING (public.is_admin());
