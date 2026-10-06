-- Règles d'accès manquantes ou dangereuses relevées dans pg_policies.
-- Réexécutable sans risque.

-- ---------------------------------------------------------------------------
-- 1. Pièces d'identité : fermer l'accès public au bucket `documents`
-- ---------------------------------------------------------------------------
-- Ces deux règles permettaient à n'importe qui (même non connecté) de lire
-- les CNI / permis, et à tout compte de déposer n'importe où dans le bucket.
-- Les règles par dossier utilisateur de 20261006100000 les remplacent.
drop policy if exists "Permettre la lecture publique flreew_0" on storage.objects;
drop policy if exists "Permettre l'upload aux connectés flreew_0" on storage.objects;

-- ---------------------------------------------------------------------------
-- 2. Photos de profil : aucun envoi n'était autorisé dans `avatars`
-- ---------------------------------------------------------------------------
drop policy if exists "Utilisateur dépose sa photo de profil" on storage.objects;
create policy "Utilisateur dépose sa photo de profil"
on storage.objects for insert to authenticated
with check (bucket_id = 'avatars');

drop policy if exists "Photos de profil visibles" on storage.objects;
create policy "Photos de profil visibles"
on storage.objects for select to anon, authenticated
using (bucket_id = 'avatars');

-- ---------------------------------------------------------------------------
-- 3. Boutiques : vitrine publique, chaque vendeur gère la sienne
-- ---------------------------------------------------------------------------
alter table public.boutiques enable row level security;
grant select on public.boutiques to anon, authenticated;
grant insert, update on public.boutiques to authenticated;

drop policy if exists "Boutiques visibles" on public.boutiques;
create policy "Boutiques visibles"
on public.boutiques for select to anon, authenticated
using (true);

drop policy if exists "Vendeur crée sa boutique" on public.boutiques;
create policy "Vendeur crée sa boutique"
on public.boutiques for insert to authenticated
with check (id_vendeur = (select auth.uid()));

drop policy if exists "Vendeur modifie sa boutique" on public.boutiques;
create policy "Vendeur modifie sa boutique"
on public.boutiques for update to authenticated
using (id_vendeur = (select auth.uid()))
with check (id_vendeur = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 4. Produits : le vendeur peut modifier (stock, prix…) et retirer les siens
-- ---------------------------------------------------------------------------
grant update, delete on public.produits to authenticated;

drop policy if exists "Vendeur modifie ses produits" on public.produits;
create policy "Vendeur modifie ses produits"
on public.produits for update to authenticated
using (id_vendeur = (select auth.uid()))
with check (id_vendeur = (select auth.uid()));

drop policy if exists "Vendeur supprime ses produits" on public.produits;
create policy "Vendeur supprime ses produits"
on public.produits for delete to authenticated
using (id_vendeur = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 5. Ventes éphémères : visibles par tous, créées par le vendeur du produit
-- ---------------------------------------------------------------------------
-- La seule règle existante était restrictive : sans règle permissive, aucune
-- vente ne pouvait être lue ni créée.
alter table public.ventes_ephemeres enable row level security;
grant select on public.ventes_ephemeres to anon, authenticated;
grant insert, update on public.ventes_ephemeres to authenticated;

drop policy if exists "Ventes éphémères visibles" on public.ventes_ephemeres;
create policy "Ventes éphémères visibles"
on public.ventes_ephemeres for select to anon, authenticated
using (true);

drop policy if exists "Vendeur crée une vente sur son produit" on public.ventes_ephemeres;
create policy "Vendeur crée une vente sur son produit"
on public.ventes_ephemeres for insert to authenticated
with check (
  exists (
    select 1 from public.produits p
    where p.id_produit = ventes_ephemeres.id_produit
      and p.id_vendeur = (select auth.uid())
  )
);

drop policy if exists "Vendeur modifie ses ventes" on public.ventes_ephemeres;
create policy "Vendeur modifie ses ventes"
on public.ventes_ephemeres for update to authenticated
using (
  exists (
    select 1 from public.produits p
    where p.id_produit = ventes_ephemeres.id_produit
      and p.id_vendeur = (select auth.uid())
  )
);

-- ---------------------------------------------------------------------------
-- 6. Commandes : le vendeur voit celles qui contiennent ses produits
-- ---------------------------------------------------------------------------
-- Sans ces règles, l'écran « Commandes reçues » et le tableau de bord du
-- vendeur restaient vides.
drop policy if exists "Vendeur lit les lignes de ses produits" on public.lignes_commande;
create policy "Vendeur lit les lignes de ses produits"
on public.lignes_commande for select to authenticated
using (
  exists (
    select 1 from public.produits p
    where p.id_produit = lignes_commande.id_produit
      and p.id_vendeur = (select auth.uid())
  )
);

drop policy if exists "Vendeur lit les commandes de ses produits" on public.commandes;
create policy "Vendeur lit les commandes de ses produits"
on public.commandes for select to authenticated
using ((select public.is_vendor_of_order(id_commande)));

grant execute on function public.is_vendor_of_order(uuid) to authenticated;

-- Les commandes ne s'écrivent plus que via create_order / simulate_payment… :
-- les anciennes règles d'écriture directe sont retirées.
drop policy if exists "Acheteur crée sa commande" on public.commandes;
drop policy if exists "Acheteur ajoute les lignes de sa commande" on public.lignes_commande;
