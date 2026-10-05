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





    final List<String> _taglines = [
    "L'excellence du shopping au Cameroun",
    "Vos marques préférées, livrées chez vous",
  ];


  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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

      final nextPage = (_currentPage + 1) % _taglines.length;

      if (mounted) {
        setState(() => _currentPage = nextPage);
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _checkSessionAndProceed() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      try {
        final userId = session.user.id;
        String? role;
        final userDoc = await Supabase.instance.client
            .from('utilisateurs')
            .select('role')
            .eq('id_utilisateur', userId)
            .maybeSingle();

        role =
            userDoc?['role']?.toString() ??
            session.user.userMetadata?['role']?.toString();

        if (!mounted) return;

        switch (role?.toLowerCase()) {
          case 'vendeur':
            context.go('/vendor/shop-management');
            return;
          case 'livreur':
            context.go('/delivery/missions');
            return;
          case 'admin':
          case 'administrateur':
            context.go('/admin/dashboard');
            return;
          case 'acheteur':
          default:
            context.go('/home');
            return;
        }
      } catch (_) {
        if (mounted) context.go('/home');
        return;
      }
    }

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColor.goldLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColor.gold.withValues(alpha: 0.3),
                  ),
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

















































































































































































































        return Scaffold(
      backgroundColor: AppColor.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // Monogramme & Logo Central (Style Minimaliste)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColor.primary,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                "A'samesse",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  color: AppColor.textPrimary,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Tagline Discrète
              SizedBox(
                height: 50,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: _taglines.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _taglines[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColor.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Indicateurs discrets
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _taglines.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 4,
                    width: _currentPage == index ? 12 : 4,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? AppColor.primary : AppColor.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Actions Minimalistes (Pill Style comme au Home)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () => context.go('/home'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.darkPill,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Découvrir",
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => context.go('/login'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                              ),
                            ),
                            child: const Text(
                              "Connexion",
                              style: TextStyle(
                                color: AppColor.textPrimary, 
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: () => context.go('/register'),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "S'inscrire",
                              style: TextStyle(
                                color: AppColor.textPrimary, 
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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