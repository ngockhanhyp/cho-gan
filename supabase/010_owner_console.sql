alter table public.messages add column admin_notice_shown boolean not null default false;

create function public.owner_console(section text, page_no integer default 0, target uuid default null, reason text default '', search_term text default '')
returns table(row_id uuid,label text,detail text) language plpgsql security definer set search_path='' as $$
declare actor uuid := auth.uid();
begin
 if not exists(select 1 from auth.users u join public.admin_emails a on lower(a.email)=lower(u.email) where u.id=actor and u.email_confirmed_at is not null) then
   raise exception 'Tài khoản chưa có quyền chủ nền tảng' using errcode='42501';
 end if;
 if page_no is null or page_no not between 0 and 1000000 then raise exception 'Trang không hợp lệ'; end if;
 if section='Tin đăng' then
   return query select l.id,l.title,concat_ws(' · ',l.area,l.status,case when l.moderated then 'Đã ẩn do kiểm duyệt' end) from public.listings l where l.title ilike '%'||search_term||'%' or l.id::text=search_term order by l.created_at desc,l.id limit 50 offset page_no*50;
 elsif section in ('Ẩn tin','Gỡ ẩn') then
   if length(trim(coalesce(reason,''))) not between 5 and 300 then raise exception 'Cần ghi lý do'; end if;
   update public.listings set moderated=(section='Ẩn tin') where id=target and moderated is distinct from (section='Ẩn tin');
   if not found then raise exception 'Tin đã đổi trạng thái hoặc không tồn tại'; end if;
   insert into public.moderation_log(actor_id,action) values(actor,concat(section,' ',target,' · ',reason));
 elsif section='Thành viên' then
   return query select p.id,p.name,p.area from public.profiles p where p.name ilike '%'||search_term||'%' or p.id::text=search_term order by p.created_at desc,p.id limit 50 offset page_no*50;
 elsif section='Hội thoại' then
   return query select c.id,l.title,concat_ws(' ↔ ',b.name,s.name) from public.conversations c join public.listings l on l.id=c.listing_id join public.profiles b on b.id=c.buyer_id join public.profiles s on s.id=c.seller_id where concat_ws(' ',l.title,b.name,s.name,c.id) ilike '%'||search_term||'%' order by c.created_at desc,c.id limit 50 offset page_no*50;
 elsif section='Tin nhắn' then
   if length(trim(coalesce(reason,''))) not between 5 and 300 or target is null then raise exception 'Cần ghi lý do truy cập'; end if;
   insert into public.moderation_log(actor_id,action) values(actor,concat('Đọc hội thoại ',target,' · ',reason));
   return query select m.id,concat_ws(' · ',p.name,m.created_at::text),m.body from public.messages m join public.profiles p on p.id=m.sender_id where m.conversation_id=target and m.admin_notice_shown order by m.created_at desc,m.id limit 50 offset page_no*50;
 elsif section='Nhật ký' then
   return query select l.id,l.action,concat_ws(' · ',p.name,l.created_at::text) from public.moderation_log l left join public.profiles p on p.id=l.actor_id where l.action ilike '%'||search_term||'%' order by l.created_at desc,l.id limit 50 offset page_no*50;
 else raise exception 'Mục không hợp lệ';
 end if;
end; $$;
revoke all on function public.owner_console(text,integer,uuid,text,text) from public,anon;
grant execute on function public.owner_console(text,integer,uuid,text,text) to authenticated;
notify pgrst,'reload schema';
