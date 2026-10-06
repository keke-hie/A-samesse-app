import 'package:asamesse_app/core/routes/route_guard.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSession implements RouteSession {
  FakeSession({
    this.isReady = true,
    this.isLoggedIn = true,
    this.isAdmin = false,
    this.isVendor = false,
    this.isCourier = false,
    this.isActive = true,
  });

  @override
  final bool isReady;
  @override
  final bool isLoggedIn;
  @override
  final bool isAdmin;
  @override
  final bool isVendor;
  @override
  final bool isCourier;
  @override
  final bool isActive;

  @override
  String get homePath {
    if (!isLoggedIn) return '/home';
    if (isAdmin) return '/admin/dashboard';
    if (isVendor) return isActive ? '/vendor/dashboard' : '/pending';
    if (isCourier) return isActive ? '/delivery/missions' : '/pending';
    return '/home';
  }
}

String? guard(FakeSession session, String location) =>
    guardRoute(session, Uri.parse(location));

void main() {
  test('attend le chargement du profil sur le splash', () {
    final session = FakeSession(isReady: false);
    expect(guard(session, '/vendor/dashboard'), '/splash');
    expect(guard(session, '/splash'), isNull);
  });

  test('un visiteur peut parcourir le catalogue mais pas les espaces pro', () {
    final guest = FakeSession(isLoggedIn: false);
    expect(guard(guest, '/home'), isNull);
    expect(guard(guest, '/shops/42'), isNull);
    expect(guard(guest, '/admin/dashboard'), '/login');
    expect(guard(guest, '/vendor/dashboard'), '/login');
    expect(guard(guest, '/delivery/missions'), '/login');
  });

  test('un acheteur ne peut pas ouvrir l’administration par lien direct', () {
    final buyer = FakeSession();
    expect(guard(buyer, '/admin/management?tab=users'), '/home');
    expect(guard(buyer, '/vendor/products'), '/home');
    expect(guard(buyer, '/pending'), '/home');
  });

  test('un vendeur non validé est renvoyé vers la page de validation', () {
    final pendingVendor = FakeSession(isVendor: true, isActive: false);
    expect(guard(pendingVendor, '/vendor/dashboard'), '/pending');
    expect(guard(pendingVendor, '/pending'), isNull);
    expect(guard(pendingVendor, '/delivery/missions'), '/pending');
  });

  test('un vendeur validé accède à son espace mais pas à celui du livreur', () {
    final vendor = FakeSession(isVendor: true);
    expect(guard(vendor, '/vendor/dashboard'), isNull);
    expect(guard(vendor, '/delivery/missions'), '/vendor/dashboard');
    expect(guard(vendor, '/pending'), '/vendor/dashboard');
  });

  test('un utilisateur connecté ne revoit pas la connexion', () {
    expect(guard(FakeSession(isAdmin: true), '/login'), '/admin/dashboard');
    expect(
      guard(FakeSession(isCourier: true), '/register'),
      '/delivery/missions',
    );
  });
}
