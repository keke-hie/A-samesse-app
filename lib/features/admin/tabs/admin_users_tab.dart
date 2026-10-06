import 'package:flutter/material.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _adminService = AdminService();
  late Future<List<Map<String, dynamic>>> _usersFuture = _adminService
      .listUsers();

  Future<void> _reload() async {
    final future = _adminService.listUsers();
    setState(() => _usersFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Chargement impossible',
            message: friendlyError(snapshot.error!),
            actionLabel: 'Réessayer',
            onAction: _reload,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!;
        if (users.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'Aucun utilisateur',
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _UserTile(user: users[index]),
          ),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final rawName = user['nom']?.toString().trim() ?? '';
    final name = rawName.isEmpty ? 'Utilisateur' : rawName;
    final role = user['role']?.toString() ?? 'acheteur';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColor.primarySoft,
          child: Text(
            name[0].toUpperCase(),
            style: const TextStyle(
              color: AppColor.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          user['email']?.toString() ??
              user['telephone']?.toString() ??
              'Coordonnée indisponible',
        ),
        trailing: StatusChip(label: role, color: AppColor.primary),
      ),
    );
  }
}
