import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_page.dart';
import '../auth/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserAndNavigate();
  }

  Future<void> _checkUserAndNavigate() async {
    try {
      // Short delay to allow Firebase to initialize fully
      await Future.delayed(const Duration(seconds: 2));
      
      // Check current user
      User? user = FirebaseAuth.instance.currentUser;
      
      if (!mounted) return;
      
      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage())
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage())
        );
      }
    } catch (e) {
      print('Authentication error: $e');
      if (!mounted) return;
      
      // Navigate to login page if there's an error
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your app logo here
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 20),
            const Text(
              'Kasbill',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ],
        ),
      ),
    );
  }
} 