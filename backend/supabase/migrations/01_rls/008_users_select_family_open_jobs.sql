-- Allow sitters to read family user profiles for browsing open jobs.
-- This enables the sitter app to fetch family full names and avatar URLs
-- without hiding job rows when nested selects encounter RLS-protected user rows.

create or replace function public.family_user_has_open_job(p_user_id uuid)
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
    where family_id = p_user_id
      and status = 'open'::public.job_status
  );
$$;

grant execute on function public.family_user_has_open_job(uuid) to authenticated;

create policy "users: select family with open jobs"
  on public.users for select
  using (
    public.current_user_role() = 'sitter'
    and role = 'family'
    and public.family_user_has_open_job(id)
  );
