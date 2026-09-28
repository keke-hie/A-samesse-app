import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Importations des écrans
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/customer/home/home_screen.dart';
import '../../features/customer/home/product_detail_screen.dart';
import '../../features/customer/deals/deals_screen.dart';
import '../../features/customer/cart/cart_screen.dart';
import '../../features/customer/orders/order_tracking_screen.dart';
import '../../features/customer/profile/profile_screen.dart';
import 'package:asamesse_app/features/vendor/marketing_ia_screen.dart';
import '../../features/vendor/campaign_refine_screen.dart';
import '../../features/delivery/delivery_map_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/analytics_screen.dart';
import '../../navigation/main_wrapper.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    // --- AUTHENTIFICATION ---
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // --- NAVIGATION CLIENT AVEC BOTTOM NAV BAR ---
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainWrapper(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'product-detail',
              builder: (context, state) => ProductDetailScreen(
                product: state.extra as Map<String, dynamic>?,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/deals',
          builder: (context, state) => const DealsScreen(),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => CartScreen(
            extraData: state.extra as Map<String, dynamic>?,
          ),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) => OrderTrackingScreen(
            orderData: state.extra as Map<String, dynamic>?,
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // --- ESPACE VENDEUR ---
    GoRoute(
      path: '/vendor/marketing-ia',
      builder: (context, state) => const MarketingiaScreen(),
    ),
    GoRoute(
      path: '/vendor/campaign-refine',
      builder: (context, state) => const CampaignRefineScreen(),
    ),

    // --- ESPACE LIVREUR ---
    GoRoute(
      path: '/delivery/map',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return DeliveryMapScreen(
          idCommande: extra?['id_commande']?.toString() ?? extra?['id']?.toString(),
          extraData: extra,
        );
      },
    ),

    // --- ESPACE ADMINISTRATEUR ---
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
  ],
);