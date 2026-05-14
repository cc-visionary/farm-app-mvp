import 'package:farm_app/src/core/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/application/auth_providers.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/signup_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      if (authState.isLoading) return '/splash';
      final isLoggedIn = authState.asData?.value != null;
      final isAtAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      if (!isLoggedIn) return isAtAuth ? null : '/login';
      if (isLoggedIn && isAtAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignUpScreen()),
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(
          body: Center(child: Text('Home — to be built')),
        ),
      ),
    ],
  );
});
