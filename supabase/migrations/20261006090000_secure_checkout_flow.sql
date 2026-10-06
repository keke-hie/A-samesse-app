-- Parcours de commande sécurisé : prix calculés côté serveur, création atomique,
-- réservation du stock, statuts pilotés par le vendeur / l'admin / le livreur.
--
-- Cycle de vie d'une commande :
--   en_attente_paiement -> payee -> en_preparation -> prete -> en_livraison -> livre
--   (annule possible avant la livraison, le stock est alors restitué)

alter table public.commandes
  add column if not exists mode_livraison text not null default 'standard',
  add column if not exists frais_livraison numeric(12, 2) not null default 0,
  add column if not exists date_paiement timestamptz;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Prix unitaire effectif : prix catalogue, ou prix promo d'une vente éphémère active.
create or replace function public.current_unit_price(p_id_produit uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select least(
    p.prix,
    coalesce((
      select min(v.prix_promo)
      from public.ventes_ephemeres v
      where v.id_produit = p.id_produit
        and v.statut = 'actif'
        and coalesce(v.date_debut, '-infinity'::timestamptz) <= now()
        and v.date_fin > now()
    ), p.prix)
  )
  from public.produits p
  where p.id_produit = p_id_produit;
$$;

create or replace function public.is_current_user_courier()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.livreurs l where l.id_livreur = (select auth.uid())
  );
$$;

-- Le vendeur courant vend-il au moins un article de cette commande ?
create or replace function public.is_vendor_of_order(p_id_commande uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.lignes_commande lc
    join public.produits p on p.id_produit = lc.id_produit
    where lc.id_commande = p_id_commande
      and p.id_vendeur = (select auth.uid())
  );
$$;

-- Restitue le stock réservé par une commande.
create or replace function public.restore_order_stock(p_id_commande uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.produits p
  set stock = p.stock + lc.quantite
  from public.lignes_commande lc
  where lc.id_commande = p_id_commande
    and lc.id_produit = p.id_produit
    and p.stock is not null;
$$;

-- ---------------------------------------------------------------------------
-- Acheteur
-- ---------------------------------------------------------------------------

create or replace function public.create_order(
  p_line_ids text[],
  p_mode_paiement text,
  p_mode_livraison text,
  p_adresse text,
  p_latitude double precision,
  p_longitude double precision
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_panier public.paniers.id_panier%type;
  v_order uuid;
  v_frais numeric := case p_mode_livraison when 'express' then 1500 else 0 end;
  v_subtotal numeric := 0;
  v_count integer := 0;
  v_line record;
begin
  if v_user is null then
    raise exception 'Connecte-toi pour passer commande.' using errcode = '42501';
  end if;
  if p_mode_paiement is null or p_mode_paiement not in ('orange_money', 'mobile_money', 'card') then
    raise exception 'Mode de paiement invalide.' using errcode = '22023';
  end if;
  if p_mode_livraison is null or p_mode_livraison not in ('express', 'standard') then
    raise exception 'Mode de livraison invalide.' using errcode = '22023';
  end if;
  if coalesce(trim(p_adresse), '') = '' or p_latitude is null or p_longitude is null then
    raise exception 'Choisis le point et saisis l''adresse de livraison.' using errcode = '22023';
  end if;
  if coalesce(array_length(p_line_ids, 1), 0) = 0 then
    raise exception 'Sélectionne au moins un article.' using errcode = '22023';
  end if;

  select pa.id_panier into v_panier
  from public.paniers pa
  where pa.id_acheteur = v_user;
  if v_panier is null then
    raise exception 'Ton panier est vide.' using errcode = '22023';
  end if;

  insert into public.commandes (
    id_acheteur, montant_total, statut, mode_paiement, mode_livraison, frais_livraison,
    adresse_livraison, latitude_destination, longitude_destination, date_commande
  )
  values (
    v_user, 0, 'en_attente_paiement', p_mode_paiement, p_mode_livraison, v_frais,
    trim(p_adresse), p_latitude, p_longitude, now()
  )
  returning id_commande into v_order;

  -- Les produits sont verrouillés pour éviter de vendre deux fois le dernier article.
  for v_line in
    select lp.id_produit,
           lp.quantite,
           coalesce(lp.couleur, '') as couleur,
           coalesce(lp.taille, '') as taille,
           p.nom_produit,
           p.stock,
           public.current_unit_price(p.id_produit) as prix
    from public.lignes_panier lp
    join public.produits p on p.id_produit = lp.id_produit
    where lp.id_panier = v_panier
      and lp.id_ligne::text = any (p_line_ids)
    order by p.id_produit
    for update of p
  loop
    if v_line.quantite is null or v_line.quantite <= 0 then
      raise exception 'Quantité invalide pour %.', v_line.nom_produit using errcode = '22023';
    end if;
    if v_line.prix is null then
      raise exception 'Le prix de % n''est pas renseigné.', v_line.nom_produit using errcode = '22023';
    end if;
    if v_line.stock is not null and v_line.quantite > v_line.stock then
      raise exception 'Stock insuffisant pour % (disponible : %).', v_line.nom_produit, v_line.stock
        using errcode = '22023';
    end if;

    insert into public.lignes_commande (id_commande, id_produit, quantite, prix_unitaire, couleur, taille)
    values (v_order, v_line.id_produit, v_line.quantite, v_line.prix, v_line.couleur, v_line.taille);

    update public.produits
    set stock = stock - v_line.quantite
    where id_produit = v_line.id_produit
      and stock is not null;

    v_subtotal := v_subtotal + v_line.prix * v_line.quantite;
    v_count := v_count + 1;
  end loop;

  if v_count <> array_length(p_line_ids, 1) then
    raise exception 'Certains articles ne sont plus dans ton panier. Actualise et réessaie.'
      using errcode = '22023';
  end if;

  update public.commandes
  set montant_total = v_subtotal + v_frais
  where id_commande = v_order;

  delete from public.lignes_panier
  where id_panier = v_panier
    and id_ligne::text = any (p_line_ids);

  return v_order;
end;
$$;

create or replace function public.cancel_order(p_id_commande uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.commandes%rowtype;
  v_is_admin boolean := public.is_current_user_admin();
begin
  select * into v_order
  from public.commandes
  where id_commande = p_id_commande
  for update;

  if v_order.id_commande is null
     or (v_order.id_acheteur <> (select auth.uid()) and not v_is_admin) then
    raise exception 'Commande introuvable.' using errcode = '42501';
  end if;

  -- L'acheteur annule seul tant qu'il n'a pas payé ; ensuite il faut un admin (remboursement).
  if not v_is_admin and v_order.statut <> 'en_attente_paiement' then
    raise exception 'Cette commande est déjà payée : ouvre un litige pour l''annuler.' using errcode = '22023';
  end if;
  if v_order.statut in ('en_livraison', 'livre', 'annule') then
    raise exception 'Cette commande ne peut plus être annulée.' using errcode = '22023';
  end if;

  perform public.restore_order_stock(p_id_commande);

  update public.commandes set statut = 'annule' where id_commande = p_id_commande;
  update public.livraisons
  set statut_livraison = 'annulee'
  where id_commande = p_id_commande;
end;
$$;

-- ---------------------------------------------------------------------------
-- Administrateur
-- ---------------------------------------------------------------------------

-- En attendant l'intégration d'un agrégateur (Orange Money / MTN MoMo), le paiement
-- est confirmé manuellement par un administrateur. Un webhook de paiement appellera
-- plus tard cette même transition avec la clé service_role.
create or replace function public.admin_confirm_payment(p_id_commande uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Accès réservé aux administrateurs.' using errcode = '42501';
  end if;

  update public.commandes
  set statut = 'payee', date_paiement = now()
  where id_commande = p_id_commande
    and statut = 'en_attente_paiement';

  if not found then
    raise exception 'Cette commande n''est pas en attente de paiement.' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.admin_list_orders()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Accès réservé aux administrateurs.' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id_commande', c.id_commande,
        'montant_total', c.montant_total,
        'statut', c.statut,
        'mode_paiement', c.mode_paiement,
        'mode_livraison', c.mode_livraison,
        'date_commande', c.date_commande,
        'adresse_livraison', c.adresse_livraison,
        'acheteur', u.nom
      )
      order by c.date_commande desc
    )
    from public.commandes c
    left join public.utilisateurs u on u.id_utilisateur = c.id_acheteur
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- Vendeur
-- ---------------------------------------------------------------------------

create or replace function public.vendor_advance_order(p_id_commande uuid, p_statut text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.commandes%rowtype;
begin
  if not public.is_vendor_of_order(p_id_commande) then
    raise exception 'Cette commande ne concerne pas ta boutique.' using errcode = '42501';
  end if;

  select * into v_order
  from public.commandes
  where id_commande = p_id_commande
  for update;

  if not (
    (v_order.statut = 'payee' and p_statut = 'en_preparation')
    or (v_order.statut = 'en_preparation' and p_statut = 'prete')
  ) then
    raise exception 'Transition de statut impossible (% -> %).', v_order.statut, p_statut
      using errcode = '22023';
  end if;

  update public.commandes set statut = p_statut where id_commande = p_id_commande;

  -- Commande prête : elle est proposée aux livreurs.
  if p_statut = 'prete' and not exists (
    select 1 from public.livraisons l
    where l.id_commande = p_id_commande
      and lower(coalesce(l.statut_livraison, '')) not in ('annulee', 'annulée')
  ) then
    insert into public.livraisons (
      id_commande, statut_livraison, adresse_destination,
      latitude_destination, longitude_destination
    )
    values (
      p_id_commande, 'en_attente', v_order.adresse_livraison,
      v_order.latitude_destination, v_order.longitude_destination
    );
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Livreur
-- ---------------------------------------------------------------------------

create or replace function public.courier_list_available_deliveries()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_current_user_courier() then
    raise exception 'Accès réservé aux livreurs.' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id_livraison', l.id_livraison,
        'id_commande', l.id_commande,
        'statut_livraison', 'disponible',
        'adresse_destination', l.adresse_destination,
        'date_attribution', l.date_attribution,
        'commandes', jsonb_build_object(
          'id_commande', c.id_commande,
          'montant_total', c.montant_total,
          'mode_paiement', c.mode_paiement,
          'date_commande', c.date_commande,
          'lignes_commande', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'quantite', lc.quantite,
                'produits', jsonb_build_object('nom_produit', p.nom_produit)
              )
            )
            from public.lignes_commande lc
            left join public.produits p on p.id_produit = lc.id_produit
            where lc.id_commande = c.id_commande
          ), '[]'::jsonb)
        )
      )
      order by c.date_commande
    )
    from public.livraisons l
    join public.commandes c on c.id_commande = l.id_commande
    where l.id_livreur is null
      and lower(coalesce(l.statut_livraison, '')) in ('en_attente', 'refusee', 'refusée')
      and c.statut = 'prete'
  ), '[]'::jsonb);
end;
$$;

-- Le livreur prend une livraison disponible : elle lui est attribuée et démarre.
-- Le trigger create_delivery_otp_after_assignment génère alors le code de remise.
create or replace function public.courier_claim_delivery(p_id_livraison uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id_commande uuid;
begin
  if not public.is_current_user_courier() then
    raise exception 'Accès réservé aux livreurs.' using errcode = '42501';
  end if;

  update public.livraisons
  set id_livreur = (select auth.uid()),
      statut_livraison = 'en_cours',
      date_attribution = now()
  where id_livraison = p_id_livraison
    and id_livreur is null
    and lower(coalesce(statut_livraison, '')) in ('en_attente', 'refusee', 'refusée')
  returning id_commande into v_id_commande;

  if v_id_commande is null then
    raise exception 'Cette livraison vient d''être prise par un autre livreur.' using errcode = '22023';
  end if;

  update public.commandes set statut = 'en_livraison' where id_commande = v_id_commande;
end;
$$;

-- Acceptation d'une livraison attribuée par un admin : la commande passe aussi en livraison.
create or replace function public.accept_assigned_delivery(p_id_livraison uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id_commande uuid;
begin
  update public.livraisons
  set statut_livraison = 'en_cours'
  where id_livraison = p_id_livraison
    and id_livreur = (select auth.uid())
    and lower(coalesce(statut_livraison, '')) not in ('livree', 'livrée', 'terminee', 'terminée', 'annulee', 'annulée', 'refusee', 'refusée')
  returning id_commande into v_id_commande;

  if v_id_commande is null then
    raise exception 'Cette livraison ne vous est pas attribuée.' using errcode = '42501';
  end if;

  update public.commandes set statut = 'en_livraison' where id_commande = v_id_commande;
end;
$$;

-- ---------------------------------------------------------------------------
-- Droits
-- ---------------------------------------------------------------------------

-- Les commandes ne s'écrivent plus que via les fonctions ci-dessus.
revoke insert, update, delete on public.commandes from anon, authenticated;
revoke insert, update, delete on public.lignes_commande from anon, authenticated;

revoke all on function public.current_unit_price(uuid) from public;
revoke all on function public.is_current_user_courier() from public;
revoke all on function public.is_vendor_of_order(uuid) from public;
revoke all on function public.restore_order_stock(uuid) from public;
revoke all on function public.create_order(text[], text, text, text, double precision, double precision) from public;
revoke all on function public.cancel_order(uuid) from public;
revoke all on function public.admin_confirm_payment(uuid) from public;
revoke all on function public.admin_list_orders() from public;
revoke all on function public.vendor_advance_order(uuid, text) from public;
revoke all on function public.courier_list_available_deliveries() from public;
revoke all on function public.courier_claim_delivery(uuid) from public;
revoke all on function public.accept_assigned_delivery(uuid) from public;

grant execute on function public.current_unit_price(uuid) to anon, authenticated;
grant execute on function public.create_order(text[], text, text, text, double precision, double precision) to authenticated;
grant execute on function public.cancel_order(uuid) to authenticated;
grant execute on function public.admin_confirm_payment(uuid) to authenticated;
grant execute on function public.admin_list_orders() to authenticated;
grant execute on function public.vendor_advance_order(uuid, text) to authenticated;
grant execute on function public.courier_list_available_deliveries() to authenticated;
grant execute on function public.courier_claim_delivery(uuid) to authenticated;
grant execute on function public.accept_assigned_delivery(uuid) to authenticated;
