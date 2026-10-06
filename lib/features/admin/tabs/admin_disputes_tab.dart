import 'package:flutter/material.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';

class AdminDisputesTab extends StatefulWidget {
  const AdminDisputesTab({super.key});

  @override
  State<AdminDisputesTab> createState() => _AdminDisputesTabState();
}

class _AdminDisputesTabState extends State<AdminDisputesTab> {
  final _adminService = AdminService();
  late Future<List<Map<String, dynamic>>> _disputesFuture = _adminService
      .listDisputes();

  Future<void> _reload() async {
    final future = _adminService.listDisputes();
    setState(() => _disputesFuture = future);
    await future;
  }

  Future<void> _decide(Map<String, dynamic> dispute, String status) async {
    final controller = TextEditingController(
      text: dispute['decision_admin']?.toString() ?? '',
    );
    final decision = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          status == 'en_examen' ? 'Mettre en examen' : 'Décision sur le litige',
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note administrative',
            hintText: 'Suivi ou décision communiquée au client',
          ),
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
    if (decision == null) return;

    try {
      await _adminService.decideDispute(
        disputeId: dispute['id_litige'].toString(),
        status: status,
        decision: decision,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Litige mis à jour.')));
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _disputesFuture,
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
        final disputes = snapshot.data!;
        if (disputes.isEmpty) {
          return const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Aucun litige à traiter',
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: disputes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildDispute(disputes[index]),
          ),
        );
      },
    );
  }

  Widget _buildDispute(Map<String, dynamic> dispute) {
    final status = dispute['statut']?.toString() ?? 'ouvert';
    final decision = dispute['decision_admin']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dispute['motif']?.toString() ?? 'Litige',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(
                  label: status.replaceAll('_', ' '),
                  color: AppColor.primary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Commande ${shortOrderRef(dispute['id_commande'])} · ${formatDate(dispute['date_creation'])}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColor.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(dispute['description']?.toString() ?? ''),
            if (decision.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Suivi : $decision',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColor.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _decide(dispute, 'en_examen'),
                  child: const Text('En examen'),
                ),
                TextButton(
                  onPressed: () => _decide(dispute, 'accepte'),
                  child: const Text('Accepter'),
                ),
                TextButton(
                  onPressed: () => _decide(dispute, 'rejete'),
                  child: const Text('Rejeter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
