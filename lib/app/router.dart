import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/core/widgets/bottom_nav_bar.dart';
import 'package:nutri_ai/features/admin/screens/admin_screen.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/auth/screens/email_verification_screen.dart';
import 'package:nutri_ai/features/auth/screens/forgot_password_screen.dart';
import 'package:nutri_ai/features/auth/screens/login_screen.dart';
import 'package:nutri_ai/features/auth/screens/pending_approval_screen.dart';
import 'package:nutri_ai/features/auth/screens/register_screen.dart';
import 'package:nutri_ai/features/auth/screens/set_new_password_screen.dart';
import 'package:nutri_ai/features/dashboard/screens/dashboard_screen.dart';
import 'package:nutri_ai/features/food_details/screens/food_details_screen.dart';
import 'package:nutri_ai/features/food_diary/screens/food_diary_screen.dart';
import 'package:nutri_ai/features/food_scanner/screens/food_scanner_screen.dart';
import 'package:nutri_ai/features/food_search/screens/food_search_screen.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';
import 'package:nutri_ai/features/goals/screens/goal_selection_screen.dart';
import 'package:nutri_ai/features/meal_planner/screens/meal_planner_screen.dart';
import 'package:nutri_ai/features/nutrition_plan/screens/nutrition_plan_screen.dart';
import 'package:nutri_ai/features/onboarding/screens/onboarding_screen.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';
import 'package:nutri_ai/features/profile/screens/profile_screen.dart';
import 'package:nutri_ai/features/profile/screens/profile_setup_screen.dart';
import 'package:nutri_ai/features/progress/screens/progress_screen.dart';
import 'package:nutri_ai/features/settings/screens/settings_screen.dart';
import 'package:nutri_ai/features/splash/screens/splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Screens that can be opened without being signed in.
const _publicRoutes = <String>{
  '/login',
  '/register',
  '/forgot-password',
  '/email-verification',
  '/onboarding',
};

/// Re-runs the router's redirect whenever sign-in, access, profile or goal change.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen(profileProvider, (_, __) => notifyListeners());
    ref.listen(goalProvider, (_, __) => notifyListeners());
  }
}

String? _redirect(Ref ref, GoRouterState state) {
  final auth = ref.read(authProvider);
  final loc = state.matchedLocation;

  if (auth.status == AuthStatus.initializing) {
    return loc == '/splash' ? null : '/splash';
  }

  if (auth.status == AuthStatus.signedOut) {
    if (_publicRoutes.contains(loc)) return null;
    final firstLaunch = ref.read(preferencesServiceProvider).isFirstLaunch;
    return firstLaunch ? '/onboarding' : '/login';
  }

  // Signed in from here on.
  if (auth.passwordRecovery) return loc == '/reset-password' ? null : '/reset-password';
  if (auth.isRecoveringWithCode) return null;

  if (!auth.isApproved) return loc == '/pending' ? null : '/pending';

  if (ref.read(profileProvider) == null) {
    return loc == '/profile-setup' ? null : '/profile-setup';
  }
  if (ref.read(goalProvider) == null) {
    return loc == '/goal-selection' ? null : '/goal-selection';
  }

  if (_publicRoutes.contains(loc) ||
      loc == '/splash' ||
      loc == '/pending' ||
      loc == '/reset-password') {
    return '/';
  }
  if (loc == '/admin' && !auth.isAdmin) return '/';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth', redirect: (context, state) => '/login'),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/email-verification',
        builder: (context, state) {
          final email = state.extra as String? ?? ref.read(authProvider).pendingVerificationEmail ?? '';
          return EmailVerificationScreen(email: email);
        },
      ),
      GoRoute(path: '/reset-password', builder: (context, state) => const SetNewPasswordScreen()),
      GoRoute(path: '/pending', builder: (context, state) => const PendingApprovalScreen()),
      GoRoute(path: '/profile-setup', builder: (context, state) => const ProfileSetupScreen()),
      GoRoute(path: '/goal-selection', builder: (context, state) => const GoalSelectionScreen()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/diary', builder: (context, state) => const FoodDiaryScreen()),
          GoRoute(path: '/meals', builder: (context, state) => const MealPlannerScreen()),
          GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/food-scanner',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FoodScannerScreen(),
      ),
      GoRoute(
        path: '/food-search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FoodSearchScreen(),
      ),
      GoRoute(
        path: '/food-details/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return FoodDetailsScreen(foodId: id);
        },
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/nutrition-plan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NutritionPlanScreen(),
      ),
    ],
  );
});

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _navRoutes = ['/', '/diary', '/meals', '/progress'];

  void _onTabSelected(int index) {
    if (index == 99) {
      context.push('/food-scanner');
      return;
    }
    if (index >= 0 && index < _navRoutes.length) {
      setState(() => _currentIndex = index);
      context.go(_navRoutes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final activeIndex = _navRoutes.indexOf(location);
    if (activeIndex != -1) {
      _currentIndex = activeIndex;
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
