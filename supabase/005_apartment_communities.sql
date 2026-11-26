begin;
alter table public.communities
 add column community_type text not null default 'general' check(community_type in ('general','apartment')),
 add column building_location text;
alter table public.communities add constraint apartment_location_required
 check(community_type <> 'apartment' or (building_location is not null and length(building_location) between 3 and 160));

create function public.create_apartment_community(building_name text, building_location text)
returns uuid language plpgsql security definer set search_path=public as $$
declare g uuid;
begin
 if auth.uid() is null then raise exception 'Cần đăng nhập'; end if;
 if length(trim(building_name)) not between 3 and 80 or length(trim(building_location)) not between 3 and 160 then
   raise exception 'Kiểm tra tên tòa nhà và khu vực';
 end if;
 if (select count(*) from public.communities where owner_id=auth.uid())>=5 then raise exception 'Tối đa 5 cộng đồng mỗi tài khoản'; end if;
 insert into public.communities(name,owner_id,community_type,building_location)
 values(trim(building_name),auth.uid(),'apartment',trim(building_location)) returning id into g;
 insert into public.community_members(community_id,user_id) values(g,auth.uid());
 return g;
end; $$;
revoke all on function public.create_apartment_community(text,text) from public;
grant execute on function public.create_apartment_community(text,text) to authenticated;
commit;
