 import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../features/vendor/add_product_screen.dart';
import '../../../features/customer/home/product_detail_screen.dart';

class ShopManagementScreen extends StatefulWidget {
  final bool productsOnly;

  const ShopManagementScreen({super.key, this.productsOnly = false});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _nomVendeur = 'Vendeur';
  String? _avatarUrl;
  String _nomBoutique = 'Ma boutique';
  String _descriptionBoutique = 'Ajoutez une description à votre boutique.';
  String _adressePhysique = 'Adresse non renseignée';
  String? _messageBoutique;
  String? _logoUrl;
  int _nombreAbonnes = 0;
  int _nombreCommandes = 0;
  int _commandesEnAttente = 0;
  num _chiffreAffaires = 0;
  String? _idBoutique;
  bool _isUploadingImage = false;
  String _dateCreation = '';
  List<Map<String, dynamic>> _produitsBoutique = [];
  final Set<String> _retouchingProductIds = {};

  @override
  void initState() {
    super.initState();
    _chargerInfosBoutique();
  }

  String _valueOrFallback(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  Future<void> _chargerInfosBoutique() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Session vendeur introuvable.');
      final userId = user.id;

      final profil = await supabase
          .from('utilisateurs')
          .select('nom, avatar_url')
          .eq('id_utilisateur', userId)
          .maybeSingle();

      final responseBoutique = await supabase
          .from('boutiques')
          .select()
          .eq('id_vendeur', userId)
          .maybeSingle();

      if (responseBoutique != null) {
        _idBoutique = responseBoutique['id_boutique']?.toString();
        _nomBoutique = _valueOrFallback(
          responseBoutique['nom_boutique'],
          _valueOrFallback(user.userMetadata?['nom_commerce'], 'Ma boutique'),
        );
        _descriptionBoutique = _valueOrFallback(
          responseBoutique['description'],
          'Ajoutez une description à votre boutique.',
        );
        _adressePhysique = _valueOrFallback(
          responseBoutique['adresse_physique'],
          'Adresse non renseignée',
        );
        _logoUrl = responseBoutique['logo_url']?.toString();
        _nombreAbonnes =
            int.tryParse('${responseBoutique['nombre_abonnements'] ?? 0}') ?? 0;
        _dateCreation = responseBoutique['date_creation'] != null
            ? responseBoutique['date_creation'].toString().split('T')[0]
            : '';
      } else {
        _nomBoutique =
            user.userMetadata?['nom_commerce']?.toString() ?? 'Ma boutique';
        _messageBoutique =
            'La boutique n’est pas encore reliée à ce compte. Le nom vient de votre inscription.';
      }

      final responseProduits = await supabase
          .from('produits')
          .select()
          .eq('id_vendeur', userId);
      final products = List<Map<String, dynamic>>.from(responseProduits);
      final productIds = products
          .map((product) => product['id_produit'])
          .whereType<Object>()
          .toList();
      var orderCount = 0;
      var pendingOrders = 0;
      num sales = 0;
      final salesByOrder = <Object, num>{};

      if (productIds.isNotEmpty) {
        try {
          final lines = await supabase
              .from('lignes_commande')
              .select('id_commande, quantite, prix_unitaire')
              .inFilter('id_produit', productIds);
          final orderIds = <Object>{};
          for (final line in List<Map<String, dynamic>>.from(lines)) {
            final orderId = line['id_commande'];
            if (orderId == null) continue;
            orderIds.add(orderId as Object);
            final quantity = int.tryParse('${line['quantite'] ?? 0}') ?? 0;
            final unitPrice =
                num.tryParse('${line['prix_unitaire'] ?? 0}') ?? 0;
            salesByOrder[orderId] =
                (salesByOrder[orderId] ?? 0) + quantity * unitPrice;
          }
          if (orderIds.isNotEmpty) {
            final orders = await supabase
                .from('commandes')
                .select('id_commande, statut')
                .inFilter('id_commande', orderIds.toList());
            final orderRows = List<Map<String, dynamic>>.from(orders);
            orderCount = orderRows.length;
            for (final order in orderRows) {
              final status = order['statut']?.toString().toLowerCase() ?? '';
              if (status.contains('attente') || status.contains('paiement')) {
                pendingOrders++;
              } else if (!status.contains('annul')) {
                sales += salesByOrder[order['id_commande']] ?? 0;
              }
            }
          }
        } catch (error) {
          debugPrint('Statistiques commandes indisponibles : $error');
        }
      }

      if (!mounted) return;
      setState(() {
        _nomVendeur =
            profil?['nom']?.toString() ??
            user.userMetadata?['nom']?.toString() ??
            user.userMetadata?['full_name']?.toString() ??
            'Vendeur';
        _avatarUrl = profil?['avatar_url']?.toString();
        _produitsBoutique = products;
        _nombreCommandes = orderCount;
        _commandesEnAttente = pendingOrders;
        _chiffreAffaires = sales;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur : $e');
      if (mounted) {
        setState(() {
          _nomVendeur =
              supabase.auth.currentUser?.userMetadata?['full_name']
                  ?.toString() ??
              'Vendeur';
          _nomBoutique =
              supabase.auth.currentUser?.userMetadata?['nom_commerce']
                  ?.toString() ??
              'Ma boutique';
          _messageBoutique =
              'Certaines informations n’ont pas pu être chargées. Actualisez pour réessayer.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _modifierNomVendeur() async {
    final controller = TextEditingController(text: _nomVendeur);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier mon profil'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom affiché'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase
          .from('utilisateurs')
          .update({'nom': name})
          .eq('id_utilisateur', userId);
      if (mounted) setState(() => _nomVendeur = name);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Profil non modifié : $error')));
      }
    }
  }

  Future<void> _choisirPhoto({required bool avatar}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _isUploadingImage = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final bytes = await picked.readAsBytes();
      final extension = picked.name.split('.').last.toLowerCase();
      final path =
          '${avatar ? 'avatars' : 'shops'}/${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final bucket = avatar ? 'avatars' : 'images';
      await supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = supabase.storage.from(bucket).getPublicUrl(path);
      if (avatar) {
        await supabase
            .from('utilisateurs')
            .update({'avatar_url': url})
            .eq('id_utilisateur', userId);
      } else if (_idBoutique != null) {
        await supabase
            .from('boutiques')
            .update({'logo_url': url})
            .eq('id_boutique', _idBoutique!);
      }
      if (!mounted) return;
      setState(() {
        if (avatar) {
          _avatarUrl = url;
        } else {
          _logoUrl = url;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo non mise à jour : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColor.primary),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColor.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColor.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _transformerPhotoProduit(
    Map<String, dynamic> produit, {
    required bool restaurer,
  }) async {
    final productId = produit['id_produit']?.toString();
    if (productId == null || _retouchingProductIds.contains(productId)) return;

    if (!restaurer) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Générer une image catalogue ?'),
          content: const Text(
            'Gemini créera une nouvelle variante studio. Cet appel d’image peut être facturé ; l’original restera conservé.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Générer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _retouchingProductIds.add(productId));
    try {
      final response = await supabase.functions.invoke(
        'enhance-product-image',
        body: {'productId': productId, 'restoreOriginal': restaurer},
      );
      final data = response.data;
      if (response.status < 200 ||
          response.status >= 300 ||
          data is! Map ||
          data['image_url'] is! String) {
        throw Exception(
          data is Map
              ? data['error'] ?? 'Opération image impossible.'
              : 'Opération image impossible.',
        );
      }

      if (!mounted) return;
      setState(() {
        for (final item in _produitsBoutique) {
          if (item['id_produit']?.toString() == productId)
            item['image_url'] = data['image_url'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restaurer
                ? 'Photo originale restaurée.'
                : 'Image catalogue mise à jour.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opération image impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _retouchingProductIds.remove(productId));
    }
  }

  Future<void> _modifierBoutique() async {
    final nomController = TextEditingController(text: _nomBoutique);
    final descController = TextEditingController(text: _descriptionBoutique);
    final adresseController = TextEditingController(text: _adressePhysique);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier les informations de la boutique'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la boutique',
                ),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: adresseController,
                decoration: const InputDecoration(
                  labelText: 'Adresse physique',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = supabase.auth.currentUser!.id;
              await supabase
                  .from('boutiques')
                  .update({
                    'nom_boutique': nomController.text,
                    'description': descController.text,
                    'adresse_physique': adresseController.text,
                  })
                  .eq('id_vendeur', userId);

              if (!mounted || !context.mounted) return;
              setState(() {
                _nomBoutique = nomController.text;
                _descriptionBoutique = descController.text;
                _adressePhysique = adresseController.text;
              });

              Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        title: Text(
          widget.productsOnly ? 'Mes produits' : _nomBoutique,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: widget.productsOnly
            ? const []
            : [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.black),
                  onPressed: _modifierBoutique,
                  tooltip: 'Modifier les infos',
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: _chargerInfosBoutique,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 29,
                                backgroundColor: AppColor.primarySoft,
                                backgroundImage:
                                    _avatarUrl != null && _avatarUrl!.isNotEmpty
                                    ? NetworkImage(_avatarUrl!)
                                    : null,
                                child: _avatarUrl == null || _avatarUrl!.isEmpty
                                    ? const Icon(
                                        Icons.person_outline,
                                        color: AppColor.primary,
                                        size: 30,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: IconButton(
                                  tooltip: 'Modifier ma photo',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _isUploadingImage
                                      ? null
                                      : () => _choisirPhoto(avatar: true),
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    size: 17,
                                    color: AppColor.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bonjour,',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColor.textSecondary,
                                  ),
                                ),
                                Text(
                                  _nomVendeur,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Modifier mon profil',
                            onPressed: _modifierNomVendeur,
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppColor.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.productsOnly) ...[
                    if (_messageBoutique != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColor.primarySoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColor.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _messageBoutique!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColor.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: AppColor.primarySoft,
                              backgroundImage:
                                  _logoUrl != null && _logoUrl!.isNotEmpty
                                  ? NetworkImage(_logoUrl!)
                                  : null,
                              child: _logoUrl == null || _logoUrl!.isEmpty
                                  ? const Icon(
                                      Icons.store,
                                      size: 35,
                                      color: AppColor.primary,
                                    )
                                  : null,
                            ),
                            IconButton(
                              tooltip:
                                  'Ajouter ou modifier le logo de la boutique',
                              visualDensity: VisualDensity.compact,
                              onPressed: _isUploadingImage
                                  ? null
                                  : () => _choisirPhoto(avatar: false),
                              icon: const Icon(
                                Icons.add_a_photo_outlined,
                                size: 18,
                                color: AppColor.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nomBoutique,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _descriptionBoutique,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _adressePhysique,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.people,
                              size: 16,
                              color: AppColor.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$_nombreAbonnes abonnés',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (_dateCreation.isNotEmpty)
                          Text(
                            'Créée le : $_dateCreation',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _statTile(
                          'Commandes',
                          '$_nombreCommandes',
                          Icons.receipt_long_outlined,
                        ),
                        const SizedBox(width: 8),
                        _statTile(
                          'En attente',
                          '$_commandesEnAttente',
                          Icons.pending_actions_outlined,
                        ),
                        const SizedBox(width: 8),
                        _statTile(
                          'En stock',
                          '${_produitsBoutique.fold<int>(0, (total, product) => total + (int.tryParse('${product['stock'] ?? 0}') ?? 0))}',
                          Icons.inventory_2_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.primarySoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            color: AppColor.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Ventes enregistrées',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColor.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${_chiffreAffaires.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColor.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Actions rapides',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: _actionTile(
                            icon: Icons.add_box_outlined,
                            label: 'Ajouter un produit',
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddProductScreen(),
                                ),
                              );
                              _chargerInfosBoutique();
                            },
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _actionTile(
                            icon: Icons.flash_on_outlined,
                            label: 'Vente éphémère',
                            onTap: () => context.push('/vendor/deals'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Créer du contenu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/vendor/campaign-refine'),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Campagnes'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final platform in [
                          ('Instagram', 'instagram', Icons.camera_alt_outlined),
                          ('TikTok', 'tiktok', Icons.videocam_outlined),
                          ('Facebook', 'facebook', Icons.public),
                          ('WhatsApp', 'whatsapp', Icons.chat_outlined),
                        ])
                          ActionChip(
                            avatar: Icon(
                              platform.$3,
                              size: 16,
                              color: AppColor.primary,
                            ),
                            label: Text(platform.$1),
                            onPressed: () => context.push(
                              '/vendor/marketing-ia?platform=${platform.$2}',
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColor.border),
                          ),
                      ],
                    ),
                    const Divider(height: 30),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mes Produits en ligne',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          width: 108,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddProductScreen(),
                                ),
                              );
                              _chargerInfosBoutique();
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ajouter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColor.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            _produitsBoutique.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: Text('Aucun produit pour le moment.')),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.66,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final produit = _produitsBoutique[index];
                        final imageUrl =
                            produit['image_url'] ?? produit['images'];

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            debugPrint(
                              "CLIC SUR LE PRODUIT : ${produit['nom_produit']}",
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(product: produit),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          imageUrl != null &&
                                                  imageUrl.toString().isNotEmpty
                                              ? Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => const Center(
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    Icons.image,
                                                    color: Colors.grey,
                                                    size: 40,
                                                  ),
                                                ),
                                          Positioned(
                                            left: 8,
                                            bottom: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.94,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Stock : ${produit['stock'] ?? 0}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Column(
                                              children: [
                                                if ((produit['image_originale_url'] ??
                                                        '')
                                                    .toString()
                                                    .isNotEmpty)
                                                  Material(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.92,
                                                        ),
                                                    shape: const CircleBorder(),
                                                    child: IconButton(
                                                      tooltip:
                                                          'Restaurer la photo originale',
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      onPressed:
                                                          _retouchingProductIds
                                                              .contains(
                                                                produit['id_produit']
                                                                    .toString(),
                                                              )
                                                          ? null
                                                          : () =>
                                                                _transformerPhotoProduit(
                                                                  produit,
                                                                  restaurer:
                                                                      true,
                                                                ),
                                                      icon: const Icon(
                                                        Icons.history,
                                                        color: AppColor
                                                            .textPrimary,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 4),
                                                Material(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.92),
                                                  shape: const CircleBorder(),
                                                  child: IconButton(
                                                    tooltip:
                                                        'Générer une image catalogue avec Gemini',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed:
                                                        _retouchingProductIds
                                                            .contains(
                                                              produit['id_produit']
                                                                  .toString(),
                                                            )
                                                        ? null
                                                        : () =>
                                                              _transformerPhotoProduit(
                                                                produit,
                                                                restaurer:
                                                                    false,
                                                              ),
                                                    icon:
                                                        _retouchingProductIds
                                                            .contains(
                                                              produit['id_produit']
                                                                  .toString(),
                                                            )
                                                        ? const SizedBox(
                                                            width: 18,
                                                            height: 18,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                          )
                                                        : const Icon(
                                                            Icons.auto_awesome,
                                                            color: AppColor
                                                                .primary,
                                                            size: 18,
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        produit['nom_produit'] ?? 'Sans nom',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${produit['prix'] ?? 0} FCFA',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (int.tryParse(
                                                      '${produit['stock'] ?? 0}',
                                                    ) ??
                                                    0) >
                                                0
                                            ? 'Disponible'
                                            : 'Rupture de stock',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              (int.tryParse(
                                                        '${produit['stock'] ?? 0}',
                                                      ) ??
                                                      0) >
                                                  0
                                              ? AppColor.success
                                              : AppColor.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: _produitsBoutique.length),
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}
