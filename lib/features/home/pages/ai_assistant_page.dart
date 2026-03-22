import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class AiAssistantPage extends StatelessWidget {
  const AiAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Glows
          _buildBackglow(isDark),
          
          SafeArea(
            child: Column(
              children: [
                _buildModernHeader(context, isDark),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainHero(isDark),
                        const SizedBox(height: 28),
                        _buildSectionTag('YAPAY ZEKA MODÜLLERİ', isDark),
                        const SizedBox(height: 12),
                        
                        // Compact Rich Cards
                        _buildCompactRichCard(
                          icon: Icons.psychology_rounded,
                          title: 'Kişisel Soru Üretimi',
                          desc: 'Hatalarını analiz ederek sana özel, eksiklerini kapatan sorular üretir.',
                          color: const Color(0xFF6366F1),
                          isDark: isDark,
                        ),
                        _buildCompactRichCard(
                          icon: Icons.menu_book_rounded,
                          title: 'Eksik Odaklı Anlatım',
                          desc: 'Anlamadığın konuları basitleştirir ve kilit noktaları özel anlatır.',
                          color: const Color(0xFFA855F7),
                          isDark: isDark,
                        ),
                        _buildCompactRichCard(
                          icon: Icons.auto_awesome_motion_rounded,
                          title: 'Kişiye Özel Program',
                          desc: 'Hızına ve hedefine göre dinamik, her an güncellenen çalışma takvimi.',
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                        _buildCompactRichCard(
                          icon: Icons.query_stats_rounded,
                          title: 'Sınav Trend Analizi',
                          desc: 'Çıkması muhtemel konuları ve ÖSYM trendlerini verilerle tahmin eder.',
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                        _buildCompactRichCard(
                          icon: Icons.mic_rounded,
                          title: 'Sesli Etkileşim',
                          desc: 'Çalışırken ellerin serbest, sesli soru sor ve anında cevap al.',
                          color: const Color(0xFFEC4899),
                          isDark: isDark,
                        ),
                        _buildCompactRichCard(
                          icon: Icons.description_rounded,
                          title: 'PDF/Döküman Analizi',
                          desc: 'Kendi notlarını yükle, AI senin için en önemli yerleri özetlesin.',
                          color: const Color(0xFF3B82F6),
                          isDark: isDark,
                        ),
                        
                        const SizedBox(height: 32),
                        _buildFooterInfo(isDark),
                        const SizedBox(height: 40),
                      ],
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

  Widget _buildBackglow(bool isDark) {
    return Positioned(
      top: -100,
      right: -50,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withOpacity(isDark ? 0.1 : 0.08),
          shape: BoxShape.circle,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          _buildBackBtn(context, isDark),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Assistant Hub',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              Text(
                'Gelecek yakında hizmetinizde',
                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          _buildVerBadge(),
        ],
      ),
    );
  }

  Widget _buildBackBtn(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
      ),
    );
  }

  Widget _buildVerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFA855F7).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.2)),
      ),
      child: const Text(
        'BETA 2.0',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFA855F7)),
      ),
    );
  }

  Widget _buildMainHero(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Yakında hizmetinizde olacaklar',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sana özel çalışan yapay zeka deneyimi ve çok daha fazlası tasarlanıyor.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTag(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white24 : Colors.black26,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildCompactRichCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.035) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.lock_rounded,
            size: 12,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.15),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
            const SizedBox(width: 10),
            Text(
              'Geliştirme süreci devam ediyor.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
