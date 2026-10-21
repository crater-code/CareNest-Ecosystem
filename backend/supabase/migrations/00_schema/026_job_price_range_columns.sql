-- Add hourly-rate preview fields for job listings and publishing.
alter table public.jobs
  add column min_hourly_rate numeric(10,2),
  add column max_hourly_rate numeric(10,2);

alter table public.jobs
  add constraint chk_jobs_hourly_rate_range
    check (
      min_hourly_rate is null
      or max_hourly_rate is null
      or max_hourly_rate >= min_hourly_rate
    );
