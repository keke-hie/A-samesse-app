import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../routes/app_router.dart';
import '../services/session_service.dart';

/// Service central de gestion des deep links de l'application.
///
/// Il gère aussi bien les **App Links Android** et **Universal Links iOS**
/// (`https://asamesse.app/...`) que le **schéma personnalisé** de secours
/// (`asamesse://...`). La navigation est déléguée au routeur `go_router`
/// défini dans [appRouter].
class DeepLinkService {
  DeepLinkService._internal();

  /// Instance unique (singleton).
  static final DeepLinkService instance = DeepLinkService._internal();

  /// Domaine officiel utilisé pour les App Links / Universal Links.
  static const String domain = 'asamesse.app';

  /// Schéma personnalisé de secours (deep link « classique »).
  static const String scheme = 'asamesse';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;

  // Dé-duplication : le lien de démarrage à froid peut être livré deux fois
  // (getInitialLink + onListen du flux d'événements).
  String? _lastHandledLink;
  DateTime? _lastHandledAt;

  /// Initialise l'écoute des liens entrants.
  ///
  /// À appeler **une seule fois**, juste après `runApp()`, afin de ne pas
  /// rater le lien de démarrage à froid (*cold start*).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Sur le web, l'URL du navigateur est déjà gérée par go_router : la traiter
    // ici renverrait vers l'accueil à chaque rechargement de page.
    if (kIsWeb) return;

    // Lien ayant provoqué le lancement de l'application (cold start).
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _scheduleHandle(initialUri);
      }
    } catch (error) {
      debugPrint('DeepLinkService : échec de getInitialLink ($error)');
    }

    // Liens reçus alors que l'application est déjà lancée (warm / resume).
    _subscription = _appLinks.uriLinkStream.listen(
      _scheduleHandle,
      onError: (Object error) =>
          debugPrint('DeepLinkService : erreur du flux de liens ($error)'),
    );
  }

  /// Libère l'écoute des liens.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Attend que le routeur soit monté et le profil chargé (sinon le garde de
  /// route renverrait vers le splash) avant de naviguer.
  Future<void> _scheduleHandle(Uri uri) async {
    await WidgetsBinding.instance.endOfFrame;
    await SessionService.instance.ready;
    await _handleUri(uri);
  }

  /// Indique si le lien appartient à l'application (domaine ou schéma gérés).
  bool isOwnedLink(Uri uri) {
    if (uri.scheme == scheme) return true;
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final host = uri.host.toLowerCase();
      return host == domain || host == 'www.$domain';
    }
    return false;
  }

  /// Analyse le lien et navigue vers l'écran correspondant.
  Future<bool> _handleUri(Uri uri) async {
    if (!isOwnedLink(uri)) {
      // Laisse passer les liens non gérés (ex. callbacks d'auth Supabase).
      return false;
    }
    if (_isDuplicate(uri)) {
      return true;
    }
    await _dispatch(uri);
    return true;
  }

  /// Évite de traiter deux fois d'affilée le même lien.
  ///
  /// `app_links` émet le lien de démarrage à froid à la fois via
  /// `getInitialLink()` et via `onListen` du flux d'événements.
  bool _isDuplicate(Uri uri) {
    final identifier = uri.toString();
    final now = DateTime.now();
    if (_lastHandledLink == identifier &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 2)) {
      return true;
    }
    _lastHandledLink = identifier;
    _lastHandledAt = now;
    return false;
  }

  Future<void> _dispatch(Uri uri) async {
    final segments = _pathSegments(uri);
    if (segments.isEmpty) {
      appRouter.go('/home');
      return;
    }

    final head = segments.first.toLowerCase();
    switch (head) {
      case 'home':
      case 'accueil':
        appRouter.go('/home');
        break;
      case 'deals':
      case 'deal':
      case 'promos':
      case 'promotions':
        appRouter.go('/deals');
        break;
      case 'cart':
      case 'panier':
        appRouter.go('/cart');
        break;
      case 'orders':
      case 'commandes':
        appRouter.go('/orders');
        break;
      case 'profile':
      case 'profil':
        appRouter.go('/profile');
        break;
      case 'shops':
      case 'shop':
      case 'boutique':
      case 'boutiques':
        if (segments.length > 1) {
          appRouter.go('/shops/${Uri.encodeComponent(segments[1])}');
        } else {
          appRouter.go('/home');
        }
        break;
      case 'product':
      case 'products':
      case 'produit':
      case 'produits':
      case 'p':
        _openProduct(segments.length > 1 ? segments[1] : null);
        break;
      case 'vendor':
      case 'vendeur':
        appRouter.go('/vendor/dashboard');
        break;
      case 'delivery':
      case 'livreur':
        appRouter.go('/delivery/missions');
        break;
      case 'admin':
        appRouter.go('/admin/dashboard');
        break;
      default:
        appRouter.go('/home');
    }
  }

  /// Construit la liste des segments du lien.
  ///
  /// Pour un schéma personnalisé, le premier segment se trouve dans `host`
  /// (ex. `asamesse://shops/123` → `['shops', '123']`).
  List<String> _pathSegments(Uri uri) {
    final segments = <String>[];
    if (uri.scheme == scheme && uri.host.isNotEmpty) {
      segments.add(uri.host);
    }
    segments.addAll(uri.pathSegments.where((segment) => segment.isNotEmpty));
    return segments;
  }

  /// Ouvre la fiche produit : elle charge elle-même le produit par identifiant.
  void _openProduct(String? productId) {
    if (productId == null || productId.isEmpty) {
      appRouter.go('/home');
      return;
    }
    appRouter.go('/home/product/${Uri.encodeComponent(productId)}');
  }
}
