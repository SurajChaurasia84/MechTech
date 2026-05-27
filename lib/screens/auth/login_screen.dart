import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  void _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    final success = await context.read<AppState>().signInWithGoogle();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google Sign-in failed. Please try again.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      body: Stack(
        children: [
          // Background Gradient Circles for depth
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00B0FF).withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B0FF).withOpacity(0.2),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          // Main Body Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo
                    Container(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(18.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161426),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: const Color(0xFF302B53),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.build_circle_outlined,
                          size: 64,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'MechTech',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Premium Mechanic Service App',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF8B88A5),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161426).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(28.0),
                        border: Border.all(
                          color: const Color(0xFF302B53).withOpacity(0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome Back',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please sign in with Google to browse and book professional vehicle services.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF8B88A5),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                                ),
                              ),
                            )
                          else
                            // Premium Sign In with Google Button
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16.0),
                                  onTap: _handleGoogleSignIn,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Official looking Google Icon representation
                                        Image.network(
                                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/48px-Google_%22G%22_logo.svg.png',
                                          height: 24,
                                          width: 24,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.g_mobiledata_rounded,
                                              color: Color(0xFF4285F4),
                                              size: 32,
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          'Continue with Google',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF0D0B18),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
