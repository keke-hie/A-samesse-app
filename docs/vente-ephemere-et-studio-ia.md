# Vente Éphémère & Studio Photo IA

Spécification intégrée : ventes éphémères **non bridées à 48 h** et **génération d'images IA**
(détourage + mise en scène + amélioration), sans passer par un prestataire externe.

---

## 1. Flexibilité de la Vente Éphémère (vide-dressing, liquidation, vente flash)

- **Accès** : bouton *« Nouvelle Vente »* sur l'écran **Deals** (`lib/features/customer/deals/deals_screen.dart`),
  disponible pour les vendeurs qu'ils soient éphémères ou boutiques permanentes (rôle `vendeur`).
- **Création** — le formulaire demande :
  1. **Nom de la vente** : champ libre (ex. *« Vide-dressing de marque »*, *« Liquidation parfums »*, *« Flash Sale 24h »*).
  2. **Prix promo**, **Type** (Vente Flash, Vide-dressing…) et **Produit**.
  3. **Durée / Compte à rebours personnalisable** : presets rapides (6 h, 24 h, 3 j, 7 j, 30 j)
     **+** sélecteur de **date et heure de fin**.
- **Règles** : fin au minimum **1 heure** après maintenant, au maximum **30 jours** (validation bloquante).
- **Base de données** : colonne `ventes_ephemeres.nom_vente`
  (migration `supabase/migrations/20261002090000_ephemeral_sales_flexibility.sql`).
- **Affichage côté acheteur** : nom de la vente + badge type, et un **compteur intelligent** :
  - `« Se termine dans X jours »` (+ date de fin) lorsque la vente dure **plus de 24 h** ;
  - `« Fin dans HH:MM:SS »` (compte à rebours dynamique) lorsqu'elle dure **moins de 24 h**.
- Le lien de partage `https://asamesse.app/deal/{id}` est géré par le routeur
  (mappé sur l'écran Deals).

---

## 2. Studio Photo IA (génération d'images)

**Problème** : les vendeurs informels n'ont ni studio ni mannequin.

**Flux de génération** (`lib/features/vendor/add_product_screen.dart` + Edge function
`supabase/functions/enhance-product-image/index.ts`) :

1. **Prise de vue** : le vendeur photographie simplement son produit depuis son téléphone.
2. **Traitement par l'IA (Gemini)** :
   - **Détourage automatique** : suppression de l'arrière-plan d'origine.
   - **Mise en scène** : décor choisi par le vendeur (paramètre `scene`) :
     - `studio` → décor de studio professionnel ;
     - `neutre` → fond neutre épuré ;
     - `dressing` → dressing lumineux ;
     - `mannequin` → mannequin virtuel (buste sans visage).
   - **Amélioration** : éclairage, luminosité, contrastes et netteté.
3. **Export** : deux formats sont produits et enregistrés dans `produits` :
   - **carré 1:1** (catalogue) → `image_url` ;
   - **vertical 9:16** (Story WhatsApp/Instagram) → `image_verticale_url`.
   L'image originale est conservée dans `image_originale_url` (restauration possible).

**Base de données** : colonne `produits.image_verticale_url`
(migration `supabase/migrations/20261002091000_add_product_vertical_image.sql`).

> Le rechargement/retouche d'un produit existant (avec `productId`) régénère lui aussi
> les deux formats et met à jour `image_url` + `image_verticale_url`.
