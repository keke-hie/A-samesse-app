import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/services/order_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';

class CartScreen extends StatefulWidget {
  final Map<String, dynamic>? extraData;

  const CartScreen({super.key, this.extraData});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _supabase = Supabase.instance.client;
  final _orderService = OrderService();
  int deliveryMode = 0;
  String _selectedPayment = 'orange_money';
  bool _isCheckingOut = false;
  final Set<String> _selectedLineIds = {};
  final TextEditingController _deliveryAddressController = TextEditingController();
  LatLng? _deliveryLocation;
  late Future<List<Map<String, dynamic>>> _cartItemsFuture;
  bool _selectionInitialized = false;

  @override
  void initState() {
    super.initState();
    _cartItemsFuture = _fetchCartItems();
  }

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    super.dispose();
  }

  Future<void> _chooseDeliveryLocation() async {
    var selectedLocation = _deliveryLocation ?? const LatLng(4.0511, 9.7679);
    var hasSelectedPin = _deliveryLocation != null;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.88,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adresse de livraison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _deliveryAddressController,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Adresse ou repère',
                      hintText: 'Ex. quartier, rue, point de repère',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Déplace la carte puis touche l’emplacement exact.'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: selectedLocation,
                          initialZoom: 14,
                          onTap: (_, point) {
                            setSheetState(() {
                              selectedLocation = point;
                              hasSelectedPin = true;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.asamesse.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: selectedLocation,
                                width: 44,
                                height: 44,
                                child: const Icon(Icons.location_pin, color: AppColor.primary, size: 42),
                              ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('GPS : ${selectedLocation.latitude.toStringAsFixed(5)}, ${selectedLocation.longitude.toStringAsFixed(5)}'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: hasSelectedPin && _deliveryAddressController.text.trim().isNotEmpty
                          ? () => Navigator.pop(sheetContext, true)
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmer cette adresse'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() => _deliveryLocation = selectedLocation);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCartItems() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final panier = await _supabase
          .from('paniers')
          .select('id_panier')
          .eq('id_acheteur', userId)
          .maybeSingle();

      if (panier == null) {
        _selectionInitialized = true;
        return [];
      }

      final response = await _supabase
          .from('lignes_panier')
          .select('*, produits(*)')
          .eq('id_panier', panier['id_panier']);

      final items = List<Map<String, dynamic>>.from(response);
      if (!_selectionInitialized) {
        _selectedLineIds.addAll(items.map((item) => item['id_ligne'].toString()));
        _selectionInitialized = true;
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  void _refreshCartItems() {
    setState(() => _cartItemsFuture = _fetchCartItems());
  }

  void _toggleLineSelection(dynamic lineId) {
    final key = lineId.toString();
    setState(() {
      if (_selectedLineIds.contains(key)) {
        _selectedLineIds.remove(key);
      } else {
        _selectedLineIds.add(key);
      }
    });
  }

  void _toggleSelectAll(List<Map<String, dynamic>> items) {
    setState(() {
      if (_selectedLineIds.length == items.length) {
        _selectedLineIds.clear();
      } else {
        _selectedLineIds
          ..clear()
          ..addAll(items.map((e) => e['id_ligne'].toString()));
      }
    });
  }

  Future<void> _updateQuantity(dynamic lineId, int currentQty, int delta) async {
    final newQty = currentQty + delta;
    if (newQty <= 0) {
      await _supabase.from('lignes_panier').delete().eq('id_ligne', lineId);
      _selectedLineIds.remove(lineId.toString());
    } else {
      await _supabase.from('lignes_panier').update({'quantite': newQty}).eq('id_ligne', lineId);
    }
    if (mounted) _refreshCartItems();
  }

  Future<void> _removeSelected() async {
    if (_selectedLineIds.isEmpty) return;

    for (final id in List<String>.from(_selectedLineIds)) {
      await _supabase.from('lignes_panier').delete().eq('id_ligne', id);
    }

    if (mounted) {
      setState(() {
        _selectedLineIds.clear();
        _cartItemsFuture = _fetchCartItems();
      });
    }
  }

  Future<void> _checkout(List<Map<String, dynamic>> items) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    final selectedIds = items
        .map((item) => item['id_ligne'].toString())
        .where(_selectedLineIds.contains)
        .toList();
    if (selectedIds.isEmpty) {
      _showMessage('Sélectionnez au moins un article pour valider le panier.');
      return;
    }
    if (_deliveryLocation == null || _deliveryAddressController.text.trim().isEmpty) {
      _showMessage('Choisis le point et saisis l’adresse de livraison.');
      return;
    }

    setState(() => _isCheckingOut = true);
    try {
      // Prix, stock et total sont recalculés et réservés côté serveur.
      final orderId = await _orderService.createOrder(
        cartLineIds: selectedIds,
        paymentMethod: _selectedPayment,
        deliveryMode: deliveryMode == 0 ? 'express' : 'standard',
        address: _deliveryAddressController.text.trim(),
        latitude: _deliveryLocation!.latitude,
        longitude: _deliveryLocation!.longitude,
      );
      if (!mounted) return;
      _selectedLineIds.removeAll(selectedIds);
      _showMessage('Commande ${shortOrderRef(orderId)} enregistrée. Le stock est réservé.');
      context.go('/orders');
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
      _refreshCartItems();
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColor.textPrimary, size: 24),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text(
          'Mon panier',
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
          ? _buildGuestState()
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _cartItemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColor.primary));
                }

                final cartItems = snapshot.data ?? [];
                final selectedItems = cartItems
                  .where((item) => _selectedLineIds.contains(item['id_ligne'].toString()))
                    .toList();

                if (cartItems.isEmpty) {
                  return _buildEmptyCartState();
                }

                double subtotal = 0;
                for (final item in selectedItems) {
                  final produit = item['produits'] ?? {};
                  final price = (produit['prix'] ?? 0) is num
                      ? (produit['prix'] ?? 0).toDouble()
                      : (double.tryParse((produit['prix'] ?? 0).toString()) ?? 0.0);
                  final qty = (item['quantite'] ?? 1) as int;
                  subtotal += price * qty;
                }

                final double deliveryFee = deliveryMode == 0
                    ? OrderService.expressDeliveryFee.toDouble()
                    : 0.0;
                final double total = subtotal + deliveryFee;

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
                            'Mes articles',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                          ),
                          Text(
                            '${selectedItems.length}/${cartItems.length} sélectionné(s)',
                            style: const TextStyle(fontSize: 12, color: AppColor.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: selectedItems.length == cartItems.length && cartItems.isNotEmpty,
                            activeColor: AppColor.primary,
                            onChanged: (_) => _toggleSelectAll(cartItems),
                          ),
                          const Expanded(child: Text('Tout sélectionner')),
                          if (_selectedLineIds.isNotEmpty)
                            TextButton(
                              onPressed: _removeSelected,
                              child: const Text('Supprimer sélection', style: TextStyle(color: AppColor.primary)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                        'Adresse de livraison',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _chooseDeliveryLocation,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          _deliveryLocation == null
                              ? 'Choisir sur la carte'
                              : '${_deliveryAddressController.text} · ${_deliveryLocation!.latitude.toStringAsFixed(4)}, ${_deliveryLocation!.longitude.toStringAsFixed(4)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Paiement',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentMethod(
                              key: 'orange_money',
                              label: 'Orange Money',
                              icon: Icons.phone_android_rounded,
                              color: const Color(0xFFFFA000),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPaymentMethod(
                              key: 'mobile_money',
                              label: 'Mobile Money',
                              icon: Icons.smartphone_rounded,
                              color: const Color(0xFF3F51B5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPaymentMethod(
                              key: 'card',
                              label: 'Carte',
                              icon: Icons.credit_card_rounded,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Mode de livraison',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDeliveryOption(
                              index: 0,
                              title: 'Express',
                              subtitle: '24h à 48h',
                              price: '1 500 FCFA',
                              icon: Icons.bolt_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDeliveryOption(
                              index: 1,
                              title: 'Standard',
                              subtitle: '3-5 jours',
                              price: 'Gratuit',
                              icon: Icons.local_shipping_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
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
                            _buildSummaryRow('Sous-total', '${subtotal.toStringAsFixed(0)} FCFA'),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Frais de livraison', deliveryFee == 0 ? 'Gratuit' : '${deliveryFee.toStringAsFixed(0)} FCFA'),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total à payer',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
                                ),
                                Text(
                                  '${total.toStringAsFixed(0)} FCFA',
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
                          onPressed: _isCheckingOut ? null : () => _checkout(cartItems),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: _isCheckingOut
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Valider le panier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  Widget _buildGuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, size: 40, color: AppColor.primary),
            ),
            const SizedBox(height: 18),
            const Text(
              'Connectez-vous pour voir votre panier',
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
              child: const Text('Se connecter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCartState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColor.primary),
            ),
            const SizedBox(height: 18),
            const Text(
              'Votre panier est vide',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Découvrez nos dernières nouveautés et ajoutez vos articles.',
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
              child: const Text('Explorer les articles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod({
    required String key,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedPayment == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(color: isSelected ? color : AppColor.border, width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColor.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : AppColor.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final lineId = item['id_ligne'];
    final produit = item['produits'] ?? {};
    final String name = produit['nom_produit'] ?? produit['nom'] ?? 'Produit';
    final double price = (produit['prix'] ?? 0) is num
      ? (produit['prix'] ?? 0).toDouble()
      : (double.tryParse((produit['prix'] ?? 0).toString()) ?? 0.0);
    final int qty = (item['quantite'] ?? 1) as int;
    final String? imageUrl = produit['image_url'] ?? produit['images'];
    final rawStock = produit['stock'];
    final bool inStock = rawStock is num ? rawStock.toInt() > 0 : true;
    final variants = [
      if ((item['couleur'] as String?)?.trim().isNotEmpty ?? false) 'Couleur : ${item['couleur']}',
      if ((item['taille'] as String?)?.trim().isNotEmpty ?? false) 'Taille : ${item['taille']}',
    ];

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
          Checkbox(
            value: _selectedLineIds.contains(lineId.toString()),
            activeColor: AppColor.primary,
            onChanged: (_) => _toggleLineSelection(lineId),
          ),
          SizedBox(
            width: 78,
            height: 78,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _cartImagePlaceholder())
                  : _cartImagePlaceholder(),
            ),
          ),
          const SizedBox(width: 10),
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
                  '${price.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColor.primary, fontSize: 13),
                ),
                if (variants.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    variants.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppColor.textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  inStock ? 'En stock' : 'Rupture de stock',
                  style: TextStyle(
                    fontSize: 11,
                    color: inStock ? const Color(0xFF2E7D32) : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => _updateQuantity(lineId, qty, -1),
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColor.primary),
                    ),
                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                      padding: EdgeInsets.zero,
                      onPressed: rawStock is num && qty >= rawStock.toInt() ? null : () => _updateQuantity(lineId, qty, 1),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColor.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartImagePlaceholder() {
    return const ColoredBox(
      color: AppColor.primarySoft,
      child: Center(child: Icon(Icons.image_not_supported_outlined, color: AppColor.primary)),
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
          border: Border.all(color: isSelected ? AppColor.primary : Colors.transparent, width: 1.5),
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