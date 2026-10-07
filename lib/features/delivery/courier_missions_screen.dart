import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/delivery_service.dart';
import '../../core/services/location_sharing.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/empty_state.dart';
import 'widgets/delivery_card.dart';
import 'widgets/delivery_code_dialog.dart';
import '../../core/services/session_service.dart';

/// Missions du livreur : livraisons à prendre, en cours et terminées.
class CourierMissionsScreen extends StatefulWidget {
  const CourierMissionsScreen({super.key});

  @override
  State<CourierMissionsScreen> createState() => _CourierMissionsScreenState();
}

class _CourierMissionsScreenState extends State<CourierMissionsScreen> {
  final _deliveryService = DeliveryService();
  final _location = LocationSharing.instance;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  List<Map<String, dynamic>> _assigned = [];
  List<Map<String, dynamic>> _available = [];
  bool _isLoading = true;
  Object? _error;
  int _tab = 0;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _location.addListener(_onLocationChanged);
    _load();
    final courierId = SessionService.instance.user?.id;
    if (courierId != null) {
      // Une attribution par un admin ou une confirmation met la liste à jour.
      _subscription = _deliveryService
          .watchMyDeliveries(courierId)
          .skip(1)
          .listen((_) => _load());
    }
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    _subscription?.cancel();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final assigned = await _deliveryService.listAssigned();
      final available = await _deliveryService.listAvailable().catchError(
        (_) => <Map<String, dynamic>>[],
      );
      if (!mounted) return;
      setState(() {
        _assigned = assigned;
        _available = available;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _deliveriesForTab(int tab) {
    List<Map<String, dynamic>> byStage(Set<DeliveryStage> stages) => _assigned
        .where((delivery) => stages.contains(deliveryStageOf(delivery)))
        .toList();
    return switch (tab) {
      0 => [
        ...byStage({DeliveryStage.assigned}),
        ..._available,
      ],
      1 => byStage({DeliveryStage.inProgress}),
      _ => byStage({DeliveryStage.delivered}),
    };
  }

  Future<void> _run(
    Map<String, dynamic> delivery,
    Future<void> Function(String id) action, {
    String? done,
    int? goToTab,
    bool startSharing = false,
  }) async {
    final id = delivery['id_livraison'].toString();
    setState(() => _busy.add(id));
    try {
      await action(id);
      if (startSharing) await _location.start(id);
      await _load();
      if (!mounted) return;
      if (goToTab != null) setState(() => _tab = goToTab);
      if (done != null) _showMessage(done);
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
      await _load();
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _decline(Map<String, dynamic> delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refuser cette livraison ?'),
        content: const Text('Elle sera proposée à un autre livreur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        delivery,
        _deliveryService.decline,
        done: 'Livraison libérée.',
      );
    }
  }

  Future<void> _confirm(Map<String, dynamic> delivery) async {
    final id = delivery['id_livraison'].toString();
    final confirmed = await showDeliveryCodeDialog(context, id);
    if (confirmed != true) return;
    if (_location.isSharing(id)) await _location.stop();
    await _load();
    if (!mounted) return;
    setState(() => _tab = 2);
    _showMessage('Livraison confirmée. Merci !');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes missions'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Chargement impossible',
              message: friendlyError(_error!),
              actionLabel: 'Réessayer',
              onAction: _load,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 0,
                        label: Text(
                          'À prendre (${_deliveriesForTab(0).length})',
                        ),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text(
                          'En cours (${_deliveriesForTab(1).length})',
                        ),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text('Livrées (${_deliveriesForTab(2).length})'),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (value) =>
                        setState(() => _tab = value.first),
                  ),
                ),
                if (_location.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _location.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(child: _buildList(_deliveriesForTab(_tab))),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> deliveries) {
    return RefreshIndicator(
      onRefresh: _load,
      child: deliveries.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 60),
                EmptyState(
                  icon: Icons.delivery_dining_outlined,
                  title: switch (_tab) {
                    0 => 'Aucune livraison à prendre',
                    1 => 'Aucune livraison en cours',
                    _ => 'Aucune livraison terminée',
                  },
                  message: _tab == 0
                      ? 'Les commandes prêtes chez les vendeurs apparaîtront ici.'
                      : null,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: deliveries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final delivery = deliveries[index];
                final id = delivery['id_livraison'].toString();
                return DeliveryCard(
                  delivery: delivery,
                  isBusy: _busy.contains(id),
                  isSharingLocation: _location.isSharing(id),
                  onClaim: () => _run(
                    delivery,
                    _deliveryService.claim,
                    done:
                        'Livraison prise en charge. Ta position est partagée avec le client.',
                    goToTab: 1,
                    startSharing: true,
                  ),
                  onAccept: () => _run(
                    delivery,
                    _deliveryService.accept,
                    done: 'Livraison acceptée.',
                    goToTab: 1,
                    startSharing: true,
                  ),
                  onDecline: () => _decline(delivery),
                  onConfirm: () => _confirm(delivery),
                  onOpenMap: () =>
                      context.push('/delivery/map/${delivery['id_commande']}'),
                  onToggleLocation: () => _location.isSharing(id)
                      ? _location.stop()
                      : _location.start(id),
                );
              },
            ),
    );
  }
}
