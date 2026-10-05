import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';

class CampaignEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? initialContent;

  const CampaignEditorScreen({super.key, this.initialContent});

  @override
  State<CampaignEditorScreen> createState() => _CampaignEditorScreenState();
}

class _CampaignEditorScreenState extends State<CampaignEditorScreen> {
  final _supabase = Supabase.instance.client;
  final _captionController = TextEditingController();
  final _directionController = TextEditingController();
  bool _isGenerating = false;
  bool _isSaving = false;
  String? _error;

  Map<String, dynamic> get _content => widget.initialContent ?? const {};
  String get _platform => _content['platform']?.toString() ?? 'instagram';
  String get _productName => _content['productName']?.toString() ?? 'Produit';

  @override
  void initState() {
    super.initState();
    _captionController.text = _content['caption']?.toString() ?? '';
  }

  @override
  void dispose() {
    _captionController.dispose();
    _directionController.dispose();
    super.dispose();
  }

  Future<void> _refineWithAI() async {
    final direction = _directionController.text.trim();
    if (direction.isEmpty) {
      setState(() => _error = 'Décris la modification souhaitée.');
      return;
    }
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'generate-marketing-copy',
        body: {
          'productName': _productName,
          'description': _content['description']?.toString() ?? '',
          'price': _content['price']?.toString() ?? '',
          'platforms': [_platform],
          'creativeDirection':
              '$direction\nTexte actuel à retravailler : ${_captionController.text.trim()}',
          'productImageUrl': _content['image_url']?.toString(),
          'includeVisuals': false,
        },
      );
      final data = response.data;
      final contents = data is Map ? data['contents'] : null;
      if (response.status < 200 ||
          response.status >= 300 ||
          contents is! List ||
          contents.isEmpty) {
        throw Exception(
          data is Map
              ? data['error'] ?? 'Réponse IA invalide.'
              : 'Réponse IA invalide.',
        );
      }
      final generated = Map<String, dynamic>.from(contents.first as Map);
      if (!mounted) return;
      setState(() {
        _captionController.text =
            generated['caption']?.toString() ?? _captionController.text;
        _content['hashtags'] = generated['hashtags'] ?? _content['hashtags'];
        _content['visual_prompt'] =
            generated['visual_prompt'] ?? _content['visual_prompt'];
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = 'La modification IA a échoué : $error');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Map<String, dynamic> _editedContent() => {
    ..._content,
    'platform': _platform,
    'caption': _captionController.text.trim(),
  };

  Future<void> _saveCampaign() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Connectez-vous pour enregistrer ce brouillon.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _supabase.from('campagnes').insert({
        'id_vendeur': user.id,
        'id_produit': _content['id_produit'],
        'nom_campagne': _productName,
        'plateformes': [_platform],
        'contenus': [_editedContent()],
        'statut': 'brouillon',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Brouillon enregistré.')));
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Enregistrement impossible : $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareKit() async {
    final hashtags = _content['hashtags'] is List
        ? (_content['hashtags'] as List).join(' ')
        : '';
    final imageUrl = _content['image_url']?.toString();
    final text = '${_captionController.text.trim()}\n$hashtags';
    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final bytes = await NetworkAssetBundle(
          Uri.parse(imageUrl),
        ).load(imageUrl);
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/jpeg',
              name: 'kit_marketing.jpg',
            ),
          ],
          text: text,
          subject: 'Publication $_platform - $_productName',
        );
      } else {
        await Share.share(
          text,
          subject: 'Publication $_platform - $_productName',
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Partage du visuel indisponible : $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _content['image_url']?.toString();
    final hashtags = _content['hashtags'] is List
        ? (_content['hashtags'] as List).join(' ')
        : '';
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: AppColor.background,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/vendor/marketing-ia');
            }
          },
        ),
        title: const Text('Éditeur de campagne'),
        actions: [
          IconButton(
            tooltip: 'Partager le kit',
            onPressed: _shareKit,
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: 'Enregistrer le brouillon',
            onPressed: _isSaving ? null : _saveCampaign,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            '$_productName · ${_platform.toUpperCase()}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                height: 250,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 100,
                  child: Center(child: Text('Visuel indisponible.')),
                ),
              ),
            )
          else
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppColor.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('Aucun visuel joint à cette publication.'),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _captionController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Texte de la publication',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          if (hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              hashtags,
              style: const TextStyle(
                color: AppColor.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _directionController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Consigne de modification',
              hintText:
                  'Ex. Rends le ton plus chaleureux et ajoute une offre limitée.',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _isGenerating ? null : _refineWithAI,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isGenerating ? 'Génération en cours...' : 'Modifier avec l’IA',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _saveCampaign,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _isSaving ? 'Enregistrement...' : 'Enregistrer le brouillon',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _shareKit,
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Partager / télécharger le kit'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColor.primary)),
          ],
        ],
      ),
    );
  }
}
