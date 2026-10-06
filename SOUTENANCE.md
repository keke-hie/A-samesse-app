# Démonstration — A'samesse (version web)

## Préparer (la veille)

1. **Base Supabase** : exécuter dans le SQL Editor, dans l'ordre, les fichiers de
   `supabase/migrations/` listés dans le README (dont `20261006120000_simulated_payment.sql`).
2. **Lancer le site** : `flutter run -d chrome --web-port 8080`
   (ou `flutter build web` puis publier `build/web`).
3. **Créer 4 comptes** dans le site (4 adresses e-mail différentes) :
   - `admin@…` en **Acheteur**, puis dans le SQL Editor :
     ```sql
     insert into public.administrateurs (id_administrateur)
     select id from auth.users where email = 'admin@…';
     update public.utilisateurs set role = 'Admin' where email = 'admin@…';
     ```
   - `vendeur@…` en **Vendeur**, `livreur@…` en **Livreur**, `client@…` en **Acheteur**.
4. **Valider les comptes pro** : se connecter en admin › Comptes › valider le
   vendeur et le livreur (ou les laisser « à valider » pour le montrer en direct).
5. **Préparer le catalogue** : en vendeur, compléter la boutique et ajouter
   2-3 produits avec photo (stock 5 par exemple) ; créer une vente flash.
6. **Ouvrir 4 fenêtres** (ou profils Chrome / navigation privée) : une par compte.
   La session est propre à chaque navigateur.

## Scénario (≈ 10 min)

| # | Qui | Action | Ce qu'on montre |
|---|-----|--------|-----------------|
| 1 | Client | Accueil › recherche, catégories › fiche produit (prix promo) | Catalogue, ventes flash |
| 2 | Client | Ajouter au panier (couleur / taille) › Panier › adresse sur la carte › Commander | Stock réservé, total recalculé côté serveur |
| 3 | Client | Paiement Orange Money : numéro `6XXXXXXXX`, code `1234` | Paiement simulé → « Paiement accepté » + référence |
| 3b | Client | *(option)* code `0000` | Cas de paiement refusé |
| 4 | Vendeur | Commandes › Commencer la préparation › Marquer prête | La commande devient visible des livreurs |
| 5 | Livreur | Missions › À prendre › Prendre la livraison | Attribution, partage GPS |
| 6 | Client | Commandes › détail : statut « En livraison », **code de remise**, Suivre le livreur | Suivi temps réel |
| 7 | Livreur | Confirmer la remise › saisir le code du client | Commande « Livrée » |
| 8 | Client | Signaler un problème | Litige |
| 9 | Admin | Accueil (chiffres), Comptes (pièces justificatives), Litiges | Back-office |
| 10 | Vendeur | Marketing IA *(si la clé Gemini est configurée)* | Génération de publications |

## Codes et valeurs de démonstration

- Mobile Money : n'importe quel numéro `6XXXXXXXX`, code secret à 4 chiffres ; **`0000` = refusé**.
- Carte : `4242 4242 4242 4242`, date `1230`, CVC `123` ; **CVC `000` = refusé**.
- Aucun argent n'est débité, aucune donnée de paiement n'est enregistrée.

## Si quelque chose bloque

- **Le livreur ne voit pas la livraison** : la commande doit être « Prête » et
  le compte livreur validé (admin › Comptes).
- **Le GPS ne marche pas** : le navigateur doit autoriser la localisation, et
  le site doit être en `https` ou en `localhost`.
- **Un compte arrive sur « compte en attente »** : le valider dans admin › Comptes,
  puis « Vérifier mon statut ».
