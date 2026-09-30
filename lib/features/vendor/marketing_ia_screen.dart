import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/widgets/apple_button.dart';

class MarketingiaScreen extends StatefulWidget {
  const MarketingiaScreen({super.key});

  @override
  State<MarketingiaScreen> createState() => _MarketingiaScreenState();
}

class _MarketingiaScreenState extends State<MarketingiaScreen> {
  final Set<String> _selectedPlatforms = {'instagram'};
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  List<Map<String, dynamic>> _vendorProducts = [];
  List<Map<String, dynamic>> _savedCampaigns = [];
  String? _selectedProductId;
  bool _isLoadingProducts = true;
  bool _isLoadingCampaigns = true;
  List<Map<String, dynamic>> _generatedContents = [];
  bool _isGenerating = false;
  bool _generateVisuals = false;
  bool _isSavingCampaign = false;
  bool _campaignSaved = false;
  String? _generationError;

  static const List<Map<String, dynamic>> _platforms = [
    {'id': 'instagram', 'label': 'Instagram', 'icon': Icons.camera_alt_outlined, 'format': 'Post carré ou portrait, légende et hashtags'},
    {'id': 'tiktok', 'label': 'TikTok', 'icon': Icons.videocam_outlined, 'format': 'Script vidéo vertical, accroche et légende'},
    {'id': 'facebook', 'label': 'Facebook', 'icon': Icons.public, 'format': 'Publication, texte et visuel pour le fil'},
    {'id': 'whatsapp', 'label': 'WhatsApp', 'icon': Icons.chat_outlined, 'format': 'Message court, statut vertical ou catalogue'},
    {'id': 'snapchat', 'label': 'Snapchat', 'icon': Icons.photo_camera_outlined, 'format': 'Story verticale avec texte bref'},
    {'id': 'telegram', 'label': 'Telegram', 'icon': Icons.send_outlined, 'format': 'Message de canal avec visuel et lien'},
    {'id': 'x', 'label': 'X', 'icon': Icons.alternate_email, 'format': 'Texte court, lien et visuel optionnel'},
    {'id': 'linkedin', 'label': 'LinkedIn', 'icon': Icons.work_outline, 'format': 'Publication professionnelle et visuel'},
  ];

  @override
  void initState() {
    super.initState();
    _loadVendorProducts();
    _loadCampaigns();
  }

  Future<void> _loadVendorProducts() async {
    try {
      final supabase = Supabase.instance.client;
      final vendorId = supabase.auth.currentUser?.id;
      if (vendorId == null) return;

      final response = await supabase
          .from('produits')
          .select('id_produit, nom_produit, description, prix')
          .eq('id_vendeur', vendorId)
          .order('date_ajout', ascending: false);

      if (!mounted) return;
      setState(() {
        _vendorProducts = List<Map<String, dynamic>>.from(response);
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadCampaigns() async {
    try {
      final supabase = Supabase.instance.client;
      final vendorId = supabase.auth.currentUser?.id;
      if (vendorId == null) return;

      final response = await supabase
          .from('campagnes')
          .select('id_campagne, nom_campagne, plateformes, contenus, statut, date_creation')
          .eq('id_vendeur', vendorId)
          .order('date_creation', ascending: false);

      if (!mounted) return;
      setState(() {
        _savedCampaigns = List<Map<String, dynamic>>.from(response);
        _isLoadingCampaigns = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingCampaigns = false);
    }
  }

  void _selectVendorProduct(String? productId) {
    if (productId == null) return;
    final product = _vendorProducts.firstWhere((item) => item['id_produit'].toString() == productId);
    setState(() {
      _selectedProductId = productId;
      _productNameController.text = product['nom_produit']?.toString() ?? '';
      _descriptionController.text = product['description']?.toString() ?? '';
      _priceController.text = product['prix']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _generateContent() async {
    if (_selectedPlatforms.isEmpty) {
      setState(() => _generationError = 'Sélectionne au moins un réseau.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationError = null;
      _campaignSaved = false;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate-marketing-copy',
        body: {
          'productName': _productNameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': _priceController.text.trim(),
          'platforms': _selectedPlatforms.toList(),
          'includeVisuals': _generateVisuals,
        },
      );

      final data = response.data;
      if (response.status < 200 || response.status >= 300 || data is! Map) {
        throw Exception(data is Map ? data['error'] ?? 'Réponse IA invalide.' : 'Réponse IA invalide.');
      }

      final contents = data['contents'];
      if (contents is! List) throw Exception('La réponse IA ne contient aucun contenu.');

      if (mounted) {
        setState(() {
          _generatedContents = contents.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _generationError = 'Génération impossible : $error');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveCampaign() async {
    if (_generatedContents.isEmpty || _isSavingCampaign) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _generationError = 'Connecte-toi pour enregistrer cette campagne.');
      return;
    }

    setState(() => _isSavingCampaign = true);
    try {
      await Supabase.instance.client.from('campagnes').insert({
        'id_vendeur': user.id,
        'id_produit': _selectedProductId,
        'nom_campagne': _productNameController.text.trim(),
        'plateformes': _selectedPlatforms.toList(),
        'contenus': _generatedContents,
        'statut': 'brouillon',
      });
      await _loadCampaigns();

      if (!mounted) return;
      setState(() => _campaignSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brouillon de campagne enregistré.')),
      );
    } catch (error) {
      if (mounted) setState(() => _generationError = 'Enregistrement impossible : $error');
    } finally {
      if (mounted) setState(() => _isSavingCampaign = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("A'samesse", style: TextStyle(color: AppColor.primary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Marketing IA", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Créez des campagnes exceptionnelles en un instant.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // Étape 1 : Choix Produit
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("1. CHOISIR LE PRODUIT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  if (_isLoadingProducts)
                    const LinearProgressIndicator(color: AppColor.primary)
                  else if (_vendorProducts.isEmpty)
                    const Text('Aucun produit trouvé dans votre boutique. Vous pouvez saisir les informations ci-dessous.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProductId,
                      decoration: const InputDecoration(labelText: 'Produit de ma boutique'),
                      items: _vendorProducts.map((product) {
                        final productId = product['id_produit'].toString();
                        return DropdownMenuItem<String>(
                          value: productId,
                          child: Text(product['nom_produit']?.toString() ?? 'Produit', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _selectVendorProduct,
                    ),
                  const SizedBox(height: 8),
                  ListTile(
                    tileColor: AppColor.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: TextField(
                      controller: _productNameController,
                      decoration: const InputDecoration(labelText: 'Nom du produit', border: InputBorder.none),
                    ),
                    subtitle: TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description / campagne', border: InputBorder.none),
                    ),
                  )
                  ,
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prix (optionnel)', suffixText: 'FCFA'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Étape 2 : Réseaux Sociaux
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("2. RÉSEAUX SOCIAUX", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _platforms.map((platform) {
                      final platformId = platform['id'] as String;
                      final isSelected = _selectedPlatforms.contains(platformId);
                      return FilterChip(
                        avatar: Icon(platform['icon'] as IconData, size: 18),
                        label: Text(platform['label'] as String),
                        selected: isSelected,
                        selectedColor: AppColor.cardBackground,
                        checkmarkColor: AppColor.primary,
                        side: BorderSide(color: isSelected ? AppColor.primary : Colors.transparent),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedPlatforms.add(platformId);
                            } else if (_selectedPlatforms.length > 1) {
                              _selectedPlatforms.remove(platformId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Générer aussi les visuels'),
              subtitle: const Text('Un appel Gemini image par réseau sélectionné peut être facturé.'),
              value: _generateVisuals,
              activeThumbColor: AppColor.primary,
              onChanged: (value) => setState(() => _generateVisuals = value),
            ),

            if (_selectedPlatforms.isNotEmpty) ...[
              const Text('Formats sélectionnés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._platforms.where((platform) => _selectedPlatforms.contains(platform['id'])).map(
                    (platform) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(platform['icon'] as IconData, color: AppColor.primary),
                      title: Text(platform['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(platform['format'] as String),
                    ),
                  ),
              const SizedBox(height: 12),
            ],

            AppleButton(
              text: "Générer avec l'IA",
              icon: Icons.bolt,
              onPressed: _isGenerating ? null : _generateContent,
            ),

            const SizedBox(height: 24),
            if (_isGenerating) const LinearProgressIndicator(color: AppColor.primary),
            if (_generationError != null) ...[
              const SizedBox(height: 10),
              Text(_generationError!, style: const TextStyle(color: Colors.red)),
            ],
            const Text("Contenus générés", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_generatedContents.isEmpty && !_isGenerating)
              const Text('Les publications générées apparaîtront ici.')
            else
              ..._generatedContents.map((content) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (content['platform'] ?? '').toString().toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColor.primary),
                        ),
                        const SizedBox(height: 8),
                        SelectableText((content['caption'] ?? '').toString()),
                        if (content['image_url'] is String) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              content['image_url'] as String,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Text('Visuel indisponible.'),
                            ),
                          ),
                        ],
                        if (content['image_error'] != null) ...[
                          const SizedBox(height: 8),
                          Text(content['image_error'].toString(), style: const TextStyle(color: Colors.red)),
                        ],
                        if (content['hashtags'] is List && (content['hashtags'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SelectableText((content['hashtags'] as List).join(' '), style: const TextStyle(color: AppColor.primary)),
                        ],
                        if (content['visual_prompt'] != null) ...[
                          const SizedBox(height: 8),
                          Text('Idée visuelle : ${content['visual_prompt']}', style: const TextStyle(color: Colors.black54)),
                        ],
                      ],
                    ),
                  )),
            if (_generatedContents.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSavingCampaign || _campaignSaved ? null : _saveCampaign,
                icon: Icon(_campaignSaved ? Icons.check : Icons.save_outlined),
                label: Text(_campaignSaved ? 'Brouillon enregistré' : 'Enregistrer le brouillon'),
              ),
            ],
            const SizedBox(height: 28),
            const Text('Mes brouillons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_isLoadingCampaigns)
              const LinearProgressIndicator(color: AppColor.primary)
            else if (_savedCampaigns.isEmpty)
              const Text('Aucun brouillon enregistré.')
            else
              ..._savedCampaigns.map((campaign) {
                final platforms = (campaign['plateformes'] as List? ?? []).join(', ');
                final contents = campaign['contenus'] as List? ?? [];
                return Card(
                  color: Colors.white,
                  child: ExpansionTile(
                    title: Text(campaign['nom_campagne']?.toString() ?? 'Campagne'),
                    subtitle: Text('$platforms • ${campaign['statut'] ?? 'brouillon'}'),
                    children: contents.map<Widget>((entry) {
                      if (entry is! Map) return const SizedBox.shrink();
                      return ListTile(
                        dense: true,
                        title: Text((entry['platform'] ?? '').toString().toUpperCase()),
                        subtitle: Text((entry['caption'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

}