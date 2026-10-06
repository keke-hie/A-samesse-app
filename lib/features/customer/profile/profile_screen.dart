import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';

/// Profil commun aux quatre espaces ; les raccourcis dépendent du rôle.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;

  static const _roleLabels = {
    UserRole.buyer: 'Client',
    UserRole.vendor: 'Vendeur',
    UserRole.courier: 'Livreur',
    UserRole.admin: 'Administrateur',
  };

  Future<void> _editName(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mon nom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom complet'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await SessionService.instance.updateDisplayName(name);
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    }
  }

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 600,
    );
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      await SessionService.instance.updateAvatar(file);
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SessionService.instance.signOut();
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionService.instance;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (!session.isLoggedIn) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profil')),
            body: EmptyState(
              icon: Icons.person_outline_rounded,
              title: 'Tu n’es pas connecté',
              message:
                  'Connecte-toi pour retrouver tes commandes et ton panier.',
              actionLabel: 'Se connecter',
              onAction: () => context.go('/login'),
            ),
          );
        }

        final user = session.user!;
        final name = session.displayName?.trim().isNotEmpty == true
            ? session.displayName!.trim()
            : 'Utilisateur';

        return Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: RefreshIndicator(
            onRefresh: session.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColor.primarySoft,
                              backgroundImage:
                                  session.avatarUrl?.isNotEmpty == true
                                  ? NetworkImage(session.avatarUrl!)
                                  : null,
                              child: session.avatarUrl?.isNotEmpty == true
                                  ? null
                                  : Text(
                                      name[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        color: AppColor.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: -10,
                              bottom: -10,
                              child: IconButton.filledTonal(
                                tooltip: 'Changer ma photo',
                                visualDensity: VisualDensity.compact,
                                onPressed: _uploadingAvatar
                                    ? null
                                    : _changeAvatar,
                                icon: _uploadingAvatar
                                    ? const SizedBox.square(
                                        dimension: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_outlined,
                                        size: 16,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (user.email != null)
                                Text(
                                  user.email!,
                                  style: const TextStyle(
                                    color: AppColor.textSecondary,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              StatusChip(
                                label: _roleLabels[session.role]!,
                                color: AppColor.primary,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Modifier mon nom',
                          onPressed: () => _editName(name),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      for (final shortcut in _shortcuts(session))
                        ListTile(
                          leading: Icon(shortcut.icon),
                          title: Text(shortcut.label),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.go(shortcut.location),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColor.danger,
                  ),
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<({IconData icon, String label, String location})> _shortcuts(
    SessionService session,
  ) => switch (session.role) {
    UserRole.vendor => const [
      (
        icon: Icons.dashboard_outlined,
        label: 'Tableau de bord',
        location: '/vendor/dashboard',
      ),
      (
        icon: Icons.storefront_outlined,
        label: 'Ma boutique',
        location: '/vendor/shop-management',
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Commandes reçues',
        location: '/vendor/sales',
      ),
      (
        icon: Icons.home_outlined,
        label: 'Voir le catalogue client',
        location: '/home',
      ),
    ],
    UserRole.courier => const [
      (
        icon: Icons.assignment_outlined,
        label: 'Mes missions',
        location: '/delivery/missions',
      ),
      (icon: Icons.map_outlined, label: 'Carte', location: '/delivery/map'),
    ],
    UserRole.admin => const [
      (
        icon: Icons.dashboard_outlined,
        label: 'Administration',
        location: '/admin/dashboard',
      ),
      (
        icon: Icons.home_outlined,
        label: 'Voir le catalogue client',
        location: '/home',
      ),
    ],
    UserRole.buyer => const [
      (
        icon: Icons.inventory_2_outlined,
        label: 'Mes commandes',
        location: '/orders',
      ),
      (
        icon: Icons.shopping_bag_outlined,
        label: 'Mon panier',
        location: '/cart',
      ),
      (
        icon: Icons.local_offer_outlined,
        label: 'Ventes éphémères',
        location: '/deals',
      ),
    ],
  };
}
