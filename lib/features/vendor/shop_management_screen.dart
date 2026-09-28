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
                          final imageUrl = produit['images'] ?? produit['image_url'];

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
                                        child: imageUrl != null && imageUrl.toString().isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                errorBuilder: (context, error, stackTrace) => 
                                                    const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                              )
                                            : const Center(child: Icon(Icons.image, color: Colors.grey, size: 40)),
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