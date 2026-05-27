import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lastbite/features/auth/screens/login_screen.dart';
import 'package:lastbite/features/auth/screens/register_screen.dart';
import 'package:lastbite/features/user/screens/user_main_screen.dart';
import 'package:lastbite/features/user/screens/user_home_screen.dart';
import 'package:lastbite/features/auth/screens/register_merchant_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_main_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_product_management_screen.dart';
import 'package:lastbite/features/merchant/screens/add_product_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_order_list_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_order_detail_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_chat_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_store_profile_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_settings_screen.dart';
import 'package:lastbite/features/merchant/screens/merchant_balance_screen.dart';
import 'package:lastbite/features/merchant/screens/withdrawal_screen.dart';
import 'package:lastbite/features/user/screens/user_explore_screen.dart';
import 'package:lastbite/features/user/screens/user_chat_screen.dart';
import 'package:lastbite/features/shared/chat_detail_screen.dart';
import 'package:lastbite/features/shared/splash_screen.dart';
import 'package:lastbite/features/user/screens/user_orders_screen.dart';
import 'package:lastbite/features/user/screens/user_profile_screen.dart';
import 'package:lastbite/features/user/screens/edit_profile_screen.dart';
import 'package:lastbite/features/user/screens/change_password_screen.dart';
import 'package:lastbite/features/user/screens/user_address_screen.dart';
import 'package:lastbite/features/user/screens/merchant_store_screen.dart';
import 'package:lastbite/features/user/screens/product_detail_screen.dart';
import 'package:lastbite/features/user/screens/category_products_screen.dart';
import 'package:lastbite/features/user/screens/product_search_screen.dart';
import 'package:lastbite/features/user/screens/cart_screen.dart';
import 'package:lastbite/features/user/screens/checkout_screen.dart';
import 'package:lastbite/features/user/screens/payment_detail_screen.dart';
import 'package:lastbite/features/user/screens/user_order_detail_screen.dart';
import 'package:lastbite/core/models/product_model.dart';
import 'package:lastbite/core/models/order_model.dart';
import 'package:lastbite/core/models/cart_item_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/features/auth/providers/auth_provider.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateAsync = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final authEvent = authStateAsync.value;
      final isAuthenticated = authEvent?.session != null;

      if (state.matchedLocation == '/splash') {
        return null;
      }

      final isGoingToAuth =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isGoingToAuth) {
        return '/login';
      }

      if (isAuthenticated && isGoingToAuth) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/register-merchant',
        builder: (context, state) => const RegisterMerchantScreen(),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final product = state.extra as ProductModel?;
          return ProductDetailScreen(productId: id, product: product);
        },
      ),

      GoRoute(
        path: '/merchant/products',
        builder: (context, state) => const MerchantProductManagementScreen(),
      ),
      GoRoute(
        path: '/merchant/add-product',
        builder: (context, state) => const AddProductScreen(),
      ),
      GoRoute(
        path: '/merchant/edit-product',
        builder: (context, state) => AddProductScreen(
          productToEdit: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/merchant/settings',
        builder: (context, state) => const MerchantSettingsScreen(),
      ),
      GoRoute(
        path: '/merchant/balance',
        builder: (context, state) => const MerchantBalanceScreen(),
      ),
      GoRoute(
        path: '/merchant/withdraw',
        builder: (context, state) => const WithdrawalScreen(),
      ),
      GoRoute(
        path: '/merchant/order-detail/:id',
        builder: (context, state) {
          final order = state.extra as OrderModel;
          return MerchantOrderDetailScreen(order: order);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MerchantMainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/merchant/dashboard',
                builder: (context, state) => const MerchantDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/merchant/orders',
                builder: (context, state) => const MerchantOrderListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/merchant/chats',
                builder: (context, state) => const MerchantChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/merchant/store-profile',
                builder: (context, state) => const MerchantStoreProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatDetailScreen(
            chatId: extra['chatId'] as String? ?? '',
            peerName: extra['peerName'] as String? ?? 'Chat',
            peerAvatar: extra['peerAvatar'] as String?,
            isUserSide: extra['isUserSide'] as bool? ?? true,
            productName: extra['productName'] as String?,
            productPrice: extra['productPrice'] as String?,
            productImage: extra['productImage'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/category/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          final name = state.uri.queryParameters['name'] ?? slug;
          return CategoryProductsScreen(categorySlug: slug, categoryName: name);
        },
      ),

      GoRoute(
        path: '/search',
        builder: (context, state) => const ProductSearchScreen(),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final items = state.extra as List<CartItemModel>?;
          return CheckoutScreen(directItems: items);
        },
      ),
      GoRoute(
        path: '/payment/:orderId',
        builder: (context, state) {
          final order = state.extra as OrderModel;
          return PaymentDetailScreen(order: order);
        },
      ),
      GoRoute(
        path: '/order-detail/:id',
        builder: (context, state) {
          final order = state.extra as OrderModel;
          return UserOrderDetailScreen(order: order);
        },
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/user-address',
        builder: (context, state) => const UserAddressScreen(),
      ),
      GoRoute(
        path: '/merchant/:id',
        builder: (context, state) {
          final merchantId = state.pathParameters['id']!;
          return MerchantStoreScreen(merchantId: merchantId);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return UserMainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const UserHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const UserOrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const UserChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const UserProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
