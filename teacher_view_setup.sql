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
  '37950e68c16d166df473babf95ea690bcde08b31c1e9c9c1664de4405392ca66'
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


create or replace function public.delete_app_ide_submission(p_code text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Återanvänd samma lärarkodskontroll som lärarvyn.
  perform 1
  from public.get_app_ide_submissions(p_code)
  limit 1;

  delete from public.app_ide_submissions
  where id = p_id;
end;
$$;

revoke all on function public.delete_app_ide_submission(text, uuid) from public;
grant execute on function public.delete_app_ide_submission(text, uuid) to anon;
