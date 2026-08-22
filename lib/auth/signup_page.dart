import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/ratnex_theme.dart';
import 'auth_helpers.dart';
import 'auth_landing_shell.dart';
import 'signin_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showEmailForm = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _googleLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await AuthHelpers.auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final name = _nameController.text.trim();
      await credential.user!.updateDisplayName(name);
      await AuthHelpers.storeUserInfo(credential.user!, displayName: name);

      if (!mounted) return;
      AuthHelpers.goToHome(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'email-already-in-use' => 'An account already exists for this email.',
          'invalid-email' => 'Please enter a valid email.',
          'weak-password' => 'Password should be at least 6 characters.',
          'operation-not-allowed' => 'Email/password sign-up is disabled.',
          _ => e.message ?? 'Sign up failed. Please try again.',
        };
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await AuthHelpers.signInWithGoogle();
      if (credential == null) {
        setState(() => _googleLoading = false);
        return;
      }

      final isNew = credential.additionalUserInfo?.isNewUser ?? false;
      if (isNew) {
        await AuthHelpers.storeUserInfo(credential.user!);
      } else {
        await AuthHelpers.updateOrCreateUserInfo(credential.user!);
      }

      if (!mounted) return;
      AuthHelpers.goToHome(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Google sign-up failed.';
      });
    } catch (e) {
      setState(() => _errorMessage = AuthHelpers.googleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  bool get _busy => _isLoading || _googleLoading;

  @override
  Widget build(BuildContext context) {
    return AuthLandingShell(
      heroFlex: _showEmailForm ? 0.22 : 0.42,
      bottom: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _showEmailForm ? _buildEmailForm() : _buildLanding(),
      ),
    );
  }

  Widget _buildLanding() {
    return KeyedSubtree(
      key: const ValueKey('signup-landing'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 8),
                    AuthBrandBlock(
                      title: 'Ratnex',
                      tagline: 'Start your shop workspace.',
                      description:
                          'Create an account to bill customers, track girvi & mod, and keep rates and stock in sync.',
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: RatnexTheme.label(size: 12, color: RatnexColors.down),
              ),
              const SizedBox(height: 12),
            ],
            AuthGoogleButton(
              label: 'Sign up with Google',
              loading: _googleLoading,
              onPressed: _busy ? null : _signUpWithGoogle,
            ),
            const SizedBox(height: 12),
            AuthPillButton(
              label: 'Continue with email',
              leading: Icon(
                Icons.mail_outline,
                size: 20,
                color: RatnexColors.ink,
              ),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _showEmailForm = true;
                        _errorMessage = null;
                      }),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SigninPage()),
                      );
                    },
              child: Text.rich(
                TextSpan(
                  style: RatnexTheme.label(size: 14, color: RatnexColors.ink),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'Sign in',
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return KeyedSubtree(
      key: const ValueKey('signup-email'),
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _showEmailForm = false;
                            _errorMessage = null;
                          }),
                  icon: const Icon(Icons.arrow_back),
                  color: RatnexColors.ink,
                ),
              ),
              Text('Create account', style: RatnexTheme.brand(size: 28)),
              const SizedBox(height: 6),
              Text(
                'Set up your shop with email',
                style: RatnexTheme.label(size: 13),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _field(
                        controller: _nameController,
                        label: 'Shop / owner name',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _passwordController,
                        label: 'Password',
                        obscure: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        validator: (v) {
                          if (v == null || v.length < 6) {
                            return 'Min 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _confirmController,
                        label: 'Confirm password',
                        obscure: _obscureConfirm,
                        onToggleObscure: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: RatnexTheme.label(
                            size: 12,
                            color: RatnexColors.down,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      AuthPillButton(
                        label: 'Create account',
                        filled: true,
                        loading: _isLoading,
                        onPressed: _busy ? null : _signUpWithEmail,
                      ),
                      const SizedBox(height: 12),
                      AuthGoogleButton(
                        label: 'Sign up with Google',
                        loading: _googleLoading,
                        onPressed: _busy ? null : _signUpWithGoogle,
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SigninPage(),
                          ),
                        );
                      },
                child: Text.rich(
                  TextSpan(
                    style: RatnexTheme.label(size: 14, color: RatnexColors.ink),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        style: RatnexTheme.label(
                          size: 14,
                          weight: FontWeight.w700,
                          color: RatnexColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: RatnexTheme.label(size: 14, color: RatnexColors.ink),
      decoration: authFieldDecoration(
        label,
        suffix: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: RatnexColors.muted,
                ),
              ),
      ),
    );
  }
}
