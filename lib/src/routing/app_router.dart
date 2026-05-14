import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_shell.dart';
import '../core/widgets/splash_screen.dart';
import '../features/activity/presentation/activity_screen.dart';
import '../features/areas/presentation/areas_list_screen.dart';
import '../features/authentication/application/auth_providers.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/equipment/presentation/equipment_list_screen.dart';
import '../features/expenses/presentation/expenses_list_screen.dart';
import '../features/farms/application/farm_providers.dart';
import '../features/farms/presentation/create_farm_screen.dart';
import '../features/farms/presentation/farm_setup_screen.dart';
import '../features/inventory/presentation/inventory_list_screen.dart';
import '../features/layout/farm_layout_screen.dart';
import '../features/pigs/presentation/pigs_list_screen.dart';
import '../features/purchases/presentation/purchases_list_screen.dart';
import '../features/sales/presentation/sales_list_screen.dart';
import '../features/shifts/presentation/shifts_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/team/application/team_providers.dart';
import '../features/team/presentation/team_management_screen.dart';
import '../features/yield/yield_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;

  // Drive initial farm selection.
  ref.watch(initialFarmResolverProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      if (authState.isLoading) return '/splash';
      final isLoggedIn = user != null;
      final isAtAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      final isAtSetup = state.matchedLocation == '/setup' ||
          state.matchedLocation == '/create-farm';

      if (!isLoggedIn) return isAtAuth ? null : '/login';

      final memberships = ref.read(userMembershipsProvider(user.uid)).asData?.value;
      // Memberships still loading? Hold at splash.
      if (memberships == null) return '/splash';

      if (memberships.isEmpty) {
        return isAtSetup ? null : '/setup';
      }

      // Has at least one membership; ensure selected farm is set.
      // Watch so the router rebuilds once the initial resolver populates it.
      final selected = ref.watch(selectedFarmIdProvider);
      if (selected == null) return '/splash';

      if (isAtAuth || isAtSetup) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignUpScreen()),
      GoRoute(path: '/setup', builder: (c, s) => const FarmSetupScreen()),
      GoRoute(path: '/create-farm', builder: (c, s) => const CreateFarmScreen()),
      GoRoute(path: '/team', builder: (c, s) => const TeamManagementScreen()),
      GoRoute(path: '/areas', builder: (c, s) => const AreasListScreen()),
      GoRoute(path: '/equipment', builder: (c, s) => const EquipmentListScreen()),
      GoRoute(path: '/inventory', builder: (c, s) => const InventoryListScreen()),
      GoRoute(path: '/pigs', builder: (c, s) => const PigsListScreen()),
      GoRoute(path: '/purchases', builder: (c, s) => const PurchasesListScreen()),
      GoRoute(path: '/sales', builder: (c, s) => const SalesListScreen()),
      GoRoute(path: '/expenses', builder: (c, s) => const ExpensesListScreen()),
      GoRoute(path: '/tasks', builder: (c, s) => const TasksScreen()),
      GoRoute(path: '/shifts', builder: (c, s) => const ShiftsScreen()),
      GoRoute(path: '/activity', builder: (c, s) => const ActivityScreen()),
      GoRoute(path: '/yield', builder: (c, s) => const YieldScreen()),
      GoRoute(path: '/layout', builder: (c, s) => const FarmLayoutScreen()),
      GoRoute(
        path: '/',
        builder: (c, s) => const AppShell(child: DashboardScreen()),
      ),
    ],
  );
});
