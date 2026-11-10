-- Streamia Player: physical-device trial, registration and server-side access.
-- Reviewed against the owner's exported public schema/functions (2026-11-08).
-- NOT applied to the live Supabase project. Test on a staging project first.

begin;

alter table public.devices
  add column if not exists device_fingerprint_hash text,
  add column if not exists trial_started_at timestamptz,
  add column if not exists trial_ends_at timestamptz,
  add column if not exists trial_used_at timestamptz;

create table if not exists public.device_trial_registry (
  fingerprint_hash text primary key,
  first_user_id uuid not null references auth.users(id) on delete cascade,
  trial_started_at timestamptz not null default now(),
  trial_ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint device_trial_registry_hash_length check (length(fingerprint_hash) = 64),
  constraint device_trial_registry_window check (trial_ends_at > trial_started_at)
);
alter table public.device_trial_registry enable row level security;
revoke all on table public.device_trial_registry from public, anon, authenticated;

create table if not exists public.admin_device_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  max_devices integer not null check (max_devices between 1 and 20),
  reason text,
  updated_at timestamptz not null default now()
);
alter table public.admin_device_limits enable row level security;
revoke all on table public.admin_device_limits from public, anon, authenticated;

-- Only the confirmed owner account receives the 10-device testing exception.
insert into public.admin_device_limits(user_id, max_devices, reason, updated_at)
values ('7947f863-ac28-41ef-a5c4-9154b6223f09'::uuid, 10,
        'Owner testing across TVs, TV boxes and smartphones', now())
on conflict (user_id) do update
set max_devices = excluded.max_devices, reason = excluded.reason, updated_at = now();

-- The admin grant is indefinite, has no customer plan, and is limited to this account.
insert into public.entitlements(
  user_id, plan_id, access_status, entitlement_source,
  trial_started_at, trial_ends_at, trial_used_at,
  subscription_started_at, subscription_ends_at,
  manual_override, granted_by, grant_reason, created_at, updated_at
)
values (
  '7947f863-ac28-41ef-a5c4-9154b6223f09'::uuid, null, 'active', 'admin_grant',
  null, null, null, now(), null, true,
  '7947f863-ac28-41ef-a5c4-9154b6223f09'::uuid,
  'Unbefristeter Admin-Testzugang; 10 Geräte', now(), now()
)
on conflict (user_id) do update
set plan_id = null, access_status = 'active', entitlement_source = 'admin_grant',
    subscription_started_at = coalesce(public.entitlements.subscription_started_at, now()),
    subscription_ends_at = null, manual_override = true,
    granted_by = '7947f863-ac28-41ef-a5c4-9154b6223f09'::uuid,
    grant_reason = 'Unbefristeter Admin-Testzugang; 10 Geräte', updated_at = now();

create unique index if not exists devices_user_fingerprint_unique
  on public.devices(user_id, device_fingerprint_hash)
  where device_fingerprint_hash is not null;

-- One physical fingerprint can consume only one trial, even across accounts.
create or replace function public.register_my_device_v2(
  p_installation_id text,
  p_fingerprint_hash text,
  p_device_name text default null,
  p_platform text default 'unknown',
  p_legacy_installation_id text default null
)
returns table(device_id uuid, device_status text, approved_at timestamptz,
              canonical_installation_id text, trial_started_at timestamptz,
              trial_ends_at timestamptz, trial_available boolean)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_device public.devices%rowtype;
  v_trial public.device_trial_registry%rowtype;
begin
  if v_user is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_installation_id is null or length(trim(p_installation_id)) < 16 or length(p_installation_id) > 128 then
    raise exception 'Invalid installation identifier' using errcode = '22023';
  end if;
  if p_fingerprint_hash is null or p_fingerprint_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid device fingerprint' using errcode = '22023';
  end if;
  if p_platform not in ('android','android_tv','ios','web','unknown') then
    raise exception 'Unsupported platform' using errcode = '22023';
  end if;

  -- Serialize registrations per account and per physical device.
  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));
  perform pg_advisory_xact_lock(hashtextextended(p_fingerprint_hash, 1));

  select * into v_device from public.devices d
   where d.user_id = v_user and
     (d.device_fingerprint_hash = p_fingerprint_hash
      or d.installation_id = trim(p_installation_id)
      or (p_legacy_installation_id is not null and p_legacy_installation_id = trim(p_installation_id)
          and d.installation_id = trim(p_legacy_installation_id)))
   order by (d.device_fingerprint_hash = p_fingerprint_hash) desc nulls last, d.created_at
   limit 1 for update;

  if v_device.id is null then
    -- Every previously unseen physical device may receive its own one-time trial.
    -- Paid/admin device caps are enforced by get_my_device_access_status.
    insert into public.devices(user_id, installation_id, device_fingerprint_hash,
      device_name, platform, status, approved_at, last_seen_at)
    values (v_user, trim(p_installation_id), p_fingerprint_hash,
      nullif(trim(coalesce(p_device_name,'')), ''), p_platform, 'active', now(), now())
    returning * into v_device;

    insert into public.device_trial_registry(fingerprint_hash, first_user_id, trial_started_at, trial_ends_at)
    values (p_fingerprint_hash, v_user, now(), now() + interval '7 days')
    on conflict (fingerprint_hash) do nothing;
    select * into v_trial from public.device_trial_registry r where r.fingerprint_hash = p_fingerprint_hash;
    if v_trial.first_user_id = v_user then
      update public.devices d set trial_started_at = v_trial.trial_started_at,
        trial_ends_at = v_trial.trial_ends_at, trial_used_at = v_trial.trial_started_at
      where d.id = v_device.id returning * into v_device;
    end if;
  else
    -- Never reactivate a blocked device through registration.
    update public.devices d set
      device_fingerprint_hash = coalesce(d.device_fingerprint_hash, p_fingerprint_hash),
      device_name = coalesce(nullif(trim(coalesce(p_device_name,'')), ''), d.device_name),
      platform = coalesce(nullif(p_platform, 'unknown'), d.platform),
      last_seen_at = now()
    where d.id = v_device.id returning * into v_device;

    -- Backfill the first physical-device trial for an installation carried over
    -- from the legacy register_my_device() function.
    if v_device.trial_started_at is null then
      insert into public.device_trial_registry(fingerprint_hash, first_user_id, trial_started_at, trial_ends_at)
      values (p_fingerprint_hash, v_user, now(), now() + interval '7 days')
      on conflict (fingerprint_hash) do nothing;
      select * into v_trial from public.device_trial_registry r where r.fingerprint_hash = p_fingerprint_hash;
      if v_trial.first_user_id = v_user then
        update public.devices d set trial_started_at = v_trial.trial_started_at,
          trial_ends_at = v_trial.trial_ends_at, trial_used_at = v_trial.trial_started_at
        where d.id = v_device.id returning * into v_device;
      end if;
    end if;
  end if;

  return query select v_device.id, v_device.status, v_device.approved_at,
    v_device.installation_id, v_device.trial_started_at, v_device.trial_ends_at,
    (v_device.trial_ends_at is not null and v_device.trial_ends_at > now());
end;
$$;

create or replace function public.get_my_device_access_status(p_installation_id text)
returns table(has_access boolean, access_reason text, device_id uuid, device_status text,
  trial_started_at timestamptz, trial_ends_at timestamptz, plan_code text,
  plan_name text, max_devices integer, effective_device_limit integer,
  entitlement_source text, subscription_ends_at timestamptz, manual_override boolean)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  return query
  with target as (
    select d.* from public.devices d
    where d.user_id = v_user and d.installation_id = p_installation_id
    limit 1
  ), ent as (
    select e.*, pl.code as p_code, pl.name as p_name, pl.max_devices as p_max
    from public.entitlements e left join public.plans pl on pl.id = e.plan_id
    where e.user_id = v_user limit 1
  ), lim as (
    select coalesce(adl.max_devices, ent.p_max, 1)::integer as cap
    from (select 1) s left join public.admin_device_limits adl on adl.user_id = v_user
    left join ent on true
  ), ranked as (
    select d.id, row_number() over(order by d.created_at, d.id) as rn
    from public.devices d where d.user_id = v_user and d.status = 'active'
  )
  select
    (t.id is not null and t.status = 'active' and (
      case when (
        (e.manual_override is true and e.entitlement_source = 'admin_grant'
         and (e.subscription_ends_at is null or e.subscription_ends_at > now()))
        or (e.access_status = 'active' and e.entitlement_source = 'subscription'
            and (e.subscription_ends_at is null or e.subscription_ends_at > now()))
      ) then coalesce(r.rn, 999999) <= lim.cap
      else (t.trial_ends_at is not null and t.trial_ends_at > now()) end
    )) as has_access,
    case
      when t.id is null then 'device_not_registered'
      when t.status = 'blocked' then 'device_blocked'
      when t.status <> 'active' then 'device_not_active'
      when e.manual_override is true and e.entitlement_source = 'admin_grant'
           and (e.subscription_ends_at is null or e.subscription_ends_at > now())
           and coalesce(r.rn,999999) > lim.cap then 'device_limit_reached'
      when e.access_status = 'active' and e.entitlement_source = 'subscription'
           and (e.subscription_ends_at is null or e.subscription_ends_at > now())
           and coalesce(r.rn,999999) > lim.cap then 'device_limit_reached'
      when e.manual_override is true and e.entitlement_source = 'admin_grant'
           and (e.subscription_ends_at is null or e.subscription_ends_at > now()) then 'admin_grant'
      when e.access_status = 'active' and e.entitlement_source = 'subscription'
           and (e.subscription_ends_at is null or e.subscription_ends_at > now()) then 'subscription'
      when t.trial_ends_at is not null then 'trial_expired'
      else 'no_active_access' end,
    t.id, t.status, t.trial_started_at, t.trial_ends_at,
    e.p_code, e.p_name, e.p_max, lim.cap, e.entitlement_source,
    e.subscription_ends_at, coalesce(e.manual_override,false)
  from target t cross join lim left join ent e on true
  left join ranked r on r.id = t.id;
end;
$$;

-- Disable the legacy account-wide trial entry point. Trials are started only by
-- successful first registration of a physical device in register_my_device_v2.
create or replace function public.start_streamia_trial()
returns table(started_at timestamptz, ends_at timestamptz)
language plpgsql security definer set search_path = ''
as $$ begin
  raise exception 'Account-wide trials are disabled. Register a physical device to start its one-time trial.';
end; $$;

-- Admin device inventory: no arbitrary user ID parameter; admin authorization server-side.
create or replace function public.admin_list_my_devices()
returns table(device_id uuid, user_id uuid, installation_id text, device_name text,
  platform text, device_status text, approved_at timestamptz, blocked_at timestamptz,
  last_seen_at timestamptz, created_at timestamptz, trial_ends_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$ begin
  if auth.uid() is null or not exists(select 1 from public.app_admins a where a.user_id = auth.uid()) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  return query select d.id,d.user_id,d.installation_id,d.device_name,d.platform,d.status,
    d.approved_at,d.blocked_at,d.last_seen_at,d.created_at,d.trial_ends_at
    from public.devices d order by d.created_at desc,d.id;
end; $$;

revoke all on function public.register_my_device_v2(text,text,text,text,text) from public, anon;
grant execute on function public.register_my_device_v2(text,text,text,text,text) to authenticated;
revoke all on function public.get_my_device_access_status(text) from public, anon;
grant execute on function public.get_my_device_access_status(text) to authenticated;
revoke all on function public.start_streamia_trial() from public, anon, authenticated;
revoke all on function public.admin_list_my_devices() from public, anon;
grant execute on function public.admin_list_my_devices() to authenticated;

-- Retain the auth.users AFTER INSERT trigger; revoking direct API execution does not remove it.
revoke execute on function public.handle_new_streamia_user() from public, anon, authenticated;
revoke execute on function public.admin_grant_access(uuid,integer,text) from public, anon;
revoke execute on function public.admin_set_device_status(uuid,text,text) from public, anon;
revoke execute on function public.is_streamia_admin() from public, anon;
grant execute on function public.is_streamia_admin() to authenticated;

commit;
