// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/setup_farm_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      title: 'Farm Logbook',
      theme: ThemeData(
        primarySwatch: Colors.green,
        // Define a nice green color for our theme
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF66BB6A)),
        scaffoldBackgroundColor: Colors.white,
        // Style for our text form fields
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.green),
          ),
        ),
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (userSnapshot.hasData) {
          // User is logged in, now check if they have a farm document
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('farms').doc(userSnapshot.data!.uid).get(),
            builder: (context, farmSnapshot) {
              if (farmSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (farmSnapshot.hasData && farmSnapshot.data!.exists) {
                // Farm exists, go to the main app
                return const HomeScreen();
              }
              // Farm does not exist, force user to the setup screen
              return const SetupFarmScreen();
            },
          );
        }
        // User is not logged in
        return const AuthScreen();
      },
    );
  }
}