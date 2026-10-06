import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Importations des écrans
import '../../features/auth/pending_account_screen.dart';
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
import '../../features/vendor/campaign_editor_screen.dart';
import '../../features/vendor/shop_management_screen.dart';
import '../../features/vendor/vendor_storefront_screen.dart';
import '../../features/vendor/vendor_orders_screen.dart';
import '../../features/vendor/vendor_dashboard_screen.dart';
import '../../features/delivery/courier_map_screen.dart';
import '../../features/delivery/courier_missions_screen.dart';
import '../../features/delivery/delivery_tracking_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_management_screen.dart';
import '../../navigation/main_wrapper.dart';
import '../../navigation/vendor_wrapper.dart';
import '../../navigation/delivery_wrapper.dart';
import '../../navigation/admin_wrapper.dart';
import '../services/session_service.dart';
import 'route_guard.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  refreshListenable: SessionService.instance,
  redirect: (context, state) => guardRoute(SessionService.instance, state.uri),
  routes: [
    // --- AUTHENTIFICATION ---
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/pending',
      builder: (context, state) => const PendingAccountScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
              path: 'product/:productId',
              builder: (context, state) => ProductDetailScreen(
                productId: state.pathParameters['productId']!,
                initialProduct: state.extra as Map<String, dynamic>?,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/deals',
          builder: (context, state) => const DealsScreen(),
        ),
        GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
        GoRoute(
          path: '/orders',
          builder: (context, state) => const OrderTrackingScreen(),
          routes: [
            GoRoute(
              path: 'track/:orderId',
              builder: (context, state) => DeliveryTrackingScreen(
                orderId: state.pathParameters['orderId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // --- ESPACE VENDEUR ---
    ShellRoute(
      builder: (context, state, child) => VendorWrapper(child: child),
      routes: [
        GoRoute(
          path: '/vendor/dashboard',
          builder: (context, state) => const VendorDashboardScreen(),
        ),
        GoRoute(
          path: '/vendor/shop-management',
          builder: (context, state) => const ShopManagementScreen(),
        ),
        GoRoute(
          path: '/vendor/products',
          builder: (context, state) =>
              const ShopManagementScreen(productsOnly: true),
        ),
        GoRoute(
          path: '/vendor/orders',
          builder: (context, state) => const VendorOrdersScreen(),
        ),
        GoRoute(
          path: '/vendor/sales',
          builder: (context, state) => const VendorOrdersScreen(),
        ),
        GoRoute(
          path: '/vendor/deals',
          builder: (context, state) => const DealsScreen(),
        ),
        GoRoute(
          path: '/vendor/marketing-ia',
          builder: (context, state) => MarketingAiScreen(
            initialPlatform: state.uri.queryParameters['platform'],
          ),
        ),
        GoRoute(
          path: '/vendor/campaign-refine',
          builder: (context, state) {
            final content = state.extra as Map<String, dynamic>?;
            return content == null
                ? MarketingAiScreen()
                : CampaignEditorScreen(initialContent: content);
          },
        ),
        GoRoute(
          path: '/vendor/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/shops/:shopId',
      builder: (context, state) =>
          VendorStorefrontScreen(shopId: state.pathParameters['shopId']!),
    ),

    // --- ESPACE LIVREUR ---
    ShellRoute(
      builder: (context, state, child) => DeliveryWrapper(child: child),
      routes: [
        GoRoute(
          path: '/delivery/missions',
          builder: (context, state) => const CourierMissionsScreen(),
        ),
        GoRoute(
          path: '/delivery/map',
          builder: (context, state) => const CourierMapScreen(),
          routes: [
            GoRoute(
              path: ':orderId',
              builder: (context, state) => DeliveryTrackingScreen(
                orderId: state.pathParameters['orderId']!,
                courierMode: true,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/delivery/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // --- ESPACE ADMINISTRATEUR ---
    ShellRoute(
      builder: (context, state, child) => AdminWrapper(child: child),
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/management',
          builder: (context, state) => AdminManagementScreen(
            tab: AdminTab.parse(state.uri.queryParameters['tab']),
          ),
        ),
        GoRoute(
          path: '/admin/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
