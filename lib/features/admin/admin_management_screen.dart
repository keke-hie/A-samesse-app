import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';

class AdminManagementScreen extends StatefulWidget {
  final int initialTab;

  const AdminManagementScreen({super.key, this.initialTab = 0});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _supabase = Supabase.instance.client;
  late int _selectedTab = widget.initialTab;
  late Future<List<Map<String, dynamic>>> _usersFuture;
  late Future<List<Map<String, dynamic>>> _disputesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _usersFuture = _supabase.rpc('admin_list_utilisateurs').then(
        (response) => List<Map<String, dynamic>>.from(response as List),
      );
    _disputesFuture = _supabase
        .from('litiges')
        .select('id_litige, id_commande, id_acheteur, motif, description, statut, date_creation, decision_admin')
        .order('date_creation', ascending: false);
    if (mounted) setState(() {});
  }

  Future<void> _decideDispute(Map<String, dynamic> dispute, String status) async {
    final decisionController = TextEditingController(text: dispute['decision_admin']?.toString() ?? '');
    final decision = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == 'en_examen' ? 'Mettre en examen' : 'Décision sur le litige'),
        content: TextField(
          controller: decisionController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Note administrative', hintText: 'Ajouter le suivi ou la décision'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, decisionController.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    decisionController.dispose();
    if (decision == null) return;

    try {
      await _supabase.from('litiges').update({
        'statut': status,
        'decision_admin': decision,
        'id_administrateur': _supabase.auth.currentUser?.id,
        'date_decision': DateTime.now().toUtc().toIso8601String(),
      }).eq('id_litige', dispute['id_litige']);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Litige mis à jour.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mise à jour impossible : $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        title: const Text('Gestion', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColor.background,
        actions: [IconButton(tooltip: 'Actualiser', onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Utilisateurs'), icon: Icon(Icons.people_outline)),
                ButtonSegment(value: 1, label: Text('Litiges'), icon: Icon(Icons.report_problem_outlined)),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (value) => setState(() => _selectedTab = value.first),
            ),
          ),
          Expanded(child: _selectedTab == 0 ? _buildUsers() : _buildDisputes()),
        ],
      ),
    );
  }

  Widget _buildUsers() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _errorState(snapshot.error.toString());
        final users = snapshot.data ?? [];
        if (users.isEmpty) return const Center(child: Text('Aucun utilisateur trouvé.'));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final user = users[index];
            final name = user['nom']?.toString().trim().isNotEmpty == true ? user['nom'].toString() : 'Utilisateur';
            final role = user['role']?.toString() ?? 'Sans rôle';
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: AppColor.primarySoft, child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColor.primary, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(user['email']?.toString() ?? user['telephone']?.toString() ?? 'Coordonnée indisponible', style: const TextStyle(fontSize: 12, color: AppColor.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: AppColor.primarySoft, borderRadius: BorderRadius.circular(14)),
                    child: Text(role, style: const TextStyle(fontSize: 10, color: AppColor.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDisputes() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _disputesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _errorState(snapshot.error.toString());
        final disputes = snapshot.data ?? [];
        if (disputes.isEmpty) return const Center(child: Text('Aucun litige à traiter.'));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: disputes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final dispute = disputes[index];
            final status = dispute['statut']?.toString() ?? 'ouvert';
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(dispute['motif']?.toString() ?? 'Litige', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text(status.replaceAll('_', ' '), style: const TextStyle(color: AppColor.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text('Commande #${dispute['id_commande']}', style: const TextStyle(fontSize: 11, color: AppColor.textSecondary)),
                  const SizedBox(height: 8),
                  Text(dispute['description']?.toString() ?? '', style: const TextStyle(fontSize: 13, height: 1.35)),
                  if ((dispute['decision_admin'] as String?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text('Suivi : ${dispute['decision_admin']}', style: const TextStyle(fontSize: 12, color: AppColor.textSecondary)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(onPressed: () => _decideDispute(dispute, 'en_examen'), child: const Text('En examen')),
                      TextButton(onPressed: () => _decideDispute(dispute, 'accepte'), child: const Text('Accepter')),
                      TextButton(onPressed: () => _decideDispute(dispute, 'rejete'), child: const Text('Rejeter')),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Chargement impossible. Vérifie les permissions administrateur.\n$message', textAlign: TextAlign.center),
      ),
    );
  }
}
