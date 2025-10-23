// lib/src/routing/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/authentication/application/auth_providers.dart';
import '../features/authentication/presentation/signup_screen.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/farms/presentation/create_farm_screen.dart';
import '../features/farms/presentation/home_screen.dart'; // A placeholder home screen

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authState.asData?.value != null;
      
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      // If user is not logged in and not on a login/signup page, redirect to login
      if (!isLoggedIn && !loggingIn) {
        return '/login';
      }

      // If user is logged in and trying to access login/signup, redirect to home
      if (isLoggedIn && loggingIn) {
        return '/';
      }

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(), // Or check if farm exists
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/create-farm',
        builder: (context, state) => const CreateFarmScreen(),
      ),
    ],
  );
});