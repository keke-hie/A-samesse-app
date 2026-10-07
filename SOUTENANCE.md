# Démonstration — A'samesse

- **Application mobile** (Android / iOS) : client, vendeur, livreur.
- **Site web** : console d'administration uniquement.

## Préparer (la veille)

1. **Base Supabase** : exécuter dans le SQL Editor, dans l'ordre, les fichiers de
   `supabase/migrations/` listés dans le README (dont `20261006120000_simulated_payment.sql`).
2. **Installer l'app** sur le(s) téléphone(s) : `flutter build apk` puis
   installer `build/app/outputs/flutter-apk/app-release.apk`
   (ou `flutter run` téléphone branché).
   **Lancer la console admin** : `flutter run -d chrome`
   (ou `flutter build web` puis publier `build/web`).
3. **Créer 4 comptes** dans l'app mobile (4 adresses e-mail différentes) :
   - `admin@…` en **Acheteur**, puis dans le SQL Editor :
     ```sql
     insert into public.administrateurs (id_administrateur)
     select id from auth.users where email = 'admin@…';
     update public.utilisateurs set role = 'Admin' where email = 'admin@…';
     ```
   - `vendeur@…` en **Vendeur**, `livreur@…` en **Livreur**, `client@…` en **Acheteur**.
4. **Valider les comptes pro** : se connecter sur la console web › Comptes › valider le
   vendeur et le livreur (ou les laisser « à valider » pour le montrer en direct).
5. **Préparer le catalogue** : en vendeur, compléter la boutique et ajouter
   2-3 produits avec photo (stock 5 par exemple) ; créer une vente flash.
6. **Répartir les rôles** : la console admin sur l'ordinateur ; client,
   vendeur et livreur sur téléphones (ou émulateurs). Avec un seul téléphone,
   se déconnecter / reconnecter entre les étapes.
   *Secours* : `flutter run -d chrome --dart-define=WEB_FULL_APP=true`
   affiche l'app mobile complète dans le navigateur (une fenêtre de
   navigation privée par compte).

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
| 9 | Admin (web) | Tableau de bord, Comptes (pièces justificatives), Litiges | Console d'administration |
| 10 | Vendeur | Marketing IA *(si la clé Gemini est configurée)* | Génération de publications |

## Codes et valeurs de démonstration

- Mobile Money : n'importe quel numéro `6XXXXXXXX`, code secret à 4 chiffres ; **`0000` = refusé**.
- Carte : `4242 4242 4242 4242`, date `1230`, CVC `123` ; **CVC `000` = refusé**.
- Aucun argent n'est débité, aucune donnée de paiement n'est enregistrée.

## Si quelque chose bloque

- **Le livreur ne voit pas la livraison** : la commande doit être « Prête » et
  le compte livreur validé (admin › Comptes).
- **Le GPS ne marche pas** : le navigateur doit autoriser la localisation, et
  téléphone doit autoriser la localisation pour l'app.
- **Un compte arrive sur « compte en attente »** : le valider dans admin › Comptes,
  puis « Vérifier mon statut ».
