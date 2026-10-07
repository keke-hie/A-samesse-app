import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/delivery_service.dart';

/// Carte OpenStreetMap avec la destination et la position du livreur en
/// temps réel (table `positions_livreurs`).
class LiveDeliveryMap extends StatelessWidget {
  const LiveDeliveryMap({super.key, required this.delivery});

  final Map<String, dynamic> delivery;

  // Douala par défaut si aucune coordonnée n'est connue.
  static const _fallbackCenter = LatLng(4.0511, 9.7679);

  @override
  Widget build(BuildContext context) {
    final latitude = delivery['latitude_destination'];
    final longitude = delivery['longitude_destination'];
    final destination = latitude is num && longitude is num
        ? LatLng(latitude.toDouble(), longitude.toDouble())
        : null;

    return StreamBuilder<LatLng?>(
      stream: DeliveryService().watchCourierPosition(
        delivery['id_livraison'].toString(),
      ),
      builder: (context, snapshot) {
        final courier = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 300,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: courier ?? destination ?? _fallbackCenter,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.asamesse.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (destination != null)
                          Marker(
                            point: destination,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_pin,
                              size: 42,
                              color: AppColor.primary,
                            ),
                          ),
                        if (courier != null)
                          Marker(
                            point: courier,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColor.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColor.primary,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.delivery_dining,
                                color: AppColor.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
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
            Row(
              children: [
                Icon(
                  courier == null
                      ? Icons.gps_off_rounded
                      : Icons.gps_fixed_rounded,
                  size: 16,
                  color: courier == null
                      ? AppColor.textMuted
                      : AppColor.success,
                ),
                const SizedBox(width: 6),
                Text(
                  courier == null
                      ? 'Position du livreur pas encore disponible'
                      : 'Position du livreur en temps réel',
                  style: const TextStyle(
                    color: AppColor.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
