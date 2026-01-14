import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/subscription_service.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with TickerProviderStateMixin {
  final SubscriptionService _subscriptionService = SubscriptionService();
  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.free();
  bool _isLoading = true;
  String? _selectedPlan;
  
  late AnimationController _waveController;
  late AnimationController _particleController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
    
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
  }

  @override
  void dispose() {
    _waveController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionStatus() async {
    final status = await _subscriptionService.getSubscriptionStatus();
    setState(() {
      _subscriptionStatus = status;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Container(
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
                          final progress = ((_particleController.value + delay) * speed) % 1.0;
                          final moveDistance = screenHeight * 1.5;
                          final x = startX + math.cos(angle) * moveDistance * progress;
                          final y = startY + math.sin(angle) * moveDistance * progress;
                          final wrappedX = x % screenWidth;
                          final wrappedY = y % screenHeight;
                          final opacity = (math.sin(progress * math.pi)).clamp(0.0, 1.0) * 0.6;
                          
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
                                      color: Colors.white.withOpacity(0.8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    // Content
                    Column(
                      children: [
                        // Compact Header
                        Container(
                          padding: EdgeInsets.only(
                            top: statusBarHeight + (isSmallScreen ? 8 : 12),
                            bottom: isSmallScreen ? 12 : 16,
                            left: isTablet ? 20 : 16,
                            right: isTablet ? 20 : 16,
                          ),
                          child: Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: isSmallScreen ? 16 : 18,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 12 : 16),
                              Expanded(
                                child: Text(
                                  'Premium',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 22 : 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (_subscriptionStatus.isPremium)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 10 : 12,
                                    vertical: isSmallScreen ? 6 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: isSmallScreen ? 16 : 18,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Aktif',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 11 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Content - Tek sayfada göster
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isTablet ? 20 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Premium Features - Kompakt
                                _buildPremiumFeatures(isDark, isSmallScreen),
                                SizedBox(height: isSmallScreen ? 12 : 14),
                                
                                // Compact Pricing Plans
                                _buildCompactPricingPlans(isDark, isSmallScreen, isTablet),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPremiumFeatures(bool isDark, bool isSmallScreen) {
    final features = [
      {'icon': Icons.library_books_rounded, 'text': 'Tüm konulara erişim', 'color': AppColors.primaryBlue},
      {'icon': Icons.video_library_rounded, 'text': 'Sınırsız içerik', 'color': AppColors.gradientPurpleStart},
      {'icon': Icons.picture_as_pdf_rounded, 'text': 'PDF indirme', 'color': AppColors.gradientRedStart},
      {'icon': Icons.analytics_rounded, 'text': 'Gelişmiş istatistikler', 'color': AppColors.gradientGreenStart},
      {'icon': Icons.block_rounded, 'text': 'Reklamsız', 'color': AppColors.gradientOrangeStart},
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.4),
                      Colors.orange.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: isSmallScreen ? 16 : 18,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 10),
              Text(
                'Premium Özellikler',
                style: TextStyle(
                  fontSize: isSmallScreen ? 15 : 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          ...features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            return Container(
              margin: EdgeInsets.only(bottom: index < features.length - 1 ? (isSmallScreen ? 6 : 8) : 0),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 10 : 12,
                vertical: isSmallScreen ? 9 : 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 7 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (feature['color'] as Color).withValues(alpha: 0.35),
                          (feature['color'] as Color).withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: (feature['color'] as Color).withValues(alpha: 0.25),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      size: isSmallScreen ? 16 : 18,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 10 : 12),
                  Expanded(
                    child: Text(
                      feature['text'] as String,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: isSmallScreen ? 14 : 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactPricingPlans(bool isDark, bool isSmallScreen, bool isTablet) {
    final plans = [
      {
        'title': 'Aylık',
        'price': '149',
        'period': '/ay',
        'type': 'monthly',
        'isPopular': false,
        'savings': null,
      },
      {
        'title': '6 Aylık',
        'price': '799',
        'period': '/6 ay',
        'type': '6monthly',
        'isPopular': true,
        'savings': '1 ay bedava',
      },
      {
        'title': 'Yıllık',
        'price': '1299',
        'period': '/yıl',
        'type': 'yearly',
        'isPopular': false,
        'savings': '3 ay bedava',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fiyatlandırma',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
          SizedBox(height: isSmallScreen ? 8 : 10),
          ...plans.map((plan) => Padding(
              padding: EdgeInsets.only(bottom: isSmallScreen ? 7 : 9),
              child: _buildCompactPlanCard(
                title: plan['title'] as String,
                price: plan['price'] as String,
                period: plan['period'] as String,
                type: plan['type'] as String,
                isPopular: plan['isPopular'] as bool,
                savings: plan['savings'] as String?,
                isSmallScreen: isSmallScreen,
                isSelected: _selectedPlan == plan['type'],
                onTap: () {
                  setState(() {
                    _selectedPlan = plan['type'] as String;
                  });
                  _handlePurchase(plan['type'] as String);
                },
              ),
            )),
      ],
    );
  }

  Widget _buildCompactPlanCard({
    required String title,
    required String price,
    required String period,
    required String type,
    required bool isPopular,
    String? savings,
    required bool isSmallScreen,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isPopular || isSelected ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: isPopular || isSelected ? 0.45 : 0.25),
          width: isPopular || isSelected ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: isPopular || isSelected ? 12 : 6,
            spreadRadius: isPopular || isSelected ? 1.5 : 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.9),
                      Colors.orange.withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'POPÜLER',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (isSelected) ...[
                            SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 22 : 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 3),
                          Padding(
                            padding: EdgeInsets.only(top: isSmallScreen ? 5 : 6),
                            child: Text(
                              'TL$period',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (savings != null) ...[
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                savings,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                SizedBox(
                  width: isSmallScreen ? 75 : 85,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryBlue,
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 9 : 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      elevation: isPopular || isSelected ? 3 : 1,
                    ),
                    child: Text(
                      'Satın Al',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePurchase(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Premium Satın Al'),
        content: Text(
          'In-App Purchase entegrasyonu yakında eklenecek.\n\n'
          'Test için manuel abonelik eklemek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final days = type == 'yearly'
                  ? 365
                  : type == '6monthly'
                      ? 180
                      : 30;
              final endDate = DateTime.now().add(Duration(days: days));
              await _subscriptionService.setSubscriptionStatus(
                status: 'premium',
                type: type,
                endDate: endDate,
              );
              await _loadSubscriptionStatus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Premium abonelik aktif edildi! (Test)'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Test Aboneliği Ekle'),
          ),
        ],
      ),
    );
  }
}

// Wave Painter for animated background
class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 50.0;
    final waveLength = size.width / 2.5;

    path.moveTo(0, size.height * 0.7);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.7 +
          waveHeight * math.sin((x / waveLength * 2 * math.pi) + animationValue);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Second wave
    final path2 = Path();
    path2.moveTo(0, size.height * 0.8);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.8 +
          waveHeight * 0.7 *
              math.sin((x / waveLength * 2 * math.pi) + animationValue + math.pi);
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
