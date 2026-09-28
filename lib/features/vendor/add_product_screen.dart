import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/widgets/apple_button.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prixController = TextEditingController();
  final _stockController = TextEditingController();
  final String _categorie = 'friandises';
  
  XFile? _imageFile;
  bool _isLoading = false;
  String? _idBoutique;

  @override
  void initState() {
    super.initState();
    _recupererIdBoutique();
  }

  Future<void> _recupererIdBoutique() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('boutiques')
          .select('id_boutique')
          .eq('id_vendeur', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _idBoutique = response['id_boutique'].toString();
        });
      }
    } catch (e) {
      print('Erreur récupération boutique : $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs et choisir une image.')),
      );
      return;
    }

    if (_idBoutique == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur : Aucune boutique associée à ce compte.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      const storageBucket = 'images'; // Le bucket Supabase s'appelle 'images'
      
      final bytes = await _imageFile!.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.name}';

      // 1. Upload de l'image dans le bucket 'images'
      await supabase.storage.from(storageBucket).uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      // 2. Récupération de l'URL publique
      final publicUrl = supabase.storage.from(storageBucket).getPublicUrl(fileName);

      // 3. Insertion dans la table `produits`
      await supabase.from('produits').insert({
        'id_vendeur': supabase.auth.currentUser!.id,
        'id_boutique': _idBoutique,
        'nom_produit': _nomController.text,
        'description': _descriptionController.text,
        'prix': double.parse(_prixController.text),
        'stock': int.parse(_stockController.text),
        'image': publicUrl,
        'catégorie': _categorie,
        'date': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit ajouté avec succès !')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un produit')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(labelText: 'Nom du produit'),
                validator: (v) => v!.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prixController,
                decoration: const InputDecoration(labelText: 'Prix (FCFA)'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Quantité en stock'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 20),
              _imageFile == null
                  ? OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Ajouter une photo du produit'),
                    )
                  : Row(
                      children: [
                        const Text('Photo sélectionnée ✅'),
                        const Spacer(),
                        TextButton(
                          onPressed: _pickImage,
                          child: const Text('Modifier'),
                        ),
                      ],
                    ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitProduct,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Publier le produit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}