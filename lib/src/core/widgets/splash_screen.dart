import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // You can use your app logo here instead of the icon
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.black,
              child: Icon(Icons.eco, color: Colors.white, size: 50),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your farm...'),
          ],
        ),
      ),
    );
  }
}