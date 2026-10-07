-- Litiges : structure alignée sur la table existante (statut_litige,
-- date_resolution…). Le script complète la table si elle existe déjà et
-- peut être réexécuté sans risque.
--
-- Valeurs de statut_litige utilisées par l'app :
--   'En attente' (défaut), 'En examen', 'Accepté', 'Rejeté'

create or replace function public.is_current_user_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.administrateurs a
    where a.id_administrateur = (select auth.uid())
  );
$$;

revoke all on function public.is_current_user_admin() from public;
grant execute on function public.is_current_user_admin() to authenticated;

create table if not exists public.litiges (
  id_litige uuid primary key default gen_random_uuid(),
  id_commande uuid,
  id_acheteur uuid,
  id_vendeur uuid,
  id_administrateur uuid,
  motif text not null,
  description text,
  detail text,
  preuve_url text,
  statut_litige character varying default 'En attente',
  date_creation timestamptz default now(),
  date_resolution timestamptz
);

-- Note de l'administrateur (suivi ou décision communiquée au client).
alter table public.litiges
  add column if not exists decision_admin text;

create index if not exists litiges_commande_idx on public.litiges(id_commande);
create index if not exists litiges_acheteur_idx on public.litiges(id_acheteur);
create index if not exists litiges_statut_idx on public.litiges(statut_litige);

alter table public.litiges enable row level security;
grant select, insert, update on public.litiges to authenticated;

drop policy if exists "Acheteur lit ses litiges" on public.litiges;
create policy "Acheteur lit ses litiges"
on public.litiges for select to authenticated
using (id_acheteur = (select auth.uid()) or (select public.is_current_user_admin()));

drop policy if exists "Acheteur ouvre un litige sur sa commande" on public.litiges;
create policy "Acheteur ouvre un litige sur sa commande"
on public.litiges for insert to authenticated
with check (
  id_acheteur = (select auth.uid())
  and exists (
    select 1 from public.commandes c
    where c.id_commande = litiges.id_commande
      and c.id_acheteur = (select auth.uid())
  )
);

drop policy if exists "Administrateur traite les litiges" on public.litiges;
create policy "Administrateur traite les litiges"
on public.litiges for update to authenticated
using ((select public.is_current_user_admin()))
with check ((select public.is_current_user_admin()));

-- Photos de preuve (bucket privé, dossier par acheteur).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('preuves-litiges', 'preuves-litiges', false, 10485760, array['image/jpeg', 'image/png'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Acheteur charge ses preuves de litige" on storage.objects;
create policy "Acheteur charge ses preuves de litige"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'preuves-litiges'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Acheteur ou admin lit les preuves de litige" on storage.objects;
create policy "Acheteur ou admin lit les preuves de litige"
on storage.objects for select to authenticated
using (
  bucket_id = 'preuves-litiges'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select public.is_current_user_admin())
  )
);
