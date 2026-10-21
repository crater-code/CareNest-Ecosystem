-- Allow sitters to see family profiles if that family has an OPEN job.
-- This fixed the issue where BrowseTab was returning 0 jobs because of the !inner join 
-- on family_profiles failing RLS checks.

create or replace function public.family_has_open_job(p_family_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.jobs
    where family_id = p_family_user_id
      and status = 'open'::public.job_status
  );
$$;

grant execute on function public.family_has_open_job(uuid) to authenticated;

-- Add the policy to family_profiles
create policy "family_profiles: sitter sees families with open jobs"
  on public.family_profiles for select
  using (
    public.current_user_role() = 'sitter'
    and public.family_has_open_job(family_profiles.user_id)
  );
