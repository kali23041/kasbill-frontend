import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/signin_page.dart';
import 'auth/signup_page.dart';
import 'l10n/app_l10n.dart';
import 'main_shell.dart';
import 'services/app_prefs_service.dart';
import 'services/notifications_service.dart';
import 'theme/ratnex_theme.dart';
import 'widgets/app_lock_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Jewellery shops in smaller towns run on patchy connections. Cached reads
  // and queued writes mean the counter keeps working when the line drops.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore persistence already configured: $e');
  }

  FirebaseMessaging.onBackgroundMessage(ratnexBackgroundMessageHandler);

  await AppPrefs.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// On "Match device", the OS flipping to dark must also flip the static
  /// RatnexColors palette — MaterialApp alone would only swap ThemeData.
  @override
  void didChangePlatformBrightness() {
    if (AppPrefs.instance.themeMode.value == ThemeMode.system && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: prefs.themeMode,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: prefs.locale,
          builder: (context, locale, __) {
            // Keep the palette in step with the resolved brightness so the
            // static RatnexColors call sites across the app follow the theme.
            final systemDark =
                WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark;
            final isDark = themeMode == ThemeMode.dark ||
                (themeMode == ThemeMode.system && systemDark);
            RatnexPalette.apply(isDark ? Brightness.dark : Brightness.light);

            return MaterialApp(
              title: 'Ratnex',
              debugShowCheckedModeBanner: false,
              theme: RatnexTheme.light,
              darkTheme: RatnexTheme.dark,
              themeMode: themeMode,
              locale: locale,
              supportedLocales: L10n.supportedLocales,
              localizationsDelegates: const [
                L10n.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AppLockGate(child: AuthenticationWrapper()),
              routes: {
                '/signin': (context) => const SigninPage(),
                '/signup': (context) => const SignupPage(),
                '/home': (context) => const ProtectedRoute(child: MainShell()),
              },
            );
          },
        );
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
          return Scaffold(
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
          return Scaffold(
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
          return Scaffold(
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
