import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/study_program.dart';
import '../../../core/services/study_program_service.dart';

class _DraggedProgramTask {
  final int fromWeekday; // 1..7
  final StudyProgramTask task;
  const _DraggedProgramTask({required this.fromWeekday, required this.task});
}

class _TaskEditorResult {
  final StudyProgramTask? task;
  final bool delete;
  const _TaskEditorResult._({required this.task, required this.delete});
  const _TaskEditorResult.save(StudyProgramTask task)
    : this._(task: task, delete: false);
  const _TaskEditorResult.delete() : this._(task: null, delete: true);
}

class MyProgramPage extends StatefulWidget {
  final bool isTransparent;
  const MyProgramPage({super.key, this.isTransparent = false});

  @override
  State<MyProgramPage> createState() => _MyProgramPageState();
}

class _MyProgramPageState extends State<MyProgramPage> {
  bool _loading = true;
  StudyProgram? _program;
  bool _editMode = true; // Always in edit mode as requested
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  late final Map<int, GlobalKey> _daySectionKeys;
  Timer? _autoScrollTimer;
  Offset? _lastDragGlobalPosition;
  int _activeDay = 1; // 1-indexed day
  StreamSubscription? _programSubscription;

  @override
  void dispose() {
    _programSubscription?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _daySectionKeys = {};
    _load();
    _programSubscription = StudyProgramService.instance.onProgramUpdated.listen(
      (_) {
        if (mounted) _load();
      },
    );
  }

  void _ensureKeys(int dayCount) {
    for (int i = 1; i <= dayCount; i++) {
      _daySectionKeys[i] ??= GlobalKey();
    }
  }

  Future<void> _load() async {
    // Cache'den önce göster (anlık), loading ekranı gösterme
    final cached = await StudyProgramService.instance.getProgramFromCache();
    if (cached != null && mounted) {
      setState(() {
        _program = cached;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = true);
    }

    final program = await StudyProgramService.instance.getProgram();
    if (!mounted) return;
    
    if (program == null) {
      await _createEmptyProgramAndEnterEdit();
    } else {
      _ensureKeys(program.days.length);
      setState(() {
        _program = program;
        _loading = false;
        if (program.programType == 'weekly') {
          _activeDay = DateTime.now().weekday;
        } else if (program.programType == 'dated' && program.startDateMillis != null) {
          final now = DateTime.now();
          final start = DateTime.fromMillisecondsSinceEpoch(program.startDateMillis!);
          // normalize dates by setting to midnight to calculate correct day offset
          final startMid = DateTime(start.year, start.month, start.day);
          final nowMid = DateTime(now.year, now.month, now.day);
          final diff = nowMid.difference(startMid).inDays;
          if (diff >= 0 && diff < program.days.length) {
            _activeDay = diff + 1;
          } else {
            _activeDay = 1;
          }
        } else {
          _activeDay = 1;
        }
      });
    }
  }

  Future<void> _saveProgram(StudyProgram program) async {
    // Optimistic UI update – UI anında güncellendi, reload gerekmez.
    setState(() => _program = program);
    try {
      await StudyProgramService.instance.saveProgram(program);
      // NOT: saveProgram() içinde _isSelfSaving=true olduğu için
      // stream event'i bu widget'ta _load() tetiklemez. Optimistic update yeterli.
    } catch (_) {
      // Hata olursa cache'den tekrar yükle
      _load();
    }
  }

  List<Color> _gradientForKind(String kind) {
    switch (kind) {
      case 'test':
        return const [AppColors.gradientBlueStart, AppColors.gradientBlueEnd];
      case 'video':
        return const [Color(0xFFF44336), Color(0xFFD32F2F)];
      case 'podcast':
        return const [Color(0xFF8E24AA), Color(0xFF5E35B1)];
      case 'kart':
        return const [Color(0xFFFF9800), Color(0xFFF57C00)];
      case 'tekrar':
        return const [AppColors.gradientGreenStart, AppColors.gradientGreenEnd];
      case 'konu':
        return const [AppColors.gradientTealStart, AppColors.gradientTealEnd];
      default:
        return const [
          AppColors.gradientOrangeStart,
          AppColors.gradientYellowEnd,
        ];
    }
  }

  List<Color> _gradientForWeekday(int day) {
    // Ensure day cycles every 7 days
    final cycleValue = ((day - 1) % 7) + 1;
    switch (cycleValue) {
      case 1:
        return const [AppColors.gradientBlueStart, AppColors.gradientTealEnd];
      case 2:
        return const [AppColors.gradientTealStart, AppColors.gradientTealEnd];
      case 3:
        return const [
          AppColors.gradientPurpleStart,
          AppColors.gradientPurpleEnd,
        ];
      case 4:
        return const [
          AppColors.gradientOrangeStart,
          AppColors.gradientYellowEnd,
        ];
      case 5:
        return const [AppColors.gradientRedStart, AppColors.gradientRedEnd];
      case 6:
        return const [AppColors.gradientGreenStart, AppColors.gradientGreenEnd];
      case 7:
      default:
        return const [
          AppColors.gradientYellowStart,
          AppColors.gradientOrangeEnd,
        ];
    }
  }

  Future<void> _createEmptyProgramAndEnterEdit({
    String type = 'weekly',
    int dayCount = 7,
    DateTime? startDate,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    String title = 'Haftalık Plan';
    if (type == 'monthly') title = 'Aylık Plan';
    else if (type == 'custom' || type == 'dated') title = 'Özel Plan';

    String subtitle = '7 Günlük Plan';
    if (type == 'monthly') {
      subtitle = '30 Günlük Plan';
    } else if (type == 'custom') {
      subtitle = '$dayCount Günlük Plan';
    } else if (type == 'dated' && startDate != null) {
      final endDate = startDate.add(Duration(days: dayCount - 1));
      subtitle = '${startDate.day} ${_formatMonth(startDate.month)} – '
          '${endDate.day} ${_formatMonth(endDate.month)}';
    }

    final program = StudyProgram(
      createdAtMillis: now,
      title: title,
      subtitle: subtitle,
      programType: type,
      startDateMillis: startDate?.millisecondsSinceEpoch,
      days: List.generate(
        dayCount,
        (i) => StudyProgramDay(weekday: i + 1, tasks: const []),
      ),
    );
    
    _ensureKeys(dayCount);
    setState(() {
      _program = program;
      _editMode = true;
      _activeDay = 1;
    });
    await _saveProgram(program);
  }

  // _clear method removed as unnecessary / confirm dialog removed as requested


  List<StudyProgramTask> _tasksForWeekday(StudyProgram program, int weekday) {
    for (final d in program.days) {
      if (d.weekday == weekday) return d.tasks;
    }
    return const <StudyProgramTask>[];
  }

  bool _sameTask(StudyProgramTask a, StudyProgramTask b) {
    return a.start == b.start &&
        a.end == b.end &&
        a.title == b.title &&
        a.kind == b.kind &&
        a.lesson == b.lesson &&
        a.topic == b.topic &&
        a.notes == b.notes &&
        a.detail == b.detail;
  }

  int _indexOfTask(List<StudyProgramTask> list, StudyProgramTask task) {
    final direct = list.indexOf(task);
    if (direct != -1) return direct;
    return list.indexWhere((t) => _sameTask(t, task));
  }

  bool _removeTaskFromList(List<StudyProgramTask> list, StudyProgramTask task) {
    final idx = _indexOfTask(list, task);
    if (idx < 0 || idx >= list.length) return false;
    list.removeAt(idx);
    return true;
  }

  StudyProgram _withDayTasks(
    StudyProgram base,
    int weekday,
    List<StudyProgramTask> tasks,
  ) {
    final byDay = <int, StudyProgramDay>{};
    for (final d in base.days) {
      byDay[d.weekday] = d;
    }
    byDay[weekday] = StudyProgramDay(weekday: weekday, tasks: tasks);
    final days = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return StudyProgram(
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      title: base.title,
      subtitle: base.subtitle,
      days: days.map((e) => e.value).toList(),
    );
  }

  Future<void> _toggleTaskCompletion(int weekday, StudyProgramTask task) async {
    final program = _program;
    if (program == null) return;
    final list = List<StudyProgramTask>.from(
      _tasksForWeekday(program, weekday),
    );
    final idx = _indexOfTask(list, task);
    if (idx >= 0) {
      list[idx] = task.copyWith(isCompleted: !task.isCompleted);
      await _saveProgram(_withDayTasks(program, weekday, list));
    }
  }

  Future<void> _deleteTask(int weekday, StudyProgramTask task) async {
    final program = _program;
    if (program == null) return;
    final list = List<StudyProgramTask>.from(
      _tasksForWeekday(program, weekday),
    );
    _removeTaskFromList(list, task);
    await _saveProgram(_withDayTasks(program, weekday, list));
  }

  Future<void> _moveTaskToIndex({
    required int fromWeekday,
    required int toWeekday,
    required StudyProgramTask task,
    required int toIndex,
  }) async {
    final program = _program;
    if (program == null) return;

    final fromList = List<StudyProgramTask>.from(
      _tasksForWeekday(program, fromWeekday),
    );
    final removedIndex = _indexOfTask(fromList, task);
    final removed = _removeTaskFromList(fromList, task);
    if (!removed) return;

    final toList = (fromWeekday == toWeekday)
        ? fromList
        : List<StudyProgramTask>.from(_tasksForWeekday(program, toWeekday));

    var insertIndex = toIndex;
    if (insertIndex < 0) insertIndex = 0;
    if (insertIndex > toList.length) insertIndex = toList.length;
    // If moving within same list, removal shifts indices.
    if (fromWeekday == toWeekday &&
        removedIndex != -1 &&
        removedIndex < insertIndex) {
      insertIndex = math.max(0, insertIndex - 1);
    }
    toList.insert(insertIndex, task);

    final updated = (fromWeekday == toWeekday)
        ? _withDayTasks(program, toWeekday, toList)
        : _withDayTasks(
            _withDayTasks(program, fromWeekday, fromList),
            toWeekday,
            toList,
          );
    await _saveProgram(updated);
  }

  Future<void> _upsertTask({
    required int weekday,
    required StudyProgramTask task,
    StudyProgramTask? replace,
  }) async {
    final program = _program;
    if (program == null) return;
    final list = List<StudyProgramTask>.from(
      _tasksForWeekday(program, weekday),
    );
    if (replace != null) {
      final idx = _indexOfTask(list, replace);
      if (idx >= 0) {
        list[idx] = task;
      } else {
        list.add(task);
      }
    } else {
      list.add(task);
    }
    await _saveProgram(_withDayTasks(program, weekday, list));
  }

  Future<void> _showTaskEditor({
    required int weekday,
    StudyProgramTask? existing,
  }) async {
    final result = await showModalBottomSheet<_TaskEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskEditorSheet(
        existing: existing,
        colorForKind: _colorForKind,
        gradientForKind: _gradientForKind,
      ),
    );

    if (result == null) return;
    if (result.delete && existing != null) {
      await _deleteTask(weekday, existing);
      return;
    }
    final task = result.task;
    if (task == null) return;
    await _upsertTask(weekday: weekday, task: task, replace: existing);
  }

  void _onDragStarted() {
    HapticFeedback.selectionClick();
    _startAutoScroll();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _lastDragGlobalPosition = details.globalPosition;
  }

  void _onDragFinished() {
    _stopAutoScroll();
  }

  void _startAutoScroll() {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (!_scrollController.hasClients) return;
      // Can be attached before first layout; avoid reading extents too early.
      if (!_scrollController.position.hasContentDimensions) return;
      final pos = _lastDragGlobalPosition;
      final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
      if (pos == null || box == null) return;

      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      final height = box.size.height;
      // Dynamic edges: more reliable across devices/orientations.
      final edgeTop = math.min(220.0, height * 0.26);
      final edgeBottom = math.min(200.0, height * 0.24);
      final maxStep = math.min(28.0, height * 0.035);

      double delta = 0;
      if (pos.dy < top + edgeTop) {
        final t = ((top + edgeTop) - pos.dy) / edgeTop;
        delta = -maxStep * t.clamp(0.0, 1.0);
      } else if (pos.dy > bottom - edgeBottom) {
        final t = (pos.dy - (bottom - edgeBottom)) / edgeBottom;
        delta = maxStep * t.clamp(0.0, 1.0);
      }

      if (delta.abs() < 0.5) return;
      final max = _scrollController.position.maxScrollExtent;
      final next = (_scrollController.offset + delta).clamp(0.0, max);
      if (next != _scrollController.offset) {
        _scrollController.jumpTo(next);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastDragGlobalPosition = null;
  }

  Future<void> _scrollToWeekday(int day) async {
    setState(() => _activeDay = day);
    final ctx = _daySectionKeys[day]?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.06,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_program == null) {
      return _buildEmpty(isDark);
    }

    return _buildProgram(isDark, _program!);
  }

  Widget _buildEmpty(bool isDark) {
    final bg = isDark ? const Color(0xFF0B0F14) : const Color(0xFFF6F8FC);
    final card = isDark ? const Color(0xFF121826) : Colors.white;

    return Container(
      color: widget.isTransparent ? Colors.transparent : bg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: isDark ? 0.16 : 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.gradientTealStart,
                          AppColors.gradientBlueEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gradientTealStart.withValues(
                            alpha: isDark ? 0.22 : 0.26,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Programın hazır değil',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Asistan’dan “Program Oluştur” ile programı kaydet.\nİstersen manuel olarak da haftalık planını oluşturabilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: isDark ? 0.06 : 0.04,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withValues(
                          alpha: isDark ? 0.14 : 0.12,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.gradientYellowStart.withValues(
                            alpha: 0.95,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'İpucu: AI ile program oluşturup kaydettiğinde bu ekran otomatik dolacak.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showNewProgramDialog,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AppColors.gradientTealStart,
                      ),
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: const Text(
                        'Yeni Program Oluştur',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgram(bool isDark, StudyProgram program) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 390;
    final totalTasks = program.days.fold<int>(
      0,
      (sum, d) => sum + d.tasks.length,
    );
    final activeDays = program.days.where((d) => d.tasks.isNotEmpty).length;

    final bg = isDark ? const Color(0xFF0B0F14) : const Color(0xFFF6F8FC);

    return Container(
      color: widget.isTransparent ? Colors.transparent : bg,
      child: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final contentMaxW = 860.0;
            final horizontal = maxW > contentMaxW
                ? (maxW - contentMaxW) / 2
                : (isCompact ? 12.0 : 16.0);

            return Column(
              children: [
                Container(
                  color: isDark ? const Color(0xFF0B0F14) : const Color(0xFFF6F8FC),
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      _buildHeader(
                        program: program,
                        isDark: isDark,
                        isCompact: isCompact,
                        totalTasks: totalTasks,
                        activeDays: activeDays,
                        horizontalPadding: horizontal,
                      ),
                      const SizedBox(height: 12),
                      _buildDayStrip(
                        program: program,
                        isDark: isDark,
                        horizontalPadding: horizontal,
                        isCompact: isCompact,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      key: _listKey,
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (_editMode) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontal),
                            child: _buildEditHint(isDark),
                          ),
                          const SizedBox(height: 10),
                        ],
                        ..._buildDaySections(
                          program: program,
                          isDark: isDark,
                          compact: isCompact,
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditHint(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151515)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.withValues(alpha: isDark ? 0.14 : 0.14),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_rounded,
            size: 18,
            color: AppColors.gradientTealStart.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Düzenleme: basılı tut → sürükle/bırak, çöp ile sil.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayStrip({
    required StudyProgram program,
    required bool isDark,
    required double horizontalPadding,
    required bool isCompact,
  }) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    const shortNames = {
      1: 'Pzt',
      2: 'Sal',
      3: 'Çar',
      4: 'Per',
      5: 'Cum',
      6: 'Cmt',
      7: 'Paz',
    };

    final isWeekly = program.programType == 'weekly';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: horizontalPadding),
      child: Row(
        children: List.generate(program.days.length, (i) {
          final idx = i + 1;
          bool isToday = false;
          String label = '';
          final isDated = program.programType == 'dated' && program.startDateMillis != null;
          final grad = _gradientForWeekday(idx);

          if (isWeekly && idx <= 7) {
            final date = weekStart.add(Duration(days: i));
            isToday = date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day;
            label = shortNames[idx] ?? '';
          } else if (isDated) {
            final date = DateTime.fromMillisecondsSinceEpoch(program.startDateMillis!).add(Duration(days: i));
            isToday = date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day;
            label = '${date.day}';
          } else {
            label = '$idx';
          }

          final isActive = idx == _activeDay;
          final tasks = _tasksForWeekday(program, idx);

          return Padding(
            padding: EdgeInsets.only(right: i == program.days.length - 1 ? 0 : 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _scrollToWeekday(idx);
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuint,
                  width: isWeekly ? 48 : 42,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: grad,
                          )
                        : null,
                    color: isToday
                        ? null
                        : (isDark
                              ? (isActive
                                    ? grad[0].withOpacity(0.12)
                                    : Colors.white.withOpacity(0.04))
                              : (isActive
                                    ? grad[0].withOpacity(0.08)
                                    : Colors.white)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive
                          ? grad[0]
                          : (isToday
                                ? Colors.white.withOpacity(0.2)
                                : (isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.black.withOpacity(0.04))),
                      width: isActive ? 1.5 : 1,
                    ),
                    boxShadow: [
                      if (isToday || isActive)
                        BoxShadow(
                          color: grad[0].withOpacity(isActive ? 0.2 : 0.15),
                          blurRadius: isActive ? 12 : 10,
                          offset: Offset(0, isActive ? 4 : 4),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: isWeekly ? 13 : 14,
                          fontWeight: (isToday || isActive)
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: isToday
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.white.withOpacity(0.2)
                              : (isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : const Color(0xFFF1F5F9)),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${tasks.length}',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: isToday
                                ? Colors.white
                                : (isDark
                                      ? Colors.white60
                                      : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNewProgramButton(bool isDark) {
    return TextButton.icon(
      onPressed: _showNewProgramDialog,
      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
      label: const Text(
        'Planı Değiştir',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.gradientTealStart,
        backgroundColor: AppColors.gradientTealStart.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showNewProgramDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gradientTealStart.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.gradientTealStart,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Programını Güncelle',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Sana en uygun çalışma düzenini seç',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildDialogOption(
              icon: Icons.calendar_view_week_rounded,
              title: 'Haftalık Program',
              subtitle: '7 günlük standart çalışma düzeni',
              onTap: () {
                Navigator.pop(context);
                _createEmptyProgramAndEnterEdit(type: 'weekly', dayCount: 7);
              },
            ),
            _buildDialogOption(
              icon: Icons.calendar_view_month_rounded,
              title: 'Aylık Program',
              subtitle: '30 günlük uzun süreli hedefler için',
              onTap: () {
                Navigator.pop(context);
                _createEmptyProgramAndEnterEdit(type: 'monthly', dayCount: 30);
              },
            ),
            _buildDialogOption(
              icon: Icons.edit_calendar_rounded,
              title: 'Özel Program',
              subtitle: 'Belirlediğin gün sayısı kadar plan oluştur',
              onTap: () {
                Navigator.pop(context);
                _showCustomDaySelector();
              },
            ),
            _buildDialogOption(
              icon: Icons.date_range_rounded,
              title: 'Tarih Aralığı',
              subtitle: 'Takvimden tarih seçerek nokta atışı plan yap',
              onTap: () {
                Navigator.pop(context);
                _showDateRangePicker();
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Yeni program oluşturduğunda mevcut programın silinecektir.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
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
  }

  void _showCustomDaySelector() {
    final controller = TextEditingController(text: '10');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gün Sayısı'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Örn: 10, 15, 45...',
            suffixText: 'GÜN',
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İPTAL'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 10;
              Navigator.pop(context);
              _createEmptyProgramAndEnterEdit(type: 'custom', dayCount: val);
            },
            child: const Text('OLUŞTUR'),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.gradientTealStart,
                ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      final days = range.end.difference(range.start).inDays + 1;
      _createEmptyProgramAndEnterEdit(
        type: 'dated',
        dayCount: days,
        startDate: range.start,
      );
    }
  }

  Widget _buildDialogOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Icon(icon, color: AppColors.gradientTealStart, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required StudyProgram program,
    required bool isDark,
    required bool isCompact,
    required int totalTasks,
    required int activeDays,
    required double horizontalPadding,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 22 : 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.1,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  program.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildNewProgramButton(isDark),
        ],
      ),
    );
  }

  // _buildActionButton removed as requested


  String _formatMonth(int month) {
    const names = {
      1: 'Ocak',
      2: 'Şubat',
      3: 'Mart',
      4: 'Nisan',
      5: 'Mayıs',
      6: 'Haziran',
      7: 'Temmuz',
      8: 'Ağustos',
      9: 'Eylül',
      10: 'Ekim',
      11: 'Kasım',
      12: 'Aralık',
    };
    return names[month] ?? '';
  }

  // (removed unused UI helpers)

  List<Widget> _buildDaySections({
    required StudyProgram program,
    required bool isDark,
    required bool compact,
  }) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    const longNames = {
      1: 'Pazartesi',
      2: 'Salı',
      3: 'Çarşamba',
      4: 'Perşembe',
      5: 'Cuma',
      6: 'Cumartesi',
      7: 'Pazar',
    };

    StudyProgramDay? dayForIndex(int idx) {
      for (final d in program.days) {
        if (d.weekday == idx) return d;
      }
      return null;
    }

    final widgets = <Widget>[];
    final isWeekly = program.programType == 'weekly';

    for (var i = 0; i < program.days.length; i++) {
      final idx = i + 1;
      
      String dayTitle = '';
      String dateLabel = '';
      bool isToday = false;

      final isDated = program.programType == 'dated' && program.startDateMillis != null;

      if (isWeekly && idx <= 7) {
        final date = weekStart.add(Duration(days: i));
        isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
        dayTitle = longNames[idx] ?? '';
        dateLabel = '${date.day} ${_formatMonth(date.month)}';
      } else if (isDated) {
        final date = DateTime.fromMillisecondsSinceEpoch(program.startDateMillis!).add(Duration(days: i));
        isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
        dayTitle = '$idx. GÜN';
        dateLabel = '${date.day} ${_formatMonth(date.month)}';
      } else {
        dayTitle = '$idx. GÜN';
      }

      final tasks = _sortedTasks(
        dayForIndex(idx)?.tasks ?? const <StudyProgramTask>[],
      );
      final isActive = idx == _activeDay;

      widgets.add(
        _buildDaySection(
          weekday: idx,
          dayTitle: dayTitle,
          dateLabel: dateLabel,
          isToday: isToday,
          isActive: isActive,
          tasks: tasks,
          isDark: isDark,
          compact: compact,
        ),
      );
    }
    return widgets;
  }

  Widget _buildDaySection({
    required int weekday,
    required String dayTitle,
    required String dateLabel,
    required bool isToday,
    required bool isActive,
    required List<StudyProgramTask> tasks,
    required bool isDark,
    required bool compact,
  }) {
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    final listBg = isDark
        ? Colors.black.withOpacity(0.2)
        : const Color(0xFFF8FAFC);
    final dayGrad = _gradientForWeekday(weekday);
    final baseBorder = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);

    Widget card({required bool dropHighlight}) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? dayGrad[0] : baseBorder,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            if (isToday || isActive)
              BoxShadow(
                color: dayGrad[0].withOpacity(isActive ? 0.15 : 0.08),
                blurRadius: isActive ? 20 : 15,
                offset: Offset(0, isActive ? 10 : 8),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isToday)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        dayGrad[0].withOpacity(0.05),
                        dayGrad[0].withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: dayGrad,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          dayTitle.contains('.') ? dayTitle.split('.').first : dayTitle.characters.first,
                          style: TextStyle(
                            fontSize: dayTitle.contains('.') && dayTitle.split('.').first.length > 1 ? 12 : 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dayTitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dayGrad[0].withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'BUGÜN',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: dayGrad[0],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              dateLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 12,
                              color: dayGrad[0],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${tasks.length}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add button is now always here as requested
                      _buildIconButton(
                        icon: Icons.add_circle_outline_rounded,
                        onPressed: () => _showTaskEditor(weekday: weekday),
                        isDark: isDark,
                        color: dayGrad[0],
                      ),
                    ],
                  ),
                  if (tasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: listBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: baseBorder),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < tasks.length; i++) ...[
                            Dismissible(
                              key: Key('task_${tasks[i].start}_${tasks[i].title}_$i'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _deleteTask(weekday, tasks[i]),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              ),
                              child: _buildTaskRow(
                                weekday: weekday,
                                task: tasks[i],
                                isDark: isDark,
                                compact: compact,
                              ),
                            ),
                            if (i != tasks.length - 1)
                              Divider(
                                height: 1,
                                indent: 44,
                                endIndent: 12,
                                color: baseBorder,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (dropHighlight)
              Positioned.fill(
                child: Container(
                  color: dayGrad[0].withOpacity(0.1),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: dayGrad[0],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Buraya Bırak',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (!_editMode) {
      return KeyedSubtree(
        key: _daySectionKeys[weekday],
        child: card(dropHighlight: false),
      );
    }

    return KeyedSubtree(
      key: _daySectionKeys[weekday],
      child: DragTarget<_DraggedProgramTask>(
        hitTestBehavior: HitTestBehavior.opaque,
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) async {
          await _moveTaskToIndex(
            fromWeekday: d.data.fromWeekday,
            toWeekday: weekday,
            task: d.data.task,
            toIndex: tasks.length,
          );
          HapticFeedback.lightImpact();
        },
        builder: (context, candidates, _) =>
            card(dropHighlight: candidates.isNotEmpty),
      ),
    );
  }

  Widget _buildTaskRow({
    required int weekday,
    required StudyProgramTask task,
    required bool isDark,
    required bool compact,
  }) {
    final grad = _gradientForKind(task.kind);

    IconData kindIcon(String k) {
      switch (k) {
        case 'test': return Icons.quiz_rounded;
        case 'video': return Icons.play_circle_filled_rounded;
        case 'podcast': return Icons.podcasts_rounded;
        case 'tekrar': return Icons.restart_alt_rounded;
        case 'konu': return Icons.menu_book_rounded;
        default: return Icons.more_horiz_rounded;
      }
    }

    final lesson = task.lesson.trim();
    final topic = task.topic.trim();
    final primary = (lesson.isNotEmpty || topic.isNotEmpty)
        ? [if (lesson.isNotEmpty) lesson, if (topic.isNotEmpty) topic].join(' – ')
        : task.title;
    final secondary = (lesson.isNotEmpty || topic.isNotEmpty) ? task.title : (task.notes.trim());

    Widget content = Opacity(
      opacity: task.isCompleted ? 0.6 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _editMode
              ? () => _showTaskEditor(weekday: weekday, existing: task)
              : null,
          onLongPress: _editMode
              ? null
              : () {
                  HapticFeedback.heavyImpact();
                  _showTaskActions(weekday, task, isDark, grad);
                },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: compact ? 10 : 12,
            ),
            child: Row(
              children: [
                // Kind Icon (Static, Always there)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: grad.map((x) => x.withValues(alpha: 0.95)).toList(),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: grad[0].withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    kindIcon(task.kind),
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        primary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (secondary.trim().isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Modern Action Buttons (Tick & Delete)
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_editMode) ...[
                      _buildCompactAction(
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red.withOpacity(0.7),
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _deleteTask(weekday, task);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildCompactAction(
                      icon: task.isCompleted 
                          ? Icons.check_circle_rounded 
                          : Icons.check_circle_outline_rounded,
                      color: task.isCompleted ? Colors.green : (isDark ? Colors.white24 : Colors.black12),
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _toggleTaskCompletion(weekday, task);
                      },
                      filled: task.isCompleted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!_editMode) return content;

    return LongPressDraggable<_DraggedProgramTask>(
      data: _DraggedProgramTask(fromWeekday: weekday, task: task),
      onDragStarted: _onDragStarted,
      onDragUpdate: _onDragUpdate,
      onDragEnd: (_) => _onDragFinished(),
      onDraggableCanceled: (_, __) => _onDragFinished(),
      onDragCompleted: _onDragFinished,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Opacity(opacity: 0.96, child: content),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: content),
      child: content,
    );
  }

  Widget _buildCompactAction({
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color.withOpacity(0.12) : Colors.transparent,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  void _showTaskActions(int weekday, StudyProgramTask task, bool isDark, List<Color> grad) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A).withOpacity(0.95) : Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _buildModernActionCard(
                    icon: task.isCompleted ? Icons.radio_button_off_rounded : Icons.check_circle_rounded,
                    title: task.isCompleted ? "Yapılmadı Bitirilenlerden Kaldır" : "Görevi Bitirildi Olarak Seç",
                    desc: task.isCompleted ? "Görevi yapılacaklara geri taşı" : "Çalışmanı başarıyla bitirdiğini işaretle",
                    color: task.isCompleted ? Colors.amber : Colors.green,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _toggleTaskCompletion(weekday, task);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildModernActionCard(
                    icon: Icons.delete_forever_rounded,
                    title: "Görevi Programdan Sil",
                    desc: "Bu dersi programdan kalıcı olarak siler",
                    color: Colors.red,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteTask(weekday, task);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<StudyProgramTask> _sortedTasks(List<StudyProgramTask> tasks) {
    // Keep ordering stable even when times are missing/identical.
    final indexed = tasks.asMap().entries.toList();
    indexed.sort((a, b) {
      final ta = _timeToMinutes(a.value.start);
      final tb = _timeToMinutes(b.value.start);
      final c = ta.compareTo(tb);
      if (c != 0) return c;
      return a.key.compareTo(b.key); // stable tie-breaker
    });
    return indexed.map((e) => e.value).toList();
  }

  int _timeToMinutes(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h * 60) + m;
  }

  Widget _buildModernActionCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(isDark ? 0.25 : 0.15),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : AppColors.textSecondary)
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withOpacity(0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (color ?? (isDark ? Colors.white : Colors.black)).withOpacity(
          0.1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: color ?? (isDark ? Colors.white70 : Colors.black87),
          size: 20,
        ),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Color _colorForKind(String kind) {
    switch (kind) {
      case 'test':
        return AppColors.primaryBlue;
      case 'video':
        return const Color(0xFFF44336);
      case 'podcast':
        return const Color(0xFF8E24AA);
      case 'kart':
        return const Color(0xFFFF9800);
      case 'tekrar':
        return AppColors.gradientGreenStart;
      case 'konu':
      default:
        return AppColors.gradientTealStart;
    }
  }
}

class _TaskEditorSheet extends StatefulWidget {
  final StudyProgramTask? existing;
  final Color Function(String kind) colorForKind;
  final List<Color> Function(String kind) gradientForKind;
  const _TaskEditorSheet({
    required this.existing,
    required this.colorForKind,
    required this.gradientForKind,
  });

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  static const _kindOptions = <String>[
    'konu',
    'test',
    'tekrar',
    'video',
    'podcast',
    'kart',
    'diğer',
  ];

  late final TextEditingController _lessonController;
  late final TextEditingController _topicController;
  late final TextEditingController _taskController;
  late final TextEditingController _notesController;
  late String _selectedKind;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _lessonController = TextEditingController(text: e?.lesson ?? '');
    _topicController = TextEditingController(text: e?.topic ?? '');
    _taskController = TextEditingController(text: e?.title ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _selectedKind = (e?.kind.trim().isNotEmpty == true) ? e!.kind : 'konu';
    if (!_kindOptions.contains(_selectedKind)) _selectedKind = 'diğer';
  }

  @override
  void dispose() {
    _lessonController.dispose();
    _topicController.dispose();
    _taskController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  IconData _kindIcon(String k) {
    switch (k) {
      case 'test':
        return Icons.quiz_rounded;
      case 'video':
        return Icons.play_circle_filled_rounded;
      case 'podcast':
        return Icons.podcasts_rounded;
      case 'kart':
        return Icons.style_rounded;
      case 'tekrar':
        return Icons.restart_alt_rounded;
      case 'konu':
        return Icons.menu_book_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  String _fallbackTitle({required String kind, required String topic}) {
    switch (kind) {
      case 'test':
        return 'Test çöz';
      case 'tekrar':
        return 'Tekrar';
      case 'video':
        return 'Video izle';
      case 'podcast':
        return 'Podcast dinle';
      case 'kart':
        return 'Bilgi kartı bak';
      case 'konu':
        return 'Konu çalış';
      default:
        return topic.isNotEmpty ? topic : 'Görev';
    }
  }

  StudyProgramTask _buildTask() {
    final e = widget.existing;
    final lesson = _lessonController.text.trim();
    final topic = _topicController.text.trim();
    final notes = _notesController.text.trim();
    var title = _taskController.text.trim();
    if (title.isEmpty) {
      title = _fallbackTitle(kind: _selectedKind, topic: topic);
    }
    return StudyProgramTask(
      start: e?.start ?? '',
      end: e?.end ?? '',
      title: title,
      kind: _selectedKind,
      lesson: lesson,
      topic: topic,
      notes: notes,
      detail: e?.detail ?? '',
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isDark = false,
    int? minLines,
    int? maxLines,
    TextInputAction? textInputAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: (isDark ? Colors.white70 : AppColors.textSecondary)
                  .withValues(alpha: 0.8),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines ?? 1,
            textInputAction: textInputAction,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: (isDark ? Colors.white38 : AppColors.textLight),
              ),
              prefixIcon: Icon(
                icon,
                size: 20,
                color: isDark ? Colors.white38 : AppColors.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final e = widget.existing;
    final headerGrad = widget.gradientForKind(_selectedKind);
    final accentColor = widget.colorForKind(_selectedKind);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  28 + MediaQuery.of(context).viewInsets.bottom,
                ),
                children: [
                  // Modern Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: headerGrad,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_task_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e == null ? 'Yeni Görev Ekle' : 'Görevi Düzenle',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Programına özel çalışma ekle',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white38
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.white70
                                : AppColors.textPrimary,
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Live Preview Card (Glassmorphism look)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? accentColor.withOpacity(0.1)
                          : accentColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: accentColor.withOpacity(isDark ? 0.2 : 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: headerGrad),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _kindIcon(_selectedKind),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_lessonController.text.trim().isEmpty &&
                                        _topicController.text.trim().isEmpty)
                                    ? 'Ders – Konu'
                                    : [
                                        _lessonController.text.trim(),
                                        _topicController.text.trim(),
                                      ].where((e) => e.isNotEmpty).join(' – '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _taskController.text.trim().isEmpty
                                    ? 'Görev detayları buraya gelecek'
                                    : _taskController.text.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(isDark ? 0.1 : 0.8),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                ),
                            ],
                          ),
                          child: Text(
                            _selectedKind.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Kind Selection Label
                  Text(
                    'Çalışma Türü',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Modern Kind Selector (Dropdown)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _selectedKind,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isDark
                              ? Colors.white38
                              : AppColors.textSecondary,
                        ),
                        dropdownColor: isDark
                            ? const Color(0xFF0F172A)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedKind = val);
                        },
                        items: _kindOptions.map((k) {
                          final label = k == 'kart'
                              ? 'Bilgi Kartı'
                              : k[0].toUpperCase() + k.substring(1);
                          final color = widget.colorForKind(k);
                          return DropdownMenuItem<String>(
                            value: k,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _kindIcon(k),
                                    size: 16,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Form Fields
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _lessonController,
                          label: 'Ders',
                          hint: 'Örn: Tarih',
                          icon: Icons.book_rounded,
                          isDark: isDark,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _topicController,
                          label: 'Konu',
                          hint: 'Örn: Osmanlı',
                          icon: Icons.topic_rounded,
                          isDark: isDark,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _taskController,
                    label: 'Görev',
                    hint: 'Örn: Konu çalışması ve test',
                    icon: Icons.checklist_rounded,
                    isDark: isDark,
                    textInputAction: TextInputAction.done,
                    minLines: 1,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      if (e != null) ...[
                        Material(
                          color: Colors.red.withValues(
                            alpha: isDark ? 0.15 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => Navigator.pop(
                              context,
                              const _TaskEditorResult.delete(),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: headerGrad,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(
                                context,
                                _TaskEditorResult.save(_buildTask()),
                              ),
                              borderRadius: BorderRadius.circular(18),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      e == null
                                          ? Icons.add_rounded
                                          : Icons.check_rounded,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      e == null
                                          ? 'Programa Ekle'
                                          : 'Değişiklikleri Kaydet',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Programın her an güncellenebilir 🚀',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
