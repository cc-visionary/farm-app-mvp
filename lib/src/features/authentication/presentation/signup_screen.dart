// lib/src/features/authentication/presentation/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/shared_dialogs.dart';
import '../application/auth_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add listeners to clear the error when the user starts typing
    _emailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in both fields.';
      });
      return false;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return false;
    }
    // You can add password strength validation here
    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters long.';
      });
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access theme for specific text styling
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Info Button
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.black54),
              onPressed: () => showAppInfoDialog(context),
            ),
          ),
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.black,
                      child: Icon(Icons.eco, color: Colors.white, size: 50),
                    ),
                    const SizedBox(height: 48),

                    // Email Label
                    const Text(
                      'Email',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      // Style is now inherited from the main theme
                      decoration: const InputDecoration(hintText: 'Email'),
                    ),
                    const SizedBox(height: 16),

                    // Password Label
                    const Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      // Style is inherited, but we add the suffixIcon
                      decoration: InputDecoration(
                        hintText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Sign Up Button - Styling is applied automatically
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              if (!_validateInputs()) {
                                return;
                              }

                              setState(
                                () => _isLoading = true,
                              ); // <-- START loading

                              try {
                                await ref
                                    .read(authRepositoryProvider)
                                    .signUpWithEmail(
                                      email: _emailController.text.trim(),
                                      password: _passwordController.text.trim(),
                                    );
                                if (mounted) context.go('/create-farm');
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    _errorMessage = e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    );
                                  });
                                }
                              } finally {
                                if (mounted) {
                                  setState(
                                    () => _isLoading = false,
                                  ); // <-- STOP loading
                                }
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text('Sign Up'),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Login',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
