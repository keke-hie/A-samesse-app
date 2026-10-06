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

Les migrations de `supabase/migrations/` s'appliquent **dans l'ordre** sur un
schéma existant (tables `utilisateurs`, `produits`, `commandes`, `paniers`,
`lignes_*`, `livraisons`, `boutiques`, `ventes_ephemeres`…) :

```bash
supabase db push
supabase functions deploy enhance-product-image generate-marketing-copy
```

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
en_attente_paiement ─(admin : paiement reçu)→ payee
payee ─(vendeur)→ en_preparation ─(vendeur)→ prete   ⇒ livraison proposée aux livreurs
prete ─(livreur prend la livraison)→ en_livraison
en_livraison ─(livreur saisit le code du client)→ livre
annule : par le client avant paiement, par l'admin avant la livraison (stock restitué)
```

Le paiement est confirmé manuellement par un administrateur tant qu'aucun
agrégateur Mobile Money (Orange Money / MTN MoMo) n'est intégré ; un webhook
de paiement pourra appeler la même transition.

## Comptes professionnels

Les vendeurs et livreurs s'inscrivent normalement, puis envoient leurs pièces
(CNI, photo de boutique ou permis) depuis l'écran « Compte en attente ». Ces
pièces sont stockées dans le bucket privé `documents` ; l'admin les consulte
par lien temporaire et valide, refuse ou suspend le compte.

Voir aussi [DEEP_LINKS.md](DEEP_LINKS.md) pour les liens `asamesse.app`.
