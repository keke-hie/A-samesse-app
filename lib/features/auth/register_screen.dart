import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_color.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_screen_shell.dart';

enum _SignupRole {
  buyer('acheteur', 'Acheteur', Icons.shopping_bag_outlined),
  vendor('vendeur', 'Vendeur', Icons.storefront_outlined),
  courier('livreur', 'Livreur', Icons.delivery_dining_outlined);

  const _SignupRole(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _commerceController = TextEditingController();
  final _taxNumberController = TextEditingController();

  _SignupRole _role = _SignupRole.buyer;
  String _saleType = 'boutique';
  String _vehicle = 'Moto';
  bool _acceptTerms = false;
  bool _isLoading = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _passwordController,
      _confirmPasswordController,
      _addressController,
      _commerceController,
      _taxNumberController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_nameController.text.trim().isEmpty) return 'Indique ton nom complet.';
    if (!_emailPattern.hasMatch(_emailController.text.trim())) {
      return 'Adresse email invalide.';
    }
    if (_role != _SignupRole.buyer && _phoneController.text.trim().isEmpty) {
      return 'Le téléphone est obligatoire pour les comptes professionnels.';
    }
    if (_role == _SignupRole.vendor && _commerceController.text.trim().isEmpty) {
      return 'Indique le nom de ton commerce.';
    }
    if (_passwordController.text.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Les mots de passe ne correspondent pas.';
    }
    if (!_acceptTerms) return 'Accepte les conditions d’utilisation.';
    return null;
  }

  Future<void> _signUp() async {
    final validationError = _validate();
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Le rôle n'est qu'une demande : la base le contrôle et met les comptes
      // vendeur / livreur en attente de validation. Les pièces justificatives
      // sont envoyées une fois connecté, dans un espace privé.
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
          'telephone': _phoneController.text.trim(),
          'role': _role.value,
          if (_role == _SignupRole.buyer)
            'adresse': _addressController.text.trim(),
          if (_role == _SignupRole.vendor) ...{
            'nom_commerce': _commerceController.text.trim(),
            'type_vente': _saleType,
            'numero_contribuable': _taxNumberController.text.trim(),
          },
          if (_role == _SignupRole.courier) 'type_vehicule': _vehicle,
        },
      );
      if (!mounted) return;

      if (response.session == null) {
        _showMessage(
          'Compte créé ! Confirme ton adresse email puis connecte-toi.',
        );
        context.go('/login');
        return;
      }

      final session = SessionService.instance;
      await session.refresh();
      if (mounted) context.go(session.homePath);
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: 'Créer un compte',
      subtitle: "Rejoignez la communauté A'samesse.",
      leading: IconButton(
        tooltip: 'Retour',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: Colors.white,
        onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Je m’inscris en tant que',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            SegmentedButton<_SignupRole>(
              showSelectedIcon: false,
              segments: [
                for (final role in _SignupRole.values)
                  ButtonSegment(
                    value: role,
                    label: Text(role.label),
                    icon: Icon(role.icon, size: 18),
                  ),
              ],
              selected: {_role},
              onSelectionChanged: (selection) =>
                  setState(() => _role = selection.first),
            ),
            if (_role != _SignupRole.buyer) ...[
              const SizedBox(height: 12),
              _InfoNote(
                text: _role == _SignupRole.vendor
                    ? 'Après l’inscription, tu enverras ta CNI et une photo de ta boutique ou de ton stock. Ta boutique sera ouverte après validation.'
                    : 'Après l’inscription, tu enverras ta CNI et ton permis. Tu pourras livrer après validation.',
              ),
            ],
            const SizedBox(height: 18),
            AuthTextField(
              controller: _nameController,
              hintText: 'Nom complet',
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _emailController,
              hintText: 'Adresse email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _phoneController,
              hintText: _role == _SignupRole.buyer
                  ? 'Téléphone (facultatif)'
                  : 'Téléphone',
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 12),
            if (_role == _SignupRole.buyer) ...[
              AuthTextField(
                controller: _addressController,
                hintText: 'Quartier / adresse (facultatif)',
                autofillHints: const [AutofillHints.fullStreetAddress],
              ),
              const SizedBox(height: 12),
            ],
            if (_role == _SignupRole.vendor) ...[
              AuthTextField(
                controller: _commerceController,
                hintText: 'Nom du commerce',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _saleType,
                decoration: const InputDecoration(labelText: 'Type de vente'),
                items: const [
                  DropdownMenuItem(
                    value: 'boutique',
                    child: Text('Boutique permanente'),
                  ),
                  DropdownMenuItem(
                    value: 'occasionnel',
                    child: Text('Vente occasionnelle'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _saleType = value ?? _saleType),
              ),
              const SizedBox(height: 12),
              if (_saleType == 'boutique') ...[
                AuthTextField(
                  controller: _taxNumberController,
                  hintText: 'Numéro de contribuable (facultatif)',
                ),
                const SizedBox(height: 12),
              ],
            ],
            if (_role == _SignupRole.courier) ...[
              DropdownButtonFormField<String>(
                initialValue: _vehicle,
                decoration: const InputDecoration(
                  labelText: 'Type de véhicule',
                ),
                items: const [
                  DropdownMenuItem(value: 'Moto', child: Text('Moto')),
                  DropdownMenuItem(value: 'Voiture', child: Text('Voiture')),
                  DropdownMenuItem(
                    value: 'Tricycle',
                    child: Text('Tricycle / cargo'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _vehicle = value ?? _vehicle),
              ),
              const SizedBox(height: 12),
            ],
            AuthTextField(
              controller: _passwordController,
              hintText: 'Mot de passe (8 caractères min.)',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _confirmPasswordController,
              hintText: 'Confirmer le mot de passe',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _acceptTerms,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) =>
                  setState(() => _acceptTerms = value ?? false),
              title: const Text(
                'J’accepte les conditions d’utilisation et la politique de confidentialité.',
                style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Créer mon compte',
              isLoading: _isLoading,
              onPressed: _signUp,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Déjà inscrit ?',
                  style: TextStyle(color: AppColor.textSecondary, fontSize: 13),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Se connecter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColor.goldLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColor.goldDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColor.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
