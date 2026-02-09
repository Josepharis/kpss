import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/test_question.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/services/questions_service.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/widgets/option_text_with_underline.dart';
import '../../../../main.dart';

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
  final ProgressService _progressService = ProgressService();
  List<TestQuestion> _questions = [];
  List<int?> _selectedAnswers = []; // Her soru için seçilen şık
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _showExplanation = false;
  Timer? _timer;
  int _remainingSeconds = 60; // Default 60 seconds per question
  bool _isAnswered = false;
  bool _showExplanationManually = false; // Açıklama manuel olarak gösteriliyor mu?
  Set<String> _savedQuestionIds = {}; // Kaydedilmiş soru ID'leri

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
      
      // Load saved progress FIRST, before loading questions
      final savedQuestionIndex = await _progressService.getTestProgress(widget.topicId);
      final savedScore = await _progressService.getTestScore(widget.topicId);
      
      // Load questions (will try Storage first, then Firestore)
      final questions = await _questionsService.getQuestionsByTopicId(
        widget.topicId,
        lessonId: widget.lessonId,
      );
      
      if (mounted) {
        // Set saved progress immediately if available
        int initialQuestionIndex = 0;
        int initialScore = 0;
        if (savedQuestionIndex != null && 
            savedQuestionIndex < questions.length && 
            questions.isNotEmpty) {
          initialQuestionIndex = savedQuestionIndex;
          initialScore = savedScore ?? 0;
          debugPrint('✅ Resuming test from question ${savedQuestionIndex + 1} with score: $initialScore');
        }
        
        setState(() {
          _questions = questions;
          _currentQuestionIndex = initialQuestionIndex;
          _score = initialScore;
          _selectedAnswers = List<int?>.filled(questions.length, null);
          _isLoading = false;
        });
        
        if (_questions.isNotEmpty) {
          _checkSavedQuestions();
          _startTimer();
          _saveProgress(); // Save initial progress
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
      debugPrint('Error loading questions: $e');
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
    // Save final progress before disposing
    if (_questions.isNotEmpty) {
      _saveProgress();
    }
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
    if (_questions.isEmpty) return;

    // Bu soru daha önce cevaplandıysa tekrar puanlamayı ve değişikliği engelle
    if (_selectedAnswers.isNotEmpty &&
        _currentQuestionIndex < _selectedAnswers.length &&
        _selectedAnswers[_currentQuestionIndex] != null) {
      return;
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = index == currentQuestion.correctAnswerIndex;

    setState(() {
      _selectedAnswerIndex = index;
      if (_selectedAnswers.isNotEmpty &&
          _currentQuestionIndex < _selectedAnswers.length) {
        _selectedAnswers[_currentQuestionIndex] = index;
      }
      _isAnswered = true;
      _showExplanation = true;
      _showExplanationManually = false; // Cevap verildiğinde açıklamayı gizle
      _timer?.cancel();

      if (isCorrect) {
        _score += 10;
        // Puanı kullanıcının toplam puanına ekle (her doğru cevap için +10 puan)
        _progressService.addScore(10);
      }
    });

    // Yanlış cevaplanan soruları otomatik olarak eksiklere ekle
    if (!isCorrect) {
      _addToWeaknesses(isFromWrongAnswer: true);
    }

    // İlerlemeyi hemen kaydet (cevap verildiğinde)
    _saveProgress();
  }

  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        // Yeni soruya geçtiğimizde, daha önce cevaplandıysa işareti ve durumu geri yükle
        if (_selectedAnswers.isNotEmpty &&
            _currentQuestionIndex < _selectedAnswers.length &&
            _selectedAnswers[_currentQuestionIndex] != null) {
          _selectedAnswerIndex = _selectedAnswers[_currentQuestionIndex];
          _isAnswered = true;
          _showExplanation = true;
        } else {
          _selectedAnswerIndex = null;
          _isAnswered = false;
          _showExplanation = false;
        }
        _showExplanationManually = false;
      });
      _checkCurrentQuestionSaved();
      _startTimer();
      _saveProgress(); // Save progress after moving to next question
    } else {
      // Test completed - save final score and results before showing results
      await _saveProgress();
      
      // Calculate correct and wrong answers
      final correctAnswers = _score ~/ 10;
      final wrongAnswers = _questions.length - correctAnswers;
      
      // Save test result
      await _progressService.saveTestResult(
        topicId: widget.topicId,
        topicName: widget.topicName,
        lessonId: widget.lessonId,
        totalQuestions: _questions.length,
        correctAnswers: correctAnswers,
        wrongAnswers: wrongAnswers,
        score: _score,
      );
      
      // Delete ongoing test progress
      await _progressService.deleteTestProgress(widget.topicId);
      _showResults();
    }
  }

  Future<void> _previousQuestion() async {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        if (_selectedAnswers.isNotEmpty &&
            _currentQuestionIndex < _selectedAnswers.length &&
            _selectedAnswers[_currentQuestionIndex] != null) {
          _selectedAnswerIndex = _selectedAnswers[_currentQuestionIndex];
          _isAnswered = true;
          _showExplanation = true;
        } else {
          _selectedAnswerIndex = null;
          _isAnswered = false;
          _showExplanation = false;
        }
        _showExplanationManually = false;
      });
      _checkCurrentQuestionSaved();
      _startTimer();
      _saveProgress(); // Save progress after moving to previous question
    }
  }

  void _showQuestionSelector() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sorulara Git',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == _currentQuestionIndex;
                  final isAnswered = _selectedAnswers.isNotEmpty &&
                      index < _selectedAnswers.length &&
                      _selectedAnswers[index] != null;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentQuestionIndex = index;
                        if (_selectedAnswers.isNotEmpty &&
                            _currentQuestionIndex < _selectedAnswers.length &&
                            _selectedAnswers[_currentQuestionIndex] != null) {
                          _selectedAnswerIndex =
                              _selectedAnswers[_currentQuestionIndex];
                          _isAnswered = true;
                          _showExplanation = true;
                        } else {
                          _selectedAnswerIndex = null;
                          _isAnswered = false;
                          _showExplanation = false;
                        }
                        _showExplanationManually = false;
                      });
                      _checkCurrentQuestionSaved();
                      _startTimer();
                      _saveProgress();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primaryBlue
                            : isAnswered
                                ? Colors.green.withValues(alpha: 0.2)
                                : isDark
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primaryBlue
                              : isAnswered
                                  ? Colors.green
                                  : Colors.grey.withValues(alpha: 0.3),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? Colors.white
                                : isAnswered
                                    ? Colors.green
                                    : (isDark ? Colors.white : AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Mevcut sorunun kaydedilip kaydedilmediğini kontrol et
  Future<void> _checkCurrentQuestionSaved() async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    
    final currentQuestion = _questions[_currentQuestionIndex];
    final isSaved = await WeaknessesService.isQuestionInWeaknesses(
      currentQuestion.id,
      widget.topicName,
      lessonId: widget.lessonId,
    );
    
    if (mounted) {
      setState(() {
        if (isSaved) {
          _savedQuestionIds.add(currentQuestion.id);
        } else {
          _savedQuestionIds.remove(currentQuestion.id);
        }
      });
    }
  }

  Future<void> _saveProgress() async {
    if (_questions.isEmpty) return;
    
    await _progressService.saveTestProgress(
      topicId: widget.topicId,
      topicName: widget.topicName,
      lessonId: widget.lessonId,
      currentQuestionIndex: _currentQuestionIndex,
      totalQuestions: _questions.length,
      score: _score, // Puanı da kaydet
    );
  }

  // Kaydedilmiş soruları kontrol et
  Future<void> _checkSavedQuestions() async {
    if (_questions.isEmpty) return;
    
    final savedIds = <String>{};
    for (var question in _questions) {
      final isSaved = await WeaknessesService.isQuestionInWeaknesses(
        question.id,
        widget.topicName,
        lessonId: widget.lessonId,
      );
      if (isSaved) {
        savedIds.add(question.id);
      }
    }
    
    if (mounted) {
      setState(() {
        _savedQuestionIds = savedIds;
      });
    }
  }

  // Eksiklere ekle (yanlış cevap için)
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
      setState(() {
        _savedQuestionIds.add(currentQuestion.id);
      });
      // Snackbar kaldırıldı - yukarıdaki kaydet ikonu zaten durumu gösteriyor
    }
  }

  // Manuel olarak eksiklere ekle (Kaydet butonu için)
  Future<void> _saveToWeaknesses() async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    
    final currentQuestion = _questions[_currentQuestionIndex];
    
    // Zaten eksiklerde mi kontrol et
    final alreadyInWeaknesses = await WeaknessesService.isQuestionInWeaknesses(
      currentQuestion.id,
      widget.topicName,
      lessonId: widget.lessonId,
    );

    if (alreadyInWeaknesses) {
      // Zaten eksiklerde ise kaldır
      final success = await WeaknessesService.removeWeakness(
        currentQuestion.id,
        widget.topicName,
        lessonId: widget.lessonId,
      );
      
      if (mounted && success) {
        setState(() {
          _savedQuestionIds.remove(currentQuestion.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Soru eksiklerinizden kaldırıldı.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final weakness = WeaknessQuestion.fromTestQuestion(
      testQuestion: currentQuestion,
      lessonId: widget.lessonId,
      topicName: widget.topicName,
      isFromWrongAnswer: false, // Manuel ekleme
    );

    final success = await WeaknessesService.addWeakness(weakness);
    
    if (mounted && success) {
      setState(() {
        _savedQuestionIds.add(currentQuestion.id);
      });
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final correctAnswers = _score ~/ 10;
    final wrongAnswers = _questions.length - correctAnswers;
    final percentage = (_score / (_questions.length * 10) * 100).round();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'Test Tamamlandı!',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 22 : 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // Score Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Puan',
                            '$_score',
                            Icons.star_rounded,
                            Colors.amber,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          ),
                          _buildStatItem(
                            'Doğru',
                            '$correctAnswers',
                            Icons.check_circle_rounded,
                            Colors.green,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          ),
                          _buildStatItem(
                            'Yanlış',
                            '$wrongAnswers',
                            Icons.cancel_rounded,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '%$percentage Başarı',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      // Sayfayı kapat ve anasayfayı güncelle
                      if (mounted) {
                        Navigator.of(context).pop(true);
                        final mainScreen = MainScreen.of(context);
                        if (mainScreen != null) {
                          mainScreen.refreshHomePage();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 14 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Tamam',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.primaryBlue,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
            onPressed: () async {
              debugPrint('🔙 Back button pressed - Loading state');
              // Save progress before leaving (if questions are loaded)
              if (_questions.isNotEmpty) {
                debugPrint('💾 Saving progress...');
                await _saveProgress();
                debugPrint('✅ Progress saved');
              } else {
                debugPrint('⚠️ No questions to save');
              }
              if (mounted) {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  barrierColor: Colors.black.withValues(alpha: 0.4),
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Kaydediliyor...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                // Wait 0.5 seconds
                await Future.delayed(const Duration(milliseconds: 500));
                // Close dialog and page
                if (mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Close page
                  debugPrint('✅ Page closed');
                }
              } else {
                debugPrint('⚠️ Widget not mounted');
              }
            },
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
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.primaryBlue,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
            onPressed: () async {
              debugPrint('🔙 Back button pressed - Empty state');
              // Save progress before leaving
              if (_questions.isNotEmpty) {
                debugPrint('💾 Saving progress...');
                await _saveProgress();
                debugPrint('✅ Progress saved');
              } else {
                debugPrint('⚠️ No questions to save');
              }
              if (mounted) {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  barrierColor: Colors.black.withValues(alpha: 0.4),
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Kaydediliyor...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                // Wait 0.5 seconds
                await Future.delayed(const Duration(milliseconds: 500));
                // Close dialog and page
                if (mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  if (mounted) {
                    Navigator.of(context).pop(true); // Close page
                    debugPrint('✅ Page closed');
                    // Anasayfayı güncelle (puan için)
                    final mainScreen = MainScreen.of(context);
                    if (mainScreen != null) {
                      mainScreen.refreshHomePage();
                    }
                  }
                }
              } else {
                debugPrint('⚠️ Widget not mounted');
              }
          },
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
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Bu konu için henüz soru eklenmemiş',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () async {
            debugPrint('🔙 Back button pressed - Normal state');
            // Save progress before leaving
            if (_questions.isNotEmpty) {
              debugPrint('💾 Saving progress...');
              await _saveProgress();
              debugPrint('✅ Progress saved');
            } else {
              debugPrint('⚠️ No questions to save');
            }
            if (mounted) {
              Navigator.of(context).pop(true);
              // Anasayfayı güncelle (puan için)
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) {
                mainScreen.refreshHomePage();
              }
            } else {
              debugPrint('⚠️ Widget not mounted');
            }
          },
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
          if (_questions.length > 1)
            IconButton(
              icon: Icon(
                Icons.list_rounded,
                color: Colors.white,
                size: isSmallScreen ? 18 : 20,
              ),
              onPressed: _showQuestionSelector,
              tooltip: 'Sorulara Git',
            ),
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
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Kaydet butonu
                        if (_questions.isNotEmpty && _currentQuestionIndex < _questions.length)
                          Container(
                            margin: EdgeInsets.only(right: isSmallScreen ? 8 : 10),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _saveToWeaknesses,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 8 : 10,
                                    vertical: isSmallScreen ? 5 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _savedQuestionIds.contains(_questions[_currentQuestionIndex].id)
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : AppColors.primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _savedQuestionIds.contains(_questions[_currentQuestionIndex].id)
                                          ? Colors.green
                                          : AppColors.primaryBlue,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _savedQuestionIds.contains(_questions[_currentQuestionIndex].id)
                                            ? Icons.bookmark_rounded
                                            : Icons.bookmark_border_rounded,
                                        size: isSmallScreen ? 14 : 16,
                                        color: _savedQuestionIds.contains(_questions[_currentQuestionIndex].id)
                                            ? Colors.green
                                            : AppColors.primaryBlue,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        _savedQuestionIds.contains(_questions[_currentQuestionIndex].id)
                                            ? 'Kaydedildi'
                                            : 'Kaydet',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 11 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: _savedQuestionIds.contains(_questions[_currentQuestionIndex].id)
                                              ? Colors.green
                                              : AppColors.primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Timer
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
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 10),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _questions.length,
                  backgroundColor: isDark ? const Color(0xFF2C2C2C) : AppColors.backgroundLight,
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
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                        color: isDark ? Colors.white : AppColors.textPrimary,
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
                            color: optionColor?.withValues(alpha: 0.1) ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: optionColor ?? (isDark ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
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
                                           : (isDark ? Colors.white : AppColors.textPrimary)),
                                  ),
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 10 : 12),
                              Expanded(
                                child: OptionTextWithUnderline(
                                  text: option,
                                  underlinedWord: currentQuestion.underlinedWords != null &&
                                          index < currentQuestion.underlinedWords!.length
                                      ? (currentQuestion.underlinedWords![index].isEmpty
                                          ? null
                                          : currentQuestion.underlinedWords![index])
                                      : null,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                    color: optionColor ?? (isDark ? Colors.white : AppColors.textPrimary),
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
                  // Explanation (sadece manuel açıldıysa göster) — Modern kart
                  if (_showExplanation && _showExplanationManually)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: isSmallScreen ? 12 : 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (_selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.orange.withValues(alpha: 0.12))
                            : (_selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                ? Colors.green.withValues(alpha: 0.06)
                                : Colors.orange.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                              ? Colors.green.withValues(alpha: isDark ? 0.35 : 0.2)
                              : Colors.orange.withValues(alpha: isDark ? 0.35 : 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                    ? Colors.green
                                    : Colors.orange)
                                .withValues(alpha: isDark ? 0.08 : 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Başlık çubuğu
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 14,
                              vertical: isSmallScreen ? 8 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                  ? Colors.green.withValues(alpha: isDark ? 0.2 : 0.12)
                                  : Colors.orange.withValues(alpha: isDark ? 0.2 : 0.12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                        ? Colors.green.withValues(alpha: 0.25)
                                        : Colors.orange.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                        ? Icons.lightbulb_rounded
                                        : Icons.school_rounded,
                                    color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    size: isSmallScreen ? 18 : 20,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Soru açıklaması',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Açıklama metni
                          Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            child: Text(
                              currentQuestion.explanation,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                                color: isDark ? Colors.white.withValues(alpha: 0.92) : AppColors.textPrimary.withValues(alpha: 0.9),
                                height: 1.5,
                                letterSpacing: 0.15,
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
                      // Önceki Soru Butonu
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _previousQuestion,
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              size: isSmallScreen ? 16 : 18,
                            ),
                            label: const Text('Önceki'),
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
                      if (_currentQuestionIndex > 0) SizedBox(width: 10),
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
                        flex: (_currentQuestionIndex > 0 && _showExplanation) ? 2 : (_currentQuestionIndex > 0 || _showExplanation ? 2 : 1),
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


