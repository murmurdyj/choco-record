-- =========================================================
-- 治療生活紀錄｜Supabase 資料庫結構
-- 在 Supabase 後台 SQL Editor 貼上後整段執行一次即可
-- =========================================================

create extension if not exists pgcrypto;

-- ---------- 資料表 ----------

create table if not exists public.care_spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default '我們的治療紀錄',
  people jsonb not null default '[]'::jsonb,   -- 使用者名字，例如 ["小安","阿哲"]
  created_at timestamptz not null default now()
);

create table if not exists public.care_space_members (
  care_space_id uuid not null references public.care_spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (care_space_id, user_id)
);

create table if not exists public.daily_records (
  id uuid primary key default gen_random_uuid(),
  care_space_id uuid not null references public.care_spaces(id) on delete cascade,
  record_date date not null,
  mood text check (mood in ('good', 'ok', 'uncomfortable', 'bad')),  -- null = 只有生活打卡、尚未完成身體紀錄
  symptoms jsonb not null default '[]'::jsonb,
  red_flags jsonb not null default '[]'::jsonb,                        -- 單側下腹痛的附帶狀況
  note text,
  updated_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (care_space_id, record_date)
);

create table if not exists public.daily_habits (
  id uuid primary key default gen_random_uuid(),
  daily_record_id uuid not null unique references public.daily_records(id) on delete cascade,
  care_space_id uuid not null references public.care_spaces(id) on delete cascade,
  calcium boolean not null default false,
  protein boolean not null default false,
  exercise boolean not null default false,
  water boolean not null default false,
  no_heavy_alcohol boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.treatments (
  id uuid primary key default gen_random_uuid(),
  care_space_id uuid not null references public.care_spaces(id) on delete cascade,
  treatment_date date not null,
  treatment_name text not null,
  medical_summary text,
  next_plan text,
  test_results text,
  created_by_name text,
  updated_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shared_notes (
  id uuid primary key default gen_random_uuid(),
  care_space_id uuid not null references public.care_spaces(id) on delete cascade,
  content text not null default '',
  updated_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists daily_records_space_date on public.daily_records (care_space_id, record_date desc);
create index if not exists shared_notes_space on public.shared_notes (care_space_id, created_at);
create index if not exists treatments_space_date on public.treatments (care_space_id, treatment_date desc);

-- ---------- updated_at 自動更新 ----------

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_daily_records_touch on public.daily_records;
create trigger trg_daily_records_touch before update on public.daily_records
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_daily_habits_touch on public.daily_habits;
create trigger trg_daily_habits_touch before update on public.daily_habits
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_treatments_touch on public.treatments;
create trigger trg_treatments_touch before update on public.treatments
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_shared_notes_touch on public.shared_notes;
create trigger trg_shared_notes_touch before update on public.shared_notes
  for each row execute function public.touch_updated_at();

-- ---------- 留言板最多 3 則 ----------

create or replace function public.limit_shared_notes() returns trigger
language plpgsql as $$
begin
  if (select count(*) from public.shared_notes where care_space_id = new.care_space_id) >= 3 then
    raise exception '留言板最多 3 則';
  end if;
  return new;
end $$;

drop trigger if exists trg_limit_shared_notes on public.shared_notes;
create trigger trg_limit_shared_notes before insert on public.shared_notes
  for each row execute function public.limit_shared_notes();

-- ---------- 權限輔助函式 ----------

create or replace function public.is_member(space uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.care_space_members
    where care_space_id = space and user_id = auth.uid()
  );
$$;

-- ---------- 建立共享空間（帳號第一次登入時自動呼叫） ----------

create or replace function public.create_care_space(p_name text default '我們的治療紀錄')
returns public.care_spaces
language plpgsql security definer set search_path = public as $$
declare
  s public.care_spaces;
begin
  if auth.uid() is null then
    raise exception '請先登入';
  end if;

  -- 已經有空間就直接回傳，避免兩支手機同時第一次登入時建立兩個空間
  select cs.* into s
  from public.care_spaces cs
  join public.care_space_members m on m.care_space_id = cs.id
  where m.user_id = auth.uid()
  order by m.joined_at
  limit 1;
  if found then
    return s;
  end if;

  insert into public.care_spaces (name)
  values (coalesce(nullif(trim(p_name), ''), '我們的治療紀錄'))
  returning * into s;

  insert into public.care_space_members (care_space_id, user_id, role)
  values (s.id, auth.uid(), 'owner');

  -- 示範治療紀錄（可在 App 內修改或刪除）
  insert into public.treatments (care_space_id, treatment_date, treatment_name, test_results, medical_summary, next_plan)
  values (
    s.id,
    date '2026-09-23',
    '施打柳培林',
    E'CA-125 102.8\n右側巧克力囊腫：\n5 cm\n3 cm\n2 cm\n2 cm',
    '以巧克力囊腫／子宮內膜異位症方向治療，後續追蹤症狀及影像變化。',
    E'確認柳培林療程長度\n確認下次超音波時間\n確認 CA-125 複驗時間'
  );

  return s;
end $$;

revoke all on function public.create_care_space(text) from public, anon;
grant execute on function public.create_care_space(text) to authenticated;
grant execute on function public.is_member(uuid) to authenticated;

-- ---------- 資料表權限：只開放給登入的使用者 ----------
-- 不依賴「Automatically expose new tables」設定，勾或不勾都能正常運作

grant usage on schema public to authenticated;
revoke all on public.care_spaces, public.care_space_members, public.daily_records,
  public.daily_habits, public.treatments, public.shared_notes from anon;
grant select, update on public.care_spaces to authenticated;
grant select, delete on public.care_space_members to authenticated;
grant select, insert, update, delete on public.daily_records, public.daily_habits,
  public.treatments, public.shared_notes to authenticated;

-- ---------- Row Level Security ----------

alter table public.care_spaces enable row level security;
alter table public.care_space_members enable row level security;
alter table public.daily_records enable row level security;
alter table public.daily_habits enable row level security;
alter table public.treatments enable row level security;
alter table public.shared_notes enable row level security;

-- care_spaces：成員可讀、可修改名字清單（新增只能透過 create_care_space）
drop policy if exists spaces_select on public.care_spaces;
create policy spaces_select on public.care_spaces for select to authenticated
  using (public.is_member(id));
drop policy if exists spaces_update on public.care_spaces;
create policy spaces_update on public.care_spaces for update to authenticated
  using (public.is_member(id)) with check (public.is_member(id));

-- care_space_members：成員可讀（新增只能透過 create_care_space）
drop policy if exists members_select on public.care_space_members;
create policy members_select on public.care_space_members for select to authenticated
  using (public.is_member(care_space_id));
drop policy if exists members_leave on public.care_space_members;
create policy members_leave on public.care_space_members for delete to authenticated
  using (user_id = auth.uid());

-- 共享資料：同空間成員可新增、讀取、修改、刪除
drop policy if exists records_all on public.daily_records;
create policy records_all on public.daily_records for all to authenticated
  using (public.is_member(care_space_id)) with check (public.is_member(care_space_id));

drop policy if exists habits_all on public.daily_habits;
create policy habits_all on public.daily_habits for all to authenticated
  using (public.is_member(care_space_id))
  with check (
    public.is_member(care_space_id)
    and exists (
      select 1 from public.daily_records r
      where r.id = daily_record_id and r.care_space_id = daily_habits.care_space_id
    )
  );

drop policy if exists treatments_all on public.treatments;
create policy treatments_all on public.treatments for all to authenticated
  using (public.is_member(care_space_id)) with check (public.is_member(care_space_id));

drop policy if exists notes_all on public.shared_notes;
create policy notes_all on public.shared_notes for all to authenticated
  using (public.is_member(care_space_id)) with check (public.is_member(care_space_id));

-- ---------- Realtime ----------

alter table public.daily_records replica identity full;
alter table public.daily_habits replica identity full;
alter table public.treatments replica identity full;
alter table public.shared_notes replica identity full;
alter table public.care_spaces replica identity full;

do $$
declare t text;
begin
  foreach t in array array['daily_records', 'daily_habits', 'treatments', 'shared_notes', 'care_spaces'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
