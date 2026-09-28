import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/widgets/apple_button.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _supabase = Supabase.instance.client;
  
  // Variable de rôle de l'utilisateur
  bool _isVendor = false; 

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  // Vérifier si l'utilisateur connecté est un vendeur pour afficher le bouton "Nouvelle Vente"
  Future<void> _checkUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('utilisateurs') // Correction : utilisation de la bonne table 'utilisateurs'
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        
        if (data != null && data['role']?.toString().toLowerCase() == 'vendeur') {
          if (mounted) {
            setState(() {
              _isVendor = true;
            });
          }
        }
      }
    } catch (_) {}
  }

  // Écouter en temps réel la table `ventes_ephemeres`
  Stream<List<Map<String, dynamic>>> _getVentesEphemeresStream() {
    return _supabase
        .from('ventes_ephemeres')
        .stream(primaryKey: ['id_vente_ephemere'])
        .eq('statut', 'actif')
        .gt('date_fin', DateTime.now().toIso8601String())
        .order('date_fin', ascending: true);
  }

  // Génération et partage du lien d'accès à la vente éphémère
  void _shareDeal(String dealId, String typeVente) {
    final String dealLink = "https://asamesse.app/deal/$dealId";
    Share.share(
      "🔥 Profitez de notre $typeVente sur A'samesse ! Cliquez ici pour y accéder : $dealLink",
      subject: "$typeVente sur A'samesse",
    );
  }

  // Boîte de dialogue pour créer une nouvelle vente éphémère (Réservée au vendeur)
  void _showCreateDealDialog() {
    final produitIdController = TextEditingController();
    final prixPromoController = TextEditingController();
    String typeVente = "Vente Flash";
    int durationHours = 2;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Créer une vente éphémère"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: typeVente,
                      decoration: const InputDecoration(labelText: "Type de vente"),
                      items: const [
                        DropdownMenuItem(value: "Vente Flash", child: Text("Vente Flash")),
                        DropdownMenuItem(value: "Vide Dressing", child: Text("Vide Dressing")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => typeVente = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: produitIdController,
                      decoration: const InputDecoration(
                        labelText: "ID du Produit",
                        hintText: "Entrez l'ID du produit concerné",
                      ),
                    ),
                    TextField(
                      controller: prixPromoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Prix Promo (FCFA)"),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: durationHours,
                      decoration: const InputDecoration(labelText: "Durée de l'offre"),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text("1 Heure")),
                        DropdownMenuItem(value: 2, child: Text("2 Heures")),
                        DropdownMenuItem(value: 6, child: Text("6 Heures")),
                        DropdownMenuItem(value: 12, child: Text("12 Heures")),
                        DropdownMenuItem(value: 24, child: Text("24 Heures")),
                        DropdownMenuItem(value: 48, child: Text("48 Heures")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => durationHours = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColor.primary),
                  onPressed: () async {
                    if (produitIdController.text.isEmpty || prixPromoController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Veuillez remplir tous les champs.")),
                      );
                      return;
                    }

                    final now = DateTime.now();
                    final endDate = now.add(Duration(hours: durationHours));

                    await _supabase.from('ventes_ephemeres').insert({
                      'id_produit': produitIdController.text.trim(),
                      'prix_promo': double.tryParse(prixPromoController.text) ?? 0,
                      'type_vente': typeVente,
                      'date_debut': now.toIso8601String(),
                      'date_fin': endDate.toIso8601String(),
                      'statut': 'actif',
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("$typeVente créée avec succès !")),
                      );
                    }
                  },
                  child: const Text("Publier", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "A'samesse",
          style: TextStyle(color: AppColor.primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              showSearch(context: context, delegate: ProductSearchDelegate());
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      // Le bouton de création de vente n'apparaît QUE si l'utilisateur est un vendeur
      floatingActionButton: _isVendor
          ? FloatingActionButton.extended(
              onPressed: _showCreateDealDialog,
              backgroundColor: AppColor.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Nouvelle Vente", style: TextStyle(color: Colors.white)),
            )
          : null,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getVentesEphemeresStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final deals = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Ventes Éphémères",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Ventes Flash & Vide Dressings à durée limitée. Dépêchez-vous avant la fin du décompte !",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Bannière de décompte de la vente la plus proche de l'expiration
                if (deals.isNotEmpty) _LiveTimerBanner(dateFinStr: deals.first['date_fin']),

                const SizedBox(height: 20),

                if (deals.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        "Aucune vente éphémère en cours.\nRevenez plus tard pour de superbes offres !",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: deals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildDealCard(deals[index]);
                    },
                  ),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDealCard(Map<String, dynamic> deal) {
    final String idVente = deal['id_vente_ephemere'].toString();
    final double prixPromo = (deal['prix_promo'] ?? 0).toDouble();
    final String typeVente = deal['type_vente'] ?? 'Vente Flash';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Icon(Icons.shopping_bag, size: 50, color: Colors.grey),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: typeVente == 'Vide Dressing' ? Colors.purple : AppColor.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    typeVente.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.share, color: Colors.black, size: 20),
                    onPressed: () => _shareDeal(idVente, typeVente),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "$typeVente - Produit #${deal['id_produit']}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "${prixPromo.toStringAsFixed(0)} FCFA",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.primary),
          ),
          const SizedBox(height: 12),
          AppleButton(
            text: "Acheter Maintenant",
            icon: Icons.shopping_bag_outlined,
            onPressed: () {
              // Action d'achat
            },
            height: 46,
          ),
        ],
      ),
    );
  }
}

/// Widget séparé pour le décompte en temps réel (évite de recharger tout l'écran chaque seconde)
class _LiveTimerBanner extends StatefulWidget {
  final String dateFinStr;
  const _LiveTimerBanner({required this.dateFinStr});

  @override
  State<_LiveTimerBanner> createState() => _LiveTimerBannerState();
}

class _LiveTimerBannerState extends State<_LiveTimerBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFin = DateTime.tryParse(widget.dateFinStr) ?? DateTime.now();
    final diff = dateFin.difference(DateTime.now());

    final hours = diff.inHours.clamp(0, 99).toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).clamp(0, 59).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: AppColor.primary),
              const SizedBox(width: 8),
              const Text(
                "La vente expire dans :",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimerBox(hours, "HEURES"),
              const Text(" : ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              _buildTimerBox(minutes, "MINUTES"),
              const Text(" : ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              _buildTimerBox(seconds, "SECONDES"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColor.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class ProductSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
      ];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => Center(child: Text("Résultats pour : $query"));

  @override
  Widget buildSuggestions(BuildContext context) =>
      const Center(child: Text("Rechercher un produit ou une vente..."));
}