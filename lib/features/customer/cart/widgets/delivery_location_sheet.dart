import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_color.dart';

class DeliveryLocation {
  const DeliveryLocation({required this.address, required this.point});

  final String address;
  final LatLng point;
}

/// Feuille de choix de l'adresse de livraison : repère texte + point sur la carte.
Future<DeliveryLocation?> showDeliveryLocationSheet(
  BuildContext context, {
  DeliveryLocation? initial,
}) {
  return showModalBottomSheet<DeliveryLocation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColor.surface,
    builder: (_) => _DeliveryLocationSheet(initial: initial),
  );
}

class _DeliveryLocationSheet extends StatefulWidget {
  const _DeliveryLocationSheet({this.initial});

  final DeliveryLocation? initial;

  @override
  State<_DeliveryLocationSheet> createState() => _DeliveryLocationSheetState();
}

class _DeliveryLocationSheetState extends State<_DeliveryLocationSheet> {
  // Douala par défaut.
  static const _defaultCenter = LatLng(4.0511, 9.7679);

  late final _addressController = TextEditingController(
    text: widget.initial?.address,
  );
  late LatLng? _point = widget.initial?.point;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _point != null && _addressController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Adresse de livraison',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Quartier, rue, point de repère',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Touche la carte à l’endroit exact de la livraison.',
                style: TextStyle(color: AppColor.textSecondary),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _point ?? _defaultCenter,
                      initialZoom: 14,
                      onTap: (_, point) => setState(() => _point = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.asamesse.app',
                      ),
                      if (_point != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _point!,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_pin,
                                color: AppColor.primary,
                                size: 42,
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _canConfirm
                    ? () => Navigator.pop(
                        context,
                        DeliveryLocation(
                          address: _addressController.text.trim(),
                          point: _point!,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  _point == null
                      ? 'Place le point sur la carte'
                      : 'Confirmer cette adresse',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
