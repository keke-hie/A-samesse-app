import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/route_guard.dart';

enum UserRole { buyer, vendor, courier, admin }

enum AccountStatus { active, pending, refused, suspended }

/// Source de vérité pour l'utilisateur connecté : rôle et statut viennent de la
/// table `utilisateurs` (jamais des métadonnées, que le client peut écrire).
///
/// Le routeur écoute ce service pour protéger les espaces vendeur / livreur / admin.
class SessionService extends ChangeNotifier implements RouteSession {
  SessionService._();

  static final SessionService instance = SessionService._();

  SupabaseClient get _supabase => Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  bool _isReady = false;
  final Completer<void> _ready = Completer<void>();
  UserRole _role = UserRole.buyer;
  AccountStatus _status = AccountStatus.active;
  String? _displayName;
  String? _avatarUrl;
  String? _refusalReason;
  String? _loadedUserId;

  @override
  bool get isReady => _isReady;

  /// Se complète après le premier chargement du profil.
  Future<void> get ready => _ready.future;
  User? get user => _supabase.auth.currentUser;
  @override
  bool get isLoggedIn => user != null;
  UserRole get role => _role;
  AccountStatus get status => _status;
  @override
  bool get isActive => _status == AccountStatus.active;
  @override
  bool get isAdmin => isLoggedIn && _role == UserRole.admin;
  @override
  bool get isVendor => isLoggedIn && _role == UserRole.vendor;
  @override
  bool get isCourier => isLoggedIn && _role == UserRole.courier;
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  String? get refusalReason => _refusalReason;

  /// Page d'accueil de l'espace correspondant au rôle.
  @override
  String get homePath {
    if (!isLoggedIn) return '/home';
    return switch (_role) {
      UserRole.admin => '/admin/dashboard',
      UserRole.vendor => isActive ? '/vendor/dashboard' : '/pending',
      UserRole.courier => isActive ? '/delivery/missions' : '/pending',
      UserRole.buyer => '/home',
    };
  }

  Future<void> init() async {
    _authSubscription ??= _supabase.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.initialSession) return;
      if (state.event == AuthChangeEvent.signedOut) {
        _reset();
        notifyListeners();
      } else if (state.session?.user.id != _loadedUserId) {
        refresh();
      }
    });
    await refresh();
  }

  Future<void> refresh() async {
    final current = user;
    if (current == null) {
      _reset();
    } else {
      try {
        final row = await _supabase
            .from('utilisateurs')
            .select()
            .eq('id_utilisateur', current.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));
        final isAdmin = await _supabase
            .rpc('is_current_user_admin')
            .timeout(const Duration(seconds: 8));
        _role = isAdmin == true ? UserRole.admin : _parseRole(row?['role']);
        _status = _parseStatus(row?['statut_compte']);
        _refusalReason = row?['motif_refus']?.toString();
        _avatarUrl = row?['avatar_url']?.toString();
        _displayName =
            row?['nom']?.toString() ??
            current.userMetadata?['full_name']?.toString();
        _loadedUserId = current.id;
      } catch (error) {
        // Hors ligne : on garde le dernier profil connu de cet utilisateur,
        // sinon on retombe sur l'espace client (les données restent protégées par RLS).
        debugPrint('SessionService : profil indisponible ($error)');
        if (_loadedUserId != current.id) {
          _role = UserRole.buyer;
          _status = AccountStatus.active;
        }
      }
    }
    _isReady = true;
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  Future<void> signOut() => _supabase.auth.signOut();

  Future<void> updateDisplayName(String name) async {
    final id = user?.id;
    if (id == null) return;
    await _supabase
        .from('utilisateurs')
        .update({'nom': name})
        .eq('id_utilisateur', id);
    _displayName = name;
    notifyListeners();
  }

  /// Envoie la photo de profil dans le bucket `avatars` et l'enregistre.
  Future<void> updateAvatar(XFile file) async {
    final id = user?.id;
    if (id == null) return;
    final extension = file.name.split('.').last.toLowerCase();
    final path =
        'avatars/${id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storage = _supabase.storage.from('avatars');
    await storage.uploadBinary(
      path,
      await file.readAsBytes(),
      fileOptions: FileOptions(
        contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );
    final url = storage.getPublicUrl(path);
    await _supabase
        .from('utilisateurs')
        .update({'avatar_url': url})
        .eq('id_utilisateur', id);
    _avatarUrl = url;
    notifyListeners();
  }

  void _reset() {
    _role = UserRole.buyer;
    _status = AccountStatus.active;
    _displayName = null;
    _avatarUrl = null;
    _refusalReason = null;
    _loadedUserId = null;
  }

  static UserRole _parseRole(dynamic raw) =>
      switch (raw?.toString().toLowerCase().trim()) {
        'vendeur' => UserRole.vendor,
        'livreur' => UserRole.courier,
        _ => UserRole.buyer,
      };

  static AccountStatus _parseStatus(dynamic raw) => switch (raw?.toString()) {
    'en_attente' => AccountStatus.pending,
    'refuse' => AccountStatus.refused,
    'suspendu' => AccountStatus.suspended,
    _ => AccountStatus.active,
  };
}
