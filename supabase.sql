create table if not exists public.press (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  tag text not null,
  date date not null,
  summary text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.league (
  id text primary key,
  groups jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.signups (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  name text not null,
  contact_name text,
  contact text,
  area text,
  age text,
  count text,
  notes text,
  summary text,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  can_edit boolean not null default false
);

alter table public.press enable row level security;
alter table public.league enable row level security;
alter table public.signups enable row level security;
alter table public.profiles enable row level security;

create policy "Public can read press"
on public.press for select
to anon, authenticated
using (true);

create policy "Public can read league"
on public.league for select
to anon, authenticated
using (true);

create policy "Public can submit signups"
on public.signups for insert
to anon, authenticated
with check (true);

create policy "Editors can read signups"
on public.signups for select
to authenticated
using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.can_edit
  )
);

create policy "Editors can publish press"
on public.press for all
to authenticated
using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.can_edit
  )
)
with check (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.can_edit
  )
);

create policy "Editors can update league"
on public.league for all
to authenticated
using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.can_edit
  )
)
with check (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.can_edit
  )
);

create policy "Users can read own profile"
on public.profiles for select
to authenticated
using (id = auth.uid());
