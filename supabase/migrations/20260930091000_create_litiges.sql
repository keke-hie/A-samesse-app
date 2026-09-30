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
  id_commande uuid not null references public.commandes(id_commande) on delete restrict,
  id_acheteur uuid not null references public.acheteurs(id_acheteur) on delete restrict,
  motif text not null,
  description text not null,
  preuves text[] not null default '{}',
  statut text not null default 'ouvert'
    check (statut in ('ouvert', 'en_examen', 'accepte', 'rejete', 'rembourse')),
  decision_admin text,
  id_administrateur uuid references public.administrateurs(id_administrateur),
  date_creation timestamptz not null default now(),
  date_decision timestamptz,
  constraint litiges_description_non_vide check (length(trim(description)) > 0)
);

create index if not exists litiges_commande_idx on public.litiges(id_commande);
create index if not exists litiges_acheteur_idx on public.litiges(id_acheteur);
create index if not exists litiges_statut_idx on public.litiges(statut);

alter table public.litiges enable row level security;

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