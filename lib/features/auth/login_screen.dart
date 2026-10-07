import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_color.dart';
import '../../core/platform.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_screen_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    // Le mot de passe n'est jamais modifié : un espace peut en faire partie.
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Renseigne ton email et ton mot de passe.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().signIn(email: email, password: password);
      if (mounted) context.go(SessionService.instance.homePath);
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Adresse email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Envoyer le lien'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;
    try {
      await AuthService().sendPasswordReset(email);
      _showMessage(
        'Si un compte existe pour $email, un lien de réinitialisation vient d’être envoyé.',
      );
    } catch (error) {
      _showMessage(friendlyError(error));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: kAdminConsole ? 'Administration' : 'Bon retour !',
      subtitle: kAdminConsole
          ? 'Connecte-toi avec un compte administrateur.'
          : 'Connecte-toi pour retrouver ton espace.',
      leading: kAdminConsole
          ? null
          : IconButton(
              tooltip: 'Retour',
              color: Colors.white,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _emailController,
              hintText: 'Adresse email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _passwordController,
              hintText: 'Mot de passe',
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetPassword,
                child: const Text('Mot de passe oublié ?'),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              text: 'Se connecter',
              isLoading: _isLoading,
              onPressed: _login,
            ),
            if (!kAdminConsole) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Pas encore de compte ?',
                    style: TextStyle(color: AppColor.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('S’inscrire'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
