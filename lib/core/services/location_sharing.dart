import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'delivery_service.dart';

/// Partage de la position du livreur pendant une livraison.
///
/// Instance unique : le partage continue quand le livreur passe de l'onglet
/// Missions à l'onglet Carte.
class LocationSharing extends ChangeNotifier {
  LocationSharing._();

  static final LocationSharing instance = LocationSharing._();

  final _deliveryService = DeliveryService();
  StreamSubscription<Position>? _subscription;
  String? _deliveryId;
  String? _error;

  String? get deliveryId => _deliveryId;
  String? get error => _error;
  bool isSharing(String deliveryId) =>
      _subscription != null && _deliveryId == deliveryId;

  Future<void> start(String deliveryId) async {
    final courierId = Supabase.instance.client.auth.currentUser?.id;
    if (courierId == null) return;
    _error = null;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Active la localisation de ton téléphone.');
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

      await _subscription?.cancel();
      _deliveryId = deliveryId;
      _subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (position) => _deliveryService
                .publishPosition(
                  deliveryId: deliveryId,
                  courierId: courierId,
                  latitude: position.latitude,
                  longitude: position.longitude,
                )
                .catchError(
                  (_) => _setError('Impossible de transmettre la position.'),
                ),
            onError: (_) => _setError('La localisation a été interrompue.'),
          );
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _deliveryId = null;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
