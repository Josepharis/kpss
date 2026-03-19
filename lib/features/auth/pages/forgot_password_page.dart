import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _isLoading = false;
  late AnimationController _animationController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_waveController);

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 10000),
      vsync: this,
    )..repeat();

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      HapticFeedback.mediumImpact();

      final authService = AuthService();
      final result = await authService.sendPasswordResetEmail(_emailController.text.trim());

      if (mounted) {
        setState(() => _isLoading = false);
        if (result.success) {
          HapticFeedback.heavyImpact();
          PremiumSnackBar.show(
            context,
            message: 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.',
            type: SnackBarType.success,
            title: 'BAŞARILI',
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        } else {
          HapticFeedback.vibrate();
          PremiumSnackBar.show(
            context,
            message: result.message,
            type: SnackBarType.error,
            title: 'HATA',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildBackground(screenWidth, screenHeight),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Spacer(flex: 3), // Slightly higher than center
                      const Icon(
                        Icons.lock_reset_rounded,
                        size: 72,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Şifremi Unuttum',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hesabına bağlı e-posta adresini gir,\nsana şifre sıfırlama bağlantısı gönderelim.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 48),
                      _PremiumTextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        label: 'E-POSTA',
                        hint: 'ornek@email.com',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen e-posta adresinizi girin';
                          }
                          if (!value.contains('@')) {
                            return 'Geçerli bir e-posta adresi girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      _buildResetButton(),
                      const Spacer(flex: 5), // Push content up
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(double screenWidth, double screenHeight) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3C72),
              Color(0xFF2A5298),
              Color(0xFF1976D2),
              Color(0xFF42A5F5),
              Color(0xFF1565C0),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Waves
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _UnifiedWavePainter(_waveAnimation.value),
                  size: Size.infinite,
                );
              },
            ),
            // Noise/Particles
            CustomPaint(
              painter: _UnifiedNoisePainter(),
              size: Size.infinite,
            ),
            // Floating stars/particles
            ...List.generate(20, (index) {
              final random = math.Random(index);
              final startX = random.nextDouble() * screenWidth;
              final startY = random.nextDouble() * screenHeight;
              return AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  final progress = ((_particleController.value + (index / 20)) % 1.0);
                  return Positioned(
                    left: (startX + math.sin(progress * 2 * math.pi) * 30) % screenWidth,
                    top: (startY - progress * screenHeight * 0.3 + screenHeight) % screenHeight,
                    child: Opacity(
                      opacity: (math.sin(progress * math.pi)).clamp(0.0, 0.3),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFFFF9D6C), Color(0xFFE85D04)]),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE85D04).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleResetPassword,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Şifremi Sıfırla',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _PremiumTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1.0,
                  ),
                ),
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                    prefixIcon: Icon(icon, color: Colors.white70, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    errorStyle: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  validator: validator,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnifiedWavePainter extends CustomPainter {
  final double animationValue;
  _UnifiedWavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    const waveHeight = 60.0;
    final waveLength = size.width / 2.5;

    // Draw multiple waves like login page
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final opacity = 0.12 - (i * 0.03);
      final speedFactor = 1.0 + (i * 0.3);
      final heightFactor = 1.0 - (i * 0.15);
      final baseHeight = 0.65 + (i * 0.1);

      path.moveTo(0, size.height * baseHeight);
      for (double x = 0; x <= size.width; x++) {
        final y = size.height * baseHeight + 
                  waveHeight * heightFactor * 
                  math.sin((x / waveLength * speedFactor * math.pi) + animationValue * speedFactor);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withOpacity(opacity)..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _UnifiedNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.withOpacity(0.2);
    final random = math.Random(42); // Seed for consistency
    for (var i = 0; i < 2000; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
