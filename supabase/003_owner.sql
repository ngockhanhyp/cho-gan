create table public.admin_emails(email text primary key);
alter table public.admin_emails enable row level security;
-- Populate privately in Supabase for the verified owner account.
create or replace function public.is_moderator() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from moderators where user_id=auth.uid()) or exists(select 1 from auth.users u join public.admin_emails a on lower(u.email)=lower(a.email) where u.id=auth.uid() and u.email_confirmed_at is not null); $$;
