-- Streamia Player: account-based favorites sync + portable backup metadata.
-- Safe to apply after 202611070001_streamia_initial_schema.sql.
-- Does not store playlist credentials, stream URLs, or media files.

alter table public.favorites
  add column if not exists source_key text,
  add column if not exists source_label text,
  add column if not exists updated_at timestamptz not null default now();

-- Existing favorites remain available. Their source is marked as legacy until
-- the app can associate them with a stable playlist/source identifier.
update public.favorites
set source_key = coalesce(source_key, case
  when playlist_id is not null then 'playlist:' || playlist_id::text
  else 'legacy:default'
end)
where source_key is null;

alter table public.favorites alter column source_key set not null;
alter table public.favorites
  add constraint favorites_source_key_length
  check (char_length(source_key) between 1 and 500);

-- Remove legacy duplicates before creating the stricter account/source uniqueness rule.
with ranked as (
  select id, row_number() over (
    partition by user_id, content_type, source_key, content_id
    order by created_at asc, id asc
  ) as rn
  from public.favorites
)
delete from public.favorites f using ranked r
where f.id = r.id and r.rn > 1;

create unique index if not exists favorites_account_sync_unique
  on public.favorites(user_id, content_type, source_key, content_id);
create index if not exists favorites_user_type_idx
  on public.favorites(user_id, content_type);

-- RLS remains enabled; users can only access their own favorites.
-- Ensure update permission exists for PostgREST upsert conflict updates.
drop policy if exists favorites_update_own on public.favorites;
create policy favorites_update_own on public.favorites
  for update to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete on public.favorites to authenticated;

comment on column public.favorites.source_key is
  'Stable, non-secret identifier for the playlist/source that owns this favorite; never a stream URL or credential.';
comment on column public.favorites.source_label is
  'Optional human-readable playlist/source label; contains no credentials.';
