import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/services/session_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? userAuth;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      Map<String, dynamic>? row;
      if (user != null) {
        row = await client
            .from('utilisateurs')
            .select()
            .eq('id_utilisateur', user.id)
            .maybeSingle();
      }
      if (!mounted) return;
      setState(() {
        userAuth = user;
        _profile = row == null ? null : Map<String, dynamic>.from(row);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        userAuth = Supabase.instance.client.auth.currentUser;
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _displayName {
    final meta = userAuth?.userMetadata;
    return _profile?['nom']?.toString() ??
        meta?['full_name']?.toString() ??
        meta?['nom']?.toString() ??
        'Utilisateur';
  }

  String get _role => switch (SessionService.instance.role) {
    UserRole.admin => 'admin',
    UserRole.vendor => 'vendeur',
    UserRole.courier => 'livreur',
    UserRole.buyer => 'acheteur',
  };

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }
  void _showSettingsModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocale.text(context, 'Paramètres', 'Settings'),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_outlined),
                title: Text(AppLocale.text(
                    context, 'Langue : Français', 'Language: French')),
                subtitle: Text(AppLocale.text(context,
                    'Touchez pour basculer FR / EN', 'Tap to switch FR / EN')),
                onTap: () async {
                  final current =
                      Localizations.localeOf(context).languageCode;
                  await AppLocale.setLanguage(
                      current == 'fr' ? 'en' : 'fr');
                  if (mounted) Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.refresh_outlined),
                title: Text(AppLocale.text(
                    context, 'Actualiser le profil', 'Refresh profile')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _loadProfile();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.logout_outlined, color: Colors.red),
                title: Text(
                  AppLocale.text(context, 'Se déconnecter', 'Sign out'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Administration',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Dashboard admin'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/admin/dashboard');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: const Text('Utilisateurs'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/admin/management?tab=users');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.report_problem_outlined),
                title: const Text('Litiges'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/admin/management?tab=disputes');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.logout_outlined, color: Colors.red),
                title: const Text('Se déconnecter',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Mon Profil",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
              final r = (_role).toLowerCase();
              if (r.contains('admin')) {
                _showAdminSettingsSheet();
              } else {
                _showSettingsModal();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColor.primary))
          : _error != null && userAuth == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Chargement impossible : $_error',
                        textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (userAuth == null)
                        _buildLoggedOut(context)
                      else ...[
                        _buildHeader(context),
                        const SizedBox(height: 16),
                        _buildShortcuts(context),
                        const SizedBox(height: 16),
                        _buildLanguageCard(context),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_outlined),
                          label: Text(AppLocale.text(
                              context, 'Se déconnecter', 'Sign out')),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildLoggedOut(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocale.text(
                context, 'Vous n’êtes pas connecté', 'You are not signed in'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocale.text(
                context,
                'Connectez-vous pour retrouver vos commandes et votre panier.',
                'Sign in to find your orders and cart.'),
            style: const TextStyle(color: AppColor.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: Text(AppLocale.text(context, 'Se connecter', 'Sign in')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/register'),
            child:
                Text(AppLocale.text(context, 'Créer un compte', 'Sign up')),
          ),
        ],
      ),
    );
  }
  Widget _buildHeader(BuildContext context) {
    final avatarUrl = _profile?['avatar_url']?.toString();
    final email = userAuth?.email ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColor.primarySoft,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(Icons.person_outline,
                    color: AppColor.primary, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(email,
                      style: const TextStyle(
                          color: AppColor.textSecondary, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColor.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _role.isEmpty ? 'acheteur' : _role,
                    style: const TextStyle(
                        color: AppColor.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts(BuildContext context) {
    final tiles = <Widget>[
      ListTile(
        leading:
            const Icon(Icons.shopping_bag_outlined, color: AppColor.primary),
        title: Text(AppLocale.text(context, 'Mes commandes', 'My orders')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/orders'),
      ),
      ListTile(
        leading:
            const Icon(Icons.shopping_cart_outlined, color: AppColor.primary),
        title: Text(AppLocale.text(context, 'Mon panier', 'My cart')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/cart'),
      ),
    ];
    if (_role.contains('vendeur')) {
      tiles.add(ListTile(
        leading:
            const Icon(Icons.storefront_outlined, color: AppColor.primary),
        title: const Text('My Shop vendeur'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/vendor/dashboard'),
      ));
    }
    if (_role.contains('livreur')) {
      tiles.add(ListTile(
        leading: const Icon(Icons.delivery_dining_outlined,
            color: AppColor.primary),
        title: const Text('Mes missions'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/delivery/missions'),
      ));
    }
    if (_role.contains('admin')) {
      tiles.add(ListTile(
        leading: const Icon(Icons.admin_panel_settings_outlined,
            color: AppColor.primary),
        title: const Text('Dashboard admin'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/admin/dashboard'),
      ));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: tiles),
    );
  }

  Widget _buildLanguageCard(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode != 'en';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.language_outlined, color: AppColor.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocale.text(
                  context, 'Langue de l’application', 'App language'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'fr', label: Text('FR')),
              ButtonSegment(value: 'en', label: Text('EN')),
            ],
            selected: {isFr ? 'fr' : 'en'},
            onSelectionChanged: (selection) {
              AppLocale.setLanguage(selection.first);
            },
          ),
        ],
      ),
    );
  }
}
