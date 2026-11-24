create table if not exists public.press (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  tag text not null,
  date date not null,
  summary text not null,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.circle_posts drop constraint if exists circle_posts_author_id_fkey;
alter table public.circle_posts
  add constraint circle_posts_author_id_fkey
  foreign key (author_id) references auth.users(id) on delete set null;
alter table public.circle_invitations drop constraint if exists circle_invitations_invited_by_fkey;
alter table public.circle_invitations
  add constraint circle_invitations_invited_by_fkey
  foreign key (invited_by) references auth.users(id) on delete set null;

create or replace function public.anonymize_circle_posts_before_profile_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.circle_posts
  set author = 'Former member', author_id = null
  where author_id = old.id;
  return old;
end;
$$;

drop trigger if exists anonymize_circle_posts_before_profile_delete on public.profiles;
create trigger anonymize_circle_posts_before_profile_delete
before delete on public.profiles
for each row execute function public.anonymize_circle_posts_before_profile_delete();

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
  publish_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.site_updates
  add column if not exists publish_at timestamptz not null default now();

create table if not exists public.site_settings (
  id boolean primary key default true check (id),
  theme text not null default 'system' check (theme in ('system','light','dark')),
  circles_enabled boolean not null default true,
  feed_enabled boolean not null default true,
  messages_enabled boolean not null default true,
  events_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.site_settings (id) values (true)
on conflict (id) do nothing;

create table if not exists public.user_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);

create table if not exists public.member_directory (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  updated_at timestamptz not null default now()
);

alter table public.press enable row level security;
alter table public.league enable row level security;
alter table public.signups enable row level security;
alter table public.profiles enable row level security;
alter table public.site_updates enable row level security;
alter table public.site_settings enable row level security;
alter table public.user_follows enable row level security;
alter table public.member_directory enable row level security;

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

drop policy if exists "Public can read site updates" on public.site_updates;
create policy "Public can read site updates"
on public.site_updates for select
to anon, authenticated
using (
  publish_at <= now()
  and exists (
    select 1 from public.site_settings
    where id = true and events_enabled
  )
  or exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.can_edit
  )
);

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

create policy "Public can read site settings"
on public.site_settings for select
to anon, authenticated
using (true);

create policy "Editors can manage site settings"
on public.site_settings for all
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

create policy "Signed-in users can discover members"
on public.member_directory for select
to authenticated
using (true);

create or replace function public.sync_member_directory()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.name is null or btrim(new.name) = '' then
    delete from public.member_directory where id = new.id;
  else
    insert into public.member_directory (id, name, updated_at)
    values (new.id, btrim(new.name), now())
    on conflict (id) do update
      set name = excluded.name, updated_at = excluded.updated_at;
  end if;
  return new;
end;
$$;

create trigger sync_member_directory_after_profile_change
after insert or update of name on public.profiles
for each row execute function public.sync_member_directory();

insert into public.member_directory (id, name)
select id, btrim(name) from public.profiles
where name is not null and btrim(name) <> ''
on conflict (id) do update set name = excluded.name, updated_at = now();

create table if not exists public.circles (
  id uuid primary key default gen_random_uuid(),
  slug text not null constraint circles_slug_format_check
    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null,
  type text not null check (type in ('Cricket','Reading')),
  area text,
  meeting text,
  description text,
  status text not null default 'open',
  members integer not null default 1,
  featured boolean not null default false,
  manager_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.circles add column if not exists slug text;
update public.circles
set slug = coalesce(
  nullif(trim(both '-' from regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g')), ''),
  'circle'
) || '-' || left(id::text, 8)
where slug is null or btrim(slug) = '';
alter table public.circles alter column slug set not null;
create unique index if not exists circles_slug_unique on public.circles (slug);
alter table public.circles drop constraint if exists circles_slug_format_check;
alter table public.circles
  add constraint circles_slug_format_check
  check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$');
alter table public.circles drop constraint if exists circles_manager_id_fkey;
alter table public.circles
  add constraint circles_manager_id_fkey
  foreign key (manager_id) references auth.users(id) on delete set null;

create table if not exists public.circle_members (
  circle_id uuid references public.circles(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

alter table public.circle_members
  add column if not exists role text not null default 'member';
update public.circle_members set role = 'member'
where role is null or role not in ('member','moderator','admin');
alter table public.circle_members alter column role set default 'member';
alter table public.circle_members alter column role set not null;
alter table public.circle_members
  drop constraint if exists circle_members_role_check;
alter table public.circle_members
  add constraint circle_members_role_check
  check (role in ('member','moderator','admin')) not valid;
alter table public.circle_members validate constraint circle_members_role_check;

create table if not exists public.circle_posts (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  author_id uuid references auth.users(id) on delete set null,
  author text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.circle_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.circle_posts(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  author text not null,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.feed_engagements (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.circle_posts(id) on delete cascade,
  kind text not null default 'like' check (kind = 'like'),
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create table if not exists public.circle_invitations (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  email text not null,
  invited_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.circle_posts enable row level security;
alter table public.circle_invitations enable row level security;
alter table public.feed_engagements enable row level security;
alter table public.circle_post_comments enable row level security;
alter table public.direct_messages enable row level security;

create or replace function public.is_circle_manager(target_circle uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.circles c
    where c.id = target_circle and c.manager_id = auth.uid()
  ) or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.can_edit
  );
$$;

create or replace function public.is_circle_admin(target_circle uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_circle_manager(target_circle) or exists (
    select 1 from public.circle_members m
    where m.circle_id = target_circle and m.user_id = auth.uid() and m.role = 'admin'
  );
$$;

create or replace function public.is_circle_moderator(target_circle uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_circle_admin(target_circle) or exists (
    select 1 from public.circle_members m
    where m.circle_id = target_circle and m.user_id = auth.uid() and m.role = 'moderator'
  );
$$;

create or replace function public.is_circle_member(target_circle uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_circle_manager(target_circle) or exists (
    select 1 from public.circle_members m
    where m.circle_id = target_circle and m.user_id = auth.uid()
  );
$$;

revoke all on function public.is_circle_manager(uuid) from public;
revoke all on function public.is_circle_admin(uuid) from public;
revoke all on function public.is_circle_moderator(uuid) from public;
revoke all on function public.is_circle_member(uuid) from public;
grant execute on function public.is_circle_manager(uuid) to authenticated;
grant execute on function public.is_circle_admin(uuid) to authenticated;
grant execute on function public.is_circle_moderator(uuid) to authenticated;
grant execute on function public.is_circle_member(uuid) to authenticated;

create policy "Public can discover circles"
on public.circles for select
to anon, authenticated
using (status in ('open','active'));

create policy "Circle admins can read managed circles"
on public.circles for select
to authenticated
using (public.is_circle_admin(id));

drop policy if exists "Circle managers can create circles" on public.circles;
create policy "Circle managers can create circles"
on public.circles for insert
to authenticated
with check (
  manager_id = auth.uid() and exists (
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

create policy "Circle admins can manage their circles"
on public.circles for update
to authenticated
using (public.is_circle_admin(id))
with check (public.is_circle_admin(id));

create policy "Circle admins can delete their circles"
on public.circles for delete
to authenticated
using (public.is_circle_admin(id));

create policy "Members can read memberships"
on public.circle_members for select
to authenticated
using (user_id = auth.uid() or public.is_circle_admin(circle_id));

create policy "Users can join circles"
on public.circle_members for insert
to authenticated
with check (user_id = auth.uid() and role = 'member');

create policy "Circle admins can assign roles"
on public.circle_members for insert
to authenticated
with check (public.is_circle_admin(circle_id));

create policy "Circle admins can update roles"
on public.circle_members for update
to authenticated
using (public.is_circle_admin(circle_id))
with check (public.is_circle_admin(circle_id));

create policy "Users can leave circles"
on public.circle_members for delete
to authenticated
using (user_id = auth.uid() or public.is_circle_admin(circle_id));

create policy "Public can read circle posts"
on public.circle_posts for select
to anon, authenticated
using (true);

create policy "Members can post"
on public.circle_posts for insert
to authenticated
with check (
  author_id = auth.uid() and public.is_circle_member(circle_id)
);

create policy "Authors can delete own posts"
on public.circle_posts for delete
to authenticated
using (author_id = auth.uid());

create policy "Moderators can remove circle posts"
on public.circle_posts for delete
to authenticated
using (public.is_circle_moderator(circle_id));

create policy "Members can read circle comments"
on public.circle_post_comments for select
to authenticated
using (
  exists (
    select 1 from public.circle_posts p
    where p.id = circle_post_comments.post_id
      and public.is_circle_member(p.circle_id)
  )
);

create policy "Members can comment on circle posts"
on public.circle_post_comments for insert
to authenticated
with check (
  author_id = auth.uid()
  and exists (
    select 1 from public.circle_posts p
    where p.id = circle_post_comments.post_id
      and public.is_circle_member(p.circle_id)
  )
);

create policy "Authors and moderators can remove comments"
on public.circle_post_comments for delete
to authenticated
using (
  author_id = auth.uid()
  or exists (
    select 1 from public.circle_posts p
    where p.id = circle_post_comments.post_id
      and public.is_circle_moderator(p.circle_id)
  )
);

create policy "Users can read own feed engagement"
on public.feed_engagements for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Participants can read direct messages" on public.direct_messages;
create policy "Participants can read direct messages"
on public.direct_messages for select
to authenticated
using (
  (sender_id = auth.uid() or recipient_id = auth.uid())
  and exists (
    select 1 from public.site_settings
    where id = true and messages_enabled
  )
);

drop policy if exists "Users can send direct messages" on public.direct_messages;
create policy "Users can send direct messages"
on public.direct_messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.site_settings
    where id = true and messages_enabled
  )
  and exists (
    select 1 from public.member_directory d
    where d.id = direct_messages.recipient_id
  )
);

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
  public.is_circle_admin(circle_id)
)
with check (
  public.is_circle_admin(circle_id)
);

-- Dedicated feed interactions and Circle-owned media.
alter table public.circles
  add column if not exists profile_image_path text;
alter table public.circles
  drop constraint if exists circles_profile_image_path_check;
alter table public.circles
  add constraint circles_profile_image_path_check
  check (
    profile_image_path is null
    or profile_image_path like (id::text || '/profile/%')
  );

alter table public.circle_posts
  add column if not exists media_path text,
  add column if not exists media_type text;
alter table public.circle_posts
  drop constraint if exists circle_posts_media_metadata_check;
alter table public.circle_posts
  add constraint circle_posts_media_metadata_check
  check (
    (media_path is null and media_type is null)
    or (
      media_path is not null
      and media_path like (circle_id::text || '/%')
      and media_type in ('image/jpeg','image/png','image/webp','video/mp4','video/webm')
    )
  );

drop policy if exists "Members can post" on public.circle_posts;
create policy "Members can post"
on public.circle_posts for insert
to authenticated
with check (
  author_id = auth.uid()
  and public.is_circle_member(circle_id)
  and (
    media_path is null
    or (
      public.is_circle_admin(circle_id)
      and media_path like (circle_id::text || '/%')
      and media_type in ('image/jpeg','image/png','image/webp','video/mp4','video/webm')
    )
  )
);

drop policy if exists "Members can read circle comments" on public.circle_post_comments;
create policy "Public can read comments on public posts"
on public.circle_post_comments for select
to anon, authenticated
using (
  exists (
    select 1 from public.circle_posts p
    where p.id = circle_post_comments.post_id
  )
);

drop policy if exists "Members can comment on circle posts" on public.circle_post_comments;
create policy "Signed-in users can comment on public posts"
on public.circle_post_comments for insert
to authenticated
with check (
  author_id = auth.uid()
  and exists (
    select 1 from public.circle_posts p
    where p.id = circle_post_comments.post_id
  )
);

create table if not exists public.saved_posts (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.circle_posts(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

alter table public.saved_posts enable row level security;

drop policy if exists "Users can read own saved posts" on public.saved_posts;
create policy "Users can read own saved posts"
on public.saved_posts for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can save posts" on public.saved_posts;
create policy "Users can save posts"
on public.saved_posts for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can unsave posts" on public.saved_posts;
create policy "Users can unsave posts"
on public.saved_posts for delete
to authenticated
using (user_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'circle-media',
  'circle-media',
  true,
  20971520,
  array['image/jpeg','image/png','image/webp','video/mp4','video/webm']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read circle media" on storage.objects;
create policy "Public can read circle media"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'circle-media');

drop policy if exists "Circle admins can upload circle media" on storage.objects;
create policy "Circle admins can upload circle media"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'circle-media'
  and case
    when (storage.foldername(name))[1] ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then public.is_circle_admin(((storage.foldername(name))[1])::uuid)
    else false
  end
  and (
    (storage.foldername(name))[2] = 'profile'
    or (storage.foldername(name))[2] = auth.uid()::text
  )
);

drop policy if exists "Circle admins can remove circle media" on storage.objects;
create policy "Circle admins can remove circle media"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'circle-media'
  and case
    when (storage.foldername(name))[1] ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then public.is_circle_admin(((storage.foldername(name))[1])::uuid)
    else false
  end
);
