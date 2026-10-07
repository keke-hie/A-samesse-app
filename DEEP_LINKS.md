# Deep Links — A'samesse (`asamesse.app`)

Configuration des **App Links Android** et **Universal Links iOS** pour l'application
Flutter `asamesse_app`, avec gestion du routing **en local** (plugin
[`app_links`](https://pub.dev/packages/app_links) + `go_router`). Aucun passage par
Branch.io.

- **Identifiant de l'application** : `com.asamesse.app`
- **Domaine** : `asamesse.app` (+ `www.asamesse.app`)
- **Schéma personnalisé de secours** : `asamesse://`

> ⚠️ L'identifiant a été migré depuis les placeholders `com.example.asamesse_app`
> (Android) et `com.example.asamesseApp` (iOS) vers `com.asamesse.app`.

---

## 1. Routing Dart

Service central : `lib/core/deep_links/deep_link_service.dart`
(démarré dans `lib/main.dart` via `DeepLinkService.instance.init()`).

| URL reçue | Route interne (`go_router`) |
|---|---|
| `https://asamesse.app/` | `/home` |
| `/home`, `/accueil` | `/home` |
| `/deals`, `/promos` | `/deals` |
| `/cart`, `/panier` | `/cart` |
| `/orders`, `/commandes` | `/orders` |
| `/profile`, `/profil` | `/profile` |
| `/shops/{id}`, `/boutique/{id}` | `/shops/{id}` |
| `/product/{id}`, `/produit/{id}`, `/p/{id}` | `/home/product/{id}` (la fiche charge le produit par identifiant) |
| `/vendor`, `/vendeur` | `/vendor/dashboard` |
| `/delivery`, `/livreur` | `/delivery/missions` |
| `/admin` | `/admin/dashboard` |
| autre | `/home` |

Le schéma personnalisé `asamesse://` est traité de la même façon
(`asamesse://shops/123`). Les liens d'autres domaines (ex. callbacks d'auth
Supabase) sont **ignorés** par le service.

---

## 2. Android — App Links

`android/app/src/main/AndroidManifest.xml` :
- `flutter_deeplinking_enabled = false` (désactive le deep linking Flutter par défaut) ;
- `intent-filter` `android:autoVerify="true"` pour `https://asamesse.app` et `https://www.asamesse.app` ;
- `intent-filter` pour le schéma `asamesse://`.

`android/app/build.gradle.kts` : `namespace` et `applicationId` = `com.asamesse.app`.

### Étapes manuelles restantes
1. **Empreinte SHA-256** : renseigner `web/.well-known/assetlinks.json`
   (`sha256_cert_fingerprints`). Récupérer l'empreinte de la clé de signature :

   ```powershell
   # Debug
   keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore `
     -alias androiddebugkey -storepass android -keypass android

   # Release (remplacer par votre keystore)
   keytool -list -v -keystore chemin\vers\release.jks -alias VOTRE_ALIAS
   ```

   Copier la ligne `SHA256:` (ajouter **les deux**, debug **et** release, séparées
   par une virgule dans le tableau JSON).

2. **Héberger** `https://asamesse.app/.well-known/assetlinks.json`
   (le fichier est placé dans `web/.well-known/` : il est copié à la racine du
   build web Flutter si le site `asamesse.app` sert l'app web).

3. Tester :
   ```powershell
   adb shell am start -a android.intent.action.VIEW -d "https://asamesse.app/shops/123"
   ```

> Sur Android 12+, les liens non vérifiés doivent être activés manuellement dans
> *Paramètres de l'app > Ouvrir par défaut > Ajouter un lien*.

---

## 3. iOS — Universal Links

`ios/Runner/Runner.entitlements` : domaine associé `applinks:asamesse.app`
(+ `www.asamesse.app`). Ce fichier est relié au projet via
`CODE_SIGN_ENTITLEMENTS` (Debug/Release/Profile) dans `project.pbxproj`.

`ios/Runner/Info.plist` : `FlutterDeepLinkingEnabled = false`.

`PRODUCT_BUNDLE_IDENTIFIER` = `com.asamesse.app` (tests : `com.asamesse.app.RunnerTests`).

### Étapes manuelles restantes
1. **Team ID** : renseigner `web/.well-known/apple-app-site-association`
   (`appIDs` = `VOTRE_TEAM_ID.com.asamesse.app`).
2. Dans Xcode : **Signing & Capabilities** → ajouter la capability
   **Associated Domains** (vérifier que `applinks:asamesse.app` est présent).
3. **Héberger** `https://asamesse.app/.well-known/apple-app-site-association`
   **sans redirection** et servi en `application/json`.
4. Tester sur un appareil :
   ```
   xcrun simctl openurl booted "https://asamesse.app/shops/123"
   ```

---

## 4. Notes de déploiement

- Les fichiers `.well-known` doivent être servis **à la racine du domaine**
  (`https://asamesse.app/.well-known/...`), sans redirection, et
  `apple-app-site-association` avec le type MIME `application/json`.
- Si le domaine n'est pas servi par le build web Flutter, déployer ces mêmes
  fichiers sur l'hébergement réel du domaine.
- Pensez à incrémenter la version de l'app après le changement d'identifiant.
