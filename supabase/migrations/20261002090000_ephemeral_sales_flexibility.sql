-- Vente éphémère flexible : nom personnalisé libre + durée jusqu'à 30 jours.
-- (vide-dressing, liquidation, vente flash, etc.)
alter table public.ventes_ephemeres
  add column if not exists nom_vente text;

comment on column public.ventes_ephemeres.nom_vente is
  'Nom libre de la vente (ex : « Vide-dressing de marque », « Liquidation parfums », « Flash Sale 24h »).';
