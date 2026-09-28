import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String get _effectiveIdCommande {
    return widget.idCommande ??
        widget.extraData?['id_commande']?.toString() ??
        widget.extraData?['id']?.toString() ??
        'CMD-1082';
  }

  Stream<Map<String, dynamic>> _getDeliveryStream() {
    return Supabase.instance.client
        .from('livraisons')
        .stream(primaryKey: ['id'])
        .eq('id_commande', _effectiveIdCommande)
        .map((rows) => rows.isNotEmpty ? rows.first : <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
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
          final statut = (deliveryData['statut'] ?? widget.extraData?['statut'] ?? 'en_cours').toString();

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
                      const Text(
                        "Aujourd'hui, 17:30",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
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
                        time: "10:15",
                        isCompleted: true,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        icon: Icons.inventory_2_rounded,
                        title: "Préparée par le vendeur",
                        time: "12:45",
                        isCompleted: true,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        icon: Icons.delivery_dining_rounded,
                        title: "En cours d'acheminement",
                        time: "14:20",
                        isCompleted: statut.toLowerCase().contains('cours'),
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