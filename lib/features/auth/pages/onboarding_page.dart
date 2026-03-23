import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _blobController;
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Kadrox\'a Hoş Geldin',
      subtitle: 'SINIRLARI ZORLA',
      description: 'KPSS ve AGS hazırlık sürecinde en yakın çalışma arkadaşın olan Kadrox ile tanış. Başarıya giden yolda sana rehberlik etmek için buradayız.',
      image: Icons.rocket_launch_rounded,
      color: const Color(0xFF6366F1),
      secondaryColor: const Color(0xFF818CF8),
    ),
    OnboardingItem(
      title: 'Zengin İçerik Arşivi',
      subtitle: 'HER AN, HER YERDE',
      description: 'Ders notları, videolar, podcastler ve PDF dosyaları ile çalışma ortamını cebine taşı. En güncel kaynaklar her zaman elinin altında.',
      image: Icons.library_books_rounded,
      color: const Color(0xFFEC4899),
      secondaryColor: const Color(0xFFF472B6),
    ),
    OnboardingItem(
      title: 'Akıllı Soru Çözümü',
      subtitle: 'EKSİKSİZ HAZIRLAN',
      description: 'Konu testleri, çıkmış sorular ve AI destekli özel içeriklerle eksiklerini anında tespit et ve gidermeye başla.',
      image: Icons.psychology_rounded,
      color: const Color(0xFF10B981),
      secondaryColor: const Color(0xFF34D399),
    ),
    OnboardingItem(
      title: 'Başarını Takip Et',
      subtitle: 'ZİRVEYE ULAŞ',
      description: 'Haftalık programını oluştur, eksik olduğun konuları gör ve gelişimini detaylı grafiklerle izle. Başarı artık bir tesadüf değil.',
      image: Icons.query_stats_rounded,
      color: const Color(0xFFF59E0B),
      secondaryColor: const Color(0xFFFBBF24),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _blobController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Stack(
        children: [
          // Dynamic Animated Blobs
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, child) {
              return Stack(
                children: [
                   _buildBlob(
                    top: -100 + (math.sin(_blobController.value * 2 * math.pi) * 50),
                    left: -50 + (math.cos(_blobController.value * 2 * math.pi) * 30),
                    size: 400,
                    color: _items[_currentPage].color.withOpacity(0.2),
                  ),
                  _buildBlob(
                    bottom: -50 + (math.cos(_blobController.value * 2 * math.pi) * 40),
                    right: -100 + (math.sin(_blobController.value * 2 * math.pi) * 60),
                    size: 500,
                    color: _items[_currentPage].secondaryColor.withOpacity(0.15),
                  ),
                ],
              );
            },
          ),
          
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              HapticFeedback.selectionClick();
            },
            itemBuilder: (context, index) {
              return _buildPage(_items[index], isDark, screenHeight, screenWidth);
            },
          ),

          // Bottom Navigation UI
          Positioned(
            bottom: 60,
            left: 30,
            right: 30,
            child: Row(
              children: [
                // Indicators
                Row(
                  children: List.generate(
                    _items.length,
                    (index) => _buildIndicator(index == _currentPage, _items[_currentPage].color),
                  ),
                ),
                const Spacer(),
                // Start/Next Button
                GestureDetector(
                  onTap: () {
                    if (_currentPage == _items.length - 1) {
                      _finishOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutQuart,
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _items[_currentPage].color,
                          _items[_currentPage].secondaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _items[_currentPage].color.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _items.length - 1 ? 'BAŞLAYALIM' : 'İLERLE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Skip Button
          Positioned(
            top: 60,
            right: 20,
            child: TextButton(
              onPressed: _finishOnboarding,
              child: Text(
                'Atla',
                style: TextStyle(
                  color: (isDark ? Colors.white : AppColors.textPrimary).withOpacity(0.4),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob({double? top, double? left, double? right, double? bottom, required double size, required Color color}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingItem item, bool isDark, double screenHeight, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Visual Illustration Container
          Container(
            height: screenHeight * 0.4,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Organic background shape
                Transform.rotate(
                  angle: _blobController.value * 2 * math.pi,
                  child: Container(
                    width: screenWidth * 0.7,
                    height: screenWidth * 0.7,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(screenWidth * 0.3),
                    ),
                  ),
                ),
                // Icon with glass effect
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isDark ? 0.05 : 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Icon(
                        item.image,
                        size: 100,
                        color: item.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Subtitle (Category)
          Text(
            item.subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: item.color,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 12),
          // Main Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: (isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600),
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.1),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: 6,
      width: isActive ? 30 : 6,
      decoration: BoxDecoration(
        gradient: isActive 
          ? LinearGradient(colors: [color, color.withOpacity(0.5)])
          : LinearGradient(colors: [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.3)]),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_shown', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}

class OnboardingItem {
  final String title;
  final String subtitle;
  final String description;
  final IconData image;
  final Color color;
  final Color secondaryColor;

  OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.image,
    required this.color,
    required this.secondaryColor,
  });
}
