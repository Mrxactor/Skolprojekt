-- Lärarvy för Skolprojekt
-- Säker klasshantering + persistent individuell/grupp-sortering.
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

create table if not exists private.teacher_classes (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 80),
  created_at timestamptz not null default now()
);

create unique index if not exists teacher_classes_name_ci_idx
on private.teacher_classes (lower(trim(name)));

revoke all on table private.teacher_classes from public, anon, authenticated;

alter table public.app_ide_submissions
  add column if not exists class_id uuid references private.teacher_classes(id) on delete set null;

alter table public.app_ide_submissions
  add column if not exists teacher_category text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'app_ide_submissions_teacher_category_check'
      and conrelid = 'public.app_ide_submissions'::regclass
  ) then
    alter table public.app_ide_submissions
      add constraint app_ide_submissions_teacher_category_check
      check (teacher_category is null or teacher_category in ('individual', 'group'));
  end if;
end
$$;

create or replace function private.teacher_code_ok(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.teacher_settings t
    where t.id = 1
      and t.code_hash = encode(extensions.digest(coalesce(p_code, ''), 'sha256'), 'hex')
  );
$$;

revoke all on function private.teacher_code_ok(text) from public, anon, authenticated;

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
  created_at timestamptz,
  class_id uuid,
  class_name text,
  teacher_category text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.teacher_code_ok(p_code) then
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
    s.created_at,
    s.class_id,
    c.name as class_name,
    s.teacher_category
  from public.app_ide_submissions s
  left join private.teacher_classes c on c.id = s.class_id
  order by c.name nulls first, s.created_at desc;
end;
$$;

revoke all on function public.get_app_ide_submissions(text) from public, authenticated;
grant execute on function public.get_app_ide_submissions(text) to anon;

create or replace function public.get_teacher_classes(p_code text)
returns table (
  id uuid,
  name text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.teacher_code_ok(p_code) then
    raise exception 'Fel lärarkod' using errcode = '28000';
  end if;

  return query
  select c.id, c.name, c.created_at
  from private.teacher_classes c
  order by lower(c.name), c.created_at;
end;
$$;

revoke all on function public.get_teacher_classes(text) from public, authenticated;
grant execute on function public.get_teacher_classes(text) to anon;

create or replace function public.create_teacher_class(p_code text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_name text := trim(coalesce(p_name, ''));
begin
  if not private.teacher_code_ok(p_code) then
    raise exception 'Fel lärarkod' using errcode = '28000';
  end if;

  if length(v_name) < 1 or length(v_name) > 80 then
    raise exception 'Klassnamnet måste vara 1-80 tecken';
  end if;

  insert into private.teacher_classes(name)
  values (v_name)
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    raise exception 'Det finns redan en klass med det namnet';
end;
$$;

revoke all on function public.create_teacher_class(text, text) from public, authenticated;
grant execute on function public.create_teacher_class(text, text) to anon;

create or replace function public.rename_teacher_class(p_code text, p_id uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := trim(coalesce(p_name, ''));
begin
  if not private.teacher_code_ok(p_code) then
    raise exception 'Fel lärarkod' using errcode = '28000';
  end if;

  if length(v_name) < 1 or length(v_name) > 80 then
    raise exception 'Klassnamnet måste vara 1-80 tecken';
  end if;

  update private.teacher_classes
  set name = v_name
  where id = p_id;

  if not found then
    raise exception 'Klassen hittades inte';
  end if;
exception
  when unique_violation then
    raise exception 'Det finns redan en klass med det namnet';
end;
$$;

revoke all on function public.rename_teacher_class(text, uuid, text) from public, authenticated;
grant execute on function public.rename_teacher_class(text, uuid, text) to anon;

create or replace function public.delete_teacher_class(p_code text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.teacher_code_ok(p_code) then
    raise exception 'Fel lärarkod' using errcode = '28000';
  end if;

  delete from private.teacher_classes
  where id = p_id;

  if not found then
    raise exception 'Klassen hittades inte';
  end if;
end;
$$;

revoke all on function public.delete_teacher_class(text, uuid) from public, authenticated;
grant execute on function public.delete_teacher_class(text, uuid) to anon;

create or replace function public.set_submission_class(
  p_code text,
  p_submission_id uuid,
  p_class_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.teacher_code_ok(p_code) then
    raise exception 'Fel lärarkod' using errcode = '28000';
  end if;

  if p_class_id is not null and not exists (
    select 1 from private.teacher_classes c where c.id = p_class_id
  ) then
    raise exception 'Klassen hittades inte';
  end if;

  update public.app_ide_submissions
  set class_id = p_class_id
  where id = p_submission_id;

  if not found then
    raise exception 'Arbetet hittades inte';
  end if;
end;
$$;

revoke all on function public.set_submission_class(text, uuid, uuid) from public, authenticated;
grant execute on function public.set_submission_class(text, uuid, uuid) to anon;

create or replace function public.set_submission_category(
  p_code text,
  p_submission_id uuid,
  p_category text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category text := lower(trim(coalesce(p_category, '')));
begin
  if not private.teacher_code_ok(p_code) then
    raise exception 'Fel lärarkod' using errcode = '28000';
  end if;

  if v_category not in ('individual', 'group') then
    raise exception 'Ogiltig typ';
  end if;

  update public.app_ide_submissions
  set teacher_category = v_category
  where id = p_submission_id;

  if not found then
    raise exception 'Arbetet hittades inte';
  end if;
end;
$$;

revoke all on function public.set_submission_category(text, uuid, text) from public, authenticated;
grant execute on function public.set_submission_category(text, uuid, text) to anon;

create or replace function public.delete_app_ide_submission(p_code text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.teacher_code_ok(p_code) then
    raise exception 'Fel lärarkod' using errcode = '28000';
  end if;

  delete from public.app_ide_submissions
  where id = p_id;

  if not found then
    raise exception 'Inlämningen hittades inte';
  end if;
end;
$$;

revoke all on function public.delete_app_ide_submission(text, uuid) from public, authenticated;
grant execute on function public.delete_app_ide_submission(text, uuid) to anon;
