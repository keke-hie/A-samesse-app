import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/apple_button.dart';
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
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
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
      title: 'Bon retour !',
      subtitle: 'Connectez-vous pour retrouver votre espace.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _emailController,
            hintText: "Adresse email",
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 13),
          AuthTextField(
            controller: _passwordController,
            hintText: "Mot de passe",
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 5),
                minimumSize: const Size(0, 30),
                foregroundColor: AuthScreenShell.headingColor,
              ),
              child: const Text(
                'Mot de passe oublié ?',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 7),
          _isLoading
              ? const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : AppleButton(
                  text: 'Se connecter',
                  backgroundColor: AuthScreenShell.actionColor,
                  onPressed: _login,
                  height: 48,
                ),
          const SizedBox(height: 19),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Pas encore de compte ?',
                style: TextStyle(fontSize: 12, color: Color(0xFF9B7779)),
              ),
              TextButton(
                onPressed: () => context.go('/register'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  minimumSize: const Size(0, 32),
                  foregroundColor: AuthScreenShell.headingColor,
                ),
                child: const Text(
                  'Inscrivez-vous',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
