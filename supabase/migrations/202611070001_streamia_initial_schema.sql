-- Streamia Player initial Supabase schema.
-- Apply in Supabase Dashboard > SQL Editor.
-- This migration intentionally does not store playlist credentials or implement payments.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  preferred_language text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_language_length check (char_length(preferred_language) between 2 and 5)
);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, nullif(trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_name text not null,
  platform text not null default 'unknown',
  device_fingerprint_hash text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  is_active boolean not null default true,
  constraint devices_name_length check (char_length(device_name) between 1 and 120),
  constraint devices_platform check (platform in ('android','android_tv','web','ios','unknown'))
);
create index if not exists devices_user_id_idx on public.devices(user_id);

-- Metadata only. Passwords, tokens and private playlist URLs are not stored here.
create table if not exists public.playlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  source_type text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint playlists_name_length check (char_length(name) between 1 and 120),
  constraint playlists_source_type check (source_type in ('m3u_url','m3u_file','xtream'))
);
create index if not exists playlists_user_id_idx on public.playlists(user_id);
drop trigger if exists playlists_set_updated_at on public.playlists;
create trigger playlists_set_updated_at before update on public.playlists
for each row execute function public.set_updated_at();

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  preferred_language text not null default 'en',
  theme_mode text not null default 'dark',
  parental_lock_enabled boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint user_settings_theme check (theme_mode in ('dark','light','system')),
  constraint user_settings_language_length check (char_length(preferred_language) between 2 and 5)
);
drop trigger if exists user_settings_set_updated_at on public.user_settings;
create trigger user_settings_set_updated_at before update on public.user_settings
for each row execute function public.set_updated_at();

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  playlist_id uuid references public.playlists(id) on delete cascade,
  content_id text not null,
  content_type text not null,
  title text not null,
  created_at timestamptz not null default now(),
  constraint favorites_type check (content_type in ('live','vod','series')),
  constraint favorites_content_id_length check (char_length(content_id) between 1 and 500),
  unique (user_id, playlist_id, content_id, content_type)
);
create index if not exists favorites_user_id_idx on public.favorites(user_id);

create table if not exists public.watch_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  playlist_id uuid references public.playlists(id) on delete set null,
  content_id text not null,
  content_type text not null,
  title text not null,
  position_seconds bigint not null default 0,
  duration_seconds bigint,
  watched_at timestamptz not null default now(),
  constraint watch_history_type check (content_type in ('live','vod','series')),
  constraint watch_history_position check (position_seconds >= 0),
  constraint watch_history_duration check (duration_seconds is null or duration_seconds >= 0)
);
create index if not exists watch_history_user_watched_idx on public.watch_history(user_id, watched_at desc);

-- Read-only for normal app clients. Only trusted server-side payment logic may modify.
create table if not exists public.entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan_code text not null default 'free',
  status text not null default 'active',
  device_limit integer not null default 1,
  valid_until timestamptz,
  updated_at timestamptz not null default now(),
  constraint entitlements_status check (status in ('active','inactive','past_due','cancelled')),
  constraint entitlements_device_limit check (device_limit between 1 and 20)
);

alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.playlists enable row level security;
alter table public.user_settings enable row level security;
alter table public.favorites enable row level security;
alter table public.watch_history enable row level security;
alter table public.entitlements enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (auth.uid() = id);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists devices_select_own on public.devices;
create policy devices_select_own on public.devices for select to authenticated using (auth.uid() = user_id);
drop policy if exists devices_insert_own on public.devices;
create policy devices_insert_own on public.devices for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists devices_update_own on public.devices;
create policy devices_update_own on public.devices for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists devices_delete_own on public.devices;
create policy devices_delete_own on public.devices for delete to authenticated using (auth.uid() = user_id);

drop policy if exists playlists_select_own on public.playlists;
create policy playlists_select_own on public.playlists for select to authenticated using (auth.uid() = user_id);
drop policy if exists playlists_insert_own on public.playlists;
create policy playlists_insert_own on public.playlists for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists playlists_update_own on public.playlists;
create policy playlists_update_own on public.playlists for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists playlists_delete_own on public.playlists;
create policy playlists_delete_own on public.playlists for delete to authenticated using (auth.uid() = user_id);

drop policy if exists user_settings_select_own on public.user_settings;
create policy user_settings_select_own on public.user_settings for select to authenticated using (auth.uid() = user_id);
drop policy if exists user_settings_insert_own on public.user_settings;
create policy user_settings_insert_own on public.user_settings for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists user_settings_update_own on public.user_settings;
create policy user_settings_update_own on public.user_settings for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists favorites_select_own on public.favorites;
create policy favorites_select_own on public.favorites for select to authenticated using (auth.uid() = user_id);
drop policy if exists favorites_insert_own on public.favorites;
create policy favorites_insert_own on public.favorites for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists favorites_delete_own on public.favorites;
create policy favorites_delete_own on public.favorites for delete to authenticated using (auth.uid() = user_id);

drop policy if exists watch_history_select_own on public.watch_history;
create policy watch_history_select_own on public.watch_history for select to authenticated using (auth.uid() = user_id);
drop policy if exists watch_history_insert_own on public.watch_history;
create policy watch_history_insert_own on public.watch_history for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists watch_history_update_own on public.watch_history;
create policy watch_history_update_own on public.watch_history for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists watch_history_delete_own on public.watch_history;
create policy watch_history_delete_own on public.watch_history for delete to authenticated using (auth.uid() = user_id);

drop policy if exists entitlements_select_own on public.entitlements;
create policy entitlements_select_own on public.entitlements for select to authenticated using (auth.uid() = user_id);

create or replace function public.create_default_entitlement()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.entitlements (user_id, plan_code, status, device_limit)
  values (new.id, 'free', 'active', 1)
  on conflict (user_id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_default_entitlement on auth.users;
create trigger on_auth_user_default_entitlement after insert on auth.users
for each row execute procedure public.create_default_entitlement();

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.devices to authenticated;
grant select, insert, update, delete on public.playlists to authenticated;
grant select, insert, update on public.user_settings to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant select, insert, update, delete on public.watch_history to authenticated;
grant select on public.entitlements to authenticated;
