-- Fix auth RPC password hashing on Supabase.
-- pgcrypto functions such as gen_salt, crypt, and gen_random_bytes are exposed
-- through the extensions schema in Supabase projects.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

ALTER FUNCTION public.register_user(text, text, text, text, text)
  SET search_path = public, extensions;

ALTER FUNCTION public.login_user(text, text)
  SET search_path = public, extensions;
