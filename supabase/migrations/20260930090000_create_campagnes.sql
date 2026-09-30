create table if not exists public.campagnes (
  id_campagne uuid primary key default gen_random_uuid(),
  id_vendeur uuid not null references public.vendeurs(id_vendeur) on delete cascade,
  id_produit uuid references public.produits(id_produit) on delete set null,
  nom_campagne text not null,
  plateformes text[] not null default '{}',
  contenus jsonb not null default '[]'::jsonb,
  statut text not null default 'brouillon'
    check (statut in ('brouillon', 'publie', 'archive')),
  date_creation timestamptz not null default now()
);

alter table public.campagnes enable row level security;

create policy "Vendeur lit ses campagnes"
on public.campagnes for select to authenticated
using (id_vendeur = (select auth.uid()));

create policy "Vendeur crée ses campagnes"
on public.campagnes for insert to authenticated
with check (id_vendeur = (select auth.uid()));

create policy "Vendeur modifie ses campagnes"
on public.campagnes for update to authenticated
using (id_vendeur = (select auth.uid()))
with check (id_vendeur = (select auth.uid()));

create policy "Vendeur supprime ses campagnes"
on public.campagnes for delete to authenticated
using (id_vendeur = (select auth.uid()));
