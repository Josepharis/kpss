import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      HapticFeedback.mediumImpact();

      final authService = AuthService();
      final result = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final padding = screenWidth * 0.06;

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
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: padding),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: isSmallScreen ? 20 : 30),
                              // Logo
                              Center(
                                child: Container(
                                  width: isSmallScreen ? 80 : 90,
                                  height: isSmallScreen ? 80 : 90,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        Colors.white.withOpacity(0.95),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: AppColors.primaryBlue.withOpacity(0.3),
                                        blurRadius: 25,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.school_rounded,
                                    size: isSmallScreen ? 40 : 45,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 20 : 25),
                              // Title
                              Text(
                                'Hoş Geldiniz',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 28 : 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isSmallScreen ? 6 : 8),
                              Text(
                                'Hesabınıza giriş yapın',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isSmallScreen ? 30 : 35),
                              // Email Field
                              _GlassmorphicTextField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                label: 'E-posta',
                                hint: 'ornek@email.com',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                isSmallScreen: isSmallScreen,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Lütfen e-posta adresinizi girin';
                                  }
                                  if (!value.contains('@') || !value.contains('.')) {
                                    return 'Geçerli bir e-posta adresi girin';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: isSmallScreen ? 14 : 16),
                              // Password Field
                              _GlassmorphicTextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                label: 'Şifre',
                                hint: '••••••••',
                                icon: Icons.lock_outlined,
                                obscureText: !_isPasswordVisible,
                                isSmallScreen: isSmallScreen,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Lütfen şifrenizi girin';
                                  }
                                  if (value.length < 6) {
                                    return 'Şifre en az 6 karakter olmalıdır';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: isSmallScreen ? 10 : 12),
                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // TODO: Implement forgot password
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Şifremi Unuttum',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSmallScreen ? 13 : 14,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 20 : 25),
                              // Login Button
                              Container(
                                height: isSmallScreen ? 50 : 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.98),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                    BoxShadow(
                                      color: AppColors.primaryBlue.withOpacity(0.3),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isLoading ? null : _handleLogin,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Center(
                                      child: _isLoading
                                          ? SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                  AppColors.primaryBlue,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              'Giriş Yap',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 17 : 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryBlue,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 20 : 24),
                              // Register Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Hesabınız yok mu? ',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: isSmallScreen ? 13 : 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pushNamed('/register');
                                    },
                                    child: Text(
                                      'Kayıt Ol',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 13 : 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isSmallScreen ? 20 : 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassmorphicTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool isSmallScreen;

  const _GlassmorphicTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 14 : 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: isSmallScreen ? 14 : 15,
              ),
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                icon,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: isSmallScreen ? 14 : 16,
              ),
              errorStyle: TextStyle(
                color: Colors.redAccent,
                fontSize: isSmallScreen ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            validator: validator,
          ),
        ),
      ),
    );
  }
}
