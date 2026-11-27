begin;

alter table public.community_posts
  add column if not exists topic text not null default 'discussion'
  check (topic in ('discussion', 'notice', 'help', 'meetup'));

create table if not exists public.community_replies (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
alter table public.community_replies enable row level security;
grant select, insert on public.community_replies to authenticated;
create policy community_replies_read on public.community_replies
  for select to authenticated using (exists (
    select 1 from public.community_posts p
    where p.id = post_id and public.is_member(p.community_id)
  ));
create policy community_replies_write on public.community_replies
  for insert to authenticated with check (author_id = auth.uid() and exists (
    select 1 from public.community_posts p
    where p.id = post_id and public.is_member(p.community_id)
  ));
create index community_replies_by_post on public.community_replies(post_id, created_at);

alter table public.consignment_requests add column if not exists contact text
  check (contact is null or length(contact) between 5 and 160);

commit;
