import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/ratnex_theme.dart';
import 'auth_helpers.dart';
import 'auth_landing_shell.dart';
import 'signup_page.dart';

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showEmailForm = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _googleLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await AuthHelpers.auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await AuthHelpers.updateOrCreateUserInfo(credential.user!);

      if (!mounted) return;
      AuthHelpers.goToHome(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'user-not-found' || 'wrong-password' || 'invalid-credential' =>
            'Invalid email or password.',
          'user-disabled' => 'This account has been disabled.',
          'invalid-email' => 'Please enter a valid email.',
          _ => e.message ?? 'Sign in failed. Please try again.',
        };
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
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
        _errorMessage = e.message ?? 'Google sign-in failed.';
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
      heroFlex: _showEmailForm ? 0.28 : 0.42,
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
      key: const ValueKey('signin-landing'),
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
                      tagline: 'Jewellery billing, made simple.',
                      description:
                          'Bills, girvi, stock, and live rates — one calm place to run your shop every day.',
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
              label: 'Sign in with Google',
              loading: _googleLoading,
              onPressed: _busy ? null : _signInWithGoogle,
            ),
            const SizedBox(height: 12),
            AuthPillButton(
              label: 'Continue with email',
              leading: const Icon(
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
                        MaterialPageRoute(builder: (_) => const SignupPage()),
                      );
                    },
              child: Text.rich(
                TextSpan(
                  style: RatnexTheme.label(size: 14, color: RatnexColors.ink),
                  children: [
                    const TextSpan(text: 'New user? '),
                    TextSpan(
                      text: 'Create account',
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
      key: const ValueKey('signin-email'),
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
              Text('Sign in', style: RatnexTheme.brand(size: 30)),
              const SizedBox(height: 6),
              Text(
                'Use your email and password',
                style: RatnexTheme.label(size: 13),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: RatnexTheme.label(
                          size: 14,
                          color: RatnexColors.ink,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                        decoration: authFieldDecoration('Email'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: RatnexTheme.label(
                          size: 14,
                          color: RatnexColors.ink,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                        decoration: authFieldDecoration(
                          'Password',
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: RatnexColors.muted,
                            ),
                          ),
                        ),
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
                        label: 'Sign in',
                        filled: true,
                        loading: _isLoading,
                        onPressed: _busy ? null : _signInWithEmail,
                      ),
                      const SizedBox(height: 12),
                      AuthGoogleButton(
                        label: 'Sign in with Google',
                        loading: _googleLoading,
                        onPressed: _busy ? null : _signInWithGoogle,
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
                            builder: (_) => const SignupPage(),
                          ),
                        );
                      },
                child: Text.rich(
                  TextSpan(
                    style: RatnexTheme.label(size: 14, color: RatnexColors.ink),
                    children: [
                      const TextSpan(text: 'New user? '),
                      TextSpan(
                        text: 'Create account',
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
}
