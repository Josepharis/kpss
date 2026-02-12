import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import '../../../core/models/test_question.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/services/questions_service.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/widgets/option_text_with_underline.dart';
import '../../../core/widgets/formatted_text.dart';
import '../../../core/widgets/premium_snackbar.dart';
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
  bool _showExplanationManually =
      false; // Açıklama manuel olarak gösteriliyor mu?
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
      final savedProgress = await _progressService.getTestProgress(
        widget.topicId,
      );

      // Load questions (will try Storage first, then Firestore)
      final questions = await _questionsService.getQuestionsByTopicId(
        widget.topicId,
        lessonId: widget.lessonId,
      );

      if (mounted) {
        // Set saved progress immediately if available
        int initialQuestionIndex = 0;
        int initialScore = 0;
        List<int?> initialAnswers = List<int?>.filled(questions.length, null);

        if (savedProgress != null && questions.isNotEmpty) {
          final savedIndex = savedProgress['index'] as int? ?? 0;
          if (savedIndex < questions.length) {
            initialQuestionIndex = savedIndex;
            initialScore = savedProgress['score'] as int? ?? 0;

            // Reconstruct answers
            final savedAnswers = savedProgress['answers'] as List<dynamic>?;
            if (savedAnswers != null) {
              for (
                int i = 0;
                i < savedAnswers.length && i < initialAnswers.length;
                i++
              ) {
                final val = savedAnswers[i];
                initialAnswers[i] = val is int
                    ? val
                    : (val != null ? -1 : null);
              }
            } else {
              // Eğer cevaplar yoksa ama index ilerideyse, önceki soruları boş (-1) kabul et
              for (
                int i = 0;
                i < savedIndex && i < initialAnswers.length;
                i++
              ) {
                initialAnswers[i] = -1;
              }
            }

            debugPrint(
              '✅ Resuming test from question ${initialQuestionIndex + 1} with score: $initialScore',
            );
          }
        }

        setState(() {
          _questions = questions;
          _currentQuestionIndex = initialQuestionIndex;
          _score = initialScore;
          _selectedAnswers = initialAnswers;
          _isLoading = false;
        });

        if (_questions.isNotEmpty) {
          _restoreQuestionState(); // Restore UI state for the initial question
          _checkSavedQuestions();
          _startTimer();
          _saveProgress(); // Save initial progress
        } else {
          // Soru yoksa kullanıcıya bilgi ver
          if (mounted) {
            PremiumSnackBar.show(
              context,
              message: 'Bu konu için henüz soru eklenmemiş.',
              type: SnackBarType.warning,
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
        PremiumSnackBar.show(
          context,
          message: 'Sorular yüklenirken bir hata oluştu: $e',
          type: SnackBarType.error,
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
    if (_isAnswered) {
      _timer?.cancel();
      _remainingSeconds = 0;
      return;
    }

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
      if (_selectedAnswers.isNotEmpty &&
          _currentQuestionIndex < _selectedAnswers.length) {
        // Süre bittiğinde soruyu "süresi doldu" (-2) olarak işaretle
        _selectedAnswers[_currentQuestionIndex] = -2;
      }
    });

    // Boş bırakılan soruyu ilerlemeye kaydet
    _saveProgress();
  }

  void _selectAnswer(int index) {
    if (_questions.isEmpty) return;

    // Bu soru daha önce cevaplandıysa veya süresi bittiyse değişikliği engelle
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

  void _restoreQuestionState() {
    if (_selectedAnswers.isNotEmpty &&
        _currentQuestionIndex < _selectedAnswers.length) {
      final answer = _selectedAnswers[_currentQuestionIndex];
      if (answer != null) {
        _selectedAnswerIndex = (answer == -1 || answer == -2) ? null : answer;
        _isAnswered = true;
        _showExplanation = true;
      } else {
        _selectedAnswerIndex = null;
        _isAnswered = false;
        _showExplanation = false;
      }
    }
    _showExplanationManually = false;
  }

  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _restoreQuestionState();
      });
      _checkCurrentQuestionSaved();
      _startTimer();
      _saveProgress(); // Save progress after moving to next question
    } else {
      // Test completed - save final score and results before showing results
      await _saveProgress();

      // Calculate answers for database
      int correctCount = 0;
      int wrongCount = 0;
      for (int i = 0; i < _questions.length; i++) {
        final ans = _selectedAnswers[i];
        if (ans != null && ans != -1 && ans != -2) {
          if (ans == _questions[i].correctAnswerIndex) {
            correctCount++;
          } else {
            wrongCount++;
          }
        }
      }

      // Save test result
      await _progressService.saveTestResult(
        topicId: widget.topicId,
        topicName: widget.topicName,
        lessonId: widget.lessonId,
        totalQuestions: _questions.length,
        correctAnswers: correctCount,
        wrongAnswers: wrongCount,
        score: _score,
      );

      // Delete ongoing test progress
      await _progressService.deleteTestProgress(
        widget.topicId,
        widget.lessonId,
      );
      _showResults();
    }
  }

  Future<void> _previousQuestion() async {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _restoreQuestionState();
      });
      _checkCurrentQuestionSaved();
      _startTimer();
      _saveProgress(); // Save progress after moving to previous question
    }
  }

  void _showQuestionSelector() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ScrollController scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients && _currentQuestionIndex > 10) {
            final row = _currentQuestionIndex ~/ 5;
            scrollController.animateTo(
              row * 62.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: Container(
            width: screenWidth > 500 ? 500 : double.infinity,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 24, 20, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2563EB).withOpacity(0.1),
                          const Color(0xFF2563EB).withOpacity(0.02),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SORU GEZGİNİ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'Toplam ${_questions.length} Soru',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white60 : Colors.black45,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendItem(
                          'Doğru',
                          const Color(0xFF10B981),
                          isDark,
                        ),
                        _buildLegendItem(
                          'Yanlış',
                          const Color(0xFFEF4444),
                          isDark,
                        ),
                        _buildLegendItem(
                          'Boş',
                          const Color(0xFFF59E0B),
                          isDark,
                        ),
                        _buildLegendItem(
                          'Mevcut',
                          const Color(0xFF2563EB),
                          isDark,
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final isCurrent = index == _currentQuestionIndex;
                        final answer =
                            _selectedAnswers.isNotEmpty &&
                                index < _selectedAnswers.length
                            ? _selectedAnswers[index]
                            : null;

                        final bool isCorrect =
                            answer != null &&
                            answer >= 0 &&
                            answer == _questions[index].correctAnswerIndex;
                        final bool isWrong =
                            answer != null &&
                            answer >= 0 &&
                            answer != _questions[index].correctAnswerIndex;
                        final bool isEmpty = answer == -1;
                        final bool isTimedOut = answer == -2;

                        Color color = const Color(0xFF2563EB);
                        if (isCorrect)
                          color = const Color(0xFF10B981);
                        else if (isWrong)
                          color = const Color(0xFFEF4444);
                        else if (isEmpty || isTimedOut)
                          color = const Color(0xFFF59E0B);

                        final bool hasAction =
                            isCorrect || isWrong || isEmpty || isTimedOut;

                        return GestureDetector(
                          onTap: () {
                            final oldIndex = _currentQuestionIndex;
                            Navigator.pop(context);
                            setState(() {
                              if (index > oldIndex) {
                                for (int i = oldIndex; i < index; i++) {
                                  if (_selectedAnswers[i] == null)
                                    _selectedAnswers[i] = -1;
                                }
                              }
                              _currentQuestionIndex = index;
                              _restoreQuestionState();
                            });
                            _checkCurrentQuestionSaved();
                            _startTimer();
                            _saveProgress();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? color
                                  : (hasAction
                                        ? color.withOpacity(0.12)
                                        : (isDark
                                              ? Colors.white.withOpacity(0.04)
                                              : Colors.black.withOpacity(
                                                  0.03,
                                                ))),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrent
                                    ? color
                                    : (hasAction
                                          ? color.withOpacity(0.3)
                                          : (isDark
                                                ? Colors.white.withOpacity(0.08)
                                                : Colors.black.withOpacity(
                                                    0.05,
                                                  ))),
                                width: isCurrent ? 2 : 1,
                              ),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isCurrent
                                      ? Colors.white
                                      : (hasAction
                                            ? color
                                            : (isDark
                                                  ? Colors.white38
                                                  : Colors.black26)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // Mevcut sorunun kaydedilip kaydedilmediğini kontrol et
  Future<void> _checkCurrentQuestionSaved() async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length)
      return;

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
    if (_questions.isEmpty || _selectedAnswers.isEmpty) return;

    // Sadece sorular yüklendikten ve cevaplar listesi hazır olduğunda kaydet
    if (_selectedAnswers.length != _questions.length) return;

    await _progressService.saveTestProgress(
      topicId: widget.topicId,
      topicName: widget.topicName,
      lessonId: widget.lessonId,
      currentQuestionIndex: _currentQuestionIndex,
      totalQuestions: _questions.length,
      score: _score, // Puanı da kaydet
      answers: _selectedAnswers, // Cevapları kaydet
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
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length)
      return;

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
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length)
      return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCurrentlySaved = _savedQuestionIds.contains(currentQuestion.id);

    // Optimistic UI Update
    setState(() {
      if (isCurrentlySaved) {
        _savedQuestionIds.remove(currentQuestion.id);
      } else {
        _savedQuestionIds.add(currentQuestion.id);
      }
    });

    // Perform actual operation in background
    try {
      if (isCurrentlySaved) {
        await WeaknessesService.removeWeakness(
          currentQuestion.id,
          widget.topicName,
          lessonId: widget.lessonId,
        );
      } else {
        final weakness = WeaknessQuestion.fromTestQuestion(
          testQuestion: currentQuestion,
          lessonId: widget.lessonId,
          topicName: widget.topicName,
          isFromWrongAnswer: false,
        );
        await WeaknessesService.addWeakness(weakness);
      }
    } catch (e) {
      // Revert state if it failed
      if (mounted) {
        setState(() {
          if (isCurrentlySaved) {
            _savedQuestionIds.add(currentQuestion.id);
          } else {
            _savedQuestionIds.remove(currentQuestion.id);
          }
        });
        PremiumSnackBar.show(
          context,
          message: 'Kaydedilirken bir hata oluştu.',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _showResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int correctCount = 0;
    int wrongCount = 0;
    int emptyCount = 0;
    int timedOutCount = 0;

    for (int i = 0; i < _questions.length; i++) {
      final ans = _selectedAnswers[i];
      if (ans == null || ans == -1)
        emptyCount++;
      else if (ans == -2)
        timedOutCount++;
      else if (ans == _questions[i].correctAnswerIndex)
        correctCount++;
      else
        wrongCount++;
    }

    final percentage = ((correctCount * 10) / (_questions.length * 10) * 100)
        .round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.15),
                        const Color(0xFF10B981).withOpacity(0.02),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            width: 4,
                          ),
                        ),
                        child: const Icon(
                          Icons.celebration_rounded,
                          size: 48,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'TEST TAMAMLANDI!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10B981),
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Harika Gidiyorsun!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  'PUAN',
                                  '$_score',
                                  Icons.star_rounded,
                                  Colors.amber,
                                ),
                                _buildStatItem(
                                  'DOĞRU',
                                  '$correctCount',
                                  Icons.check_circle_rounded,
                                  const Color(0xFF10B981),
                                ),
                                _buildStatItem(
                                  'YANLIŞ',
                                  '$wrongCount',
                                  Icons.cancel_rounded,
                                  const Color(0xFFEF4444),
                                ),
                                _buildStatItem(
                                  'BOŞ',
                                  '${emptyCount + timedOutCount}',
                                  Icons.help_outline_rounded,
                                  const Color(0xFFF59E0B),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '%$percentage Başarı Oranı',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildPrimaryButton(
                        label: 'Ana Sayfaya Dön',
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (mounted) {
                            Navigator.of(context).pop(true);
                            final mainScreen = MainScreen.of(context);
                            if (mainScreen != null)
                              mainScreen.refreshHomePage();
                          }
                        },
                        isDark: isDark,
                        icon: Icons.home_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            _buildMeshBackground(isDark, screenWidth),
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            _buildMeshBackground(isDark, screenWidth),
            Column(
              children: [
                _buildPremiumAppBar(context, isDark, isSmallScreen, isTablet),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.black.withOpacity(0.02),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.quiz_outlined,
                            size: 80,
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Bu konu için henüz soru eklenmemiş',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildPrimaryButton(
                          label: 'Geri Dön',
                          onPressed: () => Navigator.pop(context),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            _buildMeshBackground(isDark, screenWidth),
            Column(
              children: [
                _buildPremiumAppBar(context, isDark, isSmallScreen, isTablet),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.of(context).padding.bottom + 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusHeader(isDark, isSmallScreen),
                        const SizedBox(height: 16),
                        _buildQuestionCard(
                          currentQuestion,
                          isDark,
                          isSmallScreen,
                        ),
                        const SizedBox(height: 24),
                        _buildOptionsList(
                          currentQuestion,
                          isDark,
                          isSmallScreen,
                        ),
                        const SizedBox(height: 24),
                        if (_showExplanation && _showExplanationManually)
                          _buildExplanationCard(
                            currentQuestion,
                            isDark,
                            isSmallScreen,
                          ),
                        const SizedBox(height: 32),
                        _buildNavigationButtons(isSmallScreen, isDark),
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

  Widget _buildPremiumAppBar(
    BuildContext context,
    bool isDark,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 12,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F0F1A) : Colors.white).withOpacity(
          0.8,
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Row(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    size: 16,
                  ),
                ),
                onPressed: () async {
                  if (_questions.isNotEmpty) await _saveProgress();
                  if (mounted) Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TEST ÇÖZÜMÜ',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.blueAccent.shade100
                            : const Color(0xFF2563EB),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      widget.topicName,
                      style: TextStyle(
                        fontSize: 18, // Reduced from 20
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_questions.isNotEmpty)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      size: 18,
                    ),
                  ),
                  onPressed: _showQuestionSelector,
                ),
              _buildScorePill(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScorePill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? Colors.white.withOpacity(0.15)
                : const Color(0xFF2563EB).withOpacity(0.1),
            isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFF2563EB).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$_score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(bool isDark, bool isSmallScreen) {
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoChip(
              icon: Icons.tag_rounded,
              label: 'Soru ${_currentQuestionIndex + 1}/${_questions.length}',
              color: const Color(0xFF2563EB),
              isDark: isDark,
            ),
            Row(
              children: [
                _buildSaveButton(isDark),
                const SizedBox(width: 8),
                _buildTimerChip(isDark),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProgressBar(progress, isDark),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    final isSaved = _savedQuestionIds.contains(
      _questions[_currentQuestionIndex].id,
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isSaved
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saveToWeaknesses,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSaved
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    )
                  : null,
              color: isSaved
                  ? null
                  : (isDark ? Colors.white.withOpacity(0.06) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSaved
                    ? Colors.white.withOpacity(0.2)
                    : (isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.08)),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 14, // Reduced from 16
                  color: isSaved
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 6),
                Text(
                  isSaved ? 'KAYDEDİLDİ' : 'KAYDET',
                  style: TextStyle(
                    fontSize: 10, // Reduced from 11
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: isSaved
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerChip(bool isDark) {
    final isWarning = _remainingSeconds < 10;
    final color = isWarning ? const Color(0xFFEF4444) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '${_remainingSeconds}s',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, bool isDark) {
    return Stack(
      children: [
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        FractionallySizedBox(
          widthFactor: progress.clamp(0.02, 1.0),
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    TestQuestion question,
    bool isDark,
    bool isSmallScreen,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (question.imageUrl != null)
                _buildQuestionImage(question.imageUrl!),
              Padding(
                padding: const EdgeInsets.all(20), // Reduced from 24
                child: Column(
                  children: [
                    if (_selectedAnswers.isNotEmpty &&
                        _currentQuestionIndex < _selectedAnswers.length &&
                        _selectedAnswers[_currentQuestionIndex] == -2)
                      _buildTimeUpIndicator(),
                    FormattedText(
                      text: question.question,
                      style: TextStyle(
                        fontSize: 15, // Reduced from 16
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withOpacity(0.9)
                            : const Color(0xFF1E293B),
                        height: 1.5, // Tighter leading
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionImage(String url) {
    return Stack(
      children: [
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.zoom_in_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeUpIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer_off_rounded,
            color: Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'SÜRE DOLDU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFFEF4444),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(
    TestQuestion question,
    bool isDark,
    bool isSmallScreen,
  ) {
    return Column(
      children: question.options.asMap().entries.map((entry) {
        return _buildOptionTile(entry.key, entry.value, question, isDark);
      }).toList(),
    );
  }

  Widget _buildOptionTile(
    int index,
    String text,
    TestQuestion question,
    bool isDark,
  ) {
    final isCorrect = index == question.correctAnswerIndex;
    final isSelected = _selectedAnswerIndex == index;
    final letter = String.fromCharCode(65 + index);

    Color? borderColor;
    Color? bgColor;
    Color? textColor;
    IconData? icon;

    if (_showExplanation) {
      if (isCorrect) {
        borderColor = const Color(0xFF10B981);
        bgColor = const Color(0xFF10B981).withOpacity(0.15);
        textColor = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
      } else if (isSelected) {
        borderColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFEF4444).withOpacity(0.15);
        textColor = const Color(0xFFEF4444);
        icon = Icons.cancel_rounded;
      }
    } else if (isSelected) {
      borderColor = const Color(0xFF2563EB);
      bgColor = const Color(0xFF2563EB).withOpacity(0.1);
      textColor = const Color(0xFF2563EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAnswered ? null : () => _selectAnswer(index),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  bgColor ??
                  (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    borderColor ??
                    (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05)),
                width: isSelected || (isCorrect && _showExplanation) ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected && !_showExplanation)
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                _buildOptionLetterBox(
                  letter,
                  isSelected,
                  isCorrect,
                  _showExplanation,
                  isDark,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OptionTextWithUnderline(
                    text: text,
                    underlinedWord:
                        question.underlinedWords != null &&
                            index < question.underlinedWords!.length
                        ? (question.underlinedWords![index].isEmpty
                              ? null
                              : question.underlinedWords![index])
                        : null,
                    style: TextStyle(
                      fontSize: 14, // Reduced from 15
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color:
                          textColor ??
                          (isDark
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF1E293B)),
                    ),
                  ),
                ),
                if (icon != null) Icon(icon, color: textColor, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionLetterBox(
    String letter,
    bool isSelected,
    bool isCorrect,
    bool showResult,
    bool isDark,
  ) {
    Color boxColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);
    Color textColor = isDark ? Colors.white60 : Colors.black54;

    if (showResult) {
      if (isCorrect) {
        boxColor = const Color(0xFF10B981);
        textColor = Colors.white;
      } else if (isSelected) {
        boxColor = const Color(0xFFEF4444);
        textColor = Colors.white;
      }
    } else if (isSelected) {
      boxColor = const Color(0xFF2563EB);
      textColor = Colors.white;
    }

    return Container(
      width: 28, // Reduced from 32
      height: 28,
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 13, // Reduced from 14
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildExplanationCard(
    TestQuestion question,
    bool isDark,
    bool isSmallScreen,
  ) {
    final isCorrect = _selectedAnswerIndex == question.correctAnswerIndex;
    final accentColor = isCorrect
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCorrect ? Icons.lightbulb_rounded : Icons.school_rounded,
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'SORU AÇIKLAMASI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: FormattedText(
              text: question.explanation,
              style: TextStyle(
                fontSize: 16, // Further increased for readability
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withOpacity(0.9)
                    : const Color(0xFF1E293B),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isSmallScreen, bool isDark) {
    return Row(
      children: [
        if (_currentQuestionIndex > 0)
          Expanded(
            flex: 1,
            child: _buildSecondaryButton(
              icon: Icons.chevron_left_rounded,
              label: 'ÖNCEKİ',
              onPressed: _previousQuestion,
              isDark: isDark,
            ),
          ),
        if (_currentQuestionIndex > 0) const SizedBox(width: 8),
        if (_showExplanation)
          Expanded(
            flex: 1,
            child: _buildSecondaryButton(
              icon: _showExplanationManually
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              label: _showExplanationManually ? 'GİZLE' : 'AÇIKLAMA',
              onPressed: () => setState(
                () => _showExplanationManually = !_showExplanationManually,
              ),
              isDark: isDark,
            ),
          ),
        if (_showExplanation) const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: _buildPrimaryButton(
            label: _currentQuestionIndex < _questions.length - 1
                ? 'SONRAKİ'
                : 'BİTİR',
            onPressed: _nextQuestion,
            isDark: isDark,
            icon: Icons.chevron_right_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
    IconData? icon,
  }) {
    return _buildCustomButton(
      label: label,
      onPressed: onPressed,
      isDark: isDark,
      icon: icon,
      isPrimary: true,
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
    required IconData icon,
  }) {
    return _buildCustomButton(
      label: label,
      onPressed: onPressed,
      isDark: isDark,
      icon: icon,
      isPrimary: false,
    );
  }

  Widget _buildCustomButton({
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
    required IconData? icon,
    required bool isPrimary,
  }) {
    final accentColor = const Color(0xFF2563EB);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null && !isPrimary) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            if (icon != null && isPrimary) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark, double screenWidth) {
    return Positioned.fill(
      child: Container(
        color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFF),
        child: Stack(
          children: [
            Positioned(
              top: 50,
              right: -screenWidth * 0.3,
              child: _buildBlurCircle(
                size: screenWidth * 1.5,
                color: isDark
                    ? const Color(0xFF2563EB).withOpacity(0.1)
                    : const Color(0xFF60A5FA).withOpacity(0.08),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -screenWidth * 0.2,
              child: _buildBlurCircle(
                size: screenWidth * 1.2,
                color: isDark
                    ? const Color(0xFFA855F7).withOpacity(0.08)
                    : const Color(0xFFC084FC).withOpacity(0.05),
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
          stops: const [0.1, 1.0],
        ),
      ),
    );
  }
}
