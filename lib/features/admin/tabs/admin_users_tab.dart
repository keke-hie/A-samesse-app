import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/services/document_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';

/// Comptes utilisateurs et validation des vendeurs / livreurs.
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _adminService = AdminService();
  late Future<List<Map<String, dynamic>>> _usersFuture = _adminService
      .listUsers();
  bool _onlyPending = true;

  Future<void> _reload() async {
    final future = _adminService.listUsers();
    setState(() => _usersFuture = future);
    await future;
  }

  Future<void> _openUser(Map<String, dynamic> user) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColor.background,
      builder: (_) => _UserReviewSheet(user: user, adminService: _adminService),
    );
    if (changed == true) await _reload();
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
        final users = snapshot.data!
            .where(
              (user) => !_onlyPending || user['statut_compte'] == 'en_attente',
            )
            .toList();

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Seulement les comptes à valider'),
                value: _onlyPending,
                onChanged: (value) => setState(() => _onlyPending = value),
              ),
              if (users.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'Aucun compte à afficher',
                  ),
                ),
              for (final user in users)
                _UserTile(user: user, onTap: () => _openUser(user)),
            ],
          ),
        );
      },
    );
  }
}

({String label, Color color}) _accountStatus(dynamic raw) =>
    switch (raw?.toString()) {
      'en_attente' => (label: 'À valider', color: AppColor.warning),
      'refuse' => (label: 'Refusé', color: AppColor.danger),
      'suspendu' => (label: 'Suspendu', color: AppColor.danger),
      _ => (label: 'Actif', color: AppColor.success),
    };

String _userName(Map<String, dynamic> user) {
  final name = user['nom']?.toString().trim() ?? '';
  return name.isEmpty ? 'Utilisateur' : name;
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = _userName(user);
    final status = _accountStatus(user['statut_compte']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
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
        subtitle: Text(user['role']?.toString() ?? 'Acheteur'),
        trailing: StatusChip(label: status.label, color: status.color),
      ),
    );
  }
}

class _UserReviewSheet extends StatefulWidget {
  const _UserReviewSheet({required this.user, required this.adminService});

  final Map<String, dynamic> user;
  final AdminService adminService;

  @override
  State<_UserReviewSheet> createState() => _UserReviewSheetState();
}

class _UserReviewSheetState extends State<_UserReviewSheet> {
  final _documentService = DocumentService();
  late final Future<Map<DocumentType, Map<String, dynamic>>> _documentsFuture =
      _documentService.fetchDocuments(
        userId: widget.user['id_utilisateur'].toString(),
      );
  bool _saving = false;

  Future<void> _openDocument(String path) async {
    try {
      final url = await _documentService.signedUrl(path);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    }
  }

  Future<void> _setStatus(String status) async {
    String? reason;
    if (status == 'refuse' || status == 'suspendu') {
      reason = await _askReason(status);
      if (reason == null) return;
    }
    setState(() => _saving = true);
    try {
      await widget.adminService.setAccountStatus(
        userId: widget.user['id_utilisateur'].toString(),
        status: status,
        reason: reason,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(friendlyError(error));
      }
    }
  }

  Future<String?> _askReason(String status) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          status == 'refuse' ? 'Motif du refus' : 'Motif de la suspension',
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ex. : CNI illisible, merci d’envoyer une photo nette.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(dialogContext, text);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final status = user['statut_compte']?.toString() ?? 'actif';
    final role = user['role']?.toString() ?? 'Acheteur';
    final isPro = const {'vendeur', 'livreur'}.contains(role.toLowerCase());

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(_userName(user), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            [role, user['telephone'], user['email']]
                .whereType<Object>()
                .where((value) => value.toString().isNotEmpty)
                .join(' · '),
            style: const TextStyle(color: AppColor.textSecondary),
          ),
          if ((user['motif_refus']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motif : ${user['motif_refus']}',
              style: const TextStyle(color: AppColor.danger),
            ),
          ],
          if (isPro) ...[
            const SizedBox(height: 20),
            Text(
              'Pièces justificatives',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<DocumentType, Map<String, dynamic>>>(
              future: _documentsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(friendlyError(snapshot.error!));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final documents = snapshot.data!;
                if (documents.isEmpty) {
                  return const Text(
                    'Aucune pièce envoyée pour le moment.',
                    style: TextStyle(color: AppColor.warning),
                  );
                }
                return Column(
                  children: [
                    for (final entry in documents.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(entry.key.label),
                        subtitle: Text(
                          'Envoyée le ${formatDate(entry.value['date_envoi'])}',
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () =>
                            _openDocument(entry.value['chemin'].toString()),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          if (_saving)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != 'actif')
                  FilledButton.icon(
                    onPressed: () => _setStatus('actif'),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      status == 'en_attente'
                          ? 'Valider le compte'
                          : 'Réactiver',
                    ),
                  ),
                if (status == 'en_attente')
                  OutlinedButton(
                    onPressed: () => _setStatus('refuse'),
                    child: const Text('Refuser'),
                  ),
                if (status == 'actif')
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColor.danger,
                    ),
                    onPressed: () => _setStatus('suspendu'),
                    child: const Text('Suspendre'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
