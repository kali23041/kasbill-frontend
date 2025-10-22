import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_page.dart';
import '../scrap/scrap_main_page.dart';
import '../auth/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Scale animation controller
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Scale animation (starts from 1.0 and goes to 20.0 for expansion effect)
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 20.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    // Fade animation for the text
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _startAnimation();
  }
  
  Future<void> _startAnimation() async {
    // Start fade in animation
    await Future.delayed(const Duration(milliseconds: 500));
    _fadeController.forward();
    
    // Wait and then check user
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Start expansion animation and navigate
    await _checkUserAndNavigate();
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkUserAndNavigate() async {
    try {
      // Check current user
      User? user = FirebaseAuth.instance.currentUser;
      
      if (!mounted) return;
      
      // Start expansion animation
      await _scaleController.forward();
      
      if (!mounted) return;
      
      // Navigate with custom page route for smooth transition
      if (user != null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ScrapMainPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    } catch (e) {
      print('Authentication error: $e');
      if (!mounted) return;
      
      // Navigate to login page if there's an error
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_scaleController, _fadeController]),
        builder: (context, child) {
          // Calculate opacity for text based on scale animation
          // Fade out text when expansion starts
          final textOpacity = _scaleAnimation.value > 1.5 
              ? 0.0 
              : _fadeAnimation.value;
          
          return Stack(
            children: [
              // App name - shown first, fades out before expansion
              if (_scaleAnimation.value < 2.0)
                Center(
                  child: Opacity(
                    opacity: textOpacity,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Scraply',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Trade Scrap Smartly',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF999999),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Expanding circle animation - starts after text is visible
              if (_scaleAnimation.value > 1.0)
                Center(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
} 