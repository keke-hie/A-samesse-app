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
      case 'en_attente_paiement':
        return const Color(0xFF9E6A16);
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
      case 'en_attente_paiement':
        return 'En attente de paiement';
      case 'annule':
      case 'annulé':
        return 'Annulé';
      default:
        return 'Préparation';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOrderLines(dynamic orderId) async {
    final response = await _supabase
        .from('lignes_commande')
      .select('*, produits(nom_produit, image_url)')
        .eq('id_commande', orderId);
    return List<Map<String, dynamic>>.from(response);
  }

  int _statusStep(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('paiement')) return -2;
    if (normalized.contains('annul')) return -1;
    if (normalized.contains('livraison') || normalized.contains('cours')) return 2;
    if (normalized == 'livre' || normalized == 'livré') return 3;
    if (normalized.contains('prepar')) return 1;
    return 0;
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final orderId = order['id_commande'] ?? order['id'];
    final status = (order['statut'] ?? 'en_attente').toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColor.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Commande #${orderId.toString().length > 8 ? orderId.toString().substring(0, 8).toUpperCase() : orderId.toString().toUpperCase()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(_formatStatusLabel(status), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.w700)),
              const SizedBox(height: 22),
              _buildStatusProgress(status),
              const SizedBox(height: 24),
              const Text('Articles commandés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary)),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchOrderLines(orderId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator(color: AppColor.primary)),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Text('Impossible de charger le détail des articles pour le moment.');
                  }
                  final lines = snapshot.data ?? [];
                  if (lines.isEmpty) return const Text('Aucun article détaillé pour cette commande.');

                  return Column(
                    children: lines.map((line) {
                      final product = line['produits'] as Map<String, dynamic>? ?? {};
                      final name = product['nom_produit'] ?? 'Produit';
                      final quantity = line['quantite'] ?? 1;
                      final rawPrice = line['prix_unitaire'] ?? 0;
                      final price = rawPrice is num ? rawPrice.toDouble() : double.tryParse(rawPrice.toString()) ?? 0;
                      final image = product['image_url'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(color: const Color(0xFFF9F7F5), borderRadius: BorderRadius.circular(12)),
                              child: image is String && image.isNotEmpty
                                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(image, fit: BoxFit.cover))
                                  : const Icon(Icons.shopping_bag_outlined, color: AppColor.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text('$name  ×  $quantity', style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text('${price.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColor.primary)),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const Divider(height: 26),
              _buildDetailRow('Total', '${_formatAmount(order['montant_total'] ?? order['total'])} FCFA'),
              if (order['mode_paiement'] != null) ...[
                const SizedBox(height: 10),
                _buildDetailRow('Paiement', order['mode_paiement'].toString().replaceAll('_', ' ')),
              ],
              if (order['date_commande'] != null) ...[
                const SizedBox(height: 10),
                _buildDetailRow('Date', _formatDate(order['date_commande'].toString())),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusProgress(String status) {
    final currentStep = _statusStep(status);
    if (currentStep == -2) {
      return const Text(
        'La commande sera confirmée après validation du paiement.',
        style: TextStyle(color: Color(0xFF9E6A16), fontWeight: FontWeight.w600),
      );
    }
    if (currentStep < 0) {
      return const Text('Cette commande a été annulée.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600));
    }
    const labels = ['Confirmée', 'Préparation', 'En livraison', 'Livrée'];
    return Column(
      children: List.generate(labels.length, (index) {
        final isComplete = index <= currentStep;
        return Row(
          children: [
            Column(
              children: [
                Icon(isComplete ? Icons.check_circle : Icons.radio_button_unchecked, size: 20,
                    color: isComplete ? AppColor.primary : Colors.black26),
                if (index < labels.length - 1)
                  Container(width: 2, height: 24, color: index < currentStep ? AppColor.primary : Colors.black12),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(labels[index], style: TextStyle(color: isComplete ? AppColor.textPrimary : Colors.black45, fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal)),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF757575))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColor.textPrimary)),
      ],
    );
  }

  String _formatAmount(dynamic value) {
    if (value is num) return value.toStringAsFixed(0);
    return (double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(0);
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
                onTap: () => _showOrderDetails(order),
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