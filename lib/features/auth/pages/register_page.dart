import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';

enum KpssType {
  ortaOgretim,
  onLisans,
  lisans,
  ags,
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
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
  late Animation<double> _fadeAnimation;

  final Map<KpssType, String> _kpssTypeLabels = {
    KpssType.ortaOgretim: 'Orta Öğretim',
    KpssType.onLisans: 'Ön Lisans',
    KpssType.lisans: 'Lisans',
    KpssType.ags: 'AGS',
  };

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lütfen KPSS türünü seçin'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      if (!_agreeToTerms) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lütfen kullanım şartlarını kabul edin'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
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
    final isSmallScreen = screenHeight < 750;
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
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        // Back Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        // Logo
                        Center(
                          child: Container(
                            width: isSmallScreen ? 60 : 70,
                            height: isSmallScreen ? 60 : 70,
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
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: AppColors.primaryBlue.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_add_rounded,
                              size: isSmallScreen ? 30 : 35,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),
                        // Title
                        Text(
                          'Hesap Oluştur',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 24 : 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Text(
                          'Yeni hesap oluşturun ve başlayın',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isSmallScreen ? 18 : 22),
                        // Name Field
                        _GlassmorphicTextField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          label: 'Ad Soyad',
                          hint: 'Adınız ve soyadınız',
                          icon: Icons.person_outline_rounded,
                          isSmallScreen: isSmallScreen,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen adınızı ve soyadınızı girin';
                            }
                            if (value.length < 3) {
                              return 'Ad soyad en az 3 karakter olmalıdır';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),
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
                        SizedBox(height: isSmallScreen ? 10 : 12),
                        // KPSS Type Dropdown
                        _KpssTypeDropdown(
                          selectedType: _selectedKpssType,
                          onTypeSelected: (type) {
                            setState(() {
                              _selectedKpssType = type;
                            });
                            HapticFeedback.selectionClick();
                          },
                          kpssTypeLabels: _kpssTypeLabels,
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),
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
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
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
                        // Confirm Password Field
                        _GlassmorphicTextField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          label: 'Şifre Tekrar',
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscureText: !_isConfirmPasswordVisible,
                          isSmallScreen: isSmallScreen,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen şifrenizi tekrar girin';
                            }
                            if (value != _passwordController.text) {
                              return 'Şifreler eşleşmiyor';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),
                        // Terms and Conditions
                        _TermsCheckbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value;
                            });
                            HapticFeedback.selectionClick();
                          },
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        // Register Button
                        Container(
                          height: isSmallScreen ? 46 : 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
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
                              onTap: _isLoading ? null : _handleRegister,
                              borderRadius: BorderRadius.circular(14),
                              child: Center(
                                child: _isLoading
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryBlue,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Kayıt Ol',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16 : 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryBlue,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Zaten hesabınız var mı? ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: isSmallScreen ? 11 : 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Giriş Yap',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                      ],
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
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
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
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: isSmallScreen ? 13 : 14,
              ),
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                icon,
                color: Colors.white.withOpacity(0.9),
                size: 18,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmallScreen ? 11 : 13,
              ),
              errorStyle: TextStyle(
                color: Colors.redAccent,
                fontSize: isSmallScreen ? 10 : 11,
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

class _KpssTypeDropdown extends StatelessWidget {
  final KpssType? selectedType;
  final Function(KpssType) onTypeSelected;
  final Map<KpssType, String> kpssTypeLabels;
  final bool isSmallScreen;

  const _KpssTypeDropdown({
    required this.selectedType,
    required this.onTypeSelected,
    required this.kpssTypeLabels,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
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
          child: DropdownButtonFormField<KpssType>(
            value: selectedType,
            decoration: InputDecoration(
              labelText: 'KPSS Türü',
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.school_outlined,
                color: Colors.white.withOpacity(0.9),
                size: 18,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmallScreen ? 11 : 13,
              ),
            ),
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: const Color(0xFF2A5298),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.9),
              size: 22,
            ),
            items: KpssType.values.map((KpssType type) {
              return DropdownMenuItem<KpssType>(
                value: type,
                child: Text(
                  kpssTypeLabels[type]!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (KpssType? newValue) {
              if (newValue != null) {
                onTypeSelected(newValue);
              }
            },
            validator: (value) {
              if (value == null) {
                return 'Lütfen KPSS türünü seçin';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final Function(bool) onChanged;
  final bool isSmallScreen;

  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isSmallScreen ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: value,
                  onChanged: (val) => onChanged(val ?? false),
                  activeColor: Colors.white,
                  checkColor: AppColors.primaryBlue,
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.7),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(!value),
                  child: Text(
                    'Kullanım şartlarını ve gizlilik politikasını kabul ediyorum',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
