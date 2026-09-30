alter table public.commandes
  add column if not exists adresse_livraison text,
  add column if not exists latitude_destination double precision,
  add column if not exists longitude_destination double precision;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'commandes_destination_coordinates_pair_check'
      and conrelid = 'public.commandes'::regclass
  ) then
    alter table public.commandes
      add constraint commandes_destination_coordinates_pair_check
      check ((latitude_destination is null) = (longitude_destination is null));
  end if;
end $$;