import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/apple_button.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _supabase = Supabase.instance.client;

  // Seuls les vendeurs validés peuvent publier une vente.
  bool get _isVendor =>
      SessionService.instance.isVendor && SessionService.instance.isActive;

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

  // Durée minimale et maximale autorisées pour une vente éphémère.
  static const Duration _minDealDuration = Duration(hours: 1);
  static const Duration _maxDealDuration = Duration(days: 30);

  String _formatPreset(Duration duration) {
    if (duration.inDays >= 1) {
      return duration.inDays == 1 ? '24 h' : '${duration.inDays} jours';
    }
    return '${duration.inHours} h';
  }

  String _formatEndDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        'à ${two(date.hour)}:${two(date.minute)}';
  }

  String? _validateEndDate(DateTime endDate, DateTime now) {
    if (!endDate.isAfter(now.add(_minDealDuration))) {
      return "La fin de la vente doit être au moins 1 heure après maintenant.";
    }
    if (endDate.isAfter(now.add(_maxDealDuration))) {
      return "La fin de la vente ne peut pas dépasser 30 jours.";
    }
    return null;
  }

  Future<DateTime?> _pickEndDate(BuildContext context, DateTime initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(_maxDealDuration),
      helpText: "Date de fin de la vente",
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: "Heure de fin de la vente",
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // Boîte de dialogue pour créer une nouvelle vente éphémère (Réservée au vendeur)
  Future<void> _showCreateDealDialog() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    List<Map<String, dynamic>> products;
    try {
      final response = await _supabase
          .from('produits')
          .select('id_produit, nom_produit, prix')
          .eq('id_vendeur', user.id)
          .order('date_ajout', ascending: false);
      products = List<Map<String, dynamic>>.from(response);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chargement des produits impossible : $error'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez un produit avant de créer une vente.'),
        ),
      );
      return;
    }

    String selectedProductId = products.first['id_produit'].toString();
    final nomController = TextEditingController();
    final prixPromoController = TextEditingController();
    String typeVente = "Vente Flash";
    DateTime endDate = DateTime.now().add(const Duration(hours: 24));

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
                    TextField(
                      controller: nomController,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: "Nom de la vente",
                        hintText: "Ex : Vide-dressing de marque",
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: typeVente,
                      decoration: const InputDecoration(
                        labelText: "Type de vente",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Vente Flash",
                          child: Text("Vente Flash"),
                        ),
                        DropdownMenuItem(
                          value: "Vide Dressing",
                          child: Text("Vide Dressing"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => typeVente = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProductId,
                      decoration: const InputDecoration(
                        labelText: 'Produit concerné',
                      ),
                      items: products.map((product) {
                        final id = product['id_produit'].toString();
                        final name =
                            product['nom_produit']?.toString() ?? 'Produit';
                        return DropdownMenuItem(
                          value: id,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedProductId = value);
                        }
                      },
                    ),
                    TextField(
                      controller: prixPromoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Prix Promo (FCFA)",
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final preset in const [
                            Duration(hours: 6),
                            Duration(days: 1),
                            Duration(days: 3),
                            Duration(days: 7),
                            Duration(days: 30),
                          ])
                            ActionChip(
                              label: Text(_formatPreset(preset)),
                              onPressed: () => setDialogState(
                                () => endDate = DateTime.now().add(preset),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text("Fin de la vente : ${_formatEndDate(endDate)}"),
                      onPressed: () async {
                        final picked = await _pickEndDate(context, endDate);
                        if (picked != null) {
                          setDialogState(() => endDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Durée personnalisable : de quelques heures à 30 jours maximum.",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primary,
                  ),
                  onPressed: () async {
                    final nom = nomController.text.trim();
                    if (nom.isEmpty ||
                        prixPromoController.text.isEmpty ||
                        (double.tryParse(prixPromoController.text) ?? 0) <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Veuillez renseigner le nom de la vente et un prix promo valide.",
                          ),
                        ),
                      );
                      return;
                    }

                    final now = DateTime.now();
                    final validationError = _validateEndDate(endDate, now);
                    if (validationError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(validationError)),
                      );
                      return;
                    }

                    await _supabase.from('ventes_ephemeres').insert({
                      'nom_vente': nom,
                      'id_produit': selectedProductId,
                      'prix_promo': double.parse(prixPromoController.text),
                      'type_vente': typeVente,
                      'date_debut': now.toIso8601String(),
                      'date_fin': endDate.toIso8601String(),
                      'statut': 'actif',
                    });

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("« $nom » publiée avec succès !")),
                    );
                  },
                  child: const Text(
                    "Publier",
                    style: TextStyle(color: Colors.white),
                  ),
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
          style: TextStyle(
            color: AppColor.primary,
            fontWeight: FontWeight.bold,
          ),
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
              label: const Text(
                "Nouvelle Vente",
                style: TextStyle(color: Colors.white),
              ),
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
                if (deals.isNotEmpty)
                  _LiveTimerBanner(
                    dateFinStr: deals.first['date_fin'],
                    nom: deals.first['nom_vente']?.toString(),
                  ),

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
    final String nomVente = (deal['nom_vente']?.toString() ?? '').trim();

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
                  child: const Icon(
                    Icons.shopping_bag,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: typeVente == 'Vide Dressing'
                        ? Colors.purple
                        : AppColor.primary,
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
                    icon: const Icon(
                      Icons.share,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () => _shareDeal(idVente, typeVente),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nomVente.isNotEmpty
                ? nomVente
                : "$typeVente - Produit #${deal['id_produit'] ?? deal['id_produit_legacy'] ?? 'à associer'}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (nomVente.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              "$typeVente · Produit #${deal['id_produit'] ?? deal['id_produit_legacy'] ?? 'à associer'}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            "${prixPromo.toStringAsFixed(0)} FCFA",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColor.primary,
            ),
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
  final String? nom;
  const _LiveTimerBanner({required this.dateFinStr, this.nom});

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
    final isLongSale = diff.inDays >= 1;

    final hours = diff.inHours.clamp(0, 99).toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60)
        .clamp(0, 59)
        .toString()
        .padLeft(2, '0');
    final seconds = (diff.inSeconds % 60)
        .clamp(0, 59)
        .toString()
        .padLeft(2, '0');

    String formatFull(DateTime date) {
      String two(int value) => value.toString().padLeft(2, '0');
      return '${two(date.day)}/${two(date.month)}/${date.year} '
          'à ${two(date.hour)}:${two(date.minute)}';
    }

    final urgencyLabel = isLongSale
        ? "Se termine dans ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}"
        : "Fin dans";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (widget.nom != null && widget.nom!.trim().isNotEmpty) ...[
            Text(
              widget.nom!.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Icon(Icons.bolt, color: AppColor.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  urgencyLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLongSale)
            Text(
              "Jusqu'au ${formatFull(dateFin)}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimerBox(hours, "HEURES"),
                const Text(
                  " : ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                _buildTimerBox(minutes, "MINUTES"),
                const Text(
                  " : ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ProductSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) =>
      Center(child: Text("Résultats pour : $query"));

  @override
  Widget buildSuggestions(BuildContext context) =>
      const Center(child: Text("Rechercher un produit ou une vente..."));
}
