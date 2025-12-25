import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/test_question.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';

class TestsPage extends StatefulWidget {
  final String topicName;
  final int testCount;
  final String lessonId; // Ders ID

  const TestsPage({
    super.key,
    required this.topicName,
    required this.testCount,
    required this.lessonId,
  });

  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _showExplanation = false;
  Timer? _timer;
  int _remainingSeconds = 60; // Default 60 seconds per question
  bool _isAnswered = false;
  bool _isInWeaknesses = false; // Mevcut soru eksiklerde mi?

  List<TestQuestion> get _questions {
    // Mock data - will be replaced with real data later
    return [
      TestQuestion(
        id: '1',
        question: 'Aşağıdaki cümlelerden hangisinde "de" bağlacı yanlış yazılmıştır?',
        options: [
          'A) O da buraya gelecek.',
          'B) Sen de mi gideceksin?',
          'C) Bende bir şeyler var.',
          'D) O da benim gibi düşünüyor.',
        ],
        correctAnswerIndex: 2,
        explanation: '"de" bağlacı ayrı yazılır. Cümlede "Bende" yerine "Bende de" yazılmalıydı.',
        timeLimitSeconds: 60,
      ),
      TestQuestion(
        id: '2',
        question: 'Aşağıdaki kelimelerden hangisi büyük ünlü uyumuna uymaz?',
        options: [
          'A) Kitap',
          'B) Kalem',
          'C) Araba',
          'D) Kardeş',
        ],
        correctAnswerIndex: 1,
        explanation: '"Kalem" kelimesi büyük ünlü uyumuna uymaz çünkü ilk hecede "a", ikinci hecede "e" ünlüsü vardır.',
        timeLimitSeconds: 60,
      ),
      TestQuestion(
        id: '3',
        question: 'Hangi cümlede yazım yanlışı vardır?',
        options: [
          'A) Herşey yolunda gidiyor.',
          'B) Hiçbir şey yapamadım.',
          'C) Bir şey söylemedim.',
          'D) Her şey tamam.',
        ],
        correctAnswerIndex: 0,
        explanation: '"Herşey" kelimesi ayrı yazılmalıdır: "Her şey".',
        timeLimitSeconds: 60,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkIfInWeaknesses();
  }

  // Sorunun eksiklerde olup olmadığını kontrol et
  Future<void> _checkIfInWeaknesses() async {
    final currentQuestion = _questions[_currentQuestionIndex];
    final isInWeaknesses = await WeaknessesService.isQuestionInWeaknesses(
      currentQuestion.id,
      widget.topicName,
      lessonId: widget.lessonId,
    );
    if (mounted) {
      setState(() {
        _isInWeaknesses = isInWeaknesses;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_currentQuestionIndex < _questions.length) {
      _remainingSeconds = _questions[_currentQuestionIndex].timeLimitSeconds;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0 && !_isAnswered) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          timer.cancel();
          if (!_isAnswered) {
            _handleTimeUp();
          }
        }
      });
    }
  }

  void _handleTimeUp() {
    setState(() {
      _isAnswered = true;
      _showExplanation = true;
    });
  }

  void _selectAnswer(int index) {
    if (_isAnswered) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = index == currentQuestion.correctAnswerIndex;

    setState(() {
      _selectedAnswerIndex = index;
      _isAnswered = true;
      _showExplanation = true;
      _timer?.cancel();

      if (isCorrect) {
        _score += 10;
      }
    });

    // Yanlış cevaplanan soruları otomatik olarak eksiklere ekle
    if (!isCorrect) {
      _addToWeaknesses(isFromWrongAnswer: true);
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _showExplanation = false;
        _isAnswered = false;
        _isInWeaknesses = false;
      });
      _startTimer();
      _checkIfInWeaknesses();
    } else {
      _showResults();
    }
  }

  // Eksiklere ekle
  Future<void> _addToWeaknesses({bool isFromWrongAnswer = false}) async {
    final currentQuestion = _questions[_currentQuestionIndex];
    
    // Zaten eksiklerde mi kontrol et
    final alreadyInWeaknesses = await WeaknessesService.isQuestionInWeaknesses(
      currentQuestion.id,
      widget.topicName,
      lessonId: widget.lessonId,
    );

    if (alreadyInWeaknesses) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu soru zaten eksiklerinizde bulunuyor.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final weakness = WeaknessQuestion.fromTestQuestion(
      testQuestion: currentQuestion,
      lessonId: widget.lessonId,
      topicName: widget.topicName,
      isFromWrongAnswer: isFromWrongAnswer,
    );

    final success = await WeaknessesService.addWeakness(weakness);
    
    if (mounted) {
      setState(() {
        _isInWeaknesses = success;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Soru eksiklerinize eklendi.'
                : 'Soru eklenirken bir hata oluştu.',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Test Tamamlandı!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Toplam Puan: $_score'),
            const SizedBox(height: 8),
            Text('Doğru: ${_score ~/ 10}/${_questions.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.topicName,
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: isTablet ? 20 : 16),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 12,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: isSmallScreen ? 16 : 18,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Text(
                  '$_score',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Timer and Progress
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Soru ${_currentQuestionIndex + 1}/${_questions.length}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: _remainingSeconds < 10
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: isSmallScreen ? 16 : 18,
                            color: _remainingSeconds < 10
                                ? Colors.red
                                : AppColors.primaryBlue,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '${_remainingSeconds}s',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: _remainingSeconds < 10
                                  ? Colors.red
                                  : AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 10 : 12),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _questions.length,
                  backgroundColor: AppColors.backgroundLight,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  minHeight: isSmallScreen ? 6 : 8,
                ),
              ],
            ),
          ),
          // Question and Options
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Container(
                    width: double.infinity,
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
                    child: Text(
                      currentQuestion.question,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  // Options
                  ...currentQuestion.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isCorrect = index == currentQuestion.correctAnswerIndex;
                    final isSelected = _selectedAnswerIndex == index;
                    Color? optionColor;
                    IconData? optionIcon;

                    if (_showExplanation) {
                      if (isCorrect) {
                        optionColor = Colors.green;
                        optionIcon = Icons.check_circle_rounded;
                      } else if (isSelected && !isCorrect) {
                        optionColor = Colors.red;
                        optionIcon = Icons.cancel_rounded;
                      }
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: isSmallScreen ? 10 : 12,
                      ),
                      child: GestureDetector(
                        onTap: () => _selectAnswer(index),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                          decoration: BoxDecoration(
                            color: optionColor?.withValues(alpha: 0.1) ?? Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: optionColor ?? Colors.grey.withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (optionColor ?? AppColors.primaryBlue)
                                          .withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              if (optionIcon != null)
                                Icon(
                                  optionIcon,
                                  color: optionColor,
                                  size: isSmallScreen ? 22 : 24,
                                ),
                              if (optionIcon != null) SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 15 : 17,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: optionColor ?? AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // Explanation
                  if (_showExplanation)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: isSmallScreen ? 12 : 16),
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: _selectedAnswerIndex ==
                                currentQuestion.correctAnswerIndex
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedAnswerIndex ==
                                  currentQuestion.correctAnswerIndex
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selectedAnswerIndex ==
                                        currentQuestion.correctAnswerIndex
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                color: _selectedAnswerIndex ==
                                        currentQuestion.correctAnswerIndex
                                    ? Colors.green
                                    : Colors.orange,
                                size: isSmallScreen ? 20 : 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _selectedAnswerIndex ==
                                        currentQuestion.correctAnswerIndex
                                    ? 'Doğru Cevap!'
                                    : 'Açıklama',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 15 : 17,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedAnswerIndex ==
                                          currentQuestion.correctAnswerIndex
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 10),
                          Text(
                            currentQuestion.explanation,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Eksiklere Ekle Butonu
                  if (_showExplanation)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: isSmallScreen ? 12 : 16),
                      child: OutlinedButton.icon(
                        onPressed: _isInWeaknesses ? null : () => _addToWeaknesses(),
                        icon: Icon(
                          _isInWeaknesses
                              ? Icons.check_circle_rounded
                              : Icons.bookmark_add_rounded,
                          size: isSmallScreen ? 18 : 20,
                        ),
                        label: Text(
                          _isInWeaknesses
                              ? 'Eksiklerde Mevcut'
                              : 'Eksiklere Ekle',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 15 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 12 : 14,
                          ),
                          side: BorderSide(
                            color: _isInWeaknesses
                                ? Colors.green
                                : AppColors.primaryBlue,
                            width: 1.5,
                          ),
                          foregroundColor: _isInWeaknesses
                              ? Colors.green
                              : AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  // Next Button
                  if (_showExplanation)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 14 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          _currentQuestionIndex < _questions.length - 1
                              ? 'Sonraki Soru'
                              : 'Testi Bitir',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

