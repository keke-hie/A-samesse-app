import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/order_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import 'widgets/cart_line_tile.dart';
import 'widgets/delivery_location_sheet.dart';
import '../../../core/services/session_service.dart';

enum _PaymentMethod {
  orangeMoney('orange_money', 'Orange Money', Color(0xFFFF7900)),
  mobileMoney('mobile_money', 'MTN MoMo', Color(0xFFE0A800)),
  card('card', 'Carte', AppColor.textPrimary);

  const _PaymentMethod(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  final _orderService = OrderService();
  final bool _isLoggedIn = SessionService.instance.isLoggedIn;

  List<Map<String, dynamic>> _lines = [];
  final Set<String> _selected = {};
  bool _isLoading = true;
  Object? _error;
  bool _express = false;
  _PaymentMethod _payment = _PaymentMethod.orangeMoney;
  DeliveryLocation? _location;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    if (_isLoggedIn) _load(selectAll: true);
  }

  Future<void> _load({bool selectAll = false}) async {
    try {
      final lines = await _cartService.fetchItems();
      if (!mounted) return;
      setState(() {
        _lines = lines;
        final ids = lines.map(_lineId).toSet();
        _selected.retainAll(ids);
        if (selectAll) {
          _selected.addAll(lines.where(_isAvailable).map(_lineId));
        }
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  static String _lineId(Map<String, dynamic> line) =>
      line['id_ligne'].toString();

  static bool _isAvailable(Map<String, dynamic> line) {
    final stock = parseAmount((line['produits'] as Map?)?['stock']);
    return stock == null || stock > 0;
  }

  num get _subtotal => _lines
      .where((line) => _selected.contains(_lineId(line)))
      .fold<num>(
        0,
        (sum, line) =>
            sum +
            (parseAmount(line['prix_effectif']) ?? 0) *
                (parseAmount(line['quantite']) ?? 1),
      );

  num get _deliveryFee => _express ? OrderService.expressDeliveryFee : 0;

  Future<void> _runAndReload(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    }
    await _load();
  }

  Future<void> _chooseLocation() async {
    final location = await showDeliveryLocationSheet(
      context,
      initial: _location,
    );
    if (location != null) setState(() => _location = location);
  }

  Future<void> _checkout() async {
    final selectedIds = _lines.map(_lineId).where(_selected.contains).toList();
    if (selectedIds.isEmpty) {
      _showMessage('Sélectionne au moins un article.');
      return;
    }
    final location = _location;
    if (location == null) {
      _showMessage('Choisis l’adresse de livraison.');
      await _chooseLocation();
      return;
    }

    setState(() => _isCheckingOut = true);
    try {
      // Prix, stock et total sont recalculés et réservés côté serveur.
      final orderId = await _orderService.createOrder(
        cartLineIds: selectedIds,
        paymentMethod: _payment.value,
        deliveryMode: _express ? 'express' : 'standard',
        address: location.address,
        latitude: location.point.latitude,
        longitude: location.point.longitude,
      );
      if (!mounted) return;
      // Le stock est réservé : on passe au paiement.
      context.go('/pay/$orderId');
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
      await _load();
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon panier')),
      body: _buildBody(),
      bottomNavigationBar: _lines.isEmpty ? null : _buildCheckoutBar(),
    );
  }

  Widget _buildBody() {
    if (!_isLoggedIn) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Connecte-toi pour voir ton panier',
        actionLabel: 'Se connecter',
        onAction: () => context.go('/login'),
      );
    }
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _lines.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Impossible de charger le panier',
        message: friendlyError(_error!),
        actionLabel: 'Réessayer',
        onAction: _load,
      );
    }
    if (_lines.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Ton panier est vide',
        message: 'Découvre les nouveautés et ajoute tes articles.',
        actionLabel: 'Explorer les articles',
        onAction: () => context.go('/home'),
      );
    }

    final allSelected = _lines
        .where(_isAvailable)
        .every((line) => _selected.contains(_lineId(line)));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged: (_) => setState(() {
                  if (allSelected) {
                    _selected.clear();
                  } else {
                    _selected.addAll(_lines.where(_isAvailable).map(_lineId));
                  }
                }),
              ),
              const Expanded(child: Text('Tout sélectionner')),
              Text(
                '${_selected.length}/${_lines.length}',
                style: const TextStyle(color: AppColor.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final line in _lines) ...[
            CartLineTile(
              line: line,
              selected: _selected.contains(_lineId(line)),
              onSelected: (value) => setState(
                () => value
                    ? _selected.add(_lineId(line))
                    : _selected.remove(_lineId(line)),
              ),
              onQuantityChanged: (quantity) => _runAndReload(
                () => _cartService.setQuantity(_lineId(line), quantity),
              ),
              onRemove: () => _runAndReload(
                () => _cartService.removeLines([_lineId(line)]),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          const _SectionTitle('Livraison'),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: AppColor.primary,
              ),
              title: Text(
                _location?.address ?? 'Choisir l’adresse de livraison',
              ),
              subtitle: _location == null
                  ? const Text('Repère + point sur la carte')
                  : const Text('Point GPS enregistré'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _chooseLocation,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: [
              const ButtonSegment(
                value: false,
                icon: Icon(Icons.local_shipping_outlined),
                label: Text('Standard · gratuit'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.bolt_rounded),
                label: Text(
                  'Express · ${formatPrice(OrderService.expressDeliveryFee)}',
                ),
              ),
            ],
            selected: {_express},
            onSelectionChanged: (value) =>
                setState(() => _express = value.first),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Paiement'),
          Wrap(
            spacing: 8,
            children: [
              for (final method in _PaymentMethod.values)
                ChoiceChip(
                  avatar: Icon(
                    method == _PaymentMethod.card
                        ? Icons.credit_card_rounded
                        : Icons.phone_android_rounded,
                    size: 18,
                    color: method.color,
                  ),
                  label: Text(method.label),
                  selected: _payment == method,
                  onSelected: (_) => setState(() => _payment = method),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tu paieras à l’étape suivante (paiement simulé pour la démonstration).',
            style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final total = _subtotal + _deliveryFee;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColor.surface,
          border: Border(top: BorderSide(color: AppColor.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow('Sous-total', formatPrice(_subtotal)),
            _SummaryRow(
              'Livraison',
              _deliveryFee == 0 ? 'Gratuite' : formatPrice(_deliveryFee),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _isCheckingOut || _selected.isEmpty ? null : _checkout,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _isCheckingOut
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Commander · ${formatPrice(total)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColor.textSecondary),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
