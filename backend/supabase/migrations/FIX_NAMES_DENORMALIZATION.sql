-- =============================================================================
-- FIX: DENORMALIZE NAMES IN JOBS, APPLICATIONS, AND HIRES
-- This script ensures that names are saved directly into the transaction tables
-- so they display correctly in the apps without complex joins.
-- It also corrects the audit_logs column names (entity_type, entity_id).
-- =============================================================================

-- 1. ADD COLUMNS
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS family_name text;
ALTER TABLE public.applications ADD COLUMN IF NOT EXISTS sitter_name text;
ALTER TABLE public.hires ADD COLUMN IF NOT EXISTS sitter_name text;

-- 2. POPULATE EXISTING DATA
UPDATE public.jobs j
SET family_name = u.full_name
FROM public.users u
WHERE j.family_id = u.id AND j.family_name IS NULL;

UPDATE public.applications a
SET sitter_name = u.full_name
FROM public.users u
WHERE a.sitter_id = u.id AND a.sitter_name IS NULL;

UPDATE public.hires h
SET sitter_name = u.full_name
FROM public.users u
WHERE h.sitter_id = u.id AND h.sitter_name IS NULL;

-- 3. UPDATE RPC: create_application (Sitter applying to a job)
CREATE OR REPLACE FUNCTION public.create_application(
  p_job_id        uuid,
  p_cover_message text default null
)
RETURNS public.applications
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_sitter_id   uuid := auth.uid();
  v_sitter_name text;
  v_app         public.applications;
  v_is_active   boolean;
BEGIN
  -- Validate sitter is active
  SELECT is_active INTO v_is_active FROM public.sitter_profiles WHERE user_id = v_sitter_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'sitter profile not found'; END IF;
  IF NOT v_is_active THEN RAISE EXCEPTION 'your profile must be approved before applying'; END IF;

  -- Get the sitter's full name to save it
  SELECT full_name INTO v_sitter_name FROM public.users WHERE id = v_sitter_id;

  -- Insert application with the name
  INSERT INTO public.applications (job_id, sitter_id, sitter_name, cover_message)
  VALUES (p_job_id, v_sitter_id, v_sitter_name, p_cover_message)
  RETURNING * INTO v_app;

  -- Log audit (Corrected columns: entity_type, entity_id)
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id)
  VALUES (v_sitter_id, 'application_create', 'applications', v_app.id);

  RETURN v_app;
END; $$;

-- 4. UPDATE RPC: create_hire (Family hiring an applicant)
CREATE OR REPLACE FUNCTION public.create_hire(
  p_application_id uuid
)
RETURNS public.hires
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_family_id   uuid := auth.uid();
  v_app         public.applications;
  v_rate        numeric(10,2);
  v_sitter_age  int;
  v_hire        public.hires;
  v_conv_id     uuid;
BEGIN
  -- 1. Fetch application and verify family owns the job
  SELECT a.* INTO v_app
    FROM public.applications a
    JOIN public.jobs j ON j.id = a.job_id
   WHERE a.id = p_application_id
     AND j.family_id = v_family_id
     AND a.status = 'pending'
     AND j.status = 'open'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'application not found or job already hired';
  END IF;

  -- 2. Determine rate
  SELECT (date_part('year', age(current_date, date_of_birth)))::int
    INTO v_sitter_age
    FROM public.sitter_profiles
   WHERE user_id = v_app.sitter_id;

  SELECT hourly_rate INTO v_rate
    FROM public.age_wage_tiers
   WHERE v_sitter_age BETWEEN min_age AND max_age
   ORDER BY effective_from DESC
   LIMIT 1;

  IF v_rate IS NULL THEN
    RAISE EXCEPTION 'no wage tier configured for sitter age %', v_sitter_age;
  END IF;

  -- 3. Create hire with sitter_name
  INSERT INTO public.hires (job_id, sitter_id, sitter_name, hourly_rate)
  VALUES (v_app.job_id, v_app.sitter_id, v_app.sitter_name, v_rate)
  RETURNING * INTO v_hire;

  -- 4. Update job and application statuses
  UPDATE public.jobs SET status = 'hired' WHERE id = v_app.job_id;
  UPDATE public.applications SET status = 'accepted' WHERE id = p_application_id;
  UPDATE public.applications SET status = 'rejected' WHERE job_id = v_app.job_id AND id != p_application_id AND status = 'pending';

  -- 5. Open conversation
  INSERT INTO public.conversations (job_id, family_id, sitter_id)
  VALUES (v_app.job_id, v_family_id, v_app.sitter_id)
  ON CONFLICT (job_id, sitter_id) DO NOTHING
  RETURNING id INTO v_conv_id;

  -- 6. Audit (Corrected columns: entity_type, entity_id)
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, after_state)
  VALUES (
    v_family_id, 'hire_created', 'hires', v_hire.id,
    jsonb_build_object(
      'job_id', v_hire.job_id,
      'sitter_id', v_hire.sitter_id,
      'hourly_rate', v_hire.hourly_rate
    )
  );

  RETURN v_hire;
END; $$;

-- 5. UPDATE RPC: family_direct_hire (Family hiring sitter directly from browse)
CREATE OR REPLACE FUNCTION public.family_direct_hire(
  p_sitter_id      uuid,
  p_date           date,
  p_start_time     timestamptz,
  p_end_time       timestamptz,
  p_num_children   int  default 1,
  p_title          text default 'Direct hire'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_family_id   uuid := auth.uid();
  v_sitter_name text;
  v_family_name text;
  v_job_id      uuid;
  v_app_id      uuid;
  v_hire        public.hires;
  v_rate        numeric(10,2);
  v_sitter_age  int;
  v_conv_id     uuid;
BEGIN
  IF v_family_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Get names
  SELECT full_name INTO v_sitter_name FROM public.users WHERE id = p_sitter_id;
  SELECT full_name INTO v_family_name FROM public.users WHERE id = v_family_id;

  -- 1. Create the job
  INSERT INTO public.jobs (
    family_id, family_name, title, date, start_time, end_time,
    number_of_children, status,
    location_lat, location_lng, location_address, geofence_radius_m
  ) VALUES (
    v_family_id, v_family_name, p_title, p_date, p_start_time, p_end_time,
    p_num_children, 'open',
    0, 0, '{}'::jsonb, 150
  )
  RETURNING id INTO v_job_id;

  -- 2. Create an application
  INSERT INTO public.applications (job_id, sitter_id, sitter_name, status, cover_message)
  VALUES (v_job_id, p_sitter_id, v_sitter_name, 'pending', null)
  RETURNING id INTO v_app_id;

  -- 3. Determine rate
  SELECT (date_part('year', age(current_date, date_of_birth)))::int
    INTO v_sitter_age
    FROM public.sitter_profiles
   WHERE user_id = p_sitter_id;

  SELECT hourly_rate INTO v_rate
    FROM public.age_wage_tiers
   WHERE v_sitter_age BETWEEN min_age AND max_age
   ORDER BY effective_from DESC
   LIMIT 1;

  IF v_rate IS NULL THEN
    RAISE EXCEPTION 'no wage tier configured for sitter age %', v_sitter_age;
  END IF;

  -- 4. Accept the application
  UPDATE public.applications SET status = 'accepted' WHERE id = v_app_id;

  -- 5. Create hire
  INSERT INTO public.hires (job_id, sitter_id, sitter_name, hourly_rate)
  VALUES (v_job_id, p_sitter_id, v_sitter_name, v_rate)
  RETURNING * INTO v_hire;

  -- 6. Update job status to hired
  UPDATE public.jobs SET status = 'hired' WHERE id = v_job_id;

  -- 7. Open conversation
  INSERT INTO public.conversations (job_id, family_id, sitter_id)
  VALUES (v_job_id, v_family_id, p_sitter_id)
  ON CONFLICT (job_id, sitter_id) DO NOTHING
  RETURNING id INTO v_conv_id;

  -- 8. Audit (Corrected columns: entity_type, entity_id)
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, after_state)
  VALUES (
    v_family_id, 'direct_hire_created', 'hires', v_hire.id,
    jsonb_build_object(
      'job_id', v_hire.job_id,
      'sitter_id', v_hire.sitter_id,
      'hourly_rate', v_hire.hourly_rate
    )
  );

  RETURN jsonb_build_object(
    'hire_id',          v_hire.id,
    'job_id',           v_job_id,
    'application_id',   v_app_id,
    'conversation_id',  v_conv_id,
    'hourly_rate',      v_rate
  );
END; $$;
