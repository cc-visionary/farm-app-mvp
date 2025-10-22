// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/setup_farm_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmly',
      theme: ThemeData(
        // 1. Color Scheme: The foundation of your app's colors.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF388E3C), // Your primary dark green
          primary: const Color(0xFF388E3C), // Dark green for buttons, icons
          secondary: const Color(0xFF4CAF50), // Brighter green for accents
          background: const Color(
            0xFFF5F5F5,
          ), // Light grey for screen backgrounds
          surface: Colors.white, // White for card backgrounds
          onPrimary: Colors
              .white, // Text color on primary background (e.g., on buttons)
          onBackground: Colors.black, // Text color on the main background
        ),

        // 2. Typography: Define the default font and text styles.
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.black87),

        // 3. Scaffold Background Color
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),

        // 4. AppBar Theme: Style for all AppBars in your app.
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(
            0xFFF5F5F5,
          ), // Light background for app bars
          foregroundColor: Colors.black87, // Dark text and icons
          elevation: 0, // No shadow for a flat look
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        // 5. Card Theme: Default style for all Card widgets.
        cardTheme: CardThemeData(
          elevation: 1,
          color: Colors.white, // Explicitly set card color to white
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),

        // 6. Input Decoration Theme: Style for all TextFormFields.
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // No border!
          ),
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),

        // 7. ElevatedButton Theme: Default style for elevated buttons.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50), // Bright green
            foregroundColor: Colors.white, // White text
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Use this to ensure other properties use the color scheme
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (userSnapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('farms')
                .doc(userSnapshot.data!.uid)
                .get(),
            builder: (context, farmSnapshot) {
              if (farmSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (farmSnapshot.hasData && farmSnapshot.data!.exists) {
                return const MainScreen();
              }
              return const SetupFarmScreen();
            },
          );
        }
        return const AuthScreen();
      },
    );
  }
}
