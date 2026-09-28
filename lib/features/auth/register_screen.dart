import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/widgets/apple_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Contrôleurs généraux
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Contrôleurs spécifiques
  final _addressController = TextEditingController(); // Acheteur
  final _commerceController = TextEditingController(); // Vendeur
  final _contribuableNumController = TextEditingController(); // Vendeur (Boutique)

  // Rôles et types
  String _selectedRole = 'Acheteur';
  String _typeVente = 'boutique'; // 'boutique' ou 'occasionnel'
  String _selectedVehicule = 'Moto'; // Default pour livreur

  bool _acceptTerms = false;
  bool _isLoading = false;

  // Fichiers d'images sélectionnées
  XFile? _cniImage;
  XFile? _proofImage; // Boutique physique ou Stock
  XFile? _permisImage; // Livreur
  XFile? _contribuableImage; // Vendeur avec boutique

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _commerceController.dispose();
    _contribuableNumController.dispose();
    super.dispose();
  }

  // Méthode générique pour sélectionner une image
  Future<void> _pickImage(Function(XFile) onPicked) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        onPicked(image);
      });
    }
  }

  // Upload d'une image vers Supabase Storage et récupération de l'URL publique
  Future<String?> _uploadFile(XFile file, String folder) async {
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = '$folder/$fileName';

      final storage = Supabase.instance.client.storage.from('documents');

      if (kIsWeb) {
        await storage.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/$fileExt'));
      } else {
        await storage.upload(path, File(file.path));
      }

      return storage.getPublicUrl(path);
    } catch (e) {
      debugPrint('Erreur lors de l\'upload de l\'image: $e');
      return null;
    }
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
      );
      return;
    }

    // Validation des fichiers selon le rôle
    if (_selectedRole == 'Vendeur') {
      if (_cniImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez fournir la photo de votre CNI.')),
        );
        return;
      }
      if (_proofImage == null) {
        final label = _typeVente == 'boutique' ? 'votre boutique' : 'votre stock';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez fournir la photo de $label.')),
        );
        return;
      }
    }

    if (_selectedRole == 'Livreur') {
      if (_cniImage == null || _permisImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez fournir votre CNI et votre permis de conduire.')),
        );
        return;
      }
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez accepter les conditions d\'utilisation.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload des images requises
      String? cniUrl;
      String? proofUrl;
      String? permisUrl;
      String? contribuableUrl;

      if (_cniImage != null) {
        cniUrl = await _uploadFile(_cniImage!, 'cni');
      }
      if (_proofImage != null) {
        proofUrl = await _uploadFile(_proofImage!, 'proofs');
      }
      if (_permisImage != null) {
        permisUrl = await _uploadFile(_permisImage!, 'permis');
      }
      if (_contribuableImage != null) {
        contribuableUrl = await _uploadFile(_contribuableImage!, 'contribuable');
      }

      // 2. Inscription Supabase Auth + transmission des métadonnées au trigger
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'telephone': phone,
          'role': _selectedRole,
          'adresse': _addressController.text.trim(),
          'nom_commerce': _commerceController.text.trim(),
          'type_vente': _typeVente,
          'type_vehicule': _selectedVehicule,
          'numero_contribuable': _contribuableNumController.text.trim(),
          'cni_url': cniUrl,
          'proof_image_url': proofUrl,
          'permis_url': permisUrl,
          'contribuable_doc_url': contribuableUrl,
        },
      );

      final user = response.user;

      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedRole == 'Acheteur'
                  ? 'Inscription réussie !'
                  : 'Inscription effectuée. Votre compte est en cours de validation par l\'administrateur.',
            ),
          ),
        );

        // Redirection GoRouter
        switch (_selectedRole) {
          case 'Vendeur':
            context.go('/vendor/marketing-ia');
            break;
          case 'Livreur':
            context.go('/delivery/map');
            break;
          case 'Acheteur':
          default:
            context.go('/home');
            break;
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Une erreur est survenue : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildImageTile({
    required String title,
    required XFile? imageFile,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            imageFile != null ? Icons.check_circle : Icons.upload_file,
            color: imageFile != null ? Colors.green : AppColor.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  imageFile != null ? imageFile.name : "Aucune image sélectionnée",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(imageFile != null ? "Changer" : "Ajouter"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login'); // Redirection de secours vers la connexion
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Créer un compte",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Inscrivez-vous pour commencer sur A'samesse.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Sélecteur de Rôle
              const Text(
                "Je souhaite m'inscrire en tant que :",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Acheteur")),
                      selected: _selectedRole == 'Acheteur',
                      selectedColor: AppColor.primary.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedRole = 'Acheteur');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Vendeur")),
                      selected: _selectedRole == 'Vendeur',
                      selectedColor: AppColor.primary.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedRole = 'Vendeur');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Livreur")),
                      selected: _selectedRole == 'Livreur',
                      selectedColor: AppColor.primary.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedRole = 'Livreur');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Champs Généraux
              CustomTextField(
                controller: _nameController,
                hintText: "Nom complet",
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                hintText: "Adresse email",
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                hintText: "Numéro de téléphone",
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // --- ACHETEUR ---
              if (_selectedRole == 'Acheteur') ...[
                CustomTextField(
                  controller: _addressController,
                  hintText: "Adresse",
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
              ],

              // --- VENDEUR ---
              if (_selectedRole == 'Vendeur') ...[
                CustomTextField(
                  controller: _commerceController,
                  hintText: "Nom du commerce",
                  prefixIcon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _typeVente,
                  decoration: const InputDecoration(
                    labelText: "Type de vente",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'boutique', child: Text("Boutique constante")),
                    DropdownMenuItem(value: 'occasionnel', child: Text("Occasionnel (Écoulement de stock)")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _typeVente = val);
                  },
                ),
                const SizedBox(height: 16),

                // Documents Vendeur
                const Text(
                  "Pièces justificatives (Identification & Boutique)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _buildImageTile(
                  title: "Photo de la CNI *",
                  imageFile: _cniImage,
                  onTap: () => _pickImage((file) => _cniImage = file),
                ),
                _buildImageTile(
                  title: _typeVente == 'boutique' ? "Photo de la boutique physique *" : "Photo du stock de produits *",
                  imageFile: _proofImage,
                  onTap: () => _pickImage((file) => _proofImage = file),
                ),

                if (_typeVente == 'boutique') ...[
                  CustomTextField(
                    controller: _contribuableNumController,
                    hintText: "Numéro de contribuable (Optionnel)",
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildImageTile(
                    title: "Document / Attestation de contribuable (Optionnel)",
                    imageFile: _contribuableImage,
                    onTap: () => _pickImage((file) => _contribuableImage = file),
                  ),
                ],
              ],

              // --- LIVREUR ---
              if (_selectedRole == 'Livreur') ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedVehicule,
                  decoration: const InputDecoration(
                    labelText: "Type de véhicule",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.two_wheeler_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Moto', child: Text("Moto")),
                    DropdownMenuItem(value: 'Voiture', child: Text("Voiture")),
                    DropdownMenuItem(value: 'Tricycle', child: Text("Tricycle / Cargo")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedVehicule = val);
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  "Pièces justificatives (Identification & Conduite)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _buildImageTile(
                  title: "Photo de la CNI *",
                  imageFile: _cniImage,
                  onTap: () => _pickImage((file) => _cniImage = file),
                ),
                _buildImageTile(
                  title: "Photo du Permis de conduire *",
                  imageFile: _permisImage,
                  onTap: () => _pickImage((file) => _permisImage = file),
                ),
              ],

              // Mot de passe
              CustomTextField(
                controller: _passwordController,
                hintText: "Mot de passe",
                prefixIcon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmPasswordController,
                hintText: "Confirmer le mot de passe",
                prefixIcon: Icons.lock_clock_outlined,
                obscureText: true,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    activeColor: AppColor.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _acceptTerms = val ?? false),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 12),
                        children: [
                          const TextSpan(text: "J'accepte les "),
                          TextSpan(
                            text: "conditions d'utilisation",
                            style: TextStyle(color: AppColor.primary, fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: " et la politique de confidentialité."),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AppleButton(
                      text: "S'inscrire",
                      onPressed: _signUp,
                    ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Vous avez déjà un compte ? ", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.go('/login'), // Remplacé par context.go pour cibler directement la page de connexion
                    child: Text(
                      "Se connecter",
                      style: TextStyle(color: AppColor.primary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}