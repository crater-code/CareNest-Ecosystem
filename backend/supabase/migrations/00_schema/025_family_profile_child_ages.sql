-- Add explicit child count + age columns to family_profiles
alter table public.family_profiles
  add column children_count int not null default 0,
  add column child_age_1 int check (child_age_1 is null or (child_age_1 >= 0 and child_age_1 <= 18)),
  add column child_age_2 int check (child_age_2 is null or (child_age_2 >= 0 and child_age_2 <= 18)),
  add column child_age_3 int check (child_age_3 is null or (child_age_3 >= 0 and child_age_3 <= 18)),
  add column child_age_4 int check (child_age_4 is null or (child_age_4 >= 0 and child_age_4 <= 18)),
  add column child_age_5 int check (child_age_5 is null or (child_age_5 >= 0 and child_age_5 <= 18)),
  add column child_age_6 int check (child_age_6 is null or (child_age_6 >= 0 and child_age_6 <= 18)),
  add column child_age_7 int check (child_age_7 is null or (child_age_7 >= 0 and child_age_7 <= 18)),
  add column child_age_8 int check (child_age_8 is null or (child_age_8 >= 0 and child_age_8 <= 18)),
  add column child_age_9 int check (child_age_9 is null or (child_age_9 >= 0 and child_age_9 <= 18)),
  add column child_age_10 int check (child_age_10 is null or (child_age_10 >= 0 and child_age_10 <= 18));
