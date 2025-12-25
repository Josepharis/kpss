import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/test_question.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/services/questions_service.dart';

class TestsPage extends StatefulWidget {
  final String topicName;
  final int testCount;
  final String lessonId; // Ders ID
  final String topicId; // Konu ID (Firebase'den soruları çekmek için)

  const TestsPage({
    super.key,
    required this.topicName,
    required this.testCount,
    required this.lessonId,
    required this.topicId,
  });

  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  final QuestionsService _questionsService = QuestionsService();
  List<TestQuestion> _questions = [];
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _showExplanation = false;
  Timer? _timer;
  int _remainingSeconds = 60; // Default 60 seconds per question
  bool _isAnswered = false;
  bool _showExplanationManually = false; // Açıklama manuel olarak gösteriliyor mu?

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final questions = await _questionsService.getQuestionsByTopicId(widget.topicId);
      
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        
        if (_questions.isNotEmpty) {
          _startTimer();
        } else {
          // Soru yoksa kullanıcıya bilgi ver
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu konu için henüz soru eklenmemiş.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error loading questions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorular yüklenirken bir hata oluştu: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    if (_isAnswered || _questions.isEmpty) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = index == currentQuestion.correctAnswerIndex;

    setState(() {
      _selectedAnswerIndex = index;
      _isAnswered = true;
      _showExplanation = true;
      _showExplanationManually = false; // Cevap verildiğinde açıklamayı gizle
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
        _showExplanationManually = false;
        _isAnswered = false;
      });
      _startTimer();
    } else {
      _showResults();
    }
  }

  // Eksiklere ekle
  Future<void> _addToWeaknesses({bool isFromWrongAnswer = false}) async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    
    final currentQuestion = _questions[_currentQuestionIndex];
    
    // Zaten eksiklerde mi kontrol et
    final alreadyInWeaknesses = await WeaknessesService.isQuestionInWeaknesses(
      currentQuestion.id,
      widget.topicName,
      lessonId: widget.lessonId,
    );

    if (alreadyInWeaknesses) {
      // Zaten eksiklerde ise sessizce çık (uyarı gösterme)
      return;
    }

    final weakness = WeaknessQuestion.fromTestQuestion(
      testQuestion: currentQuestion,
      lessonId: widget.lessonId,
      topicName: widget.topicName,
      isFromWrongAnswer: isFromWrongAnswer,
    );

    final success = await WeaknessesService.addWeakness(weakness);
    
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Soru eksiklerinize eklendi.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
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
    
    if (_isLoading) {
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
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_questions.isEmpty) {
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
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Bu konu için henüz soru eklenmemiş',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
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
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isSmallScreen ? 12 : 14,
            ),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Soru ${_currentQuestionIndex + 1}/${_questions.length}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: _remainingSeconds < 10
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: isSmallScreen ? 14 : 16,
                            color: _remainingSeconds < 10
                                ? Colors.red
                                : AppColors.primaryBlue,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${_remainingSeconds}s',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
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
                SizedBox(height: isSmallScreen ? 8 : 10),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _questions.length,
                  backgroundColor: AppColors.backgroundLight,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  minHeight: isSmallScreen ? 4 : 5,
                ),
              ],
            ),
          ),
          // Question and Options
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isSmallScreen ? 12 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 14 : 16,
                      vertical: isSmallScreen ? 12 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      currentQuestion.question,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 14),
                  // Options
                  ...currentQuestion.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isCorrect = index == currentQuestion.correctAnswerIndex;
                    final isSelected = _selectedAnswerIndex == index;
                    Color? optionColor;
                    IconData? optionIcon;
                    
                    // Şık harfleri: A, B, C, D, E
                    final optionLetter = String.fromCharCode(65 + index); // A=65, B=66, etc.

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
                        bottom: isSmallScreen ? 8 : 10,
                      ),
                      child: GestureDetector(
                        onTap: _isAnswered ? null : () => _selectAnswer(index),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 14,
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: optionColor?.withValues(alpha: 0.1) ?? Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: optionColor ?? Colors.grey.withValues(alpha: 0.2),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (optionColor ?? AppColors.primaryBlue)
                                          .withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              // Şık harfi
                              Container(
                                width: isSmallScreen ? 28 : 30,
                                height: isSmallScreen ? 28 : 30,
                                decoration: BoxDecoration(
                                  color: optionColor?.withValues(alpha: 0.2) ?? 
                                         (isSelected 
                                           ? AppColors.primaryBlue.withValues(alpha: 0.1)
                                           : Colors.grey.withValues(alpha: 0.08)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: optionColor ?? 
                                           (isSelected 
                                             ? AppColors.primaryBlue
                                             : Colors.grey.withValues(alpha: 0.25)),
                                    width: 1,
                                  ),
                                  ),
                                alignment: Alignment.center,
                                child: Text(
                                  optionLetter,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    fontWeight: FontWeight.bold,
                                    color: optionColor ?? 
                                           (isSelected 
                                             ? AppColors.primaryBlue
                                             : AppColors.textPrimary),
                                  ),
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 10 : 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                    color: optionColor ?? AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (optionIcon != null) ...[
                                SizedBox(width: 8),
                                Icon(
                                  optionIcon,
                                  color: optionColor,
                                  size: isSmallScreen ? 18 : 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // Explanation (sadece manuel açıldıysa göster)
                  if (_showExplanation && _showExplanationManually)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: isSmallScreen ? 10 : 12),
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      decoration: BoxDecoration(
                        color: _selectedAnswerIndex ==
                                currentQuestion.correctAnswerIndex
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedAnswerIndex ==
                                  currentQuestion.correctAnswerIndex
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            size: isSmallScreen ? 16 : 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentQuestion.explanation,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: isSmallScreen ? 12 : 14),
                  // Buttons Row
                  Row(
                    children: [
                      // Açıklama Butonu (sadece cevap verildiyse göster)
                      if (_showExplanation)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showExplanationManually = !_showExplanationManually;
                              });
                            },
                            icon: Icon(
                              _showExplanationManually
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: isSmallScreen ? 16 : 18,
                            ),
                            label: Text(
                              _showExplanationManually ? 'Gizle' : 'Açıklama',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              side: BorderSide(
                                color: AppColors.primaryBlue,
                                width: 1.5,
                              ),
                              foregroundColor: AppColors.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      if (_showExplanation) SizedBox(width: 10),
                      // Sonraki Soru Butonu (her zaman görünür)
                      Expanded(
                        flex: _showExplanation ? 2 : 1,
                        child: ElevatedButton(
                          onPressed: _nextQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            _currentQuestionIndex < _questions.length - 1
                                ? 'Sonraki Soru'
                                : 'Testi Bitir',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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


