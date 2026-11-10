-- Streamia Player: access status and device registration helpers.
-- IMPORTANT: This file targets the LIVE schema confirmed by the project owner:
-- plans(id, code, name, max_devices, active, created_at)
-- devices(id, user_id, installation_id, device_name, platform, status,
--         approved_at, blocked_at, last_seen_at, created_at)
-- entitlements(id, user_id, plan_id, access_status, entitlement_source,
--   trial_started_at, trial_ends_at, trial_used_at, subscription_started_at,
--   subscription_ends_at, manual_override, granted_by, grant_reason,
--   created_at, updated_at)
-- It intentionally does NOT create or modify the tables or existing admin functions.
-- Run in Supabase SQL Editor only after reviewing the duplicate check below.

-- 1) Ensure one installation can only be registered once per account.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.devices
    GROUP BY user_id, installation_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate (user_id, installation_id) rows exist in public.devices. Review and merge duplicates before applying this script.';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS devices_user_installation_unique
  ON public.devices(user_id, installation_id);

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS devices_select_own ON public.devices;
CREATE POLICY devices_select_own ON public.devices
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Clients must not approve or block devices by directly editing the table.
REVOKE INSERT, UPDATE, DELETE ON public.devices FROM anon, authenticated;
GRANT SELECT ON public.devices TO authenticated;

-- 2) Register the current app installation. New devices remain pending until
-- the administrator explicitly approves them. Existing device status is kept.
CREATE OR REPLACE FUNCTION public.register_my_device(
  p_installation_id text,
  p_device_name text DEFAULT NULL,
  p_platform text DEFAULT 'unknown'
)
RETURNS TABLE(device_id uuid, device_status text, approved_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_device public.devices%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_installation_id IS NULL OR length(trim(p_installation_id)) < 16 OR length(p_installation_id) > 100 THEN
    RAISE EXCEPTION 'Invalid installation identifier';
  END IF;
  IF p_platform NOT IN ('android', 'android_tv', 'web', 'ios', 'unknown') THEN
    RAISE EXCEPTION 'Unsupported platform';
  END IF;

  INSERT INTO public.devices(user_id, installation_id, device_name, platform, status, last_seen_at)
  VALUES (v_user_id, trim(p_installation_id), nullif(trim(coalesce(p_device_name, '')), ''), p_platform, 'pending', now())
  ON CONFLICT (user_id, installation_id) DO UPDATE
    SET last_seen_at = now(),
        device_name = coalesce(nullif(trim(excluded.device_name), ''), public.devices.device_name),
        platform = coalesce(nullif(excluded.platform, ''), public.devices.platform)
  RETURNING * INTO v_device;

  RETURN QUERY SELECT v_device.id, v_device.status, v_device.approved_at;
END;
$$;

REVOKE ALL ON FUNCTION public.register_my_device(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_my_device(text, text, text) TO authenticated;

-- 3) Return the server-calculated access state. Trial expiry is enforced here;
-- the app must not grant access based on a locally stored date.
CREATE OR REPLACE FUNCTION public.get_my_access_status()
RETURNS TABLE(
  has_access boolean,
  access_reason text,
  access_status text,
  entitlement_source text,
  plan_code text,
  plan_name text,
  max_devices integer,
  trial_ends_at timestamptz,
  subscription_ends_at timestamptz,
  manual_override boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    CASE
      WHEN e.manual_override IS TRUE
        AND e.entitlement_source = 'admin_grant'
        AND (e.subscription_ends_at IS NULL OR e.subscription_ends_at > now())
        THEN true
      WHEN e.access_status = 'active'
        AND e.entitlement_source = 'subscription'
        AND (e.subscription_ends_at IS NULL OR e.subscription_ends_at > now())
        THEN true
      WHEN e.access_status = 'trial'
        AND e.entitlement_source = 'trial'
        AND e.trial_ends_at IS NOT NULL
        AND e.trial_ends_at > now()
        THEN true
      ELSE false
    END AS has_access,
    CASE
      WHEN e.manual_override IS TRUE AND e.entitlement_source = 'admin_grant'
        AND (e.subscription_ends_at IS NULL OR e.subscription_ends_at > now()) THEN 'admin_grant'
      WHEN e.access_status = 'active' AND e.entitlement_source = 'subscription'
        AND (e.subscription_ends_at IS NULL OR e.subscription_ends_at > now()) THEN 'subscription'
      WHEN e.access_status = 'trial' AND e.entitlement_source = 'trial'
        AND e.trial_ends_at > now() THEN 'trial'
      WHEN e.trial_ends_at IS NOT NULL AND e.trial_ends_at <= now() THEN 'trial_expired'
      ELSE 'no_active_access'
    END AS access_reason,
    e.access_status,
    e.entitlement_source,
    p.code,
    p.name,
    p.max_devices,
    e.trial_ends_at,
    e.subscription_ends_at,
    coalesce(e.manual_override, false)
  FROM public.entitlements e
  LEFT JOIN public.plans p ON p.id = e.plan_id
  WHERE e.user_id = auth.uid()
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_my_access_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_access_status() TO authenticated;

-- No client-side function can start or extend a trial automatically. The
-- existing start_streamia_trial() remains the only explicit trial-start path.
