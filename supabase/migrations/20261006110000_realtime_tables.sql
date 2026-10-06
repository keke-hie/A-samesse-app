-- Tables écoutées en temps réel par l'app (.stream()) : sans publication,
-- les écrans chargent les données une fois mais ne se mettent plus à jour.
--   commandes        : suivi des commandes côté client
--   livraisons       : missions du livreur, suivi de livraison
--   ventes_ephemeres : écran Offres
-- (positions_livreurs est déjà publiée par 20260930093000.)
do $$
declare
  v_table text;
begin
  foreach v_table in array array['commandes', 'livraisons', 'ventes_ephemeres'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', v_table);
    exception
      when duplicate_object then null;
    end;
  end loop;
end $$;
