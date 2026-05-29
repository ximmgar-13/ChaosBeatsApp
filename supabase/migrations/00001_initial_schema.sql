-- ============================================================
-- CHAOS BEATS - Supabase Initial Schema
-- Tablas: users, songs, playlists, playlist_songs, favorites,
--          donations, early_listeners, comments, notifications,
--          user_settings, user_memberships
-- ============================================================

-- 0. EXTENSIONS
create extension if not exists "pgcrypto" with schema extensions;
create extension if not exists "pg_trgm" with schema extensions;

-- 1. USERS (extends auth.users)
create table public.users (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null,
  display_name  text,
  avatar_url    text,
  bio           text,
  website       text,
  phone         text,
  is_premium    boolean not null default false,
  membership_tier text check (membership_tier in ('free','early_bird','premium','lifetime')),
  membership_expires_at timestamptz,
  storage_used_mb numeric default 0,
  storage_limit_mb numeric default 500,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 2. SONGS
create table public.songs (
  id            uuid primary key default gen_random_uuid(),
  artist_id     uuid not null references public.users(id) on delete cascade,
  title         text not null,
  album         text,
  genre         text,
  duration_seconds int,
  audio_url     text not null,
  cover_url     text,
  lyrics        text,
  is_explicit   boolean default false,
  play_count    bigint default 0,
  download_count bigint default 0,
  is_offline_available boolean default false,
  status        text default 'published' check (status in ('draft','published','archived')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 3. PLAYLISTS
create table public.playlists (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references public.users(id) on delete cascade,
  name          text not null,
  description   text,
  cover_url     text,
  is_public     boolean default true,
  is_collaborative boolean default false,
  song_count    int default 0,
  total_duration_seconds int default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 4. PLAYLIST_SONGS (junction)
create table public.playlist_songs (
  id            uuid primary key default gen_random_uuid(),
  playlist_id   uuid not null references public.playlists(id) on delete cascade,
  song_id       uuid not null references public.songs(id) on delete cascade,
  position      int not null,
  added_at      timestamptz not null default now(),
  added_by      uuid references public.users(id) on delete set null,
  unique(playlist_id, song_id)
);

-- 5. FAVORITES
create table public.favorites (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  song_id       uuid not null references public.songs(id) on delete cascade,
  created_at    timestamptz not null default now(),
  unique(user_id, song_id)
);

-- 6. DONATIONS
create table public.donations (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  amount        numeric(10,2) not null check (amount > 0),
  currency      text default 'USD',
  message       text,
  is_anonymous  boolean default false,
  payment_method text,
  payment_status text default 'pending' check (payment_status in ('pending','completed','failed','refunded')),
  created_at    timestamptz not null default now()
);

-- 7. EARLY_LISTENERS (early access / supporters)
create table public.early_listeners (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  supporter_tier text check (supporter_tier in ('beta_tester','founder','early_bird','angel')),
  access_granted_at timestamptz not null default now(),
  expires_at     timestamptz,
  is_active     boolean default true,
  unique(user_id)
);

-- 8. COMMENTS
create table public.comments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  song_id       uuid not null references public.songs(id) on delete cascade,
  parent_id     uuid references public.comments(id) on delete cascade,
  content       text not null,
  is_edited     boolean default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 9. NOTIFICATIONS
create table public.notifications (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  title         text not null,
  body          text,
  data          jsonb,
  type          text check (type in ('new_song','playlist_update','donation','system','comment','follow')),
  is_read       boolean default false,
  sent_at       timestamptz not null default now(),
  read_at       timestamptz
);

-- 10. USER_SETTINGS
create table public.user_settings (
  user_id                   uuid primary key references public.users(id) on delete cascade,
  language                  text default 'es',
  dark_mode                 boolean default true,
  notifications_enabled     boolean default true,
  push_notifications_enabled boolean default true,
  email_notifications       boolean default true,
  offline_auto_download      boolean default false,
  quality_preference        text default 'high' check (quality_preference in ('low','medium','high','lossless')),
  show_explicit_content     boolean default true,
  autoplay                  boolean default true,
  updated_at                timestamptz not null default now()
);

-- 11. USER_MEMBERSHIPS (for Stripe/webhook tracking)
create table public.user_memberships (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  stripe_customer_id text,
  stripe_subscription_id text,
  plan_type       text not null check (plan_type in ('monthly','yearly','lifetime')),
  status          text not null default 'active' check (status in ('active','canceled','past_due','expired','trialing')),
  current_period_start timestamptz,
  current_period_end   timestamptz,
  canceled_at     timestamptz,
  created_at      timestamptz not null default now(),
  unique(user_id)
);

-- ============================================================
-- INDEXES
-- ============================================================
create index idx_songs_artist on public.songs(artist_id);
create index idx_songs_genre on public.songs(genre);
create index idx_songs_created on public.songs(created_at desc);
create index idx_songs_title_trgm on public.songs using gin (title gin_trgm_ops);
create index idx_favorites_user on public.favorites(user_id);
create index idx_favorites_song on public.favorites(song_id);
create index idx_comments_song on public.comments(song_id);
create index idx_comments_user on public.comments(user_id);
create index idx_playlists_owner on public.playlists(owner_id);
create index idx_notifications_user on public.notifications(user_id);
create index idx_notifications_unread on public.notifications(user_id) where is_read = false;
create index idx_donations_user on public.donations(user_id);
create index idx_songs_offline on public.songs(is_offline_available) where is_offline_available = true;

-- ============================================================
-- TRIGGER: auto-create user record on auth.signup
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.users (id, username, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'avatar_url'
  );
  insert into public.user_settings (user_id) values (new.id);
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- TRIGGER: update updated_at
-- ============================================================
create or replace function public.update_updated_at_column()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trigger_users_updated_at
  before update on public.users
  for each row execute function public.update_updated_at_column();

create trigger trigger_songs_updated_at
  before update on public.songs
  for each row execute function public.update_updated_at_column();

create trigger trigger_playlists_updated_at
  before update on public.playlists
  for each row execute function public.update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.users enable row level security;
alter table public.songs enable row level security;
alter table public.playlists enable row level security;
alter table public.playlist_songs enable row level security;
alter table public.favorites enable row level security;
alter table public.donations enable row level security;
alter table public.early_listeners enable row level security;
alter table public.comments enable row level security;
alter table public.notifications enable row level security;
alter table public.user_settings enable row level security;
alter table public.user_memberships enable row level security;

-- USERS: each user can read all profiles, update own
create policy "users_select_all" on public.users
  for select using (true);

create policy "users_insert_own" on public.users
  for insert with check (id = auth.uid());

create policy "users_update_own" on public.users
  for update using (id = auth.uid());

-- SONGS: public read, artists manage own
create policy "songs_select_published" on public.songs
  for select using (status = 'published' or artist_id = auth.uid());

create policy "songs_insert_own" on public.songs
  for insert with check (artist_id = auth.uid());

create policy "songs_update_own" on public.songs
  for update using (artist_id = auth.uid());

create policy "songs_delete_own" on public.songs
  for delete using (artist_id = auth.uid());

-- PLAYLISTS: owner full access, others see public
create policy "playlists_select" on public.playlists
  for select using (is_public = true or owner_id = auth.uid());

create policy "playlists_insert_own" on public.playlists
  for insert with check (owner_id = auth.uid());

create policy "playlists_update_own" on public.playlists
  for update using (owner_id = auth.uid());

create policy "playlists_delete_own" on public.playlists
  for delete using (owner_id = auth.uid());

-- PLAYLIST_SONGS: through playlist access
create policy "playlist_songs_select" on public.playlist_songs
  for select using (
    exists (
      select 1 from public.playlists
      where id = playlist_id and (is_public = true or owner_id = auth.uid())
    )
  );

create policy "playlist_songs_insert_own" on public.playlist_songs
  for insert with check (
    exists (select 1 from public.playlists where id = playlist_id and owner_id = auth.uid())
  );

create policy "playlist_songs_delete_own" on public.playlist_songs
  for delete using (
    exists (select 1 from public.playlists where id = playlist_id and owner_id = auth.uid())
  );

-- FAVORITES: user manages own
create policy "favorites_select_own" on public.favorites
  for select using (user_id = auth.uid());

create policy "favorites_insert_own" on public.favorites
  for insert with check (user_id = auth.uid());

create policy "favorites_delete_own" on public.favorites
  for delete using (user_id = auth.uid());

-- DONATIONS: donor can see own, admin see all (via service_role)
create policy "donations_select_own" on public.donations
  for select using (user_id = auth.uid());

create policy "donations_insert" on public.donations
  for insert with check (user_id = auth.uid());

-- EARLY_LISTENERS: public read, admin manage
create policy "early_listeners_select" on public.early_listeners
  for select using (true);

-- COMMENTS: public read, authenticated insert/update own
create policy "comments_select" on public.comments
  for select using (true);

create policy "comments_insert" on public.comments
  for insert with check (user_id = auth.uid());

create policy "comments_update_own" on public.comments
  for update using (user_id = auth.uid());

create policy "comments_delete_own" on public.comments
  for delete using (user_id = auth.uid());

-- NOTIFICATIONS: user reads own
create policy "notifications_select_own" on public.notifications
  for select using (user_id = auth.uid());

create policy "notifications_update_own" on public.notifications
  for update using (user_id = auth.uid());

-- USER_SETTINGS: individual access
create policy "user_settings_select_own" on public.user_settings
  for select using (user_id = auth.uid());

create policy "user_settings_insert_own" on public.user_settings
  for insert with check (user_id = auth.uid());

create policy "user_settings_update_own" on public.user_settings
  for update using (user_id = auth.uid());

-- USER_MEMBERSHIPS: user sees own
create policy "user_memberships_select_own" on public.user_memberships
  for select using (user_id = auth.uid());

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('audio', 'audio', true, 52428800, array['audio/mpeg','audio/wav','audio/flac','audio/aac','audio/ogg','audio/mp4']),
  ('covers', 'covers', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('avatars', 'avatars', true, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- Storage RLS
create policy "audio_select" on storage.objects
  for select using (bucket_id = 'audio');

create policy "audio_insert" on storage.objects
  for insert with check (bucket_id = 'audio' and auth.role() = 'authenticated');

create policy "audio_delete" on storage.objects
  for delete using (bucket_id = 'audio' and auth.role() = 'authenticated');

create policy "covers_select" on storage.objects
  for select using (bucket_id = 'covers');

create policy "covers_insert" on storage.objects
  for insert with check (bucket_id = 'covers' and auth.role() = 'authenticated');

create policy "covers_delete" on storage.objects
  for delete using (bucket_id = 'covers' and auth.role() = 'authenticated');

create policy "avatars_select" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "avatars_insert" on storage.objects
  for insert with check (bucket_id = 'avatars' and auth.role() = 'authenticated');

create policy "avatars_delete" on storage.objects
  for delete using (bucket_id = 'avatars' and auth.role() = 'authenticated');
