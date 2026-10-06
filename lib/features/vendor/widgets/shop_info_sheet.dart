import 'package:flutter/material.dart';

import '../../../core/services/vendor_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/primary_button.dart';

/// Création ou modification des informations de la boutique.
/// Renvoie `true` si elles ont été enregistrées.
Future<bool?> showShopInfoSheet(
  BuildContext context, {
  Map<String, dynamic>? shop,
  String? suggestedName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShopInfoSheet(shop: shop, suggestedName: suggestedName),
  );
}

class _ShopInfoSheet extends StatefulWidget {
  const _ShopInfoSheet({this.shop, this.suggestedName});

  final Map<String, dynamic>? shop;
  final String? suggestedName;

  @override
  State<_ShopInfoSheet> createState() => _ShopInfoSheetState();
}

class _ShopInfoSheetState extends State<_ShopInfoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.shop?['nom_boutique']?.toString() ?? widget.suggestedName,
  );
  late final _descriptionController = TextEditingController(
    text: widget.shop?['description']?.toString(),
  );
  late final _addressController = TextEditingController(
    text: widget.shop?['adresse_physique']?.toString(),
  );
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await VendorService().saveShop(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.shop == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                creating ? 'Créer ma boutique' : 'Informations de la boutique',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la boutique',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Indique le nom de la boutique'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse physique (facultatif)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: creating ? 'Créer la boutique' : 'Enregistrer',
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
