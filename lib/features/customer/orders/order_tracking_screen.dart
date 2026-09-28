import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic>? orderData;

  const OrderTrackingScreen({super.key, this.orderData});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _supabase = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> _getOrdersStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('commandes')
        .stream(primaryKey: ['id_commande'])
        .eq('id_acheteur', userId)
        .order('date_commande', ascending: false);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'livre':
      case 'livré':
        return const Color(0xFF2E7D32);
      case 'en_cours':
      case 'en cours':
        return AppColor.primary;
      case 'annule':
      case 'annulé':
        return Colors.red;
      default:
        return const Color(0xFFC5A880);
    }
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'livre':
      case 'livré':
        return 'Livré';
      case 'en_cours':
      case 'en cours':
        return 'En livraison';
      case 'annule':
      case 'annulé':
        return 'Annulé';
      default:
        return 'Préparation';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background, // Exact rose poudré #F9EAE5
      appBar: AppBar(
        title: const Text(
          "Mes Commandes",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
            color: AppColor.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColor.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Une erreur est survenue : ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];

          // Si aucune commande dans Supabase mais qu'on a un orderData passé par extra (ex: test ou checkout immédiat)
          final displayOrders = orders.isNotEmpty
              ? orders
              : (widget.orderData != null ? [widget.orderData!] : <Map<String, dynamic>>[]);

          if (displayOrders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColor.primary),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Aucune commande en cours",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Vos commandes et leur suivi en direct apparaîtront ici dès votre premier achat.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => context.go('/home'),
                      child: const Text("Faire des achats", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
            physics: const BouncingScrollPhysics(),
            itemCount: displayOrders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final order = displayOrders[index];
              final String commandeId = (order['id_commande'] ?? order['id'] ?? index).toString();
              final double montantTotal = ((order['montant_total'] ?? order['total'] ?? 0) as num).toDouble();
              final String statut = (order['statut'] ?? 'en_cours').toString();

              return GestureDetector(
                onTap: () {
                  // Navigation vers delivery/map avec transmission du state.extra
                  context.go('/delivery/map', extra: order);
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
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
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F7F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: AppColor.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Commande #${commandeId.length > 8 ? commandeId.substring(0, 8).toUpperCase() : commandeId.toUpperCase()}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColor.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getStatusColor(statut).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _formatStatusLabel(statut),
                                style: TextStyle(
                                  color: _getStatusColor(statut),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${montantTotal.toStringAsFixed(0)} FCFA",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColor.primary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Text(
                                "Suivre",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF757575)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}