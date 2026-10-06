import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_color.dart';
import '../../core/constants/product_categories.dart';
import '../../core/services/vendor_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/product_image.dart';

/// Création et modification d'un produit par le vendeur.
/// Renvoie `true` (via `Navigator.pop`) si le catalogue a changé.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  /// Produit à modifier ; `null` pour une création.
  final Map<String, dynamic>? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _scenes = {
    'studio': 'Studio professionnel',
    'neutre': 'Fond neutre épuré',
    'dressing': 'Dressing lumineux',
    'mannequin': 'Mannequin virtuel',
  };

  final _formKey = GlobalKey<FormState>();
  final _vendorService = VendorService();
  late final _nameController = TextEditingController(
    text: _initial('nom_produit'),
  );
  late final _descriptionController = TextEditingController(
    text: _initial('description'),
  );
  late final _priceController = TextEditingController(
    text: _initialNumber('prix'),
  );
  late final _stockController = TextEditingController(
    text: _initialNumber('stock'),
  );
  late final _colorsController = TextEditingController(
    text: _initialList('couleurs'),
  );
  late final _sizesController = TextEditingController(
    text: _initialList('tailles'),
  );
  late final _featuresController = TextEditingController(
    text: _initialList('caracteristiques'),
  );

  late String? _category =
      productCategories.contains(widget.product?['categorie'])
      ? widget.product!['categorie'] as String
      : null;
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _enhanceWithAi = true;
  String _scene = 'studio';
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  String _initial(String key) => widget.product?[key]?.toString() ?? '';

  String _initialNumber(String key) {
    final value = parseAmount(widget.product?[key]);
    return value == null ? '' : value.round().toString();
  }

  String _initialList(String key) {
    final value = widget.product?[key];
    return value is Iterable ? value.join(', ') : value?.toString() ?? '';
  }

  static List<String> _parseList(String value) => value
      .split(RegExp(r'[,;\n]'))
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList();

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _descriptionController,
      _priceController,
      _stockController,
      _colorsController,
      _sizesController,
      _featuresController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    setState(() {
      _photo = photo;
      _photoBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEditing && _photo == null) {
      _showMessage('Ajoute une photo du produit.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final values = <String, dynamic>{
        'nom_produit': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'prix': num.parse(_priceController.text.trim()),
        'stock': int.parse(_stockController.text.trim()),
        'categorie': _category,
        'couleurs': _parseList(_colorsController.text),
        'tailles': _parseList(_sizesController.text),
        'caracteristiques': _parseList(_featuresController.text),
      };

      var aiFailed = false;
      if (_photo != null) {
        final photos = await _vendorService.uploadProductPhoto(
          file: _photo!,
          productName: values['nom_produit'] as String,
          description: values['description'] as String,
          scene: _enhanceWithAi ? _scene : null,
        );
        aiFailed = _enhanceWithAi && !photos.enhanced;
        values.addAll({
          'image_url': photos.imageUrl,
          'image_originale_url': photos.originalUrl,
          'image_verticale_url': photos.verticalUrl,
        });
      }

      await _vendorService.saveProduct(
        productId: widget.product?['id_produit']?.toString(),
        values: values,
      );
      if (!mounted) return;
      _showMessage(
        aiFailed
            ? 'Produit enregistré avec la photo d’origine (la retouche IA a échoué).'
            : _isEditing
            ? 'Produit mis à jour.'
            : 'Produit publié !',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: const Text('Il disparaîtra du catalogue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColor.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _vendorService.deleteProduct(
        widget.product!['id_produit'].toString(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showMessage(friendlyError(error));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le produit' : 'Nouveau produit'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _isSaving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _PhotoPicker(
              photoBytes: _photoBytes,
              currentUrl: _isEditing
                  ? ProductImage.urlOf(widget.product!)
                  : null,
              onPick: _isSaving ? null : _pickPhoto,
            ),
            if (_photo != null) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enhanceWithAi,
                onChanged: (value) => setState(() => _enhanceWithAi = value),
                title: const Text('Retouche Studio IA'),
                subtitle: const Text(
                  'Détourage, lumière et image Story 9:16. L’original est conservé. '
                  'Chaque génération peut être facturée.',
                ),
              ),
              if (_enhanceWithAi)
                DropdownButtonFormField<String>(
                  initialValue: _scene,
                  decoration: const InputDecoration(labelText: 'Mise en scène'),
                  items: [
                    for (final entry in _scenes.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _scene = value ?? _scene),
                ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom du produit'),
              textCapitalization: TextCapitalization.sentences,
              validator: _required,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [
                for (final category in productCategories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) => setState(() => _category = value),
              validator: (value) =>
                  value == null ? 'Choisis une catégorie' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prix',
                      suffixText: 'FCFA',
                    ),
                    validator: (value) {
                      final price = num.tryParse(value?.trim() ?? '');
                      return price == null || price <= 0
                          ? 'Prix invalide'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock'),
                    validator: (value) {
                      final stock = int.tryParse(value?.trim() ?? '');
                      return stock == null || stock < 0
                          ? 'Stock invalide'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _colorsController,
              decoration: const InputDecoration(
                labelText: 'Couleurs (facultatif)',
                helperText: 'Séparées par des virgules : noir, beige, #8B2635',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sizesController,
              decoration: const InputDecoration(
                labelText: 'Tailles ou modèles (facultatif)',
                helperText: 'Ex. : S, M, L ou 38, 39, 40',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _featuresController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Caractéristiques (facultatif)',
                helperText: 'Une par ligne ou séparées par des virgules',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: _isEditing ? 'Enregistrer' : 'Publier le produit',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photoBytes,
    required this.currentUrl,
    required this.onPick,
  });

  final Uint8List? photoBytes;
  final String? currentUrl;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final hasImage = photoBytes != null || (currentUrl?.isNotEmpty ?? false);
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 200,
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColor.border),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: photoBytes != null
                        ? Image.memory(photoBytes!, fit: BoxFit.cover)
                        : ProductImage(url: currentUrl),
                  ),
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: Chip(
                      avatar: Icon(Icons.photo_library_outlined, size: 16),
                      label: Text('Changer la photo'),
                    ),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 36,
                    color: AppColor.primary,
                  ),
                  SizedBox(height: 8),
                  Text('Ajouter une photo du produit'),
                ],
              ),
      ),
    );
  }
}
