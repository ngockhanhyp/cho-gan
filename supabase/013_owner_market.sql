create function public.is_passy_owner()
returns boolean language sql stable security definer set search_path='' as $$
  select exists (
    select 1 from auth.users u
    join public.admin_emails a on lower(a.email)=lower(u.email)
    where u.id=auth.uid() and u.email_confirmed_at is not null
  );
$$;

create function public.owner_listing(target uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.is_passy_owner() then
    raise exception 'Chỉ chủ Passy được truy cập' using errcode='42501';
  end if;
  return (select to_jsonb(l) || jsonb_build_object(
    'profiles', jsonb_build_object('name', p.name), '_version', md5(to_jsonb(l)::text))
    from public.listings l join public.profiles p on p.id=l.owner_id where l.id=target);
end;
$$;

create schema if not exists private;
create table private.passy_listing_imports (
  actor_id uuid not null,
  batch_id uuid not null,
  payload_hash text not null,
  listing_count integer not null,
  primary key (actor_id,batch_id)
);
alter table private.passy_listing_imports enable row level security;
revoke all on private.passy_listing_imports from public, anon, authenticated;

create function public.owner_import_listings(batch uuid, listings jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare
  actor uuid := auth.uid();
  item record;
  photo text;
  row_no int := 1;
  n int;
  digest text;
  previous private.passy_listing_imports;
begin
  if not public.is_passy_owner() then
    raise exception 'Chỉ chủ Passy được đăng hàng loạt' using errcode='42501';
  end if;
  if batch is null or jsonb_typeof(listings) is distinct from 'array' then
    raise exception 'Lô nhập không hợp lệ';
  end if;
  n := jsonb_array_length(listings);
  if n not between 1 and 50 then raise exception 'Mỗi lô nhận từ 1 đến 50 tin'; end if;
  digest := md5(listings::text);
  insert into private.passy_listing_imports values(actor,batch,digest,n) on conflict do nothing;
  if not found then
    select * into strict previous from private.passy_listing_imports where actor_id=actor and batch_id=batch;
    if previous.payload_hash <> digest then raise exception 'Mã lô đã được dùng cho dữ liệu khác'; end if;
    return previous.listing_count;
  end if;

  for item in select * from jsonb_to_recordset(listings) as x(
    title text, description text, price bigint, category text, area text, photos text[]
  ) loop
    row_no := row_no + 1;
    if coalesce(length(trim(item.title)),0) not between 4 and 160
       or coalesce(length(trim(item.description)),0) not between 10 and 4000
       or coalesce(item.price,-1) not between 0 and 100000000000
       or not coalesce(item.category in ('Nội thất','Điện tử','Gia dụng','Sách','Thời trang'), false)
       or coalesce(length(trim(item.area)),0) not between 1 and 100
       or coalesce(cardinality(item.photos),0) not between 1 and 10 then
      raise exception 'Dòng % có thông tin chưa hợp lệ', row_no;
    end if;
    foreach photo in array item.photos loop
      if photo is null or photo !~ ('^'||actor::text||'/[0-9]+-[0-9]+[.](jpg|png|webp)$')
        or not exists(select 1 from storage.objects o where o.bucket_id='listing-images' and o.name=photo) then
        raise exception 'Ảnh dòng % chưa được tải vào Passy', row_no;
      end if;
    end loop;
    insert into public.listings(owner_id,title,description,price,category,area,image_path,additional_image_paths)
      values(actor,trim(item.title),trim(item.description),item.price,item.category,trim(item.area),
        item.photos[1],item.photos[2:10]);
  end loop;
  insert into public.moderation_log(actor_id,action) values(actor,concat('Đăng hàng loạt · ',n,' tin · ',batch));
  return n;
end;
$$;
revoke all on function public.is_passy_owner(),public.owner_listing(uuid),public.owner_import_listings(uuid,jsonb) from public,anon;
grant execute on function public.is_passy_owner(),public.owner_listing(uuid),public.owner_import_listings(uuid,jsonb) to authenticated;
