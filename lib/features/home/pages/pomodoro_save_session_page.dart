import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/models/pomodoro_session.dart';
import '../../../core/services/pomodoro_storage_service.dart';
import '../../../../main.dart';

class PomodoroSaveSessionPage extends StatefulWidget {
  final int sessionCount;
  final int totalMinutes;
  final int sessionDuration;
  final VoidCallback onSaved;

  const PomodoroSaveSessionPage({
    super.key,
    required this.sessionCount,
    required this.totalMinutes,
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
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
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

        // Refresh statistics on profile page
        final mainScreen = MainScreen.of(context);
        if (mainScreen != null) {
          mainScreen.refreshProfilePage();
        }

        PremiumSnackBar.show(
          context,
          message: 'Kayıt başarıyla kaydedildi',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        PremiumSnackBar.show(
          context,
          message: 'Hata: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 700;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Çalışma Kaydı',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 20,
              vertical: isCompact ? 12 : 16,
            ),
            children: [
              // Kompakt Özet Kartı
              _buildCompactSummary(isDark, isCompact),

              SizedBox(height: isCompact ? 16 : 20),

              // Konu Input - Kompakt
              _buildCompactInput(
                controller: _topicController,
                label: 'Çalışılan Konu',
                hint: 'Örn: Matematik - Türev',
                icon: Icons.book_outlined,
                isDark: isDark,
                isCompact: isCompact,
              ),

              SizedBox(height: isCompact ? 16 : 20),

              // Test Bilgileri - Kompakt
              _buildTestSection(isDark, isCompact),

              SizedBox(height: isCompact ? 16 : 20),

              // Notlar - Kompakt
              _buildCompactInput(
                controller: _notesController,
                label: 'Notlar',
                hint: 'Çalışma hakkında notlarınız...',
                icon: Icons.note_outlined,
                isDark: isDark,
                isCompact: isCompact,
                maxLines: 3,
              ),

              SizedBox(height: isCompact ? 20 : 24),

              // Kaydet Butonu - Kompakt
              _buildCompactSaveButton(isDark, isCompact),

              SizedBox(height: isCompact ? 12 : 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSummary(bool isDark, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientBlueStart, AppColors.gradientBlueEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Oturum Özeti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 16 : 20),
          _buildCompactStatItem(
            icon: Icons.timer_outlined,
            label: 'Oturum',
            value: '${widget.sessionCount}',
            isCompact: isCompact,
          ),
          SizedBox(height: isCompact ? 10 : 12),
          _buildCompactStatItem(
            icon: Icons.access_time_rounded,
            label: 'Toplam Süre',
            value: '${widget.totalMinutes} dk',
            isCompact: isCompact,
          ),
          SizedBox(height: isCompact ? 10 : 12),
          _buildCompactStatItem(
            icon: Icons.hourglass_empty_rounded,
            label: 'Oturum Süresi',
            value: '${widget.sessionDuration} dk',
            isCompact: isCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isCompact,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: isCompact ? 16 : 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isCompact ? 13 : 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 15 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required bool isCompact,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: isCompact ? 14 : 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: isCompact ? 13 : 14,
          ),
          prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 18,
            vertical: isCompact ? 14 : 16,
          ),
          labelStyle: TextStyle(
            fontSize: isCompact ? 13 : 14,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildTestSection(bool isDark, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Test/Soru Bilgileri',
              style: TextStyle(
                fontSize: isCompact ? 14 : 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Opsiyonel',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 10 : 12),
        Row(
          children: [
            Expanded(
              child: _buildCompactTestInput(
                controller: _correctController,
                label: 'Doğru',
                icon: Icons.check_circle_outline,
                color: AppColors.gradientGreenStart,
                isDark: isDark,
                isCompact: isCompact,
              ),
            ),
            SizedBox(width: isCompact ? 8 : 10),
            Expanded(
              child: _buildCompactTestInput(
                controller: _wrongController,
                label: 'Yanlış',
                icon: Icons.cancel_outlined,
                color: Colors.red,
                isDark: isDark,
                isCompact: isCompact,
              ),
            ),
            SizedBox(width: isCompact ? 8 : 10),
            Expanded(
              child: _buildCompactTestInput(
                controller: _totalController,
                label: 'Toplam',
                icon: Icons.quiz_outlined,
                color: AppColors.primaryBlue,
                isDark: isDark,
                isCompact: isCompact,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactTestInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required bool isCompact,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: isCompact ? 13 : 14,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: isCompact ? 11 : 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
          prefixIcon: Icon(icon, color: color, size: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 10,
            vertical: isCompact ? 12 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSaveButton(bool isDark, bool isCompact) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving ? null : _saveSession,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientBlueStart, AppColors.gradientBlueEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.save_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kaydet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 15 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
