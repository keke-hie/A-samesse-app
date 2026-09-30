import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_color.dart';

class DeliveryMapScreen extends StatefulWidget {
  final String? idCommande;
  final Map<String, dynamic>? extraData;

  const DeliveryMapScreen({super.key, this.idCommande, this.extraData});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  final _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionSubscription;
  String? _activeCommandeId;
  String? _activeDeliveryId;
  String? _userId;
  bool _isCourier = false;
  bool _isInitializing = true;
  bool _isSharingLocation = false;
  String? _locationError;
  List<Map<String, dynamic>> _assignedDeliveries = [];

  @override
  void initState() {
    super.initState();
    _userId = _supabase.auth.currentUser?.id;
    _activeCommandeId = widget.idCommande ?? widget.extraData?['id_commande']?.toString();
    _initializeDeliveryScreen();
  }

  Future<void> _initializeDeliveryScreen() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    try {
      final userRecord = await _supabase
          .from('utilisateurs')
          .select('role')
          .eq('id_utilisateur', userId)
          .maybeSingle();
      final role = userRecord?['role']?.toString().toLowerCase();
      if (role == 'livreur') {
        final response = await _supabase
            .from('livraisons')
            .select('id_livraison, id_commande, statut_livraison, adresse_destination')
            .eq('id_livreur', userId);
        final deliveries = List<Map<String, dynamic>>.from(response).where((delivery) {
          final status = (delivery['statut_livraison'] ?? '').toString().toLowerCase();
          return !status.contains('livree') && !status.contains('livrée') && !status.contains('annule');
        }).toList();

        if (mounted) {
          setState(() {
            _isCourier = true;
            _assignedDeliveries = deliveries;
            if (_activeCommandeId != null) {
              final matching = deliveries.where((item) => item['id_commande'].toString() == _activeCommandeId);
              if (matching.isNotEmpty) _activeDeliveryId = matching.first['id_livraison'].toString();
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _locationError = 'Impossible de charger les livraisons.');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
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
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Autorise la localisation pour partager ta position pendant la livraison.');
      }

      await _positionSubscription?.cancel();
      setState(() {
        _isSharingLocation = true;
      });

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (position) => _publishLocation(deliveryId, userId, position),
        onError: (_) {
          if (mounted) setState(() => _locationError = 'La localisation a été interrompue.');
        },
      );
    } catch (error) {
      if (mounted) setState(() => _locationError = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _publishLocation(String deliveryId, String userId, Position position) async {
    try {
      await _supabase.from('positions_livreurs').upsert({
        'id_livraison': deliveryId,
        'id_livreur': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'date_position': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id_livraison');
    } catch (_) {
      if (mounted) setState(() => _locationError = 'Impossible de transmettre la position.');
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
    super.dispose();
  }

  String get _effectiveIdCommande {
    return _activeCommandeId ?? widget.idCommande ?? widget.extraData?['id_commande']?.toString() ?? '';
  }

  Stream<Map<String, dynamic>> _getDeliveryStream() {
    return Supabase.instance.client
        .from('livraisons')
        .stream(primaryKey: ['id_livraison'])
        .eq('id_commande', _effectiveIdCommande)
        .map((rows) => rows.isNotEmpty ? rows.first : <String, dynamic>{});
  }

  Stream<List<Map<String, dynamic>>> _getCourierPositionStream(String deliveryId) {
    return _supabase
        .from('positions_livreurs')
        .stream(primaryKey: ['id_livraison'])
        .eq('id_livraison', deliveryId);
  }

  Widget _buildCourierDeliveryPicker() {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(title: const Text('Mes livraisons')),
      body: _assignedDeliveries.isEmpty
          ? const Center(child: Text('Aucune livraison active ne t’est attribuée.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _assignedDeliveries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final delivery = _assignedDeliveries[index];
                final deliveryId = delivery['id_livraison'].toString();
                final isSharing = _activeDeliveryId == deliveryId && _isSharingLocation;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.delivery_dining, color: AppColor.primary),
                    title: Text('Commande #${delivery['id_commande'].toString().substring(0, 8).toUpperCase()}'),
                    subtitle: Text('${delivery['adresse_destination'] ?? 'Destination à confirmer'}\n${delivery['statut_livraison'] ?? 'Attribuée'}'),
                    isThreeLine: true,
                    trailing: Icon(isSharing ? Icons.location_on : Icons.chevron_right),
                    onTap: () => _startLocationSharing(delivery),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLiveMap(Map<String, dynamic> deliveryData) {
    final deliveryId = deliveryData['id_livraison']?.toString();
    final rawLatitude = deliveryData['latitude_destination'] ?? widget.extraData?['latitude_destination'];
    final rawLongitude = deliveryData['longitude_destination'] ?? widget.extraData?['longitude_destination'];
    final destination = rawLatitude is num && rawLongitude is num
        ? LatLng(rawLatitude.toDouble(), rawLongitude.toDouble())
        : null;

    if (deliveryId == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Aucune livraison attribuée à cette commande pour le moment.')),
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

        final center = destination ?? courierPosition ?? const LatLng(4.0511, 9.7679);
        final markers = <Marker>[
          if (destination != null)
            Marker(
              point: destination,
              width: 42,
              height: 42,
              child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
            ),
          if (courierPosition != null)
            Marker(
              point: courierPosition,
              width: 46,
              height: 46,
              child: const Icon(Icons.delivery_dining, size: 38, color: AppColor.primary),
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
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.asamesse_app',
                    ),
                    MarkerLayer(markers: markers),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('OpenStreetMap contributors')],
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
              if (_locationError != null) Text(_locationError!, style: const TextStyle(color: Colors.red)),
              OutlinedButton.icon(
                onPressed: _isSharingLocation ? _stopLocationSharing : () => _startLocationSharing(deliveryData),
                icon: Icon(_isSharingLocation ? Icons.location_disabled : Icons.my_location),
                label: Text(_isSharingLocation ? 'Arrêter le partage GPS' : 'Partager ma position'),
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
    if (_isCourier && _activeDeliveryId == null) return _buildCourierDeliveryPicker();
    if (_effectiveIdCommande.isEmpty) {
      return const Scaffold(body: Center(child: Text('Aucune commande à suivre.')));
    }

    return Scaffold(
      backgroundColor: AppColor.background, // Exact rose poudré #F9EAE5
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColor.textPrimary, size: 24),
          onPressed: () {
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
          final statut = (deliveryData['statut_livraison'] ?? widget.extraData?['statut'] ?? 'en_attente').toString();

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
                        style: TextStyle(fontSize: 13, color: Color(0xFF757575), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isCourier ? 'Partage GPS désactivé' : 'Statut : $statut',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Commande #$_effectiveIdCommande",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColor.primary),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                      ),
                      const SizedBox(height: 20),
                      _buildTimelineStep(
                        icon: Icons.check_circle_rounded,
                        title: "Commande confirmée",
                        time: _formatDeliveryDate(deliveryData['date_attribution']),
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
                        time: _isSharingLocation ? 'Position partagée' : 'En attente',
                        isCompleted: statut.toLowerCase().contains('cours') || statut.toLowerCase().contains('route'),
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        icon: Icons.home_rounded,
                        title: "Livrée à domicile",
                        time: "En attente",
                        isCompleted: statut.toLowerCase().contains('livr'),
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
                        child: const Icon(Icons.person, color: AppColor.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Livreur Partenaire A'samesse",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColor.textPrimary),
                            ),
                            SizedBox(height: 3),
                            Text(
                              "Véhicule de livraison Express • Douala",
                              style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
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
                        child: const Icon(Icons.phone_rounded, color: AppColor.primary, size: 20),
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
                color: isCompleted ? AppColor.primary : const Color(0xFFF2F2F2),
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
                color: isCompleted ? AppColor.primary : const Color(0xFFF2F2F2),
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
                  color: isCompleted ? AppColor.textPrimary : const Color(0xFF9E9E9E),
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