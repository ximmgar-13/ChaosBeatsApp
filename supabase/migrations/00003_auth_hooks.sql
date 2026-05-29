-- ============================================================
-- Auth helper functions for Google OAuth & email
-- ============================================================

-- Function to check if username is available
create or replace function public.is_username_available(username text)
returns boolean
language sql
security definer
as $$
  select not exists (
    select 1 from public.users where username = $1
  );
$$;

-- Function to get current user's profile
create or replace function public.get_my_profile()
returns public.users
language sql
security definer
stable
as $$
  select * from public.users where id = auth.uid();
$$;

-- Function to get user's membership status
create or replace function public.get_my_membership()
returns table (
  plan_type text,
  status text,
  current_period_end timestamptz
)
language sql
security definer
stable
as $$
  select plan_type, status, current_period_end
  from public.user_memberships
  where user_id = auth.uid()
  order by created_at desc
  limit 1;
$$;

-- Function to increment play count
create or replace function public.increment_play_count(song_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.songs
  set play_count = play_count + 1
  where id = song_id;
end;
$$;
