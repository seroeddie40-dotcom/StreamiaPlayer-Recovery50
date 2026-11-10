-- Streamia Player: account-based playback progress / Continue Watching.
-- Safe to apply after 202611070001_streamia_initial_schema.sql.

alter table public.watch_history
  add column if not exists source_key text;

-- Preserve existing history rows while making them addressable as legacy data.
update public.watch_history
set source_key = 'legacy:default'
where source_key is null or btrim(source_key) = '';

alter table public.watch_history
  alter column source_key set default 'legacy:default',
  alter column source_key set not null;

-- Keep only the newest row for each logical item before adding the unique key.
with ranked as (
  select id,
         row_number() over (
           partition by user_id, source_key, content_id, content_type
           order by watched_at desc, id desc
         ) as rn
  from public.watch_history
)
delete from public.watch_history h
using ranked r
where h.id = r.id and r.rn > 1;

create unique index if not exists watch_history_user_source_content_uidx
  on public.watch_history(user_id, source_key, content_id, content_type);

create index if not exists watch_history_continue_idx
  on public.watch_history(user_id, watched_at desc);

alter table public.watch_history enable row level security;

drop policy if exists watch_history_select_own on public.watch_history;
create policy watch_history_select_own on public.watch_history
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists watch_history_insert_own on public.watch_history;
create policy watch_history_insert_own on public.watch_history
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists watch_history_update_own on public.watch_history;
create policy watch_history_update_own on public.watch_history
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists watch_history_delete_own on public.watch_history;
create policy watch_history_delete_own on public.watch_history
  for delete to authenticated using (auth.uid() = user_id);

grant select, insert, update, delete on public.watch_history to authenticated;
