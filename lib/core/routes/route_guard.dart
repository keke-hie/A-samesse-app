/// Ce dont le garde a besoin pour décider (implémenté par `SessionService`).
abstract interface class RouteSession {
  bool get isReady;
  bool get isLoggedIn;
  bool get isAdmin;
  bool get isVendor;
  bool get isCourier;
  bool get isActive;
  String get homePath;
}

/// Redirections selon le rôle et le statut du compte.
///
/// Les données restent protégées côté Supabase (RLS) ; ce garde évite surtout
/// d'afficher un espace à quelqu'un qui n'y a pas droit (lien direct, deep link).
String? guardRoute(RouteSession session, Uri uri) {
  final path = uri.path;
  bool under(String prefix) => path == prefix || path.startsWith('$prefix/');

  // Tant que le profil n'est pas chargé, le splash attend.
  if (!session.isReady) return path == '/splash' ? null : '/splash';

  if (under('/admin')) {
    if (!session.isLoggedIn) return '/login';
    return session.isAdmin ? null : session.homePath;
  }
  if (under('/vendor')) {
    if (!session.isLoggedIn) return '/login';
    if (!session.isVendor) return session.homePath;
    return session.isActive ? null : '/pending';
  }
  if (under('/delivery')) {
    if (!session.isLoggedIn) return '/login';
    if (!session.isCourier) return session.homePath;
    return session.isActive ? null : '/pending';
  }
  if (path == '/pending') {
    final needsValidation =
        session.isLoggedIn &&
        (session.isVendor || session.isCourier) &&
        !session.isActive;
    return needsValidation ? null : session.homePath;
  }
  if ((path == '/login' || path == '/register') && session.isLoggedIn) {
    return session.homePath;
  }
  return null;
}
