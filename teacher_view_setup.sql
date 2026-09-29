-- Lärarvy för Skolprojekt
-- Denna fil innehåller INTE lärarkoden i klartext.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public;

create table if not exists private.teacher_settings (
  id smallint primary key default 1 check (id = 1),
  code_hash text not null
);

insert into private.teacher_settings (id, code_hash)
values (
  1,
  '99399ff882ea2711d75cf2e8ea7b937f175a4bbe1a58ad71c9cd5338b7272249'
)
on conflict (id)
do update set code_hash = excluded.code_hash;

revoke all on table private.teacher_settings from public, anon, authenticated;

create or replace function public.get_app_ide_submissions(p_code text)
returns table (
  id uuid,
  group_name text,
  member_1 text,
  member_2 text,
  member_3 text,
  app_name text,
  idea text,
  target_users text,
  problem text,
  features text,
  style text,
  colors text,
  prompt_text text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if not exists (
    select 1
    from private.teacher_settings t
    where t.id = 1
      and t.code_hash = encode(extensions.digest(p_code, 'sha256'), 'hex')
  ) then
    raise exception 'Fel lärarkod' using errcode = '28000';
  end if;

  return query
  select
    s.id,
    s.group_name,
    s.member_1,
    s.member_2,
    s.member_3,
    s.app_name,
    s.idea,
    s.target_users,
    s.problem,
    s.features,
    s.style,
    s.colors,
    s.prompt_text,
    s.created_at
  from public.app_ide_submissions s
  order by s.created_at desc;
end;
$$;

revoke all on function public.get_app_ide_submissions(text) from public;
grant execute on function public.get_app_ide_submissions(text) to anon;
