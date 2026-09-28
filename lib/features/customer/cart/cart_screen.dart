import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_color.dart';

class CartScreen extends StatefulWidget {
  final Map<String, dynamic>? extraData;

  const CartScreen({super.key, this.extraData});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _supabase = Supabase.instance.client;
  int deliveryMode = 0; // 0: Express, 1: Standard
  bool _isCheckingOut = false;

  // Charger le panier et les lignes de panier associées au produit
  Future<List<Map<String, dynamic>>> _fetchCartItems() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final panier = await _supabase
          .from('paniers')
          .select('id_panier')
          .eq('id_acheteur', userId)
          .maybeSingle();

      if (panier == null) return [];

      final idPanier = panier['id_panier'];

      final response = await _supabase
          .from('lignes_panier')
          .select('*, produits(*)')
          .eq('id_panier', idPanier);

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // Mettre à jour la quantité dans la table lignes_panier
  Future<void> _updateQuantity(dynamic lineId, int currentQty, int delta) async {
    final newQty = currentQty + delta;
    if (newQty <= 0) {
      await _supabase.from('lignes_panier').delete().eq('id', lineId);
    } else {
      await _supabase.from('lignes_panier').update({'quantite': newQty}).eq('id', lineId);
    }
    setState(() {});
  }

  Future<void> _checkout(double totalAmount, List<Map<String, dynamic>> items) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    setState(() => _isCheckingOut = true);

    try {
      final orderRes = await _supabase
          .from('commandes')
          .insert({
            'id_acheteur': user.id,
            'montant_total': totalAmount,
            'statut': 'en_cours',
            'date_commande': DateTime.now().toIso8601String(),
          })
          .select('id_commande')
          .single();

      final idCommande = orderRes['id_commande'];

      // Vider le panier
      final panier = await _supabase
          .from('paniers')
          .select('id_panier')
          .eq('id_acheteur', user.id)
          .maybeSingle();

      if (panier != null) {
        await _supabase.from('lignes_panier').delete().eq('id_panier', panier['id_panier']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Commande validée avec succès !"),
            backgroundColor: Color(0xFF1E1E1E),
          ),
        );
        // Rediriger vers le suivi de commande en passant state.extra
        context.go('/orders', extra: {
          'id_commande': idCommande,
          'montant_total': totalAmount,
          'statut': 'en_cours',
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la commande: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;

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
              context.go('/home');
            }
          },
        ),
        title: const Text(
          "Mon Panier",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
            color: AppColor.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: userId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded, size: 40, color: AppColor.primary),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Connectez-vous pour voir votre panier",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => context.go('/login'),
                      child: const Text("Se connecter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchCartItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColor.primary));
                }

                final cartItems = snapshot.data ?? [];

                if (cartItems.isEmpty) {
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
                            child: const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColor.primary),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            "Votre panier est vide",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Découvrez nos dernières nouveautés et ajoutez vos articles coups de cœur.",
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
                            child: const Text("Explorer les articles", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Calcul dynamique des prix
                double subtotal = 0;
                for (var item in cartItems) {
                  final produit = item['produits'] ?? {};
                  final double price = (produit['prix'] ?? produit['price'] ?? 0).toDouble();
                  final int qty = (item['quantite'] ?? 1) as int;
                  subtotal += price * qty;
                }

                double deliveryFee = deliveryMode == 0 ? 1500.0 : 0.0;
                double total = subtotal + deliveryFee;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Mes Articles",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                          ),
                          Text(
                            "${cartItems.length} article(s)",
                            style: const TextStyle(color: Color(0xFF757575), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Liste dynamique des lignes du panier
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildCartItem(cartItems[index]);
                        },
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        "Mode de Livraison",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // Mode de livraison (Express vs Standard)
                      Row(
                        children: [
                          Expanded(
                            child: _buildDeliveryOption(
                              index: 0,
                              title: "Express",
                              subtitle: "24h à 48h",
                              price: "1 500 FCFA",
                              icon: Icons.bolt_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDeliveryOption(
                              index: 1,
                              title: "Standard",
                              subtitle: "3-5 jours",
                              price: "Gratuit",
                              icon: Icons.local_shipping_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Récapitulatif Prix (Carte Blanche Pure)
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
                        child: Column(
                          children: [
                            _buildSummaryRow("Sous-total", "${subtotal.toStringAsFixed(0)} FCFA"),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              "Frais de livraison",
                              deliveryFee == 0 ? "Gratuit" : "${deliveryFee.toStringAsFixed(0)} FCFA",
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Total à payer",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                                ),
                                Text(
                                  "${total.toStringAsFixed(0)} FCFA",
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: AppColor.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isCheckingOut ? null : () => _checkout(total, cartItems),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary, // Exact bordeaux #8B2635
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: _isCheckingOut
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Passer la commande",
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final lineId = item['id'];
    final produit = item['produits'] ?? {};
    final String name = produit['nom_produit'] ?? produit['nom'] ?? 'Produit';
    final double price = (produit['prix'] ?? produit['price'] ?? 0).toDouble();
    final int qty = (item['quantite'] ?? 1) as int;
    final String? imageUrl = produit['images'] ?? produit['image_url'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: const Color(0xFFF9F7F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  )
                : const Icon(Icons.headphones_rounded, size: 32, color: Color(0xFFD67373)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColor.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  "${price.toStringAsFixed(0)} FCFA",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColor.primary, fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _updateQuantity(lineId, qty, -1),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.grey),
              ),
              Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              IconButton(
                onPressed: () => _updateQuantity(lineId, qty, 1),
                icon: const Icon(Icons.add_circle_rounded, size: 20, color: AppColor.primary),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDeliveryOption({
    required int index,
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
  }) {
    final isSelected = deliveryMode == index;
    return GestureDetector(
      onTap: () => setState(() => deliveryMode = index),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColor.primary : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? AppColor.primary : Colors.grey, size: 22),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColor.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColor.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColor.textPrimary, fontSize: 13)),
      ],
    );
  }
}