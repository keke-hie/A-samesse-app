import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: unused_import
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_color.dart';
import '../../../features/vendor/add_product_screen.dart';
import '../../../features/customer/home/product_detail_screen.dart';

class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String _nomBoutique = '';
  String _descriptionBoutique = '';
  String _adressePhysique = '';
  String? _logoUrl;
  int _nombreAbonnes = 0;
  String _dateCreation = '';
  List<Map<String, dynamic>> _produitsBoutique = [];
  final Set<String> _retouchingProductIds = {};

  @override
  void initState() {
    super.initState();
    _chargerInfosBoutique();
  }

  Future<void> _chargerInfosBoutique() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final responseBoutique = await supabase
          .from('boutiques')
          .select()
          .eq('id_vendeur', userId)
          .maybeSingle();

      if (responseBoutique != null) {
        setState(() {
          _nomBoutique = responseBoutique['nom_boutique'] ?? 'Ma Boutique';
          _descriptionBoutique = responseBoutique['description'] ?? 'Aucune description';
          _adressePhysique = responseBoutique['adresse_physique'] ?? 'Non renseignée';
          _logoUrl = responseBoutique['logo_url'];
          _nombreAbonnes = responseBoutique['nombre_abonnements'] ?? 0;
          _dateCreation = responseBoutique['date_creation'] != null 
              ? responseBoutique['date_creation'].toString().split('T')[0] 
              : '';
        });
      }

      final responseProduits = await supabase
          .from('produits')
          .select()
          .eq('id_vendeur', userId);

      setState(() {
        _produitsBoutique = List<Map<String, dynamic>>.from(responseProduits);
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur : $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _transformerPhotoProduit(Map<String, dynamic> produit, {required bool restaurer}) async {
    final productId = produit['id_produit']?.toString();
    if (productId == null || _retouchingProductIds.contains(productId)) return;

    if (!restaurer) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Générer une image catalogue ?'),
          content: const Text('Gemini créera une nouvelle variante studio. Cet appel d’image peut être facturé ; l’original restera conservé.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Générer')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _retouchingProductIds.add(productId));
    try {
      final response = await supabase.functions.invoke(
        'enhance-product-image',
        body: {
          'productId': productId,
          'restoreOriginal': restaurer,
        },
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300 || data is! Map || data['image_url'] is! String) {
        throw Exception(data is Map ? data['error'] ?? 'Opération image impossible.' : 'Opération image impossible.');
      }

      if (!mounted) return;
      setState(() {
        for (final item in _produitsBoutique) {
          if (item['id_produit']?.toString() == productId) item['image_url'] = data['image_url'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(restaurer ? 'Photo originale restaurée.' : 'Image catalogue mise à jour.')),
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

  Future<void> _retoucherPhotoProduit(Map<String, dynamic> produit) async {
    final productId = produit['id_produit']?.toString();
    if (productId == null || _retouchingProductIds.contains(productId)) return;

    setState(() => _retouchingProductIds.add(productId));
    try {
      final response = await supabase.functions.invoke(
        'enhance-product-image',
        body: {'productId': productId},
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300 || data is! Map || data['image_url'] is! String) {
        throw Exception(data is Map ? data['error'] ?? 'Retouche impossible.' : 'Retouche impossible.');
      }

      if (!mounted) return;
      setState(() {
        for (final item in _produitsBoutique) {
          if (item['id_produit']?.toString() == productId) {
            item['image_url'] = data['image_url'];
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo catalogue professionnelle mise à jour.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retouche de la photo impossible : $error')),
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
                decoration: const InputDecoration(labelText: 'Nom de la boutique'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: adresseController,
                decoration: const InputDecoration(labelText: 'Adresse physique'),
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
              await supabase.from('boutiques').update({
                'nom_boutique': nomController.text,
                'description': descController.text,
                'adresse_physique': adresseController.text,
              }).eq('id_vendeur', userId);

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        title: Text(_nomBoutique, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                          child: _logoUrl == null ? const Icon(Icons.store, size: 35) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nomBoutique,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _descriptionBoutique,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(_adressePhysique, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
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
                            const Icon(Icons.people, size: 16, color: Colors.blue),
                            const SizedBox(width: 5),
                            Text('$_nombreAbonnes abonnés', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        if (_dateCreation.isNotEmpty)
                          Text('Créée le : $_dateCreation', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mes Produits en ligne',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddProductScreen()),
                            );
                            _chargerInfosBoutique(); 
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final produit = _produitsBoutique[index];
                          final imageUrl = produit['image_url'] ?? produit['images'];

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              print("CLIC SUR LE PRODUIT : ${produit['nom_produit']}");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(product: produit),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
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
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            imageUrl != null && imageUrl.toString().isNotEmpty
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                                  )
                                                : const Center(child: Icon(Icons.image, color: Colors.grey, size: 40)),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Column(
                                                children: [
                                                  if ((produit['image_originale_url'] ?? '').toString().isNotEmpty)
                                                    Material(
                                                      color: Colors.white.withValues(alpha: 0.92),
                                                      shape: const CircleBorder(),
                                                      child: IconButton(
                                                        tooltip: 'Restaurer la photo originale',
                                                        visualDensity: VisualDensity.compact,
                                                        onPressed: _retouchingProductIds.contains(produit['id_produit'].toString())
                                                            ? null
                                                            : () => _transformerPhotoProduit(produit, restaurer: true),
                                                        icon: const Icon(Icons.history, color: AppColor.textPrimary, size: 18),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Material(
                                                    color: Colors.white.withValues(alpha: 0.92),
                                                    shape: const CircleBorder(),
                                                    child: IconButton(
                                                      tooltip: 'Générer une image catalogue avec Gemini',
                                                      visualDensity: VisualDensity.compact,
                                                      onPressed: _retouchingProductIds.contains(produit['id_produit'].toString())
                                                          ? null
                                                          : () => _transformerPhotoProduit(produit, restaurer: false),
                                                      icon: _retouchingProductIds.contains(produit['id_produit'].toString())
                                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                                          : const Icon(Icons.auto_awesome, color: AppColor.primary, size: 18),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          produit['nom_produit'] ?? 'Sans nom',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${produit['prix'] ?? 0} FCFA',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _produitsBoutique.length,
                      ),
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}