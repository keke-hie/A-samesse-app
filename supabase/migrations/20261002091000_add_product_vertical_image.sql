-- Studio Photo IA : image verticale (format Story WhatsApp / Instagram 9:16)
-- générée en complément de l'image catalogue carrée (image_url).
alter table public.produits
  add column if not exists image_verticale_url text;

comment on column public.produits.image_verticale_url is
  'Version verticale 9:16 (Story) générée par le Studio Photo IA.';
