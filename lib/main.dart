// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'src/core/locale/locale_providers.dart';
import 'src/l10n/generated/app_localizations.dart';
import 'src/routing/app_router.dart';
import 'src/core/theme/main_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar matches the light scaffold (surfaceContainer = #F1F3F5) with
  // dark icons. System nav bar uses the same color so the chrome stays calm.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF1F3F5),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    // Wrap the entire app in a ProviderScope to use Riverpod
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the GoRouter provider
    final goRouter = ref.watch(goRouterProvider);
    // Initialize the persisted locale preference (one-shot loader).
    ref.watch(localePreferenceLoaderProvider);
    return MaterialApp.router(
      routerConfig: goRouter,
      title: 'Farm CRM',
      theme: mainTheme,
      locale: ref.watch(localePreferenceProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fil')],
    );
  }
}