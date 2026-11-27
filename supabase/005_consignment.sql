begin;
create table public.consignment_requests (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check(length(title) between 3 and 160),
 description text not null check(length(description) between 10 and 3000),
 asking_price bigint check(asking_price is null or asking_price >= 0),
 warehouse text not null check(warehouse in ('Tòa Vinacomin, Hà Nội','530 Nguyễn Trãi, Bắc Ninh')),
 status text not null default 'pending' check(status in ('pending','reviewing','accepted','received','listed','sold','paid','rejected','returned')),
 agreed_sale_price bigint check(agreed_sale_price is null or agreed_sale_price >= 0),
 commission_amount bigint check(commission_amount is null or commission_amount >= 0),
 staff_note text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.consignment_requests enable row level security;
grant select, insert on public.consignment_requests to authenticated;
grant update on public.consignment_requests to authenticated;
create policy consignment_owner_read on public.consignment_requests for select to authenticated using(owner_id=auth.uid());
create policy consignment_staff_read on public.consignment_requests for select to authenticated using(public.is_moderator());
create policy consignment_owner_insert on public.consignment_requests for insert to authenticated with check(owner_id=auth.uid() and status='pending' and agreed_sale_price is null and commission_amount is null and staff_note is null);
create policy consignment_staff_update on public.consignment_requests for update to authenticated using(public.is_moderator()) with check(public.is_moderator());
create index consignment_owner_created on public.consignment_requests(owner_id,created_at desc);
commit;
