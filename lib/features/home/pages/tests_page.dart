import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/test_question.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/services/questions_service.dart';
import '../../../core/services/progress_service.dart';
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
        // Puanı kullanıcının toplam puanına ekle (her doğru cevap için +10 puan)
        _progressService.addScore(10);
      }
    });

    // Yanlış cevaplanan soruları otomatik olarak eksiklere ekle
    if (!isCorrect) {
      _addToWeaknesses(isFromWrongAnswer: true);
    }
  }

  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _showExplanation = false;
        _showExplanationManually = false;
        _isAnswered = false;
      });
      _checkCurrentQuestionSaved();
      _startTimer();
      _saveProgress(); // Save progress after moving to next question
    } else {
      // Test completed - save final score before showing results
      await _saveProgress();
      // Puan zaten her soru için eklendi, burada eklemeye gerek yok
      _progressService.deleteTestProgress(widget.topicId);
      _showResults();
    }
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
            onPressed: () async {
              debugPrint('✅ Test completed - Tamam button pressed');
              // Save final progress
              if (_questions.isNotEmpty) {
                debugPrint('🗑️ Deleting test progress...');
                await _progressService.deleteTestProgress(widget.topicId);
                debugPrint('✅ Progress deleted');
              }
              if (mounted) {
                // Close result dialog first
              Navigator.of(context).pop();
                // Wait a bit for dialog to close
                await Future.delayed(const Duration(milliseconds: 100));
                // Show loading dialog
                if (mounted) {
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
                  // Close loading dialog and page
                  if (mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
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


