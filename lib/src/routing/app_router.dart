import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/splash_screen.dart';
import '../features/areas/presentation/areas_list_screen.dart';
import '../features/authentication/application/auth_providers.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/signup_screen.dart';
import '../features/equipment/presentation/equipment_list_screen.dart';
import '../features/farms/application/farm_providers.dart';
import '../features/farms/presentation/create_farm_screen.dart';
import '../features/farms/presentation/farm_setup_screen.dart';
import '../features/pigs/presentation/pigs_list_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/team/application/team_providers.dart';
import '../features/team/presentation/team_management_screen.dart';

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
      GoRoute(path: '/pigs', builder: (c, s) => const PigsListScreen()),
      GoRoute(path: '/tasks', builder: (c, s) => const TasksScreen()),
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(
          body: Center(child: Text('Home — Pigs/Dashboard built in later tasks')),
        ),
      ),
    ],
  );
});
