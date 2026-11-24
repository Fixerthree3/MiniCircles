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
  interests text[] not null default '{}',
  can_edit boolean not null default false,
  circle_manager boolean not null default false
);

alter table public.profiles
  add column if not exists circle_manager boolean not null default false;
alter table public.profiles
  add column if not exists interests text[] not null default '{}';

create table if not exists public.site_updates (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('Announcement','Event')),
  title text not null,
  date date not null,
  summary text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.user_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);

alter table public.press enable row level security;
alter table public.league enable row level security;
alter table public.signups enable row level security;
alter table public.profiles enable row level security;
alter table public.site_updates enable row level security;
alter table public.user_follows enable row level security;

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

create or replace function public.keep_profile_permissions_private()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = new.id then
    if tg_op = 'INSERT' then
      new.can_edit := false;
      new.circle_manager := false;
    else
      new.can_edit := old.can_edit;
      new.circle_manager := old.circle_manager;
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_profile_permissions
before insert or update on public.profiles
for each row execute function public.keep_profile_permissions_private();

create policy "Users can create own profile"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

create policy "Users can update own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "Public can read site updates"
on public.site_updates for select
to anon, authenticated
using (true);

create policy "Editors can manage site updates"
on public.site_updates for all
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

create policy "Users can read own follows"
on public.user_follows for select
to authenticated
using (follower_id = auth.uid());

create policy "Users can follow members"
on public.user_follows for insert
to authenticated
with check (follower_id = auth.uid());

create policy "Users can unfollow members"
on public.user_follows for delete
to authenticated
using (follower_id = auth.uid());

create table if not exists public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null check (type in ('Cricket','Reading')),
  area text,
  meeting text,
  description text,
  status text not null default 'open',
  members integer not null default 1,
  featured boolean not null default false,
  manager_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.circle_members (
  circle_id uuid references public.circles(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create table if not exists public.circle_posts (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  author_id uuid references auth.users(id),
  author text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.feed_engagements (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.circle_posts(id) on delete cascade,
  kind text not null default 'like' check (kind = 'like'),
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.circle_invitations (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  email text not null,
  invited_by uuid references auth.users(id),
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.circle_posts enable row level security;
alter table public.circle_invitations enable row level security;
alter table public.feed_engagements enable row level security;

create policy "Public can discover circles"
on public.circles for select
to anon, authenticated
using (status in ('open','active'));

create policy "Circle managers can create circles"
on public.circles for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
      and (profiles.can_edit or profiles.circle_manager)
  )
);

create policy "Managers can manage own circles"
on public.circles for all
to authenticated
using (manager_id = auth.uid())
with check (manager_id = auth.uid());

create policy "Members can read memberships"
on public.circle_members for select
to authenticated
using (true);

create policy "Users can join circles"
on public.circle_members for insert
to authenticated
with check (user_id = auth.uid());

create policy "Users can leave circles"
on public.circle_members for delete
to authenticated
using (user_id = auth.uid());

create policy "Public can read circle posts"
on public.circle_posts for select
to anon, authenticated
using (true);

create policy "Members can post"
on public.circle_posts for insert
to authenticated
with check (
  exists (
    select 1 from public.circle_members
    where circle_members.circle_id = circle_posts.circle_id
      and circle_members.user_id = auth.uid()
  )
);

create policy "Authors can delete own posts"
on public.circle_posts for delete
to authenticated
using (author_id = auth.uid());

create policy "Users can read own feed engagement"
on public.feed_engagements for select
to authenticated
using (user_id = auth.uid());

create policy "Users can like feed posts"
on public.feed_engagements for insert
to authenticated
with check (user_id = auth.uid());

create policy "Users can remove own feed likes"
on public.feed_engagements for delete
to authenticated
using (user_id = auth.uid());

create policy "Managers can invite circle members"
on public.circle_invitations for all
to authenticated
using (
  exists (
    select 1 from public.circles
    where circles.id = circle_invitations.circle_id
      and circles.manager_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.circles
    where circles.id = circle_invitations.circle_id
      and circles.manager_id = auth.uid()
  )
);
