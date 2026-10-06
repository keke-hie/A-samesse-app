-- Comptes : le rôle n'est plus choisi librement par le client, les vendeurs et
-- livreurs doivent être validés par un administrateur, et les pièces
-- justificatives (CNI, permis…) sont stockées dans un bucket privé.

-- ---------------------------------------------------------------------------
-- Statut de compte
-- ---------------------------------------------------------------------------

alter table public.utilisateurs
  add column if not exists statut_compte text not null default 'actif',
  add column if not exists motif_refus text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'utilisateurs_statut_compte_check'
      and conrelid = 'public.utilisateurs'::regclass
  ) then
    alter table public.utilisateurs
      add constraint utilisateurs_statut_compte_check
      check (statut_compte in ('actif', 'en_attente', 'refuse', 'suspendu'));
  end if;
end $$;

-- Opération lancée depuis l'éditeur SQL / une migration (et non depuis l'API).
create or replace function public.is_privileged_session()
returns boolean
language sql
stable
as $$
  select session_user in ('postgres', 'supabase_admin');
$$;

-- À l'inscription, le trigger d'auth recopie les métadonnées envoyées par le
-- client : on n'accepte que les rôles publics, et les comptes professionnels
-- démarrent en attente de validation.
create or replace function public.enforce_new_user_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- handle_new_auth_user écrit le rôle en minuscules alors que la contrainte
  -- utilisateurs_role_check exige 'Acheteur' / 'Vendeur' / 'Livreur' / 'Admin' :
  -- on remet la majuscule ici, sinon l'inscription échoue.
  new.role := case lower(trim(coalesce(new.role, '')))
    when 'vendeur' then 'Vendeur'
    when 'livreur' then 'Livreur'
    when 'admin' then 'Admin'
    else 'Acheteur'
  end;

  -- Depuis l'éditeur SQL, on laisse l'administrateur décider du rôle et du statut.
  if public.is_privileged_session() then
    return new;
  end if;

  if new.role = 'Admin' then
    new.role := 'Acheteur';
  end if;
  new.statut_compte := case when new.role = 'Acheteur' then 'actif' else 'en_attente' end;
  new.motif_refus := null;
  return new;
end;
$$;

drop trigger if exists enforce_new_user_role on public.utilisateurs;
create trigger enforce_new_user_role
before insert on public.utilisateurs
for each row execute function public.enforce_new_user_role();

-- Un utilisateur peut modifier son nom ou son avatar, jamais son rôle ni son statut.
create or replace function public.protect_user_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.role is distinct from old.role
      or new.statut_compte is distinct from old.statut_compte
      or new.motif_refus is distinct from old.motif_refus)
     and not public.is_privileged_session()
     and not public.is_current_user_admin() then
    raise exception 'Modification du rôle ou du statut réservée aux administrateurs.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_user_role on public.utilisateurs;
create trigger protect_user_role
before update on public.utilisateurs
for each row execute function public.protect_user_role();

-- Quel que soit le trigger d'inscription, on ne devient jamais administrateur
-- via l'API : uniquement depuis l'éditeur SQL ou par un autre administrateur.
create or replace function public.guard_admin_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_privileged_session() or public.is_current_user_admin() then
    return new;
  end if;
  return null; -- ligne ignorée silencieusement (l'inscription continue en acheteur)
end;
$$;

drop trigger if exists guard_admin_insert on public.administrateurs;
create trigger guard_admin_insert
before insert on public.administrateurs
for each row execute function public.guard_admin_insert();

create or replace function public.is_current_user_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.utilisateurs u
    where u.id_utilisateur = (select auth.uid())
      and u.statut_compte = 'actif'
  );
$$;

-- Un livreur non validé ne voit ni ne prend aucune livraison.
create or replace function public.is_current_user_courier()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.livreurs l
    join public.utilisateurs u on u.id_utilisateur = l.id_livreur
    where l.id_livreur = (select auth.uid())
      and u.statut_compte = 'actif'
  );
$$;

-- Un vendeur non validé ne peut pas publier de produit (s'ajoute aux règles existantes).
drop policy if exists "Vendeur validé publie" on public.produits;
create policy "Vendeur validé publie"
on public.produits
as restrictive
for insert
to authenticated
with check ((select public.is_current_user_active()));

drop policy if exists "Vendeur validé crée une vente éphémère" on public.ventes_ephemeres;
create policy "Vendeur validé crée une vente éphémère"
on public.ventes_ephemeres
as restrictive
for insert
to authenticated
with check ((select public.is_current_user_active()));

create or replace function public.admin_set_account_status(
  p_id_utilisateur uuid,
  p_statut text,
  p_motif text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Accès réservé aux administrateurs.' using errcode = '42501';
  end if;
  if p_statut not in ('actif', 'refuse', 'suspendu', 'en_attente') then
    raise exception 'Statut de compte invalide.' using errcode = '22023';
  end if;
  if p_statut = 'refuse' and coalesce(trim(p_motif), '') = '' then
    raise exception 'Indique le motif du refus : il sera affiché à l''utilisateur.' using errcode = '22023';
  end if;

  update public.utilisateurs
  set statut_compte = p_statut,
      motif_refus = case when p_statut in ('refuse', 'suspendu') then trim(p_motif) else null end
  where id_utilisateur = p_id_utilisateur;

  if not found then
    raise exception 'Utilisateur introuvable.' using errcode = '22023';
  end if;

  -- Colonnes d'approbation déjà présentes dans le schéma, gardées cohérentes.
  update public.vendeurs set is_approved = (p_statut = 'actif')
  where id_vendeur = p_id_utilisateur;
  update public.livreurs set is_approved = (p_statut = 'actif')
  where id_livreur = p_id_utilisateur;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pièces justificatives (bucket privé)
-- ---------------------------------------------------------------------------

create table if not exists public.pieces_justificatives (
  id_piece uuid primary key default gen_random_uuid(),
  id_utilisateur uuid not null default auth.uid()
    references public.utilisateurs(id_utilisateur) on delete cascade,
  type_piece text not null
    check (type_piece in ('cni', 'preuve_activite', 'permis', 'contribuable')),
  chemin text not null,
  date_envoi timestamptz not null default now(),
  unique (id_utilisateur, type_piece)
);

alter table public.pieces_justificatives enable row level security;
grant select, insert, update, delete on public.pieces_justificatives to authenticated;

drop policy if exists "Utilisateur lit ses pièces" on public.pieces_justificatives;
create policy "Utilisateur lit ses pièces"
on public.pieces_justificatives for select to authenticated
using (id_utilisateur = (select auth.uid()) or (select public.is_current_user_admin()));

drop policy if exists "Utilisateur dépose ses pièces" on public.pieces_justificatives;
create policy "Utilisateur dépose ses pièces"
on public.pieces_justificatives for insert to authenticated
with check (
  id_utilisateur = (select auth.uid())
  and (storage.foldername(chemin))[1] = (select auth.uid())::text
);

drop policy if exists "Utilisateur remplace ses pièces" on public.pieces_justificatives;
create policy "Utilisateur remplace ses pièces"
on public.pieces_justificatives for update to authenticated
using (id_utilisateur = (select auth.uid()))
with check (
  id_utilisateur = (select auth.uid())
  and (storage.foldername(chemin))[1] = (select auth.uid())::text
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents', 'documents', false, 10485760, array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Utilisateur dépose ses documents" on storage.objects;
create policy "Utilisateur dépose ses documents"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Utilisateur remplace ses documents" on storage.objects;
create policy "Utilisateur remplace ses documents"
on storage.objects for update to authenticated
using (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Utilisateur ou admin lit les documents" on storage.objects;
create policy "Utilisateur ou admin lit les documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select public.is_current_user_admin())
  )
);

-- ---------------------------------------------------------------------------
-- Droits
-- ---------------------------------------------------------------------------

revoke all on function public.is_privileged_session() from public;
revoke all on function public.enforce_new_user_role() from public;
revoke all on function public.protect_user_role() from public;
revoke all on function public.guard_admin_insert() from public;
revoke all on function public.is_current_user_active() from public;
revoke all on function public.is_current_user_courier() from public;
revoke all on function public.admin_set_account_status(uuid, text, text) from public;

grant execute on function public.is_privileged_session() to authenticated;
grant execute on function public.is_current_user_active() to authenticated;
grant execute on function public.admin_set_account_status(uuid, text, text) to authenticated;
