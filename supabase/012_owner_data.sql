create function public.owner_data(resource text, operation text default 'list',
  page_no integer default 0, search_term text default '', record_key jsonb default '{}',
  changes jsonb default '{}', version text default null, reason text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  config record;
  field text;
  row_select text;
  row_order text;
  key_filter text;
  assignments text;
  result jsonb;
  current_version text;
  search_pattern text := '%' || left(coalesce(search_term,''), 160) || '%';
  export_limit constant integer := 5000;
begin
  if not exists (
    select 1 from auth.users u join public.admin_emails a on lower(a.email)=lower(u.email)
    where u.id=auth.uid() and u.email_confirmed_at is not null
  ) then
    raise exception 'Chỉ chủ nền tảng được thao tác' using errcode='42501';
  end if;

  select * into config from (values
    ('profiles','id','id,name,area,created_at','name,area',false),
    ('listings','id','id,title,description,price,category,area,status,accepts_offers,owner_id,created_at','title,description,price,category,area,status,accepts_offers',false),
    ('appointments','id','id,place,meet_at,status,buyer_done,seller_done,conversation_id,proposer_id,created_at','place,meet_at,status,buyer_done,seller_done',true),
    ('consignment_requests','id','id,title,description,asking_price,warehouse,status,agreed_sale_price,commission_amount,staff_note,contact,owner_id,created_at,updated_at','title,description,asking_price,warehouse,status,agreed_sale_price,commission_amount,staff_note,contact',true),
    ('communities','id','id,name,community_type,building_location,owner_id,created_at','name,community_type,building_location',true),
    ('community_members','community_id,user_id','community_id,user_id,joined_at','',true),
    ('community_posts','id','id,body,topic,community_id,author_id,created_at','body,topic',true),
    ('community_replies','id','id,body,post_id,author_id,created_at','body',true),
    ('reports','id','id,reason,resolved,listing_id,reporter_id,created_at','resolved',true),
    ('reviews','id','id,rating,body,appointment_id,reviewer_id,reviewee_id,created_at','rating,body',true),
    ('seller_map_locations','owner_id','owner_id,updated_at','',true),
    ('conversations','id','id,listing_id,buyer_id,seller_id,created_at','',false),
    ('favorites','user_id,listing_id','user_id,listing_id','',true),
    ('blocks','blocker_id,blocked_id','blocker_id,blocked_id','',true),
    ('moderators','user_id','user_id','',true),
    ('moderation_log','id','id,action,actor_id,report_id,created_at','',false)
  ) as c(name,keys,columns,editable,deletable) where c.name=resource;
  if not found then raise exception 'Nhóm dữ liệu không hợp lệ'; end if;

  if operation in ('export','update','delete','add_moderator')
     and length(trim(coalesce(reason,''))) not between 5 and 300 then
    raise exception 'Cần ghi lý do (5–300 ký tự)';
  end if;

  select string_agg(format('%I',col),', ') into row_order
  from unnest(string_to_array(config.keys,',')) col;
  select string_agg(format('t.%I',col),', ') into row_select
  from unnest(string_to_array(config.columns,',')) col;

  if operation in ('list','export') then
    execute format(
      'select coalesce(jsonb_agg(to_jsonb(s) order by %s),''[]''::jsonb) from
       (select %s, md5(to_jsonb(t)::text) as _version from public.%I t
        where to_jsonb(row(%s))::text ilike $1 order by %s limit $2 offset $3) s',
      row_order,row_select,config.name,row_select,row_order)
    into result using search_pattern,
      case operation when 'export' then export_limit+1 else 51 end,
      case operation when 'export' then 0 else greatest(0,coalesce(page_no,0))::bigint*50 end;
    if jsonb_array_length(result)>export_limit then
      raise exception 'Kết quả vượt 5.000 dòng. Hãy thu hẹp tìm kiếm trước khi xuất.';
    end if;
    if operation='list' then
      return jsonb_build_object('rows',result,'columns',string_to_array(config.columns,','),
        'keys',string_to_array(config.keys,','),'editable',string_to_array(config.editable,','),
        'deletable',config.deletable);
    end if;
    insert into public.moderation_log(actor_id,action)
    values(auth.uid(),concat('Xuất ',config.name,' · ',jsonb_array_length(result),' dòng · ',trim(reason)));
    return jsonb_build_object('rows',result,'columns',string_to_array(config.columns,','));
  end if;

  if operation='add_moderator' and resource='moderators' then
    insert into public.moderators(user_id) values((record_key->>'user_id')::uuid);
  elsif operation in ('update','delete') then
    select string_agg(format('t.%I = ($1->>%L)::uuid',col,col),' and ') into key_filter
    from unnest(string_to_array(config.keys,',')) col;
    execute format('select md5(to_jsonb(t)::text) from public.%I t where %s for update',config.name,key_filter)
      into current_version using record_key;
    if current_version is null or current_version is distinct from version then
      raise exception 'Bản ghi đã thay đổi hoặc đã bị xóa. Hãy tải lại.';
    end if;
    if operation='delete' and config.deletable then
      execute format('delete from public.%I t where %s',config.name,key_filter) using record_key;
    elsif operation='update' and changes <> '{}'::jsonb then
      for field in select jsonb_object_keys(changes) loop
        if not (field=any(string_to_array(config.editable,','))) then
          raise exception 'Trường % không được chỉnh sửa',field;
        end if;
        assignments := concat_ws(', ',assignments,format('%1$I = (jsonb_populate_record(null::public.%2$I,$2)).%1$I',field,config.name));
      end loop;
      if resource='consignment_requests' then
        assignments := assignments || ', updated_at = now()';
      end if;
      execute format('update public.%I t set %s where %s',config.name,assignments,key_filter)
        using record_key,changes;
    else
      raise exception 'Thao tác không hợp lệ cho nhóm này';
    end if;
  else
    raise exception 'Thao tác không hợp lệ';
  end if;
  insert into public.moderation_log(actor_id,action)
  values(auth.uid(),concat(operation,' ',config.name,' · ',record_key,' · ',trim(reason)));
  return '{}'::jsonb;
exception
  when foreign_key_violation then
    raise exception 'Dữ liệu đang có liên kết hoặc mã tham chiếu không tồn tại.';
  when check_violation or not_null_violation or invalid_text_representation or invalid_datetime_format
       or datetime_field_overflow or numeric_value_out_of_range then
    raise exception 'Giá trị nhập không hợp lệ. Kiểm tra kiểu dữ liệu và các trường bắt buộc.';
end;
$$;
revoke all on function public.owner_data(text,text,integer,text,jsonb,jsonb,text,text) from public,anon;
grant execute on function public.owner_data(text,text,integer,text,jsonb,jsonb,text,text) to authenticated;
