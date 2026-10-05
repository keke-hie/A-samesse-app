alter table public.produits
  add column if not exists couleurs text[] not null default '{}',
  add column if not exists tailles text[] not null default '{}',
  add column if not exists caracteristiques text[] not null default '{}';