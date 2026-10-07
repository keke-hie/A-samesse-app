import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_color.dart';
import '../../core/services/session_service.dart';

/// Écran de démarrage : attend le chargement du profil, puis redirige
/// l'utilisateur connecté vers son espace ou affiche l'accueil visiteur.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _taglines = [
    'L’excellence du shopping au Cameroun',
    'Vos boutiques préférées, livrées chez vous',
    'Ventes flash et vide-dressings chaque semaine',
  ];

  bool _showWelcome = false;
  int _taglineIndex = 0;
  Timer? _taglineTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final session = SessionService.instance;
    await Future.wait([
      session.ready,
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    if (!mounted) return;
    if (session.isLoggedIn) {
      context.go(session.homePath);
      return;
    }
    setState(() => _showWelcome = true);
    _taglineTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      setState(() => _taglineIndex = (_taglineIndex + 1) % _taglines.length);
    });
  }

  @override
  void dispose() {
    _taglineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColor.primaryLight, AppColor.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    const _Logo(),
                    const SizedBox(height: 20),
                    const Text(
                      "A'samesse",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'serif',
                        fontSize: 40,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'MARKETPLACE CAMEROUN',
                      style: TextStyle(
                        color: AppColor.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedOpacity(
                      opacity: _showWelcome ? 1 : 0,
                      duration: const Duration(milliseconds: 400),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          _taglines[_taglineIndex],
                          key: ValueKey(_taglineIndex),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    if (!_showWelcome)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    else ...[
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColor.primary,
                          minimumSize: const Size.fromHeight(54),
                        ),
                        onPressed: () => context.go('/home'),
                        child: const Text('Découvrir le catalogue'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          minimumSize: const Size.fromHeight(54),
                        ),
                        onPressed: () => context.go('/login'),
                        child: const Text('Se connecter'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColor.gold,
                        ),
                        onPressed: () => context.go('/register'),
                        child: const Text('Créer un compte'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: AppColor.gold, width: 2),
      ),
      alignment: Alignment.center,
      child: const Text(
        "A'",
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
