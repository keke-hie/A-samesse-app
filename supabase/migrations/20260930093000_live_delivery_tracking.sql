alter table public.commandes
  add column if not exists adresse_livraison text,
  add column if not exists latitude_destination double precision,
  add column if not exists longitude_destination double precision;

alter table public.livraisons
  add column if not exists latitude_destination double precision,
  add column if not exists longitude_destination double precision;

create table if not exists public.positions_livreurs (
  id_livraison uuid primary key references public.livraisons(id_livraison) on delete cascade,
  id_livreur uuid not null references public.livreurs(id_livreur) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  date_position timestamptz not null default now()
);

create or replace function public.is_current_user_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.administrateurs a
    where a.id_administrateur = (select auth.uid())
  );
$$;

create or replace function public.can_access_livraison(p_id_livraison uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.livraisons l
    join public.commandes c on c.id_commande = l.id_commande
    where l.id_livraison = p_id_livraison
      and (
        l.id_livreur = (select auth.uid())
        or c.id_acheteur = (select auth.uid())
        or public.is_current_user_admin()
      )
  );
$$;

create or replace function public.is_assigned_courier_for_livraison(p_id_livraison uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.livraisons l
    where l.id_livraison = p_id_livraison
      and l.id_livreur = (select auth.uid())
      and lower(coalesce(l.statut_livraison, '')) not in (
        'livree', 'livrée', 'terminee', 'terminée', 'annulee', 'annulée'
      )
  );
$$;

revoke all on function public.is_current_user_admin() from public;
revoke all on function public.can_access_livraison(uuid) from public;
revoke all on function public.is_assigned_courier_for_livraison(uuid) from public;
grant execute on function public.is_current_user_admin() to authenticated;
grant execute on function public.can_access_livraison(uuid) to authenticated;
grant execute on function public.is_assigned_courier_for_livraison(uuid) to authenticated;

alter table public.livraisons enable row level security;
alter table public.positions_livreurs enable row level security;

drop policy if exists "Participants lisent leur livraison" on public.livraisons;
create policy "Participants lisent leur livraison"
on public.livraisons for select to authenticated
using (public.can_access_livraison(id_livraison));

drop policy if exists "Participants lisent la position du livreur" on public.positions_livreurs;
create policy "Participants lisent la position du livreur"
on public.positions_livreurs for select to authenticated
using (public.can_access_livraison(id_livraison));

drop policy if exists "Livreur publie sa position" on public.positions_livreurs;
create policy "Livreur publie sa position"
on public.positions_livreurs for insert to authenticated
with check (
  id_livreur = (select auth.uid())
  and public.is_assigned_courier_for_livraison(id_livraison)
);

drop policy if exists "Livreur actualise sa position" on public.positions_livreurs;
create policy "Livreur actualise sa position"
on public.positions_livreurs for update to authenticated
using (
  id_livreur = (select auth.uid())
  and public.is_assigned_courier_for_livraison(id_livraison)
)
with check (
  id_livreur = (select auth.uid())
  and public.is_assigned_courier_for_livraison(id_livraison)
);

grant select on public.livraisons to authenticated;
grant select, insert, update on public.positions_livreurs to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.positions_livreurs;
exception
  when duplicate_object then null;
 