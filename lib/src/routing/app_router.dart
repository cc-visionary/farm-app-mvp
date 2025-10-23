// lib/src/routing/app_router.dart

import 'package:farm_app/src/core/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Import all the necessary providers and models
import '../features/authentication/application/auth_providers.dart';
import '../features/authentication/domain/user_model.dart';

// Import all the screens that will be used in routing
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/signup_screen.dart';
import '../features/farms/presentation/setup_screen.dart';
import '../features/farms/presentation/home_screen.dart';
import '../features/animals/presentation/add_animal_screen.dart';
import '../features/settings/presentation/settings_screen.dart'; // Ensure this screen exists

final goRouterProvider = Provider<GoRouter>((ref) {
  // Watch the providers that determine the user's state
  final authState = ref.watch(authStateChangesProvider);
  final userData = ref.watch(userDataProvider);

  return GoRouter(
    initialLocation: '/login',
    // This debugLogDiagnostics line can be helpful for troubleshooting
    // It prints navigation events to the console.
    debugLogDiagnostics: true,

    redirect: (BuildContext context, GoRouterState state) {
      // If either the auth state or user data is still loading, show the splash screen.
      // This is the key to preventing the screen flicker.
      if (authState.isLoading || userData.isLoading) {
        return '/splash';
      }

      final isLoggedIn = authState.asData?.value != null;
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      final isSettingUp = state.matchedLocation == '/setup';

      // Determine if the user has completed the initial setup.
      // We default to `false` if the user data is still loading.
      final hasCompletedSetup =
          userData.asData?.value?.hasCompletedSetup ?? false;

      // Case 1: User is not logged in.
      if (!isLoggedIn) {
        // If they are already on a login/signup page, let them stay. Otherwise, redirect to login.
        return isLoggingIn ? null : '/login';
      }

      // Case 2: User is logged in but hasn't completed the setup.
      if (isLoggedIn && !hasCompletedSetup) {
        // If they are already on the setup page, let them stay. Otherwise, force them to the setup page.
        return isSettingUp ? null : '/setup';
      }

      // Case 3: User is logged in and has completed setup.
      if (isLoggedIn && hasCompletedSetup) {
        // If they are trying to access login, signup, or setup pages, redirect them to the home screen.
        if (isLoggingIn || isSettingUp) {
          return '/';
        }
      }

      // In all other cases, no redirect is needed.
      return null;
    },

    // This is the "map" of all possible routes in the app.
    // The error "no routes for location" means the path was not in this list.
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(
        path: '/add-animal',
        builder: (context, state) => const AddAnimalScreen(),
      ),
    ],
  );
});
