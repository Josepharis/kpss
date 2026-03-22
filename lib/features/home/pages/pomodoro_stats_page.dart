import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/pomodoro_session.dart';
import '../../../core/services/pomodoro_storage_service.dart';

class PomodoroStatsPage extends StatefulWidget {
  const PomodoroStatsPage({super.key});

  @override
  State<PomodoroStatsPage> createState() => _PomodoroStatsPageState();
}

class _PomodoroStatsPageState extends State<PomodoroStatsPage> {
  final PomodoroStorageService _storageService = PomodoroStorageService();
  List<PomodoroSession> _sessions = [];
  bool _isLoading = true;
  int _totalSessions = 0;
  int _totalSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _storageService.getAllSessions();
      final totalSessions = await _storageService.getTotalSessions();
      final totalSeconds = await _storageService.getTotalSeconds();
      
      setState(() {
        _sessions = sessions;
        _totalSessions = totalSessions;
        _totalSeconds = totalSeconds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark 
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: const Color(0xFF121212),
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Çalışma İstatistikleri'),
          backgroundColor: appBarColor,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0,
          systemOverlayStyle: isDark 
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                )
              : SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSessions,
                child: _sessions.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildStatsCards(),
                          const SizedBox(height: 24),
                          _buildSessionsList(),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white38 : Colors.grey[400];
    final textColor = isDark ? Colors.white70 : Colors.grey[600];
    final secondaryTextColor = isDark ? Colors.white60 : Colors.grey[500];
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 80,
            color: iconColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz çalışma kaydı yok',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pomodoro oturumlarınızı tamamladıktan sonra\nkayıt ederek burada görebilirsiniz',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Toplam Oturum',
            '$_totalSessions',
            Icons.timer,
            AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Toplam Süre',
            _formatDetailedDuration(_totalSeconds),
            Icons.access_time,
            AppColors.gradientGreenEnd,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.1);
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    
    final groupedSessions = <DateTime, List<PomodoroSession>>{};
    
    for (final session in _sessions) {
      final date = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
      );
      
      if (!groupedSessions.containsKey(date)) {
        groupedSessions[date] = [];
      }
      groupedSessions[date]!.add(session);
    }

    final sortedDates = groupedSessions.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Günlük Kayıtlar',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        ...sortedDates.map((date) => _buildDateSection(date, groupedSessions[date]!)),
      ],
    );
  }

  Widget _buildDateSection(DateTime date, List<PomodoroSession> sessions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.1);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final dividerColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    
    final dateFormat = DateFormat('dd MMMM yyyy', 'tr_TR');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  _formatDetailedDuration(sessions.fold<int>(0, (sum, s) => sum + s.totalSeconds)),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          ...sessions.map((session) => _buildSessionTile(session)),
        ],
      ),
    );
  }

  Widget _buildSessionTile(PomodoroSession session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: PageStorageKey(session.id),
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
          child: Icon(
            Icons.timer,
            color: AppColors.primaryBlue,
            size: 18,
          ),
        ),
        title: Text(
          session.topic ?? 'İsimsiz Çalışma',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_formatDetailedDuration(session.totalSeconds)} • ${session.sessionCount} oturum',
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 12,
          ),
        ),
        trailing: Text(
          DateFormat('HH:mm').format(session.date),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: secondaryTextColor,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (session.correctAnswers != null || session.wrongAnswers != null || session.totalQuestions != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 16, color: Colors.indigoAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Test Sonuçları:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (session.correctAnswers != null)
                        _buildBadge('Doğru: ${session.correctAnswers}', Colors.green),
                      if (session.wrongAnswers != null)
                        _buildBadge('Yanlış: ${session.wrongAnswers}', Colors.red),
                      if (session.totalQuestions != null)
                        _buildBadge('Soru: ${session.totalQuestions}', Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (session.notes != null && session.notes!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.notes_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Çalışma Notları:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.notes!,
                      style: TextStyle(color: secondaryTextColor, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDetailedDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0 sn';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    List<String> parts = [];
    if (h > 0) parts.add('$h sa');
    if (m > 0) parts.add('$m dk');
    if (s > 0 || parts.isEmpty) parts.add('$s sn');

    return parts.join(' ');
  }
}

