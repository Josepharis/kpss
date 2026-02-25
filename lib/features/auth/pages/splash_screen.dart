import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/initial_sync_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  late AnimationController _glowController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_logoController);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    // Wave animation
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_waveController);

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..repeat();

    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _logoController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Arka planda initial sync başlat (uygulamayı bloklamaz)
    Future.microtask(() => InitialSyncService().runInitialSync());

    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E3C72),
              const Color(0xFF2A5298),
              AppColors.primaryBlue,
              AppColors.gradientBlueEnd,
              const Color(0xFF1565C0),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated waves background
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: WavePainter(_waveAnimation.value),
                  size: Size.infinite,
                );
              },
            ),
            // Floating particles - random movement
            ...List.generate(30, (index) {
              // Generate random values for each particle
              final random = math.Random(index);
              final startX =
                  random.nextDouble() * MediaQuery.of(context).size.width;
              final startY =
                  random.nextDouble() * MediaQuery.of(context).size.height;
              final speed =
                  0.3 +
                  random.nextDouble() * 0.4; // Random speed between 0.3-0.7
              final angle = random.nextDouble() * 2 * math.pi; // Random angle
              final size = 2.0 + random.nextDouble() * 4.0; // Random size 2-6
              final delay = random.nextDouble(); // Random delay

              return AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  final progress =
                      ((_particleController.value + delay) * speed) % 1.0;

                  // Calculate movement in random direction
                  final moveDistance = MediaQuery.of(context).size.height * 1.5;
                  final x = startX + math.cos(angle) * moveDistance * progress;
                  final y = startY + math.sin(angle) * moveDistance * progress;

                  // Wrap around screen edges
                  final wrappedX = x % MediaQuery.of(context).size.width;
                  final wrappedY = y % MediaQuery.of(context).size.height;

                  // Opacity based on progress (fade in/out)
                  final opacity =
                      (math.sin(progress * math.pi)).clamp(0.0, 1.0) * 0.8;

                  return Positioned(
                    left: wrappedX,
                    top: wrappedY,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.9),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
            // Main content - Logo centered, full screen width
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_logoController, _glowController]),
                builder: (context, child) {
                  final screenSize = MediaQuery.of(context).size;
                  final logoWidth = screenSize.width; // Full screen width
                  final logoHeight = logoWidth; // Square aspect ratio
                  final glowSize = logoWidth * 1.3;

                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Subtle glow to lift the logo
                          Container(
                            width: glowSize,
                            height: glowSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(
                                    _glowAnimation.value * 0.08,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.8],
                              ),
                            ),
                          ),
                          // Logo only (no frame/no text) - full screen width
                          Image.asset(
                            'assets/images/kadrox_logo.png',
                            width: logoWidth,
                            height: logoHeight,
                            fit: BoxFit.contain,
                            colorBlendMode: BlendMode.srcOver,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.image,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Loading indicator at bottom
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(
                              0.3 + _glowAnimation.value * 0.2,
                            ),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(
                                _glowAnimation.value * 0.5,
                              ),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 35,
                            height: 35,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 60.0;
    final waveLength = size.width / 2.5;

    path.moveTo(0, size.height * 0.65);

    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.65 +
          waveHeight *
              math.sin((x / waveLength * 2 * math.pi) + animationValue);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Second wave
    final path2 = Path();
    path2.moveTo(0, size.height * 0.75);

    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.75 +
          waveHeight *
              0.8 *
              math.sin(
                (x / waveLength * 2 * math.pi) + animationValue + math.pi,
              );
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path2, paint2);

    // Third wave for depth
    final path3 = Path();
    path3.moveTo(0, size.height * 0.85);

    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.85 +
          waveHeight *
              0.6 *
              math.sin((x / waveLength * 1.5 * math.pi) + animationValue * 1.5);
      path3.lineTo(x, y);
    }

    path3.lineTo(size.width, size.height);
    path3.lineTo(0, size.height);
    path3.close();

    final paint3 = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
