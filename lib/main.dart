import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'auth/signin_page.dart';
import 'auth/signup_page.dart';
import 'main_shell.dart';
import 'theme/ratnex_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ratnex',
      debugShowCheckedModeBanner: false,
      theme: RatnexTheme.light,
      home: const AuthenticationWrapper(),
      routes: {
        '/signin': (context) => const SigninPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const ProtectedRoute(child: MainShell()),
      },
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: RatnexColors.surface,
            body: Center(
              child: CircularProgressIndicator(color: RatnexColors.gold),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: RatnexColors.surface,
            body: Center(
              child: Text(
                'Auth error. Please restart the app.',
                style: RatnexTheme.label(size: 13),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const SigninPage();
        }
        return const MainShell();
      },
    );
  }
}

class ProtectedRoute extends StatelessWidget {
  final Widget child;

  const ProtectedRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: RatnexColors.surface,
            body: Center(
              child: CircularProgressIndicator(color: RatnexColors.gold),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/signin');
          });
          return const Scaffold(
            backgroundColor: RatnexColors.surface,
            body: Center(
              child: CircularProgressIndicator(color: RatnexColors.gold),
            ),
          );
        }

        return child;
      },
    );
  }
}
