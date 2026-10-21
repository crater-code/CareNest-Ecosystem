-- Migration 27: Denormalize full_name and avatar_url into profile tables

-- 1. Add columns
ALTER TABLE public.family_profiles ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE public.family_profiles ADD COLUMN IF NOT EXISTS avatar_url text;

ALTER TABLE public.sitter_profiles ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE public.sitter_profiles ADD COLUMN IF NOT EXISTS avatar_url text;

-- 2. Populate existing data
UPDATE public.family_profiles fp
SET full_name = u.full_name,
    avatar_url = u.avatar_url
FROM public.users u
WHERE fp.user_id = u.id;

UPDATE public.sitter_profiles sp
SET full_name = u.full_name,
    avatar_url = u.avatar_url
FROM public.users u
WHERE sp.user_id = u.id;

-- 3. Update handle_new_auth_user to include full_name in initial inserts
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role public.user_role;
  v_dob  date;
  v_full_name text;
BEGIN
  v_role := coalesce(
    (new.raw_user_meta_data->>'role')::public.user_role,
    'family'
  );
  
  v_full_name := coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), '');

  INSERT INTO public.users (id, role, email, full_name, phone)
  VALUES (
    new.id,
    v_role,
    new.email,
    v_full_name,
    nullif(trim(new.raw_user_meta_data->>'phone'), '')
  )
  ON CONFLICT (id) DO UPDATE SET
    email     = excluded.email,
    full_name = coalesce(excluded.full_name, public.users.full_name),
    phone     = coalesce(excluded.phone, public.users.phone);

  IF v_role = 'family' THEN
    INSERT INTO public.family_profiles (user_id, full_name)
    VALUES (new.id, v_full_name)
    ON CONFLICT (user_id) DO UPDATE SET
      full_name = v_full_name;

  ELSIF v_role = 'sitter' THEN
    -- Parse DOB safely
    BEGIN
      v_dob := (nullif(trim(new.raw_user_meta_data->>'date_of_birth'), ''))::date;
    EXCEPTION WHEN OTHERS THEN
      v_dob := NULL;
    END;

    -- Clamp to valid age window (11–17 years)
    IF v_dob IS NULL
       OR v_dob <= (current_date - interval '18 years')::date
       OR v_dob >  (current_date - interval '11 years')::date
    THEN
      v_dob := (current_date - interval '14 years')::date;
    END IF;

    INSERT INTO public.sitter_profiles (user_id, date_of_birth, full_name)
    VALUES (new.id, v_dob, v_full_name)
    ON CONFLICT (user_id) DO UPDATE SET
      full_name = v_full_name,
      date_of_birth = v_dob;
  END IF;

  RETURN new;
END;
$$;

-- 4. Create sync trigger on public.users
CREATE OR REPLACE FUNCTION public.fn_sync_user_to_profiles()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN
    -- Update family profiles if role is family
    IF NEW.role = 'family' THEN
      UPDATE public.family_profiles
      SET full_name = NEW.full_name,
          avatar_url = NEW.avatar_url
      WHERE user_id = NEW.id;
    -- Update sitter profiles if role is sitter
    ELSIF NEW.role = 'sitter' THEN
      UPDATE public.sitter_profiles
      SET full_name = NEW.full_name,
          avatar_url = NEW.avatar_url
      WHERE user_id = NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_to_profiles ON public.users;
CREATE TRIGGER trg_sync_user_to_profiles
  AFTER UPDATE OF full_name, avatar_url ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_user_to_profiles();
