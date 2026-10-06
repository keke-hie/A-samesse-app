import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_color.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/formatters.dart';

class DeliveryMapScreen extends StatefulWidget {
  final String? idCommande;
  final Map<String, dynamic>? extraData;
  final bool missionsOnly;
  final bool mapOnly;

  const DeliveryMapScreen({
    super.key,
    this.idCommande,
    this.extraData,
    this.missionsOnly = false,
    this.mapOnly = false,
  });

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  final _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _deliverySubscription;
  String? _activeCommandeId;
  String? _activeDeliveryId;
  String? _userId;
  bool _isCourier = false;
  bool _isInitializing = true;
  bool _isSharingLocation = false;
  String? _locationError;
  int _selectedDeliveryTab = 0;
  List<Map<String, dynamic>> _assignedDeliveries = [];
  List<Map<String, dynamic>> _availableDeliveries = [];
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _userId = _supabase.auth.currentUser?.id;
    _activeCommandeId =
        widget.idCommande ?? widget.extraData?['id_commande']?.toString();
    _initializeDeliveryScreen();
  }

  Future<void> _initializeDeliveryScreen() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    try {
      if (SessionService.instance.isCourier) {
        final response = await _supabase.rpc(
          'courier_list_assigned_deliveries',
        );
        final deliveries = List<Map<String, dynamic>>.from(response as List);
        Map<String, dynamic>? selectedDelivery;
        if (_activeCommandeId != null) {
          for (final delivery in deliveries) {
            if (delivery['id_commande']?.toString() == _activeCommandeId) {
              selectedDelivery = delivery;
              break;
            }
          }
        }
        if (selectedDelivery == null && widget.mapOnly) {
          for (final delivery in deliveries) {
            if (!_isDeliveryCompleted(
              (delivery['statut_livraison'] ?? '').toString().toLowerCase(),
            )) {
              selectedDelivery = delivery;
              break;
            }
          }
        }

        final available = await _fetchAvailableDeliveries();
        if (mounted) {
          setState(() {
            _isCourier = true;
            _assignedDeliveries = deliveries;
            _availableDeliveries = available;
            if (selectedDelivery != null) {
              _activeDeliveryId = selectedDelivery['id_livraison']?.toString();
              _activeCommandeId = selectedDelivery['id_commande']?.toString();
            }
          });
        }
        await _deliverySubscription?.cancel();
        _deliverySubscription = _supabase
            .from('livraisons')
            .stream(primaryKey: ['id_livraison'])
            .eq('id_livreur', userId)
            .listen(
              (rows) async {
                if (!mounted) return;
                if (rows.isEmpty) {
                  setState(() => _assignedDeliveries = []);
                  return;
                }
                try {
                  final updated = await _supabase.rpc(
                    'courier_list_assigned_deliveries',
                  );
                  if (!mounted) return;
                  setState(
                    () => _assignedDeliveries = List<Map<String, dynamic>>.from(
                      updated as List,
                    ),
                  );
                } catch (_) {
                  // Retain the last successful assignment list when details fail to refresh.
                }
              },
              onError: (_) {
                if (mounted)
                  setState(
                    () => _locationError =
                        'Actualisation des livraisons impossible.',
                  );
              },
            );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _locationError = 'Impossible de charger les livraisons.',
        );
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAvailableDeliveries() async {
    try {
      final response = await _supabase.rpc('courier_list_available_deliveries');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      // Compte livreur non validé ou réseau : la liste reste vide.
      return [];
    }
  }

  Future<void> _claimDelivery(Map<String, dynamic> delivery) async {
    final id = delivery['id_livraison'].toString();
    setState(() => _claiming.add(id));
    try {
      await _supabase.rpc(
        'courier_claim_delivery',
        params: {'p_id_livraison': id},
      );
      final assigned = await _supabase.rpc('courier_list_assigned_deliveries');
      if (!mounted) return;
      setState(() {
        _availableDeliveries.removeWhere(
          (item) => item['id_livraison'].toString() == id,
        );
        _assignedDeliveries = List<Map<String, dynamic>>.from(assigned as List);
        _selectedDeliveryTab = 1;
      });
      await _startLocationSharing({...delivery, 'statut_livraison': 'en_cours'});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      final available = await _fetchAvailableDeliveries();
      if (mounted) setState(() => _availableDeliveries = available);
    } finally {
      if (mounted) setState(() => _claiming.remove(id));
    }
  }

  Future<void> _startLocationSharing(Map<String, dynamic> delivery) async {
    final deliveryId = delivery['id_livraison']?.toString();
    final userId = _userId;
    if (deliveryId == null || userId == null) return;

    setState(() {
      _activeDeliveryId = deliveryId;
      _activeCommandeId = delivery['id_commande'].toString();
      _locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Active le service de localisation de ton appareil.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Autorise la localisation pour partager ta position pendant la livraison.',
        );
      }

      await _positionSubscription?.cancel();
      setState(() {
        _isSharingLocation = true;
      });

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (position) => _publishLocation(deliveryId, userId, position),
            onError: (_) {
              if (mounted)
                setState(
                  () => _locationError = 'La localisation a été interrompue.',
                );
            },
          );
    } catch (error) {
      if (mounted)
        setState(
          () =>
              _locationError = error.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _publishLocation(
    String deliveryId,
    String userId,
    Position position,
  ) async {
    try {
      await _supabase.from('positions_livreurs').upsert({
        'id_livraison': deliveryId,
        'id_livreur': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'date_position': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id_livraison');
    } catch (_) {
      if (mounted)
        setState(
          () => _locationError = 'Impossible de transmettre la position.',
        );
    }
  }

  Future<void> _stopLocationSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) setState(() => _isSharingLocation = false);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _deliverySubscription?.cancel();
    super.dispose();
  }

  String get _effectiveIdCommande {
    return _activeCommandeId ??
        widget.idCommande ??
        widget.extraData?['id_commande']?.toString() ??
        '';
  }

  Stream<Map<String, dynamic>> _getDeliveryStream() {
    return Supabase.instance.client
        .from('livraisons')
        .stream(primaryKey: ['id_livraison'])
        .eq('id_commande', _effectiveIdCommande)
        .map((rows) => rows.isNotEmpty ? rows.first : <String, dynamic>{});
  }

  Stream<List<Map<String, dynamic>>> _getCourierPositionStream(
    String deliveryId,
  ) {
    return _supabase
        .from('positions_livreurs')
        .stream(primaryKey: ['id_livraison'])
        .eq('id_livraison', deliveryId);
  }

  bool _isDeliveryCompleted(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == 'livree' ||
        normalized == 'livrée' ||
        normalized == 'livre' ||
        normalized == 'livré' ||
        normalized == 'terminee' ||
        normalized == 'terminée' ||
        normalized == 'delivered';
  }

  List<Map<String, dynamic>> _deliveriesForTab(int tab) {
    final assigned = _assignedDeliveries.where((delivery) {
      final status = (delivery['statut_livraison'] ?? '')
          .toString()
          .toLowerCase();
      final delivered = _isDeliveryCompleted(status);
      final processing = status.contains('cours') || status.contains('route');
      return switch (tab) {
        0 =>
          !delivered &&
              !processing &&
              !status.contains('refus') &&
              !status.contains('annul'),
        1 => !delivered && processing,
        _ => delivered,
      };
    }).toList();
    return tab == 0 ? [...assigned, ..._availableDeliveries] : assigned;
  }

  Widget _buildCourierDeliveryPicker() {
    final deliveries = _deliveriesForTab(_selectedDeliveryTab);

    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        title: const Text(
          'Mes livraisons',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColor.background,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _initializeDeliveryScreen,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text('À prendre (${_countDeliveries(0)})'),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('En cours (${_countDeliveries(1)})'),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Livrées (${_countDeliveries(2)})'),
                ),
              ],
              selected: {_selectedDeliveryTab},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedDeliveryTab = selection.first),
            ),
          ),
          Expanded(
            child: deliveries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delivery_dining,
                            size: 42,
                            color: AppColor.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedDeliveryTab == 2
                                ? 'Aucune livraison terminée.'
                                : 'Aucune livraison dans cette liste.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    itemCount: deliveries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildDeliveryOrderCard(deliveries[index]),
                  ),
          ),
        ],
      ),
    );
  }

  int _countDeliveries(int tab) => _deliveriesForTab(tab).length;

  Map<String, dynamic> _orderForDelivery(Map<String, dynamic> delivery) {
    final order = delivery['commandes'];
    return order is Map<String, dynamic> ? order : <String, dynamic>{};
  }

  String _deliveryProductsLabel(Map<String, dynamic> delivery) {
    final lines = _orderForDelivery(delivery)['lignes_commande'];
    if (lines is! List || lines.isEmpty) return 'Articles de la commande';
    return lines
        .map((line) {
          if (line is! Map) return '';
          final product = line['produits'];
          final name = product is Map
              ? product['nom_produit']?.toString() ?? 'Produit'
              : 'Produit';
          final quantity = (line['quantite'] as num?)?.toInt() ?? 1;
          return '$name × $quantity';
        })
        .where((item) => item.isNotEmpty)
        .join(', ');
  }

  Widget _buildDeliveryOrderCard(Map<String, dynamic> delivery) {
    final deliveryId = delivery['id_livraison'].toString();
    final order = _orderForDelivery(delivery);
    final orderId = delivery['id_commande']?.toString() ?? '';
    final status = (delivery['statut_livraison'] ?? 'Attribuée').toString();
    final normalizedStatus = status.toLowerCase();
    final processing =
        normalizedStatus.contains('cours') ||
        normalizedStatus.contains('route');
    final delivered = _isDeliveryCompleted(normalizedStatus);
    final available = normalizedStatus == 'disponible';
    final total = order['montant_total'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Commande #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                status.replaceAll('_', ' '),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColor.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _deliveryInfoRow(
            'Paiement',
            (order['mode_paiement'] ?? 'À confirmer').toString().replaceAll(
              '_',
              ' ',
            ),
          ),
          if (total != null)
            _deliveryInfoRow('Total', formatPrice(total)),
          _deliveryInfoRow(
            'Destination',
            (delivery['adresse_destination'] ?? 'À confirmer').toString(),
          ),
          const SizedBox(height: 5),
          Text(
            'Produits : ${_deliveryProductsLabel(delivery)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColor.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (available)
                _deliveryActionButton(
                  label: _claiming.contains(deliveryId)
                      ? 'En cours…'
                      : 'Prendre la livraison',
                  color: AppColor.primary,
                  onPressed: _claiming.contains(deliveryId)
                      ? null
                      : () => _claimDelivery(delivery),
                ),
              if (!available && !processing && !delivered) ...[
                _deliveryActionButton(
                  label: 'Accepter',
                  color: AppColor.success,
                  onPressed: () => _acceptDelivery(delivery),
                ),
                _deliveryActionButton(
                  label: 'Refuser',
                  color: AppColor.danger,
                  onPressed: () => _declineDelivery(delivery),
                ),
              ],
              if (processing)
                _deliveryActionButton(
                  label: 'Livrée',
                  color: AppColor.primary,
                  onPressed: () => _showOtpDialog(delivery),
                ),
              OutlinedButton(
                onPressed: () => _showDeliveryDetails(delivery),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColor.textPrimary,
                  side: const BorderSide(color: AppColor.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                ),
                child: const Text('Détails'),
              ),
              if (processing && !delivered)
                IconButton(
                  tooltip: _activeDeliveryId == deliveryId && _isSharingLocation
                      ? 'Arrêter le GPS'
                      : 'Partager ma position',
                  onPressed:
                      _activeDeliveryId == deliveryId && _isSharingLocation
                      ? _stopLocationSharing
                      : () => _startLocationSharing(delivery),
                  icon: Icon(
                    _activeDeliveryId == deliveryId && _isSharingLocation
                        ? Icons.location_disabled
                        : Icons.my_location,
                    color: AppColor.primary,
                  ),
                ),
            ],
          ),
          if (_locationError != null && _activeDeliveryId == deliveryId)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _locationError!,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _deliveryInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColor.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveryActionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        minimumSize: const Size(82, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _acceptDelivery(Map<String, dynamic> delivery) async {
    try {
      await _supabase.rpc(
        'accept_assigned_delivery',
        params: {'p_id_livraison': delivery['id_livraison']},
      );
      if (!mounted) return;
      final id = delivery['id_livraison'].toString();
      setState(() {
        _selectedDeliveryTab = 1;
        _assignedDeliveries = _assignedDeliveries.map((item) {
          return item['id_livraison'].toString() == id
              ? {...item, 'statut_livraison': 'en_cours'}
              : item;
        }).toList();
      });
      await _startLocationSharing({
        ...delivery,
        'statut_livraison': 'en_cours',
      });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Acceptation impossible : $error')),
        );
    }
  }

  Future<void> _declineDelivery(Map<String, dynamic> delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refuser cette livraison ?'),
        content: const Text('Elle sera libérée et pourra être réattribuée.'),
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
    if (confirmed != true) return;
    try {
      await _supabase.rpc(
        'decline_assigned_delivery',
        params: {'p_id_livraison': delivery['id_livraison']},
      );
      if (!mounted) return;
      setState(
        () => _assignedDeliveries.removeWhere(
          (item) => item['id_livraison'] == delivery['id_livraison'],
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Livraison libérée.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Refus impossible : $error')));
    }
  }

  Future<void> _showOtpDialog(Map<String, dynamic> delivery) async {
    final controller = TextEditingController();
    var isSubmitting = false;
    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Confirmer la livraison'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Code OTP du client',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (controller.text.trim().length != 6) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        final verified = await _supabase.rpc(
                          'verify_delivery_otp',
                          params: {
                            'p_id_livraison': delivery['id_livraison'],
                            'p_code': controller.text.trim(),
                          },
                        );
                        if (verified != true)
                          throw Exception('Code OTP invalide.');
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Code non validé : $error')),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (verified != true || !mounted) return;

    final id = delivery['id_livraison'].toString();
    setState(() {
      _selectedDeliveryTab = 2;
      _assignedDeliveries = _assignedDeliveries.map((item) {
        return item['id_livraison'].toString() == id
            ? {...item, 'statut_livraison': 'livree'}
            : item;
      }).toList();
      _activeDeliveryId = null;
    });
    await _stopLocationSharing();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Livraison confirmée.')));
  }

  void _showDeliveryDetails(Map<String, dynamic> delivery) {
    final order = _orderForDelivery(delivery);
    final lines = order['lignes_commande'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColor.background,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
          children: [
            Text(
              'Commande #${delivery['id_commande']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _deliveryInfoRow(
              'Statut',
              delivery['statut_livraison']?.toString() ?? 'Attribuée',
            ),
            _deliveryInfoRow(
              'Destination',
              delivery['adresse_destination']?.toString() ?? 'À confirmer',
            ),
            _deliveryInfoRow(
              'Paiement',
              order['mode_paiement']?.toString() ?? 'À confirmer',
            ),
            _deliveryInfoRow(
              'Total',
              order['montant_total'] == null
                  ? 'À confirmer'
                  : formatPrice(order['montant_total']),
            ),
            const SizedBox(height: 14),
            const Text(
              'Articles',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (lines is List && lines.isNotEmpty)
              ...lines.map((line) {
                final product = line is Map ? line['produits'] : null;
                final name = product is Map
                    ? product['nom_produit']?.toString() ?? 'Produit'
                    : 'Produit';
                final quantity = line is Map
                    ? (line['quantite'] as num?)?.toInt() ?? 1
                    : 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('$name × $quantity'),
                );
              })
            else
              const Text('Détail des articles indisponible.'),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMap(Map<String, dynamic> deliveryData) {
    final deliveryId = deliveryData['id_livraison']?.toString();
    final rawLatitude =
        deliveryData['latitude_destination'] ??
        widget.extraData?['latitude_destination'];
    final rawLongitude =
        deliveryData['longitude_destination'] ??
        widget.extraData?['longitude_destination'];
    final destination = rawLatitude is num && rawLongitude is num
        ? LatLng(rawLatitude.toDouble(), rawLongitude.toDouble())
        : null;

    if (deliveryId == null) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Aucune livraison attribuée à cette commande pour le moment.',
          ),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getCourierPositionStream(deliveryId),
      builder: (context, snapshot) {
        final positionRows = snapshot.data ?? [];
        LatLng? courierPosition;
        if (positionRows.isNotEmpty) {
          final row = positionRows.first;
          final latitude = row['latitude'];
          final longitude = row['longitude'];
          if (latitude is num && longitude is num) {
            courierPosition = LatLng(latitude.toDouble(), longitude.toDouble());
          }
        }

        final center =
            destination ?? courierPosition ?? const LatLng(4.0511, 9.7679);
        final markers = <Marker>[
          if (destination != null)
            Marker(
              point: destination,
              width: 42,
              height: 42,
              child: const Icon(
                Icons.location_pin,
                size: 40,
                color: Colors.red,
              ),
            ),
          if (courierPosition != null)
            Marker(
              point: courierPosition,
              width: 46,
              height: 46,
              child: const Icon(
                Icons.delivery_dining,
                size: 38,
                color: AppColor.primary,
              ),
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 270,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 14),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.asamesse_app',
                    ),
                    MarkerLayer(markers: markers),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              courierPosition == null
                  ? 'En attente de la position du livreur.'
                  : 'Position du livreur mise à jour en temps réel.',
              style: const TextStyle(color: AppColor.textSecondary),
            ),
            if (_isCourier) ...[
              const SizedBox(height: 10),
              if (_locationError != null)
                Text(
                  _locationError!,
                  style: const TextStyle(color: Colors.red),
                ),
              OutlinedButton.icon(
                onPressed: _isSharingLocation
                    ? _stopLocationSharing
                    : () => _startLocationSharing(deliveryData),
                icon: Icon(
                  _isSharingLocation
                      ? Icons.location_disabled
                      : Icons.my_location,
                ),
                label: Text(
                  _isSharingLocation
                      ? 'Arrêter le partage GPS'
                      : 'Partager ma position',
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatDeliveryDate(dynamic value) {
    if (value == null) return 'En attente';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return 'En attente';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isCourier && widget.missionsOnly && _activeDeliveryId == null) {
      return _buildCourierDeliveryPicker();
    }
    if (_isCourier && _activeDeliveryId == null && widget.mapOnly) {
      return Scaffold(
        backgroundColor: AppColor.background,
        appBar: AppBar(title: const Text('Map')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 42,
                  color: AppColor.primary,
                ),
                const SizedBox(height: 12),
                const Text('Aucune mission assignée à suivre.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.go('/delivery/missions'),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Voir mes missions'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_isCourier && _activeDeliveryId == null)
      return _buildCourierDeliveryPicker();
    if (_effectiveIdCommande.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Aucune commande à suivre.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColor.background, // Exact rose poudré #F9EAE5
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColor.textPrimary,
            size: 24,
          ),
          onPressed: () {
            if (_isCourier) {
              _stopLocationSharing();
              setState(() => _activeDeliveryId = null);
              return;
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/orders');
            }
          },
        ),
        title: const Text(
          "Suivi de Livraison",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
            color: AppColor.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _getDeliveryStream(),
        builder: (context, snapshot) {
          final deliveryData = snapshot.data ?? {};
          final statut =
              (deliveryData['statut_livraison'] ??
                      widget.extraData?['statut'] ??
                      'en_attente')
                  .toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carte Principale avec estimation
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColor.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: AppColor.primary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Arrivée estimée",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColor.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isCourier
                            ? 'Partage GPS désactivé'
                            : 'Statut : $statut',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColor.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Commande #$_effectiveIdCommande",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColor.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildLiveMap(deliveryData),

                const SizedBox(height: 20),

                // Étapes de suivi (Timeline pure)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Progression de la livraison",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColor.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTimelineStep(
                        icon: Icons.check_circle_rounded,
                        title: "Commande confirmée",
                        time: _formatDeliveryDate(
                          deliveryData['date_attribution'],
                        ),
                        isCompleted: deliveryData['id_livreur'] != null,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        icon: Icons.inventory_2_rounded,
                        title: "Préparée par le vendeur",
                        time: "Selon le statut vendeur",
                        isCompleted: statut.toLowerCase().contains('prepar'),
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        icon: Icons.delivery_dining_rounded,
                        title: "En cours d'acheminement",
                        time: _isSharingLocation
                            ? 'Position partagée'
                            : 'En attente',
                        isCompleted:
                            statut.toLowerCase().contains('cours') ||
                            statut.toLowerCase().contains('route'),
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        icon: Icons.home_rounded,
                        title: "Livrée à domicile",
                        time: "En attente",
                        isCompleted: _isDeliveryCompleted(statut),
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Carte Détail Livreur / Contact
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColor.primarySoft,
                        child: const Icon(
                          Icons.person,
                          color: AppColor.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Livreur Partenaire A'samesse",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColor.textPrimary,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              "Véhicule de livraison Express • Douala",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColor.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColor.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          color: AppColor.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String time,
    required bool isCompleted,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? AppColor.primary : AppColor.divider,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isCompleted ? Colors.white : Colors.grey,
                size: 16,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: isCompleted ? AppColor.primary : AppColor.divider,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
                  color: isCompleted
                      ? AppColor.textPrimary
                      : AppColor.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isCompleted ? AppColor.primary : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
