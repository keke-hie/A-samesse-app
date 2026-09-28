import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_color.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  bool _isCheckingSession = true;

  final List<Map<String, dynamic>> _slides = [
    {
      "badge": "SÉLECTION OFFICIELLE",
      "title": "L'Excellence du Shopping au Cameroun",
      "subtitle":
          "Découvrez les plus belles créations, marques et boutiques vérifiées réunies sur une seule marketplace d'exception.",
      "icon": Icons.verified_outlined,
      "tag": "100% Authentique",
    },
    {
      "badge": "VENTES PRIVÉES",
      "title": "Ventes Flash & Offres Confidentielles",
      "subtitle":
          "Accédez chaque semaine à des ventes éphémères exclusives et profitez des meilleurs prix sur la mode et la tech.",
      "icon": Icons.bolt_outlined,
      "tag": "Jusqu'à -50%",
    },
    {
      "badge": "SÉRÉNITÉ & CONFIANCE",
      "title": "Livraison Express & Transactions Sécurisées",
      "subtitle":
          "Expédition rapide à Douala, Yaoundé et dans toutes les régions. Réglez à la réception ou via Mobile Money.",
      "icon": Icons.security_outlined,
      "tag": "Garantie A'samesse",
    },
  ];

  @override
  void initState() {
    super.initState();

    // Animation du logo (respiration douce)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Animation de transition vers la page de bienvenue
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _checkSessionAndProceed();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _checkSessionAndProceed() async {
    // Laisser le temps à l'effet de chargement initial (1.2s)
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // Utilisateur déjà authentifié : redirection directe selon le rôle
      try {
        final userId = session.user.id;
        String? role = session.user.userMetadata?['role']?.toString();

        if (role == null) {
          // Essayer la table utilisateurs
          final userDoc = await Supabase.instance.client
              .from('utilisateurs')
              .select('role')
              .eq('id', userId)
              .maybeSingle();

          role = userDoc?['role']?.toString();
        }

        if (role == null) {
          // Essayer la table profiles
          final profileDoc = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', userId)
              .maybeSingle();

          role = profileDoc?['role']?.toString();
        }

        if (!mounted) return;

        switch (role?.toLowerCase()) {
          case 'vendeur':
            context.go('/vendor/marketing-ia');
            break;
          case 'livreur':
            context.go('/delivery/map');
            break;
          case 'admin':
            context.go('/admin/dashboard');
            break;
          case 'acheteur':
          default:
            context.go('/home');
            break;
        }
        return;
      } catch (_) {
        if (mounted) context.go('/home');
        return;
      }
    }

    // Aucun utilisateur connecté : afficher la page d'accueil d'exception
    setState(() {
      _isCheckingSession = false;
    });
    _fadeController.forward();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      // Écran d'initialisation de prestige (Splash de démarrage rapide)
      return Scaffold(
        backgroundColor: AppColor.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColor.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColor.primary.withValues(alpha: 0.28),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: AppColor.gold.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "A'",
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "A'samesse",
                style: TextStyle(
                  color: AppColor.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColor.goldLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColor.gold.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  "MARKETPLACE CAMEROUN",
                  style: TextStyle(
                    color: AppColor.goldDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Grand Landing Page de Bienvenue
    return Scaffold(
      backgroundColor: AppColor.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Barre Supérieure Élégante
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge pays / prestige
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColor.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColor.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "CAMEROUN",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: AppColor.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bouton Explorer en invité
                    TextButton.icon(
                      onPressed: () => context.go('/home'),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: AppColor.primary,
                      ),
                      label: const Text(
                        "Explorer",
                        style: TextStyle(
                          color: AppColor.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColor.primarySoft,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu Principal Déroulant
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Monogramme & Logo de la Maison
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B1E1E), Color(0xFFA53333)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColor.gold.withValues(alpha: 0.8),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColor.primary.withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "A'",
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Nom de Marque
                      const Text(
                        "A'samesse",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: AppColor.primary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Slogan Élégant
                      const Text(
                        "L'ART DU SHOPPING & DE L'ÉLÉGANCE",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: AppColor.goldDark,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Carrousel de Présentation des Atouts
                      SizedBox(
                        height: 215,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: _slides.length,
                          itemBuilder: (context, index) {
                            final slide = _slides[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              padding: const EdgeInsets.all(22.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24.0),
                                border: Border.all(color: AppColor.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColor.goldLight,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          slide['badge'],
                                          style: const TextStyle(
                                            color: AppColor.goldDark,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColor.primarySoft,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          slide['icon'] as IconData,
                                          color: AppColor.primary,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    slide['title'],
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColor.textPrimary,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    slide['subtitle'],
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColor.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      slide['tag'],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Indicateurs de Page (Capsules animées)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            height: 6,
                            width: _currentPage == index ? 24 : 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColor.primary
                                  : AppColor.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bandeau de Réassurance / Garanties
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: AppColor.cardBackground.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _PillarItem(
                              icon: Icons.local_shipping_outlined,
                              label: "Livraison 24/48h",
                            ),
                            _DividerDot(),
                            _PillarItem(
                              icon: Icons.verified_user_outlined,
                              label: "Paiement 100% Sûr",
                            ),
                            _DividerDot(),
                            _PillarItem(
                              icon: Icons.support_agent_outlined,
                              label: "Support 7j/7",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // Actions Inférieures (Boutons d'Appel à l'Action)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton Principal : Découvrir la Boutique
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.go('/home'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Explorer la Marketplace",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Ligne Secondaire : Connexion & Inscription
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => context.go('/login'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColor.textPrimary,
                                side: const BorderSide(color: AppColor.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Se connecter",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => context.go('/register'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1E1E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Créer un compte",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Espace Commerçant / Vendeur
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
                          children: [
                            TextSpan(text: "Vous êtes commerçant ? "),
                            TextSpan(
                              text: "Vendez sur A'samesse",
                              style: TextStyle(
                                color: AppColor.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillarItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PillarItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColor.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColor.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DividerDot extends StatelessWidget {
  const _DividerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: AppColor.border,
        shape: BoxShape.circle,
      ),
    );
  }
}