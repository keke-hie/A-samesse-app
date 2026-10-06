import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/vendor_service.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/primary_button.dart';

/// Formulaire vendeur de création d'une vente éphémère.
/// Renvoie `true` si une vente a été publiée.
Future<bool?> showCreateDealSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CreateDealSheet(),
  );
}

class _CreateDealSheet extends StatefulWidget {
  const _CreateDealSheet();

  @override
  State<_CreateDealSheet> createState() => _CreateDealSheetState();
}

class _CreateDealSheetState extends State<_CreateDealSheet> {
  static const _minDuration = Duration(hours: 1);
  static const _maxDuration = Duration(days: 30);
  static const _presets = [
    Duration(hours: 6),
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 30),
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  late final Future<List<Map<String, dynamic>>> _productsFuture = VendorService()
      .fetchMyProducts();

  Map<String, dynamic>? _product;
  String _saleType = 'Vente Flash';
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _presetLabel(Duration duration) => duration.inDays >= 1
      ? (duration.inDays == 1 ? '24 h' : '${duration.inDays} jours')
      : '${duration.inHours} h';

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: now,
      lastDate: now.add(_maxDuration),
      helpText: 'Fin de la vente',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endDate),
    );
    if (time == null) return;
    setState(
      () => _endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    if (_endDate.isBefore(now.add(_minDuration))) {
      _showMessage('La vente doit durer au moins 1 heure.');
      return;
    }
    if (_endDate.isAfter(now.add(_maxDuration))) {
      _showMessage('La vente ne peut pas dépasser 30 jours.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('ventes_ephemeres').insert({
        'nom_vente': _nameController.text.trim(),
        'id_produit': _product!['id_produit'],
        'prix_promo': num.parse(_priceController.text.trim()),
        'type_vente': _saleType,
        'date_debut': now.toUtc().toIso8601String(),
        'date_fin': _endDate.toUtc().toIso8601String(),
        'statut': 'actif',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showMessage(friendlyError(error));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(friendlyError(snapshot.error!)),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Ajoute d’abord un produit à ta boutique.'),
            );
          }
          final basePrice = parseAmount(_product?['prix']);

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nouvelle vente éphémère',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la vente',
                      hintText: 'Ex. : Vide-dressing de marque',
                    ),
                    validator: (value) =>
                        (value?.trim().isEmpty ?? true) ? 'Donne un nom à la vente' : null,
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Vente Flash', label: Text('Vente flash')),
                      ButtonSegment(value: 'Vide Dressing', label: Text('Vide-dressing')),
                    ],
                    selected: {_saleType},
                    onSelectionChanged: (value) => setState(() => _saleType = value.first),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _product,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Produit'),
                    items: [
                      for (final product in products)
                        DropdownMenuItem(
                          value: product,
                          child: Text(
                            '${product['nom_produit'] ?? 'Produit'} · ${formatPrice(product['prix'])}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _product = value),
                    validator: (value) => value == null ? 'Choisis un produit' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Prix promo',
                      suffixText: 'FCFA',
                      helperText: basePrice == null
                          ? null
                          : 'Prix habituel : ${formatPrice(basePrice)}',
                    ),
                    validator: (value) {
                      final price = num.tryParse(value?.trim() ?? '');
                      if (price == null || price <= 0) return 'Prix invalide';
                      if (basePrice != null && price >= basePrice) {
                        return 'Le prix promo doit être inférieur au prix habituel';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in _presets)
                        ActionChip(
                          label: Text(_presetLabel(preset)),
                          onPressed: () => setState(
                            () => _endDate = DateTime.now().add(preset),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Fin : ${formatDate(_endDate, withTime: true)}'),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Publier la vente',
                    isLoading: _isSaving,
                    onPressed: _publish,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
