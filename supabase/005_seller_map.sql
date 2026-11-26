-- Explicit opt-in seller map presence. Coordinates are rounded by the app to
-- 0.01 degrees (roughly 1 km in Hanoi) before they are written. Never store
-- or expose a device's precise location or a home address here.
begin;
create table public.seller_map_locations (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  latitude double precision not null check(latitude between 20.4 and 21.8),
  longitude double precision not null check(longitude between 105.0 and 106.0),
  updated_at timestamptz not null default now()
);
alter table public.seller_map_locations enable row level security;
grant select on public.seller_map_locations to anon, authenticated;
grant insert, update, delete on public.seller_map_locations to authenticated;
create policy seller_map_read on public.seller_map_locations for select using(true);
create policy seller_map_insert_own on public.seller_map_locations for insert to authenticated
  with check(owner_id = auth.uid());
create policy seller_map_update_own on public.seller_map_locations for update to authenticated
  using(owner_id = auth.uid()) with check(owner_id = auth.uid());
create policy seller_map_delete_own on public.seller_map_locations for delete to authenticated
  using(owner_id = auth.uid());
create index seller_map_location_point on public.seller_map_locations(latitude, longitude);
commit;
