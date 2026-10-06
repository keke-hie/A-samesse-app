import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/session_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_screen_shell.dart';

/// Ouvert depuis le lien « mot de passe oublié » reçu par e-mail.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      _showMessage('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (password != _confirmController.text) {
      _showMessage('Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() => _saving = true);
    try {
      final session = SessionService.instance;
      await session.setNewPassword(password);
      if (!mounted) return;
      _showMessage('Mot de passe modifié.');
      context.go(session.homePath);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(friendlyError(error));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: 'Nouveau mot de passe',
      subtitle: 'Choisis le mot de passe de ton compte.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _passwordController,
              hintText: 'Nouveau mot de passe (8 caractères min.)',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _confirmController,
              hintText: 'Confirmer le mot de passe',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Enregistrer',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
