import 'package:flutter/material.dart';
import 'dart:ui';

class ExamsPage extends StatelessWidget {
  const ExamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          // Background Glows
          if (isDark) ...[
            Positioned(
              top: -100,
              right: -100,
              child: _buildBlurCircle(
                size: screenWidth,
                color: const Color(0xFFF59E0B).withOpacity(0.1),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: _buildBlurCircle(
                size: screenWidth * 1.2,
                color: const Color(0xFFD97706).withOpacity(0.05),
              ),
            ),
          ],

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 20,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Denemeler',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer for balance
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated-like Icon Container
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF59E0B).withOpacity(0.2),
                                  const Color(0xFFD97706).withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.assignment_rounded,
                              size: 72,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Title
                          const Text(
                            'Denemeler Yakında!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          
                          // Glassmorphic Info Card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? Colors.white.withOpacity(0.03) 
                                      : Colors.black.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark 
                                        ? Colors.white.withOpacity(0.05) 
                                        : Colors.black.withOpacity(0.05),
                                  ),
                                ),
                                child: Text(
                                  'Denemeler eklendikçe buradan görebilirsin. Canlı Türkiye geneli denemeler ve bireysel denemeler yapabileceksin.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark 
                                        ? Colors.white.withOpacity(0.7) 
                                        : Colors.black.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Upcoming Features List
                          _buildFeatureRow(
                            Icons.public_rounded,
                            'Türkiye Geneli Canlı Denemeler',
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureRow(
                            Icons.person_outline_rounded,
                            'Bireysel Deneme Sınavları',
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureRow(
                            Icons.analytics_outlined,
                            'Detaylı Analiz & İstatistik',
                            isDark,
                          ),
                        ],
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

  Widget _buildFeatureRow(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFFF59E0B).withOpacity(0.8),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildBlurCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.2, 1.0],
        ),
      ),
    );
  }
}
