import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/widgets/apple_button.dart';
import 'auth_screen_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const bool _testMode = bool.fromEnvironment(
    'APP_TEST_MODE',
    defaultValue: false,
  );

  // Contrôleurs généraux
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Contrôleurs spécifiques
  final _addressController = TextEditingController(); // Acheteur
  final _commerceController = TextEditingController(); // Vendeur
  final _contribuableNumController =
      TextEditingController(); // Vendeur (Boutique)

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

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$fileExt'),
      );

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
        const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires.'),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas.'),
        ),
      );
      return;
    }

    // Validation des fichiers selon le rôle
    if (!_testMode && _selectedRole == 'Vendeur') {
      if (_cniImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez fournir la photo de votre CNI.'),
          ),
        );
        return;
      }
      if (_proofImage == null) {
        final label = _typeVente == 'boutique'
            ? 'votre boutique'
            : 'votre stock';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez fournir la photo de $label.')),
        );
        return;
      }
    }

    if (!_testMode && _selectedRole == 'Livreur') {
      if (_cniImage == null || _permisImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Veuillez fournir votre CNI et votre permis de conduire.',
            ),
          ),
        );
        return;
      }
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les conditions d\'utilisation.'),
        ),
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
        contribuableUrl = await _uploadFile(
          _contribuableImage!,
          'contribuable',
        );
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

      if (user != null && mounted && response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Compte créé. Vérifiez votre email pour confirmer l’inscription avant de vous connecter.',
            ),
          ),
        );
        return;
      }

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
            context.go('/vendor/shop-management');
            break;
          case 'Livreur':
            context.go('/delivery/missions');
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
          SnackBar(
            content: Text('Erreur : ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Une erreur est survenue : $e'),
            backgroundColor: Colors.red,
          ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  imageFile != null
                      ? imageFile.name
                      : "Aucune image sélectionnée",
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

  InputDecoration _authDropdownDecoration(String label) {
    const borderColor = Color(0xFFE4B8BA);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: borderColor),
    );

    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(
          color: AuthScreenShell.actionColor,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: 'Créer un compte',
      subtitle: "Rejoignez la communauté A'samesse.",
      leading: IconButton(
        tooltip: 'Retour',
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.16),
        ),
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/login');
          }
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_testMode) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0B84C)),
              ),
              child: const Text(
                'MODE TEST : les justificatifs vendeur/livreur sont ignorés. Ne publie pas cette version.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B4E00),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            "Je souhaite m'inscrire en tant que :",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AuthScreenShell.headingColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Acheteur")),
                  selected: _selectedRole == 'Acheteur',
                  selectedColor: AuthScreenShell.actionColor.withValues(
                    alpha: 0.18,
                  ),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: _selectedRole == 'Acheteur'
                          ? AuthScreenShell.actionColor
                          : const Color(0xFFEAD6D7),
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: _selectedRole == 'Acheteur'
                        ? AuthScreenShell.headingColor
                        : AppColor.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
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
                  selectedColor: AuthScreenShell.actionColor.withValues(
                    alpha: 0.18,
                  ),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: _selectedRole == 'Vendeur'
                          ? AuthScreenShell.actionColor
                          : const Color(0xFFEAD6D7),
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: _selectedRole == 'Vendeur'
                        ? AuthScreenShell.headingColor
                        : AppColor.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
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
                  selectedColor: AuthScreenShell.actionColor.withValues(
                    alpha: 0.18,
                  ),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: _selectedRole == 'Livreur'
                          ? AuthScreenShell.actionColor
                          : const Color(0xFFEAD6D7),
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: _selectedRole == 'Livreur'
                        ? AuthScreenShell.headingColor
                        : AppColor.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedRole = 'Livreur');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: _nameController,
            hintText: "Nom complet",
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _emailController,
            hintText: "Adresse email",
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _phoneController,
            hintText: "Numéro de téléphone",
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          if (_selectedRole == 'Acheteur') ...[
            AuthTextField(controller: _addressController, hintText: "Adresse"),
            const SizedBox(height: 16),
          ],
          if (_selectedRole == 'Vendeur') ...[
            AuthTextField(
              controller: _commerceController,
              hintText: "Nom du commerce",
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _typeVente,
              decoration: _authDropdownDecoration('Type de vente'),
              items: const [
                DropdownMenuItem(
                  value: 'boutique',
                  child: Text("Boutique constante"),
                ),
                DropdownMenuItem(
                  value: 'occasionnel',
                  child: Text("Occasionnel"),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _typeVente = val);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              "Pièces justificatives",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildImageTile(
              title: "Photo de la CNI *",
              imageFile: _cniImage,
              onTap: () => _pickImage((file) => _cniImage = file),
            ),
            _buildImageTile(
              title: _typeVente == 'boutique'
                  ? "Photo de la boutique *"
                  : "Photo du stock *",
              imageFile: _proofImage,
              onTap: () => _pickImage((file) => _proofImage = file),
            ),
            if (_typeVente == 'boutique') ...[
              AuthTextField(
                controller: _contribuableNumController,
                hintText: "Numéro de contribuable",
              ),
              const SizedBox(height: 12),
              _buildImageTile(
                title: "Attestation contribuable (optionnel)",
                imageFile: _contribuableImage,
                onTap: () => _pickImage((file) => _contribuableImage = file),
              ),
            ],
          ],
          if (_selectedRole == 'Livreur') ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedVehicule,
              decoration: _authDropdownDecoration('Type de véhicule'),
              items: const [
                DropdownMenuItem(value: 'Moto', child: Text("Moto")),
                DropdownMenuItem(value: 'Voiture', child: Text("Voiture")),
                DropdownMenuItem(
                  value: 'Tricycle',
                  child: Text("Tricycle / Cargo"),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedVehicule = val);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              "Pièces justificatives",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildImageTile(
              title: "Photo de la CNI *",
              imageFile: _cniImage,
              onTap: () => _pickImage((file) => _cniImage = file),
            ),
            _buildImageTile(
              title: "Permis de conduire *",
              imageFile: _permisImage,
              onTap: () => _pickImage((file) => _permisImage = file),
            ),
          ],
          AuthTextField(
            controller: _passwordController,
            hintText: "Mot de passe",
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _confirmPasswordController,
            hintText: "Confirmer le mot de passe",
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _acceptTerms,
                activeColor: AppColor.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (val) => setState(() => _acceptTerms = val ?? false),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColor.textSecondary,
                      fontSize: 12,
                    ),
                    children: [
                      const TextSpan(text: "J'accepte les "),
                      TextSpan(
                        text: "conditions d'utilisation",
                        style: TextStyle(
                          color: AppColor.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: " et la politique de confidentialité.",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AppleButton(
                  text: "S'inscrire",
                  backgroundColor: AuthScreenShell.actionColor,
                  onPressed: _signUp,
                  height: 48,
                ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Déjà inscrit ? ",
                style: TextStyle(color: AppColor.textSecondary, fontSize: 14),
              ),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text(
                  "Se connecter",
                  style: TextStyle(
                    color: AuthScreenShell.headingColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
