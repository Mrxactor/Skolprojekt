create table if not exists public.app_ide_submissions (
  id uuid primary key default gen_random_uuid(),
  group_name text not null,
  member_1 text not null,
  member_2 text,
  member_3 text,
  app_name text,
  idea text not null,
  target_users text,
  problem text not null,
  features text not null,
  style text,
  colors text,
  prompt_text text,
  created_at timestamptz not null default now()
);

alter table public.app_ide_submissions enable row level security;

drop policy if exists "students_can_submit"
on public.app_ide_submissions;

create policy "students_can_submit"
on public.app_ide_submissions
for insert
to anon
with check (true);

revoke all on table public.app_ide_submissions from anon;
grant insert on table public.app_ide_submissions to anon;
