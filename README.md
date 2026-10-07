# A'samesse

Marketplace mobile (Flutter + Supabase) pour le Cameroun : catalogue de
boutiques, ventes éphémères, livraison suivie en temps réel et outils IA
pour les vendeurs (retouche photo, publications réseaux sociaux).

Quatre espaces selon le rôle : **client**, **vendeur**, **livreur**, **admin**.

## Démarrer

```bash
flutter pub get
flutter run
flutter test
```

Le projet Supabase est configuré dans `lib/main.dart` (clé publique `anon`,
l'accès aux données est contrôlé par les règles RLS).

### Base de données

La base a été construite à la main dans le SQL Editor (pas de suivi des
migrations) : **ne pas utiliser `supabase db push`**. Exécuter dans le SQL
Editor, dans cet ordre, ces fichiers de `supabase/migrations/` (tous
réexécutables sans risque) :

1. `20260930091000_create_litiges.sql`
2. `20260930094000_preserve_product_original_images.sql`
3. `20261001090000_add_product_options.sql`
4. `20261001093000_delivery_otp_confirmation.sql`
5. `20261002090000_ephemeral_sales_flexibility.sql`
6. `20261002091000_add_product_vertical_image.sql`
7. `20261006090000_secure_checkout_flow.sql`
8. `20261006100000_account_validation_and_documents.sql`
9. `20261006110000_realtime_tables.sql`
10. `20261006120000_simulated_payment.sql`

Les autres fichiers du dossier sont déjà appliqués.

Fonctions IA : `supabase functions deploy enhance-product-image generate-marketing-copy`.
Les edge functions ont besoin des secrets `GEMINI_API_KEY` et
`SUPABASE_SERVICE_ROLE_KEY`.

## Architecture

```
lib/
  core/
    constants/   palette (AppColor), catégories produit
    theme/       AppTheme : tout le style des composants Material
    models/      OrderStatus (cycle de vie d'une commande)
    services/    accès Supabase, un service par domaine :
                 session (rôle/statut), auth, product, cart, order,
                 vendor, delivery, location_sharing, marketing, admin,
                 document (pièces justificatives)
    routes/      go_router + garde par rôle (route_guard.dart, testé)
    utils/       formatPrice / formatDate, friendlyError
    widgets/     composants partagés (EmptyState, StatusChip, ProductImage…)
  features/      écrans par espace (auth, customer, vendor, delivery, admin)
  navigation/    barres de navigation (NavShell commun)
```

Règles suivies :

- les écrans n'appellent jamais Supabase directement, ils passent par un service ;
- toute écriture sensible (commande, paiement, statut, livraison) passe par une
  fonction SQL `security definer` : les prix et le stock sont recalculés côté
  serveur, le client ne peut pas les falsifier ;
- le rôle d'un utilisateur vient de la table `utilisateurs`, jamais des
  métadonnées d'inscription (modifiables par le client).

## Cycle d'une commande

```
en_attente_paiement ─(acheteur : paiement simulé dans l'app)→ payee
payee ─(vendeur)→ en_preparation ─(vendeur)→ prete   ⇒ livraison proposée aux livreurs
prete ─(livreur prend la livraison)→ en_livraison
en_livraison ─(livreur saisit le code du client)→ livre
annule : par le client avant paiement, par l'admin avant la livraison (stock restitué)
```

Le paiement est **simulé** (`simulate_payment`) : écran Orange Money / MTN MoMo /
carte, sans débit réel ni enregistrement des données saisies. Pour un vrai
paiement, un webhook d'agrégateur remplacera cet appel.

## Comptes professionnels

Les vendeurs et livreurs s'inscrivent normalement, puis envoient leurs pièces
(CNI, photo de boutique ou permis) depuis l'écran « Compte en attente ». Ces
pièces sont stockées dans le bucket privé `documents` ; l'admin les consulte
par lien temporaire et valide, refuse ou suspend le compte.

Voir aussi [SOUTENANCE.md](SOUTENANCE.md) (démonstration) et
[DEEP_LINKS.md](DEEP_LINKS.md) (liens `asamesse.app`).
