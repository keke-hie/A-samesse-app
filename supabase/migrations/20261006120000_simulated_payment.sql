-- Paiement simulé (démonstration) : l'acheteur « paie » sa commande depuis
-- l'app, sans agrégateur réel. La commande passe directement à « payee » et
-- reçoit une référence de transaction fictive.
--
-- Pour brancher un vrai paiement plus tard (Orange Money / MTN MoMo via un
-- agrégateur), remplacer l'appel à cette fonction par le webhook du prestataire.

alter table public.commandes
  add column if not exists reference_paiement text;

create or replace function public.simulate_payment(
  p_id_commande uuid,
  p_mode_paiement text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reference text;
begin
  if p_mode_paiement is null or p_mode_paiement not in ('orange_money', 'mobile_money', 'card') then
    raise exception 'Mode de paiement invalide.' using errcode = '22023';
  end if;

  update public.commandes
  set statut = 'payee',
      mode_paiement = p_mode_paiement,
      date_paiement = now(),
      reference_paiement = 'SIM-' || upper(substr(md5(gen_random_uuid()::text), 1, 10))
  where id_commande = p_id_commande
    and id_acheteur = (select auth.uid())
    and statut = 'en_attente_paiement'
  returning reference_paiement into v_reference;

  if v_reference is null then
    raise exception 'Cette commande n''est pas en attente de paiement.' using errcode = '22023';
  end if;

  return v_reference;
end;
$$;

-- La liste admin affiche la référence de paiement.
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
        'reference_paiement', c.reference_paiement,
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

revoke all on function public.simulate_payment(uuid, text) from public;
grant execute on function public.simulate_payment(uuid, text) to authenticated;
