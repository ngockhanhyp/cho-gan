alter table public.listings
  add column if not exists additional_image_paths text[] not null default '{}',
  add column if not exists accepts_offers boolean not null default false;

alter table public.listings
  add constraint listing_gallery_uses_owner_storage check (
    cardinality(additional_image_paths) <= 9
    and array_position(additional_image_paths, null) is null
    and array_to_string(additional_image_paths, ',') ~ (
      '^(' || owner_id::text || '/[0-9]+-[0-9]+[.](jpg|png|webp)(,|$))*$'
    )
  );

notify pgrst, 'reload schema';
