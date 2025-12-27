import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';

class WeaknessTopicDetailPage extends StatefulWidget {
  final Lesson lesson;
  final String topicName;

  const WeaknessTopicDetailPage({
    super.key,
    required this.lesson,
    required this.topicName,
  });

  @override
  State<WeaknessTopicDetailPage> createState() => _WeaknessTopicDetailPageState();
}

class _WeaknessTopicDetailPageState extends State<WeaknessTopicDetailPage> {
  List<WeaknessQuestion> _weaknesses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeaknesses();
  }

  Future<void> _loadWeaknesses() async {
    setState(() {
      _isLoading = true;
    });

    final weaknesses = await WeaknessesService.getWeaknessesByLessonAndTopic(
      widget.lesson.id,
      widget.topicName,
    );

    if (mounted) {
      setState(() {
        _weaknesses = weaknesses;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeWeakness(WeaknessQuestion weakness) async {
    final success = await WeaknessesService.removeWeakness(
      weakness.id,
      weakness.topicName,
      lessonId: weakness.lessonId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Soru eksiklerden kaldırıldı.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
      _loadWeaknesses();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Soru kaldırılırken bir hata oluştu.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getColor() {
    switch (widget.lesson.color) {
      case 'orange':
        return const Color(0xFFFF6B35);
      case 'blue':
        return const Color(0xFF4A90E2);
      case 'red':
        return const Color(0xFFE74C3C);
      case 'green':
        return const Color(0xFF27AE60);
      case 'purple':
        return const Color(0xFF9B59B6);
      case 'teal':
        return const Color(0xFF16A085);
      case 'indigo':
        return const Color(0xFF5C6BC0);
      case 'pink':
        return const Color(0xFFE91E63);
      default:
        return AppColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: _getColor(),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.topicName,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${_weaknesses.length} eksik soru',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadWeaknesses,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryBlue,
              ),
            )
          : _weaknesses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 80,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bu konuda eksik soru yok',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWeaknesses,
                  color: AppColors.primaryBlue,
                  child: ListView.builder(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    itemCount: _weaknesses.length,
                    itemBuilder: (context, index) {
                      final weakness = _weaknesses[index];
                      final isLast = index == _weaknesses.length - 1;

                      return _buildQuestionCard(
                        weakness: weakness,
                        isLast: isLast,
                        isTablet: isTablet,
                        isSmallScreen: isSmallScreen,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildQuestionCard({
    required WeaknessQuestion weakness,
    required bool isLast,
    required bool isTablet,
    required bool isSmallScreen,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : (isSmallScreen ? 16 : 20)),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soru Başlığı ve Kaldır Butonu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  weakness.question,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                iconSize: isSmallScreen ? 20 : 22,
                color: Colors.red,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeWeakness(weakness),
                tooltip: 'Kaldır',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Seçenekler
          ...weakness.options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final option = entry.value;
            final isCorrect = optionIndex == weakness.correctAnswerIndex;

            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: isCorrect ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (isCorrect)
                    Icon(
                      Icons.check_circle_rounded,
                      size: isSmallScreen ? 18 : 20,
                      color: Colors.green,
                    ),
                  if (isCorrect) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        color: isCorrect ? Colors.green : AppColors.textPrimary,
                        fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          // Açıklama
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: isSmallScreen ? 18 : 20,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    weakness.explanation,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Soru Tipi Etiketleri
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: isSmallScreen ? 12 : 16,
              runSpacing: isSmallScreen ? 8 : 10,
              children: [
                // Yanlış cevaplanan soru etiketi
                if (weakness.isFromWrongAnswer)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: isSmallScreen ? 14 : 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Yanlış cevaplanan soru',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                // Kaydedilen soru etiketi
                if (!weakness.isFromWrongAnswer)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_rounded,
                        size: isSmallScreen ? 14 : 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Kaydedilen soru',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.green,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

