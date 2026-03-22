import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/models/pomodoro_session.dart';
import '../../../core/services/pomodoro_storage_service.dart';
import '../../../../main.dart';

class PomodoroSaveSessionPage extends StatefulWidget {
  final int sessionCount;
  final int totalMinutes;
  final int totalSeconds;
  final int sessionDuration;
  final VoidCallback onSaved;

  const PomodoroSaveSessionPage({
    super.key,
    required this.sessionCount,
    required this.totalMinutes,
    required this.totalSeconds,
    required this.sessionDuration,
    required this.onSaved,
  });

  @override
  State<PomodoroSaveSessionPage> createState() =>
      _PomodoroSaveSessionPageState();
}

class _PomodoroSaveSessionPageState extends State<PomodoroSaveSessionPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _notesController = TextEditingController();
  final _correctController = TextEditingController();
  final _wrongController = TextEditingController();
  final _totalController = TextEditingController();

  final PomodoroStorageService _storageService = PomodoroStorageService();
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _topicController.dispose();
    _notesController.dispose();
    _correctController.dispose();
    _wrongController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final session = PomodoroSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        sessionCount: widget.sessionCount,
        sessionDuration: widget.sessionDuration,
        totalMinutes: widget.totalMinutes,
        totalSeconds: widget.totalSeconds,
        topic: _topicController.text.trim().isEmpty
            ? null
            : _topicController.text.trim(),
        correctAnswers: _correctController.text.trim().isEmpty
            ? null
            : int.tryParse(_correctController.text.trim()),
        wrongAnswers: _wrongController.text.trim().isEmpty
            ? null
            : int.tryParse(_wrongController.text.trim()),
        totalQuestions: _totalController.text.trim().isEmpty
            ? null
            : int.tryParse(_totalController.text.trim()),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await _storageService.saveSession(session);

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);

        final mainScreen = MainScreen.of(context);
        if (mainScreen != null) {
          mainScreen.refreshProfilePage();
        }

        PremiumSnackBar.show(
          context,
          message: 'Çalışmanız başarıyla kaydedildi!',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        PremiumSnackBar.show(
          context,
          message: 'Kaydedilirken bir hata oluştu: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  String _formatSeconds(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    List<String> parts = [];
    if (hours > 0) parts.add('$hours sa');
    if (minutes > 0) parts.add('$minutes dk');
    parts.add('$seconds sn');

    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Gradient Blobs
          _buildBackgroundBlobs(size, isDark),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(isDark),
                SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _fadeAnimation.drive(
                            Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryCard(isDark),
                              const SizedBox(height: 24),
                              _buildSectionTitle('ÇALIŞMA DETAYLARI', isDark),
                              const SizedBox(height: 12),
                              _buildGlassInput(
                                controller: _topicController,
                                label: 'Çalışılan Konu',
                                hint: 'Örn: Matematik - Fonksiyonlar',
                                icon: Icons.auto_stories_rounded,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 20),
                              _buildScoreSection(isDark),
                              const SizedBox(height: 20),
                              _buildGlassInput(
                                controller: _notesController,
                                label: 'Çalışma Notu',
                                hint: 'Bugünkü verimin nasıldı? Neleri öğrendin?',
                                icon: Icons.edit_note_rounded,
                                isDark: isDark,
                                maxLines: 4,
                              ),
                              const SizedBox(height: 32),
                              _buildActionButtons(isDark),
                            ],
                          ),
                        ),
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

  Widget _buildBackgroundBlobs(Size size, bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.1,
            child: _buildBlob(
              size: size.width * 0.8,
              color: const Color(0xFF6366F1).withOpacity(isDark ? 0.08 : 0.05),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.2,
            left: -size.width * 0.2,
            child: _buildBlob(
              size: size.width * 0.9,
              color: const Color(0xFFA855F7).withOpacity(isDark ? 0.06 : 0.04),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'OTURUMU KAYDET',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      centerTitle: true,
      pinned: true,
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.timer_rounded, size: 140, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Harika Bir İş Çıkardın!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Oturum başarıyla tamamlandı.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatBox(
                        'OTURUM',
                        widget.sessionCount.toString(),
                        Icons.repeat_rounded,
                      ),
                      _buildStatBox(
                        'SÜRE',
                        _formatSeconds(widget.totalSeconds),
                        Icons.history_toggle_off_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white30 : Colors.black38,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                icon: Icon(icon, color: Colors.indigoAccent, size: 22),
                label: Text(label),
                labelStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black45,
                  fontSize: 13,
                ),
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white12 : Colors.black12,
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniInput(
            controller: _correctController,
            label: 'DOĞRU',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniInput(
            controller: _wrongController,
            label: 'YANLIŞ',
            icon: Icons.cancel_rounded,
            color: const Color(0xFFF43F5E),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniInput(
            controller: _totalController,
            label: 'TOPLAM',
            icon: Icons.functions_rounded,
            color: Colors.blueAccent,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white24 : Colors.black26,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: color, size: 16),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Column(
      children: [
        GestureDetector(
          onTap: _isSaving ? null : _saveSession,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'KAYDI TAMAMLA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'İPTAL ET',
            style: TextStyle(
              color: isDark ? Colors.white30 : Colors.black38,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}
