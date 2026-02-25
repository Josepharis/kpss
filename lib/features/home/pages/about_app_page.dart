import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF010101)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            // Mesh Background
            _buildMeshBackground(isDark, screenWidth),

            // Content
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(context, isDark),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroSection(isDark),
                        const SizedBox(height: 20),
                        _buildSectionTitle('ÖĞRENME ARAÇLARI', isDark),
                        const SizedBox(height: 10),
                        _buildFeatureCard(
                          icon: Icons.psychology_rounded,
                          title: 'Akıllı Soru Sistemi',
                          description:
                              'Analizler ile zayıf yanlarınızı tespit eder, size özel tekrarlar sunar.',
                          color: Colors.blueAccent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildFeatureCard(
                          icon: Icons.podcasts_rounded,
                          title: 'Podcast ve Video',
                          description:
                              'Uzman eğitmenlerden sesli ve görüntülü ders içerikleriyle her yerde öğrenin.',
                          color: Colors.purpleAccent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildFeatureCard(
                          icon: Icons.style_rounded,
                          title: 'Bilgi Kartları',
                          description:
                              'Görsel hafıza teknikleriyle terimleri ve önemli bilgileri anında ezberleyin.',
                          color: Colors.orangeAccent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildFeatureCard(
                          icon: Icons.picture_as_pdf_rounded,
                          title: 'PDF Ders Notları',
                          description:
                              'Konu anlatımlarına ait dijital dokümanlara hızlıca erişin ve indirin.',
                          color: Colors.redAccent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('PLANLAMA VE TAKİP', isDark),
                        const SizedBox(height: 10),
                        _buildFeatureCard(
                          icon: Icons.event_note_rounded,
                          title: 'Kişisel Programım',
                          description:
                              'Günlük hedeflerinizi belirleyin, ders çalışma düzeninizi kontrol altında tutun.',
                          color: Colors.tealAccent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildFeatureCard(
                          icon: Icons.timer_rounded,
                          title: 'Sınav Sayacı',
                          description:
                              'KPSS ve AGS sınavlarına kalan süreyi anlık olarak takip edin.',
                          color: Colors.amberAccent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildFeatureCard(
                          icon: Icons.insights_rounded,
                          title: 'Gelişmiş İstatistik',
                          description:
                              'Doğru-yanlış oranlarınızı ve başarı yüzdenizi grafiklerle inceleyin.',
                          color: Colors.indigoAccent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('TEKNOLOJİ', isDark),
                        const SizedBox(height: 8),
                        _buildCompactInfoTile(
                          icon: Icons.cloud_sync_rounded,
                          title: 'Bulut Senkronizasyon',
                          subtitle:
                              'Verileriniz tüm cihazlarınızda güvenle saklanır.',
                          isDark: isDark,
                        ),
                        _buildCompactInfoTile(
                          icon: Icons.bolt_rounded,
                          title: 'Hızlı Erişim ve Çevrimdışı',
                          subtitle:
                              'Önbellek teknolojisiyle internet olmasa da çalışın.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 24),
                        _buildContactSection(isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark, double screenWidth) {
    return Positioned.fill(
      child: Opacity(
        opacity: isDark ? 0.5 : 0.8,
        child: Stack(
          children: [
            Positioned(
              top: -screenWidth * 0.2,
              right: -screenWidth * 0.2,
              child: _buildBlurCircle(
                size: screenWidth * 1.2,
                color: isDark
                    ? const Color(0xFF1E3A8A).withOpacity(0.2)
                    : const Color(0xFFDBEAFE),
              ),
            ),
            Positioned(
              bottom: -screenWidth * 0.4,
              left: -screenWidth * 0.4,
              child: _buildBlurCircle(
                size: screenWidth * 1.5,
                color: isDark
                    ? const Color(0xFF581C87).withOpacity(0.15)
                    : const Color(0xFFF3E8FF),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Uygulama Bilgisi',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: (isDark ? const Color(0xFF010101) : const Color(0xFFF8FAFF))
                .withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDark) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 35,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kadrox',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'V1.0.0 (Global)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.blueAccent.shade100 : Colors.blueAccent.shade700,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildCompactInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(bool isDark) {
    return Center(
      child: Column(
        children: [
          Text(
            'Sorularınız mı var?',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'yftsoftware@gmail.com',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.blueAccent,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}
