import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/services/auth_service.dart';

enum KpssType { ortaOgretim, onLisans, lisans, ags }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  KpssType? _selectedKpssType;
  late AnimationController _animationController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _glowAnimation;

  final Map<KpssType, String> _kpssTypeLabels = {
    KpssType.ortaOgretim: 'Ortaöğretim KPSS',
    KpssType.onLisans: 'Ön Lisans KPSS',
    KpssType.lisans: 'Lisans KPSS',
    KpssType.ags: 'AGS',
  };

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
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_waveController);

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedKpssType == null) {
        HapticFeedback.vibrate();
        PremiumSnackBar.show(
          context,
          message: 'Lütfen KPSS türünü seçin',
          type: SnackBarType.warning,
        );
        return;
      }

      if (!_agreeToTerms) {
        HapticFeedback.vibrate();
        PremiumSnackBar.show(
          context,
          message: 'Lütfen kullanım şartlarını kabul edin',
          type: SnackBarType.warning,
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      HapticFeedback.mediumImpact();

      final authService = AuthService();
      final kpssTypeString = _selectedKpssType.toString().split('.').last;
      final result = await authService.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        kpssTypeString,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result.success) {
          HapticFeedback.heavyImpact();
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          HapticFeedback.vibrate();
          PremiumSnackBar.show(
            context,
            message: result.message,
            type: SnackBarType.error,
          );
        }
      }
    }
  }

  void _showLegalModal(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LegalModal(title: title, content: content),
    );
  }

  Widget _buildSplashBackground(double screenWidth, double screenHeight) {
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
            // Floating particles
            ...List.generate(20, (index) {
              final random = math.Random(index);
              final startX = random.nextDouble() * screenWidth;
              final startY = random.nextDouble() * screenHeight;
              final speed = 0.2 + random.nextDouble() * 0.3;
              final angle = random.nextDouble() * 2 * math.pi;
              final size = 2.0 + random.nextDouble() * 3.0;
              final delay = random.nextDouble();

              return AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  final progress =
                      ((_particleController.value + delay) * speed) % 1.0;
                  final moveDistance = screenHeight * 0.4;
                  final x = startX + math.cos(angle) * moveDistance * progress;
                  final y = startY + math.sin(angle) * moveDistance * progress;
                  final wrappedX = x % screenWidth;
                  final wrappedY = y % screenHeight;
                  final opacity =
                      (math.sin(progress * math.pi)).clamp(0.0, 1.0) * 0.4;

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
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = screenHeight < 750;

    return Scaffold(
      body: Stack(
        children: [
          _buildSplashBackground(screenWidth, screenHeight),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Premium Compact Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        _buildBackButton(isDark),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_moon_rounded,
                                size: 14,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'GÜVENLİ KAYIT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.09,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 0),
                            Transform.translate(
                              offset: const Offset(0, -60),
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _fadeAnimation,
                                    _glowAnimation,
                                  ]),
                                  builder: (context, child) {
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: screenWidth * 1.0,
                                          height: screenWidth * 0.5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                Colors.white.withOpacity(
                                                  _glowAnimation.value * 0.1,
                                                ),
                                                Colors.white.withOpacity(0),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Image.asset(
                                          'assets/images/kadrox_logo.png',
                                          width: screenWidth * 1.0,
                                          height: screenWidth * 0.5,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.auto_awesome_rounded,
                                                    size: 80,
                                                    color: Colors.white,
                                                  ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Transform.translate(
                              offset: const Offset(0, -100),
                              child: Text(
                                'Yeni Hesap',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 30 : 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.5,
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: const Offset(0, 4),
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -100),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PremiumTextField(
                                    controller: _nameController,
                                    focusNode: _nameFocusNode,
                                    label: 'AD SOYAD',
                                    hint: 'Adınız ve soyadınız',
                                    icon: Icons.person_outline_rounded,
                                    isDark: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty)
                                        return 'Lütfen adınızı girin';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _PremiumTextField(
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    label: 'E-POSTA',
                                    hint: 'ornek@email.com',
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    isDark: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty)
                                        return 'E-posta gerekli';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _buildKpssTypeDropdown(isDark),
                                  const SizedBox(height: 8),
                                  _PremiumTextField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    label: 'ŞİFRE',
                                    hint: '••••••••',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: !_isPasswordVisible,
                                    isDark: true,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                        () => _isPasswordVisible =
                                            !_isPasswordVisible,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty)
                                        return 'Şifre gerekli';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _PremiumTextField(
                                    controller: _confirmPasswordController,
                                    focusNode: _confirmPasswordFocusNode,
                                    label: 'ŞİFRE TEKRAR',
                                    hint: '••••••••',
                                    icon: Icons.lock_reset_rounded,
                                    obscureText: !_isConfirmPasswordVisible,
                                    isDark: true,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                        () => _isConfirmPasswordVisible =
                                            !_isConfirmPasswordVisible,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value != _passwordController.text)
                                        return 'Şifreler eşleşmiyor';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  _TermsCheckbox(
                                    value: _agreeToTerms,
                                    onChanged: (val) =>
                                        setState(() => _agreeToTerms = val),
                                    isDark: isDark,
                                    isSmallScreen: isSmallScreen,
                                    onShowTerms: () => _showLegalModal(
                                      context,
                                      'Hizmet Koşulları',
                                      _termsOfServiceText,
                                    ),
                                    onShowPrivacy: () => _showLegalModal(
                                      context,
                                      'Gizlilik Politikası',
                                      _privacyPolicyText,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 8 : 12),
                                  _buildRegisterButton(isSmallScreen, isDark),
                                  SizedBox(height: isSmallScreen ? 12 : 16),
                                  Center(
                                    child: GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          children: [
                                            TextSpan(
                                              text:
                                                  'Zaten bir hesabın var mı? ',
                                            ),
                                            TextSpan(
                                              text: 'Giriş Yap',
                                              style: TextStyle(
                                                color: const Color(0xFFF48C06),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18,
                                                letterSpacing: 0.5,
                                                shadows: [
                                                  Shadow(
                                                    color: const Color(
                                                      0xFFF48C06,
                                                    ).withOpacity(0.5),
                                                    blurRadius: 15,
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
                            ),
                            const SizedBox(height: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: isDark ? Colors.white : Colors.black87,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildKpssTypeDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'SINAV SEÇİMİ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white60,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _PremiumDropdown<KpssType>(
          value: _selectedKpssType,
          hint: 'Gireceğiniz Sınavı Seçin',
          items: KpssType.values.map((type) {
            return DropdownMenuItem<KpssType>(
              value: type,
              child: Text(_kpssTypeLabels[type]!),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedKpssType = value);
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }

  Widget _buildRegisterButton(bool isSmallScreen, bool isDark) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9D6C), Color(0xFFE85D04)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE85D04).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleRegister,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hesabını Oluştur',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
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
    const waveHeight = 60.0;
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

    // Third wave
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

class NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.withOpacity(0.2);
    final random = math.Random();
    for (var i = 0; i < 3000; i++) {
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

class _PremiumDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _PremiumDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(
                hint,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 15,
                ),
              ),
              items: items,
              onChanged: onChanged,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white60,
              ),
              dropdownColor: const Color(0xFF1E3C72),
              borderRadius: BorderRadius.circular(16),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
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
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool isDark;

  const _PremiumTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white54,
              letterSpacing: 1.2,
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1.0,
                  ),
                ),
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(icon, color: Colors.white70, size: 20),
                    suffixIcon: suffixIcon,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    errorStyle: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  validator: validator,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final Function(bool) onChanged;
  final bool isDark;
  final bool isSmallScreen;
  final VoidCallback onShowTerms;
  final VoidCallback onShowPrivacy;

  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.isDark,
    this.isSmallScreen = false,
    required this.onShowTerms,
    required this.onShowPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? const Color(0xFFF48C06) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? const Color(0xFFF48C06) : Colors.white30,
                  width: 1.5,
                ),
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF48C06).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 14,
                color: value ? Colors.black : Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(text: 'Kullanım '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: onShowTerms,
                        child: const Text(
                          'şartlarını',
                          style: TextStyle(
                            color: Color(0xFFF48C06),
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFF48C06),
                            shadows: [
                              Shadow(color: Color(0xFFF48C06), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' ve '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: onShowPrivacy,
                        child: const Text(
                          'gizlilik politikasını',
                          style: TextStyle(
                            color: Color(0xFFF48C06),
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFF48C06),
                            shadows: [
                              Shadow(color: Color(0xFFF48C06), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' kabul ediyorum'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const String _termsOfServiceText = """
KULLANIM KOŞULLARI VE HİZMET ŞARTLARI

Son Güncelleme: 17 Şubat 2026

1. KABUL EDİLEN ŞARTLAR
Kadrox uygulamasını indirerek veya kullanarak, bu kullanım koşullarına bağlı kalmayı kabul etmiş sayılırsınız. Eğer bu şartları kabul etmiyorsanız, uygulamayı kullanmamanız gerekmektedir.

2. HİZMET KAPSAMI VE LİSANS
Kadrox, KPSS (Kamu Personeli Seçme Sınavı) hazırlık sürecinde kullanıcılara eğitim içerikleri, testler, ilerleme takibi ve odaklanma araçları (Pomodoro vb.) sunan bir platformdur. Kullanıcıya sadece kişisel, ticari olmayan kullanım için geri alınabilir bir lisans verilmektedir.

3. KULLANICI HESAPLARI VE GÜVENLİK
- Uygulama özelliklerinden tam yararlanmak için hesap oluşturmanız gerekmektedir.
- Kayıt sırasında verilen bilgilerin doğruluğundan kullanıcı sorumludur.
- Şifrenizin gizliliğini korumak sizin sorumluluğunuzdadır. Hesabınız altındaki tüm faaliyetlerden siz sorumlu tutulursunuz.

4. FİKRİ MÜLKİYET HAKLARI
Uygulama içerisindeki tüm kodlar, tasarımlar, logolar, metinler, sorular ve grafikler Kadrox'un mülkiyetindedir. Yazılı izin olmaksızın içeriğin kopyalanması, paylaşılması veya üzerinde değişiklik yapılması kesinlikle yasaktır ve yasal işlem başlatılmasına sebebiyet verir.

5. ÜCRETLİ HİZMETLER VE ABONELİKLER
- Bazı özellikler uygulama içi satın alma veya abonelik gerektirebilir.
- Ödeme işlemleri App Store/Google Play Store üzerinden gerçekleştirilir.
- Ücret iadesi politikası, ilgili mağazanın kurallarına tabidir.

6. FERAGATNAME VE SORUMLULUK SINIRLANDIRILMASI
- Kadrox, sınav başarısını garanti etmez; sadece yardımcı bir araçtır.
- Teknik aksaklıklardan, veri kayıplarından veya yanlış sorulardan kaynaklanabilecek doğrudan veya dolaylı zararlardan geliştirici sorumlu tutulamaz.
- Hizmet "olduğu gibi" sunulmaktadır.

7. DEĞİŞİKLİKLER
Kadrox, bu koşulları herhangi bir zamanda değiştirme hakkını saklı tutar. Değişiklikler uygulama üzerinden bildirilecektir.
""";

const String _privacyPolicyText = """
GİZLİLİK POLİTİKASI

Son Güncelleme: 17 Şubat 2026

Bu gizlilik politikası, Kadrox uygulamasını kullandığınızda bilgilerinizin nasıl toplandığını, kullanıldığını ve korunduğunu açıklamaktadır.

1. TOPLANAN VERİLER
- Kayıt Bilgileri: Adınız, e-posta adresiniz ve şifreniz.
- Sınav Tercihleri: Hedeflediğiniz KPSS türü ve puan türleri.
- Kullanım Verileri: Çözülen sorular, test sonuçları, odaklanma süreleri ve uygulama içi etkileşimleriniz.
- Cihaz Bilgisi: Model, işletim sistemi ve anonim analitik veriler.

2. VERİLERİN KULLANIM AMACI
- Kişiselleştirilmiş bir hazırlık programı sunmak.
- İlerlemenizi takip etmek ve eksik olduğunuz konuları analiz etmek.
- Uygulama performansını iyileştirmek ve hataları tespit etmek.
- Önemli güncellemeler hakkında sizi bilgilendirmek.

3. VERİ PAYLAŞIMI VE GÜVENLİK
- Verileriniz asla üçüncü taraflara ticari amaçlarla satılmaz.
- Verileriniz, dünya standartlarında güvenlik protokollerine sahip güvenli sunucularda (Google Firebase/Cloud) barındırılmaktadır.
- Yasal zorunluluklar haricinde bilgileriniz paylaşılmaz.

4. KULLANICI HAKLARI
- Hesabınızı ve tüm ilişkili verilerinizi dilediğiniz zaman "Hesabı Sil" seçeneğiyle kalıcı olarak silebilirsiniz.
- Verilerinizin düzeltilmesini talep etme hakkına sahipsiniz.

5. İLETİŞİM
Gizlilik veya veri güvenliği ile ilgili sorularınız için uygulama içerisinden bizimle iletişime geçebilirsiniz.
""";

class _LegalModal extends StatelessWidget {
  final String title;
  final String content;

  const _LegalModal({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: const Color(0xFF1E3C72),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Text(
                content,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3C72),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Anladım',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
