import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _lineController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _lineWidth;

  @override
  void initState() {
    super.initState();

    // ==========================================================
    // LOGO ANIMATION
    // ==========================================================

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1000,
      ),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );

    // ==========================================================
    // TEXT ANIMATION
    // ==========================================================

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 800,
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, .35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textFade = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    // ==========================================================
    // LINE ANIMATION
    // ==========================================================

    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 650,
      ),
    );

    _lineWidth = CurvedAnimation(
      parent: _lineController,
      curve: Curves.easeOut,
    );

    _startAnimation();

    // ==========================================================
    // GO TO AUTH GATE
    // ==========================================================

    Timer(
      const Duration(
        milliseconds: 2600,
      ),
      () {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (
              context,
              animation,
              secondaryAnimation,
            ) =>
                const AuthGate(),
            transitionDuration:
                const Duration(
              milliseconds: 500,
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _startAnimation() async {
    await Future.delayed(
      const Duration(
        milliseconds: 150,
      ),
    );

    if (!mounted) return;

    _logoController.forward();

    await Future.delayed(
      const Duration(
        milliseconds: 350,
      ),
    );

    if (!mounted) return;

    _textController.forward();

    await Future.delayed(
      const Duration(
        milliseconds: 250,
      ),
    );

    if (!mounted) return;

    _lineController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _lineController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF7A1F2B),

      body: SafeArea(
        child: Stack(
          children: [

            // ====================================================
            // BACKGROUND CIRCLE 1
            // ====================================================

            Positioned(
              top: -120,
              right: -100,
              child: Container(
                width: 310,
                height: 310,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white
                        .withOpacity(.055),
                    width: 38,
                  ),
                ),
              ),
            ),

            // ====================================================
            // BACKGROUND CIRCLE 2
            // ====================================================

            Positioned(
              bottom: -140,
              left: -120,
              child: Container(
                width: 330,
                height: 330,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white
                        .withOpacity(.045),
                    width: 42,
                  ),
                ),
              ),
            ),

            // ====================================================
            // CENTER CONTENT
            // ====================================================

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // =================================================
                  // LOGO
                  // =================================================

                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 120,
                        height: 120,
                        padding:
                            const EdgeInsets.all(12),
                        decoration:
                            const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/RoyalLogo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =================================================
                  // TEXT
                  // =================================================

                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [

                          Text(
                            'ROYAL COLLEGE',
                            textAlign:
                                TextAlign.center,
                            style:
                                GoogleFonts.roboto(
                              color:
                                  Colors.white,
                              fontSize: 25,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          Text(
                            'STUDENT PORTAL',
                            style:
                                GoogleFonts.poppins(
                              color: Colors.white
                                  .withOpacity(.72),
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.w700,
                              letterSpacing: 2.6,
                            ),
                          ),

                          const SizedBox(
                            height: 22,
                          ),

                          // =========================================
                          // ANIMATED LINE
                          // =========================================

                          AnimatedBuilder(
                            animation:
                                _lineWidth,
                            builder:
                                (
                              context,
                              child,
                            ) {
                              return Container(
                                width: 45 *
                                    _lineWidth.value,
                                height: 3,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      Colors.white,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ====================================================
            // FOOTER
            // ====================================================

            Positioned(
              left: 0,
              right: 0,
              bottom: 25,
              child: Text(
                'Powered by Royal College',
                textAlign:
                    TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white
                      .withOpacity(.55),
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}