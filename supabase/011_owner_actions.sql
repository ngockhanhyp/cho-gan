create function public.owner_content_action(op text, target uuid, payload jsonb default '{}', reason text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  item public.listings;
  images text[];
  photo text := payload->>'photo';
  version text;
begin
  if not exists(select 1 from auth.users u join public.admin_emails a on lower(a.email)=lower(u.email)
    where u.id=auth.uid() and u.email_confirmed_at is not null) then
    raise exception 'Chỉ chủ nền tảng được thao tác' using errcode='42501';
  end if;
  if op <> 'inspect' and length(trim(coalesce(reason,''))) not between 5 and 300 then
    raise exception 'Cần ghi lý do (5–300 ký tự)';
  end if;
  if op='delete_message' then
    delete from public.messages where id=target and conversation_id=(payload->>'thread')::uuid and admin_notice_shown;
    if not found then raise exception 'Tin nhắn không còn khả dụng'; end if;
  else
    select * into strict item from public.listings where id=target for update;
    version := md5(to_jsonb(item)::text);
    images := array_remove(array_prepend(item.image_path,item.additional_image_paths),'');
    if op='inspect' then
      return jsonb_build_object('title',item.title,'description',item.description,'price',item.price,'photos',images,'version',version);
    end if;
    if version is distinct from payload->>'version' then raise exception 'Tin đã thay đổi. Hãy mở lại.'; end if;
    case op
    when 'edit' then
      update public.listings set title=trim(payload->>'title'),description=trim(payload->>'description'),price=(payload->>'price')::bigint where id=target;
    when 'remove_photo' then
      if photo is null or not(photo=any(images)) then raise exception 'Ảnh không còn trong tin'; end if;
      images:=array_remove(images,photo);
      update public.listings set image_path=coalesce(images[1],''),additional_image_paths=coalesce(images[2:cardinality(images)],'{}') where id=target;
    when 'delete_listing' then
      delete from public.listings where id=target;
    else raise exception 'Thao tác không hợp lệ';
    end case;
  end if;
  insert into public.moderation_log(actor_id,action) values(auth.uid(),concat(op,' · ',target,' · ',trim(reason)));
  return '{}'::jsonb;
exception when foreign_key_violation then
  raise exception 'Tin có dữ liệu liên kết. Hãy dùng Ẩn tin để giữ lịch sử giao dịch.';
end; $$;
revoke all on function public.owner_content_action(text,uuid,jsonb,text) from public,anon;
grant execute on function public.owner_content_action(text,uuid,jsonb,text) to authenticated;
notify pgrst,'reload schema';
