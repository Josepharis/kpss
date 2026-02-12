import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/formatted_text.dart';

class PastQuestion {
  final String id;
  final int year;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String? topic;
  final String? imageUrl;

  PastQuestion({
    required this.id,
    required this.year,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    this.topic,
    this.imageUrl,
  });
}

class QuestionDistribution {
  final int year;
  final int questionCount;

  QuestionDistribution({required this.year, required this.questionCount});
}

class PastQuestionsPage extends StatefulWidget {
  final String topicName;
  final int averageQuestionCount;

  const PastQuestionsPage({
    super.key,
    required this.topicName,
    required this.averageQuestionCount,
  });

  @override
  State<PastQuestionsPage> createState() => _PastQuestionsPageState();
}

class _PastQuestionsPageState extends State<PastQuestionsPage> {
  String _selectedView = 'distribution'; // 'distribution' or 'questions'
  int? _selectedYear;
  int? _selectedQuestionIndex;
  bool _showAnswer = false;

  List<QuestionDistribution> get _distribution {
    // Mock data - gerçek uygulamada API'den gelecek
    return [
      QuestionDistribution(year: 2024, questionCount: 12),
      QuestionDistribution(year: 2023, questionCount: 15),
      QuestionDistribution(year: 2022, questionCount: 10),
      QuestionDistribution(year: 2021, questionCount: 18),
      QuestionDistribution(year: 2020, questionCount: 14),
      QuestionDistribution(year: 2019, questionCount: 16),
      QuestionDistribution(year: 2018, questionCount: 13),
    ];
  }

  List<PastQuestion> get _questions {
    // Mock data - gerçek uygulamada API'den gelecek
    return [
      PastQuestion(
        id: '1',
        year: 2024,
        question:
            'Aşağıdaki cümlelerden hangisinde "de" bağlacı yanlış yazılmıştır?',
        options: [
          'A) O da buraya gelecek.',
          'B) Sen de mi gideceksin?',
          'C) Bende bir şeyler var.',
          'D) O da benim gibi düşünüyor.',
        ],
        correctAnswerIndex: 2,
        explanation:
            '"de" bağlacı ayrı yazılır. Cümlede "Bende" yerine "Bende de" yazılmalıydı.',
      ),
      PastQuestion(
        id: '2',
        year: 2024,
        question: 'Aşağıdaki kelimelerden hangisi büyük ünlü uyumuna uymaz?',
        options: ['A) Kitap', 'B) Kalem', 'C) Araba', 'D) Kardeş'],
        correctAnswerIndex: 1,
        explanation:
            '"Kalem" kelimesi büyük ünlü uyumuna uymaz çünkü ilk hecede "a", ikinci hecede "e" ünlüsü vardır.',
      ),
      PastQuestion(
        id: '3',
        year: 2023,
        question:
            'Aşağıdaki cümlelerden hangisinde noktalama işareti yanlış kullanılmıştır?',
        options: [
          'A) Bugün hava çok güzel; dışarı çıkmak istiyorum.',
          'B) Ali, Ahmet ve Mehmet geldi.',
          'C) "Neredesin?" diye sordu.',
          'D) Ankara\'da yaşıyorum.',
        ],
        correctAnswerIndex: 0,
        explanation:
            'Noktalı virgül (;) bağımsız cümleler arasında kullanılır. Bu cümlede virgül kullanılmalıydı.',
      ),
      PastQuestion(
        id: '4',
        year: 2023,
        question: 'Aşağıdaki kelimelerden hangisinde ünsüz yumuşaması görülür?',
        options: ['A) Kitap', 'B) Ağaç', 'C) Renk', 'D) Yurt'],
        correctAnswerIndex: 3,
        explanation:
            '"Yurt" kelimesi ek aldığında "yurdu" şeklinde ünsüz yumuşaması görülür.',
      ),
      PastQuestion(
        id: '5',
        year: 2022,
        question: 'Aşağıdaki cümlelerden hangisi devrik cümledir?',
        options: [
          'A) Bugün okula gittim.',
          'B) Yarın sinemaya gideceğiz.',
          'C) Geldi dün akşam.',
          'D) Kitap okuyorum.',
        ],
        correctAnswerIndex: 2,
        explanation:
            'Devrik cümle, yüklemi sonda olmayan cümledir. "Geldi dün akşam" cümlesinde yüklem başta olduğu için devrik cümledir.',
      ),
    ];
  }

  List<PastQuestion> get _filteredQuestions {
    if (_selectedYear == null) {
      return _questions;
    }
    return _questions.where((q) => q.year == _selectedYear).toList();
  }

  int get _totalQuestions =>
      _distribution.fold(0, (sum, d) => sum + d.questionCount);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : AppColors.backgroundLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 100 : 110),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFFF6B35), const Color(0xFFFF9800)],
                  ),
            color: isDark ? const Color(0xFF1E1E1E) : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFFFF6B35).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Watermark
                Positioned(
                  top: -10,
                  right: -10,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      'KPSS',
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.08),
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isSmallScreen ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      // Back button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
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
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Çıkmış Sorular',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              widget.topicName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // View Selector
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 14,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E)
                  : AppColors.backgroundWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildViewButton(
                    'Soru Dağılımı',
                    'distribution',
                    Icons.bar_chart_rounded,
                    isSmallScreen,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Expanded(
                  child: _buildViewButton(
                    'Sorular',
                    'questions',
                    Icons.quiz_rounded,
                    isSmallScreen,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _selectedView == 'distribution'
                ? _buildDistributionView(isTablet, isSmallScreen)
                : _buildQuestionsView(isTablet, isSmallScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton(
    String label,
    String value,
    IconData icon,
    bool isSmallScreen,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedView == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedView = value;
          _selectedQuestionIndex = null;
          _showAnswer = false;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [const Color(0xFFFF6B35), const Color(0xFFFF9800)],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF2C2C2C) : AppColors.backgroundLight),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                      ? Colors.grey.withValues(alpha: 0.3)
                      : AppColors.textSecondary.withValues(alpha: 0.2)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isSmallScreen ? 18 : 20,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade400 : AppColors.textSecondary),
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionView(bool isTablet, bool isSmallScreen) {
    final maxCount = _distribution.map((d) => d.questionCount).reduce(math.max);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 20 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 18 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFFFF6B35), const Color(0xFFFF9800)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toplam Soru',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$_totalQuestions',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 28 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        size: isSmallScreen ? 32 : 36,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      'Yıllar',
                      '${_distribution.length}',
                      isSmallScreen,
                    ),
                    _buildStatItem(
                      'Ortalama',
                      '${(_totalQuestions / _distribution.length).toStringAsFixed(1)}',
                      isSmallScreen,
                    ),
                    _buildStatItem(
                      'En Çok',
                      '${_distribution.map((d) => d.questionCount).reduce(math.max)}',
                      isSmallScreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 20 : 24),
          // Chart Title
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Text(
                'Yıllara Göre Soru Dağılımı',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              );
            },
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          // Distribution Chart
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                padding: EdgeInsets.all(isSmallScreen ? 18 : 24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : AppColors.backgroundWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: _distribution.map((dist) {
                    final percentage = dist.questionCount / maxCount;
                    final isSelected = _selectedYear == dist.year;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedYear = isSelected ? null : dist.year;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                          bottom: isSmallScreen ? 16 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? const Color(0xFFFF6B35)
                                            : const Color(0xFFFF9800),
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 10),
                                    Text(
                                      '${dist.year}',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${dist.questionCount} soru',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFF6B35),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Container(
                                    height: isSmallScreen ? 32 : 36,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2C2C2C)
                                          : AppColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: percentage,
                                    child: Container(
                                      height: isSmallScreen ? 32 : 36,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            isSelected
                                                ? const Color(0xFFFF6B35)
                                                : const Color(0xFFFF9800),
                                            isSelected
                                                ? const Color(0xFFFF9800)
                                                : const Color(
                                                    0xFFFF6B35,
                                                  ).withValues(alpha: 0.7),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          if (_selectedYear != null) ...[
            SizedBox(height: isSmallScreen ? 20 : 24),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  padding: EdgeInsets.all(isSmallScreen ? 18 : 24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : AppColors.backgroundWhite,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_selectedYear Yılı Soruları',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedView = 'questions';
                                _showAnswer = false;
                                _selectedQuestionIndex = null;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 8 : 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF6B35),
                                    const Color(0xFFFF9800),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Soruları Gör',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Text(
                        '${_questions.where((q) => q.year == _selectedYear).length} soru bulundu',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          SizedBox(height: isSmallScreen ? 20 : 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isSmallScreen) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsView(bool isTablet, bool isSmallScreen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Year Filter
        if (_selectedYear == null)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 14,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E)
                  : AppColors.backgroundWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildYearFilterButton(null, 'Tümü', isSmallScreen),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  ..._distribution.map((dist) {
                    return Padding(
                      padding: EdgeInsets.only(right: isSmallScreen ? 8 : 10),
                      child: _buildYearFilterButton(
                        dist.year,
                        '${dist.year}',
                        isSmallScreen,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        // Questions List
        Expanded(
          child: _filteredQuestions.isEmpty
              ? Builder(
                  builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 64,
                            color: isDark
                                ? Colors.grey.shade600
                                : AppColors.textSecondary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Soru bulunamadı',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 20 : 14),
                  itemCount: _filteredQuestions.length,
                  itemBuilder: (context, index) {
                    final question = _filteredQuestions[index];
                    final isSelected = _selectedQuestionIndex == index;
                    return _buildQuestionCard(
                      question,
                      index,
                      isSelected,
                      isSmallScreen,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildYearFilterButton(int? year, String label, bool isSmallScreen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedYear == year;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedYear = year;
          _selectedQuestionIndex = null;
          _showAnswer = false;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 14 : 18,
          vertical: isSmallScreen ? 8 : 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [const Color(0xFFFF6B35), const Color(0xFFFF9800)],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF2C2C2C) : AppColors.backgroundLight),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                      ? Colors.grey.withValues(alpha: 0.3)
                      : AppColors.textSecondary.withValues(alpha: 0.2)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    PastQuestion question,
    int index,
    bool isSelected,
    bool isSmallScreen,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedQuestionIndex = isSelected ? null : index;
          _showAnswer = false;
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Header
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B35).withValues(alpha: 0.1),
                    const Color(0xFFFF9800).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 10,
                          vertical: isSmallScreen ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF6B35),
                              const Color(0xFFFF9800),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${question.year}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 10),
                      Text(
                        'Soru ${index + 1}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isSelected
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFFFF6B35),
                  ),
                ],
              ),
            ),
            // Question Content
            if (isSelected) ...[
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question.imageUrl != null)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                          bottom: isSmallScreen ? 12 : 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.02),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            question.imageUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    FormattedText(
                      text: question.question,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    ...question.options.asMap().entries.map((entry) {
                      final optionIndex = entry.key;
                      final option = entry.value;
                      final isCorrect =
                          optionIndex == question.correctAnswerIndex;
                      final showCorrect = _showAnswer && isCorrect;
                      return Container(
                        margin: EdgeInsets.only(
                          bottom: isSmallScreen ? 10 : 12,
                        ),
                        padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                        decoration: BoxDecoration(
                          color: showCorrect
                              ? Colors.green.withValues(alpha: 0.1)
                              : (isDark
                                    ? const Color(0xFF2C2C2C)
                                    : AppColors.backgroundLight),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: showCorrect
                                ? Colors.green
                                : (isDark
                                      ? Colors.grey.withValues(alpha: 0.3)
                                      : AppColors.textSecondary.withValues(
                                          alpha: 0.2,
                                        )),
                            width: showCorrect ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (showCorrect)
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: 20,
                              ),
                            if (showCorrect) SizedBox(width: 10),
                            Expanded(
                              child: FormattedText(
                                text: option,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: showCorrect
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (!_showAnswer)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showAnswer = true;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 14 : 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF6B35),
                                const Color(0xFFFF9800),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Cevabı Göster',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_showAnswer) ...[
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_rounded,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Açıklama',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 15 : 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 10 : 12),
                            Builder(
                              builder: (context) {
                                final isDark =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;
                                return FormattedText(
                                  text: question.explanation,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    height: 1.6,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
