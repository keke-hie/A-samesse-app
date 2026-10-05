create table if not exists public.delivery_otps (
  id_livraison uuid primary key references public.livraisons(id_livraison) on delete cascade,
  id_commande uuid not null references public.commandes(id_commande) on delete cascade,
  id_acheteur uuid not null references public.acheteurs(id_acheteur) on delete cascade,
  code_otp text not null check (code_otp ~ '^[0-9]{6}$'),
  attempt_count smallint not null default 0 check (attempt_count between 0 and 5),
  locked_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.delivery_otps
  add column if not exists attempt_count smallint not null default 0,
  add column if not exists locked_at timestamptz;

alter table public.delivery_otps enable row level security;
grant select on public.delivery_otps to authenticated;

alter table public.livraisons alter column id_livreur drop not null;

drop policy if exists "Acheteur lit le code de sa livraison" on public.delivery_otps;
create policy "Acheteur lit le code de sa livraison"
on public.delivery_otps for select to authenticated
using (id_acheteur = (select auth.uid()));

create or replace function public.create_delivery_otp()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_acheteur uuid;
begin
  select c.id_acheteur into v_acheteur
  from public.commandes c
  where c.id_commande = new.id_commande;

  if v_acheteur is not null and new.id_livreur is not null then
    insert into public.delivery_otps (id_livraison, id_commande, id_acheteur, code_otp)
    values (
      new.id_livraison,
      new.id_commande,
      v_acheteur,
      lpad(abs(('x' || substr(md5(gen_random_uuid()::text), 1, 8))::bit(32)::bigint % 1000000)::text, 6, '0')
    )
    on conflict (id_livraison) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists create_delivery_otp_after_assignment on public.livraisons;
create trigger create_delivery_otp_after_assignment
after insert or update of id_livreur on public.livraisons
for each row
when (new.id_livreur is not null)
execute function public.create_delivery_otp();

insert into public.delivery_otps (id_livraison, id_commande, id_acheteur, code_otp)
select
  l.id_livraison,
  l.id_commande,
  c.id_acheteur,
  lpad(abs(('x' || substr(md5(gen_random_uuid()::text), 1, 8))::bit(32)::bigint % 1000000)::text, 6, '0')
from public.livraisons l
join public.commandes c on c.id_commande = l.id_commande
where l.id_livreur is not null
  and not exists (
  select 1 from public.delivery_otps d where d.id_livraison = l.id_livraison
);

create or replace function public.verify_delivery_otp(p_id_livraison uuid, p_code text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_otp public.delivery_otps%rowtype;
begin
  if not exists (
    select 1
    from public.livraisons l
    where l.id_livraison = p_id_livraison
      and l.id_livreur = (select auth.uid())
      and lower(coalesce(l.statut_livraison, '')) not in ('livree', 'livrée', 'terminee', 'terminée', 'annulee', 'annulée')
  ) then
    raise exception 'Cette livraison ne vous est pas attribuée ou est déjà terminée.' using errcode = '42501';
  end if;

  select d.* into v_otp
  from public.delivery_otps d
  where d.id_livraison = p_id_livraison
  for update;

  if v_otp.id_livraison is null then
    raise exception 'Code OTP introuvable.' using errcode = '22023';
  end if;

  if v_otp.locked_at is not null then
    raise exception 'Trop de codes incorrects. Demande une nouvelle attribution.' using errcode = '22023';
  end if;

  if v_otp.code_otp <> trim(coalesce(p_code, '')) then
    update public.delivery_otps
    set attempt_count = attempt_count + 1,
        locked_at = case when attempt_count + 1 >= 5 then now() else null end
    where id_livraison = p_id_livraison;
    return false;
  end if;

  update public.livraisons
  set statut_livraison = 'livree'
  where id_livraison = p_id_livraison;

  update public.commandes
  set statut = 'livre'
  where id_commande = (
    select l.id_commande from public.livraisons l where l.id_livraison = p_id_livraison
  );
  return true;
end;
$$;

create or replace function public.accept_assigned_delivery(p_id_livraison uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.livraisons
  set statut_livraison = 'en_cours'
  where id_livraison = p_id_livraison
    and id_livreur = (select auth.uid())
    and lower(coalesce(statut_livraison, '')) not in ('livree', 'livrée', 'terminee', 'terminée', 'annulee', 'annulée', 'refusee', 'refusée');

  if not found then
    raise exception 'Cette livraison ne vous est pas attribuée.' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.decline_assigned_delivery(p_id_livraison uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.livraisons
  set statut_livraison = 'refusee', id_livreur = null
  where id_livraison = p_id_livraison
    and id_livreur = (select auth.uid())
    and lower(coalesce(statut_livraison, '')) not in ('livree', 'livrée', 'terminee', 'terminée', 'annulee', 'annulée', 'en_cours', 'en cours', 'en_route', 'en route');

  if not found then
    raise exception 'Cette livraison a déjà commencé ou ne vous est pas attribuée.' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.courier_list_assigned_deliveries()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id_livraison', l.id_livraison,
        'id_commande', l.id_commande,
        'statut_livraison', l.statut_livraison,
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
      ) order by l.date_attribution desc nulls last
    ),
    '[]'::jsonb
  )
  from public.livraisons l
  join public.commandes c on c.id_commande = l.id_commande
  where l.id_livreur = (select auth.uid());
$$;

revoke all on function public.create_delivery_otp() from public;
revoke all on function public.verify_delivery_otp(uuid, text) from public;
revoke all on function public.accept_assigned_delivery(uuid) from public;
revoke all on function public.decline_assigned_delivery(uuid) from public;
revoke all on function public.courier_list_assigned_deliveries() from public;
grant execute on function public.verify_delivery_otp(uuid, text) to authenticated;
grant execute on function public.accept_assigned_delivery(uuid) to authenticated;
grant execute on function public.decline_assigned_delivery(uuid) to authenticated;
grant execute on function public.courier_list_assigned_deliveries() to authenticated;

create or replace function public.admin_list_utilisateurs()
returns setof public.utilisateurs
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Accès réservé aux administrateurs.' using errcode = '42501';
  end if;

  return query
  select u.* from public.utilisateurs u order by u.nom;
end;
$$;

revoke all on function public.admin_list_utilisateurs() from public;
grant execute on function public.admin_list_utilisateurs() to authenticated;