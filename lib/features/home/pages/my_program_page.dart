import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/study_program.dart';
import '../../../core/services/study_program_service.dart';
import 'ai_assistant_page.dart';

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
  bool _editMode = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  late final Map<int, GlobalKey> _daySectionKeys;
  Timer? _autoScrollTimer;
  Offset? _lastDragGlobalPosition;
  int _activeWeekday = DateTime.now().weekday;
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
    _daySectionKeys = {for (var i = 1; i <= 7; i++) i: GlobalKey()};
    _load();
    _programSubscription = StudyProgramService.instance.onProgramUpdated.listen(
      (_) {
        if (mounted && !_editMode) _load();
      },
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final program = await StudyProgramService.instance.getProgram();
    if (!mounted) return;
    setState(() {
      _program = program;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await StudyProgramService.instance.clearProgram();
    await _load();
  }

  Future<void> _saveProgram(StudyProgram program) async {
    // Optimistic UI update.
    setState(() => _program = program);
    try {
      await StudyProgramService.instance.saveProgram(program);
    } catch (_) {
      // Ignore persistence failures for now; UI already updated.
    }
  }

  List<Color> _gradientForKind(String kind) {
    switch (kind) {
      case 'test':
        return const [AppColors.gradientBlueStart, AppColors.gradientBlueEnd];
      case 'video':
        return const [AppColors.gradientRedStart, AppColors.gradientRedEnd];
      case 'podcast':
        return const [
          AppColors.gradientPurpleStart,
          AppColors.gradientPurpleEnd,
        ];
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

  List<Color> _gradientForWeekday(int weekday) {
    switch (weekday) {
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

  Future<void> _createEmptyProgramAndEnterEdit() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final program = StudyProgram(
      createdAtMillis: now,
      title: 'Programım',
      subtitle: 'Manuel haftalık plan',
      days: const <StudyProgramDay>[],
    );
    setState(() {
      _program = program;
      _editMode = true;
    });
    await _saveProgram(program);
  }

  Future<void> _confirmClearProgram() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Programı Sil'),
        content: const Text('Kaydedilmiş program silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) await _clear();
  }

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
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
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

  Future<void> _scrollToWeekday(int weekday) async {
    setState(() => _activeWeekday = weekday);
    final ctx = _daySectionKeys[weekday]?.currentContext;
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
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 460;
                      final aiBtn = FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AiAssistantPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('AI ile program oluştur'),
                      );
                      final manualBtn = OutlinedButton.icon(
                        onPressed: _createEmptyProgramAndEnterEdit,
                        icon: const Icon(Icons.edit_calendar_rounded),
                        label: const Text('Manuel program oluştur'),
                      );

                      if (wide) {
                        return Row(
                          children: [
                            Expanded(child: aiBtn),
                            const SizedBox(width: 10),
                            Expanded(child: manualBtn),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          SizedBox(width: double.infinity, child: aiBtn),
                          const SizedBox(height: 10),
                          SizedBox(width: double.infinity, child: manualBtn),
                        ],
                      );
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

            return ListView(
              key: _listKey,
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 10, bottom: 24),
              children: [
                _buildHeader(
                  program: program,
                  isDark: isDark,
                  isCompact: isCompact,
                  totalTasks: totalTasks,
                  activeDays: activeDays,
                  horizontalPadding: horizontal,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.only(left: horizontal),
                  child: _buildWeekStrip(
                    program: program,
                    isDark: isDark,
                    isCompact: isCompact,
                  ),
                ),
                const SizedBox(height: 16),
                if (_editMode) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: _buildEditHint(isDark),
                  ),
                  const SizedBox(height: 10),
                ],
                ..._buildWeekSections(
                  program: program,
                  isDark: isDark,
                  compact: isCompact,
                ),
                const SizedBox(height: 4),
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

  Widget _buildWeekStrip({
    required StudyProgram program,
    required bool isDark,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                'Haftalık Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (_editMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gradientTealStart.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'DÜZENLEME MODU',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gradientTealStart,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          child: Row(
            children: List.generate(7, (i) {
              final weekday = i + 1;
              final date = weekStart.add(Duration(days: i));
              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isActive = weekday == _activeWeekday;
              final tasks = _tasksForWeekday(program, weekday);
              final grad = _gradientForWeekday(weekday);

              return Padding(
                padding: EdgeInsets.only(right: i == 6 ? 0 : 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _scrollToWeekday(weekday);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutQuint,
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 6),
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
                            shortNames[weekday] ?? '',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: isToday
                                  ? Colors.white.withOpacity(0.8)
                                  : (isDark ? Colors.white54 : Colors.black45),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
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
        ),
      ],
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
    final title = program.title.trim().isEmpty
        ? 'Programım'
        : program.title.trim();
    final subtitle = program.subtitle.trim().isEmpty
        ? 'Haftalık plan'
        : program.subtitle.trim();
    final progress = (activeDays / 7.0).clamp(0.0, 1.0);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white70 : AppColors.textSecondary;

    Widget chip({
      required IconData icon,
      required String text,
      required List<Color> gradient,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
                color: textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: _editMode
                    ? Icons.check_rounded
                    : Icons.mode_edit_outline_rounded,
                tooltip: _editMode ? 'Bitti' : 'Planı Düzenle',
                isDark: isDark,
                onPressed: () => setState(() => _editMode = !_editMode),
                isPrimary: _editMode,
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.delete_sweep_rounded,
                tooltip: 'Tümünü Temizle',
                isDark: isDark,
                onPressed: _confirmClearProgram,
                isPrimary: false,
                colorOverride: Colors.red.withOpacity(0.1),
                iconColorOverride: Colors.red.shade400,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildProgressBlock(
            isDark: isDark,
            textSecondary: textSecondary,
            progress: progress,
            totalTasks: totalTasks,
            activeDays: activeDays,
            chip: chip, // Pass the chip function
            horizontalPadding: horizontalPadding,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBlock({
    required bool isDark,
    required Color textSecondary,
    required double progress,
    required int totalTasks,
    required int activeDays,
    required Widget Function({
      required IconData icon,
      required String text,
      required List<Color> gradient,
    })
    chip,
    required double horizontalPadding,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: chip(
                icon: Icons.checklist_rounded,
                text: '$totalTasks Görev',
                gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: chip(
                icon: Icons.calendar_today_rounded,
                text: '$activeDays/7 Gün',
                gradient: [const Color(0xFF10B981), const Color(0xFF3B82F6)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Haftalık İlerleme',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? AppColors.gradientTealStart
                        : AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(3),
              ),
              child: UnconstrainedBox(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  height: 6,
                  width:
                      (MediaQuery.of(context).size.width -
                          (MediaQuery.of(context).size.width > 860
                              ? (MediaQuery.of(context).size.width - 860)
                              : 32)) *
                      progress,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.gradientTealStart,
                        AppColors.gradientBlueEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gradientTealStart.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
    bool isPrimary = false,
    Color? colorOverride,
    Color? iconColorOverride,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: isPrimary
            ? const LinearGradient(
                colors: [
                  AppColors.gradientTealStart,
                  AppColors.gradientBlueEnd,
                ],
              )
            : null,
        color:
            colorOverride ??
            (isPrimary
                ? null
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.white)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? Colors.transparent
              : (isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05)),
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? AppColors.gradientTealStart.withOpacity(0.2)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color:
              iconColorOverride ??
              (isPrimary
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87)),
          size: 19,
        ),
      ),
    );
  }

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

  List<Widget> _buildWeekSections({
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

    StudyProgramDay? dayForWeekday(int weekday) {
      for (final d in program.days) {
        if (d.weekday == weekday) return d;
      }
      return null;
    }

    final widgets = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final weekday = i + 1;
      final date = weekStart.add(Duration(days: i));
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      final tasks = _sortedTasks(
        dayForWeekday(weekday)?.tasks ?? const <StudyProgramTask>[],
      );
      final isActive = weekday == _activeWeekday;

      widgets.add(
        _buildDaySection(
          weekday: weekday,
          dayTitle: longNames[weekday] ?? '',
          dateLabel: '${date.day} ${_formatMonth(date.month)}',
          isToday: isToday,
          isActive: isActive,
          tasks: tasks,
          isDark: isDark,
          compact: compact,
        ),
      );
      // Removed spacing: if (i != 6) widgets.add(const SizedBox(height: 4));
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
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          dayTitle.characters.first,
                          style: const TextStyle(
                            fontSize: 14,
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
                      if (_editMode) ...[
                        const SizedBox(width: 8),
                        _buildIconButton(
                          icon: Icons.add_circle_outline_rounded,
                          onPressed: () => _showTaskEditor(weekday: weekday),
                          isDark: isDark,
                          color: dayGrad[0],
                        ),
                      ],
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
                            _buildTaskRow(
                              weekday: weekday,
                              task: tasks[i],
                              isDark: isDark,
                              compact: compact,
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
    final c = _colorForKind(task.kind);

    IconData kindIcon(String k) {
      switch (k) {
        case 'test':
          return Icons.quiz_rounded;
        case 'video':
          return Icons.play_circle_filled_rounded;
        case 'podcast':
          return Icons.podcasts_rounded;
        case 'tekrar':
          return Icons.restart_alt_rounded;
        case 'konu':
          return Icons.menu_book_rounded;
        default:
          return Icons.more_horiz_rounded;
      }
    }

    final lesson = task.lesson.trim();
    final topic = task.topic.trim();
    final primary = (lesson.isNotEmpty || topic.isNotEmpty)
        ? [
            if (lesson.isNotEmpty) lesson,
            if (topic.isNotEmpty) topic,
          ].join(' – ')
        : task.title;
    final secondary = (lesson.isNotEmpty || topic.isNotEmpty)
        ? task.title
        : (task.notes.trim());

    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _editMode
            ? () => _showTaskEditor(weekday: weekday, existing: task)
            : null,
        onLongPress: () {
          HapticFeedback.heavyImpact();
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black26,
            isScrollControlled: true,
            builder: (context) => Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withOpacity(0.9)
                    : Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.1,
                  ),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 30,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: grad),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: grad[0].withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                kindIcon(task.kind),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    primary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    "Görev İşlemleri",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          (isDark
                                                  ? Colors.white
                                                  : AppColors.textSecondary)
                                              .withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildModernActionCard(
                          icon: task.isCompleted
                              ? Icons.undo_rounded
                              : Icons.check_circle_rounded,
                          title: task.isCompleted ? "Geri Al" : "Tamamla",
                          desc: task.isCompleted
                              ? "Görevi yapılacaklara geri taşı"
                              : "Çalışmanı başarıyla bitirdiğini işaretle",
                          color: task.isCompleted ? Colors.amber : Colors.green,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(context);
                            _toggleTaskCompletion(weekday, task);
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildModernActionCard(
                          icon: Icons.delete_forever_rounded,
                          title: "Görevi Kaldır",
                          desc: "Bu dersi programdan kalıcı olarak siler",
                          color: Colors.red,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(context);
                            _deleteTask(weekday, task);
                          },
                        ),
                        SizedBox(height: MediaQuery.of(context).padding.bottom),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        splashColor: c.withValues(alpha: isDark ? 0.18 : 0.10),
        highlightColor: c.withValues(alpha: isDark ? 0.10 : 0.06),
        child: Opacity(
          opacity: task.isCompleted ? 0.5 : 1.0,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: compact ? 8 : 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: task.isCompleted
                          ? [Colors.grey, Colors.grey.withOpacity(0.5)]
                          : [
                              grad[0].withValues(alpha: 0.95),
                              grad[1].withValues(alpha: 0.80),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (_editMode) ...[
                  Icon(
                    Icons.drag_indicator_rounded,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: task.isCompleted
                          ? [
                              Colors.grey.withOpacity(0.6),
                              Colors.grey.withOpacity(0.4),
                            ]
                          : grad.map((x) => x.withValues(alpha: 0.95)).toList(),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    task.isCompleted
                        ? Icons.check_rounded
                        : kindIcon(task.kind),
                    size: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
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
                            color: isDark
                                ? Colors.white54
                                : AppColors.textSecondary,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? Colors.grey.withOpacity(0.2)
                        : grad[0].withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: task.isCompleted
                          ? Colors.grey.withOpacity(0.3)
                          : grad[0].withValues(alpha: isDark ? 0.2 : 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    task.kind.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: task.isCompleted
                          ? Colors.grey
                          : (isDark ? grad[0].withValues(alpha: 0.9) : grad[0]),
                    ),
                  ),
                ),
                if (_editMode) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Sil',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteTask(weekday, task),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
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
        return const Color(0xFFE74C3C);
      case 'podcast':
        return AppColors.gradientPurpleStart;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final e = widget.existing;
    final headerGrad = widget.gradientForKind(_selectedKind);

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Colorful header (changes with selected kind)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      headerGrad[0].withValues(alpha: isDark ? 0.70 : 0.95),
                      headerGrad[1].withValues(alpha: isDark ? 0.55 : 0.88),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e == null ? 'Manuel görev ekle' : 'Görevi düzenle',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              // Live preview card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF171A1F)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: isDark ? 0.14 : 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: headerGrad),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _kindIcon(_selectedKind),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _taskController.text.trim().isEmpty
                                ? 'Görev'
                                : _taskController.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: headerGrad[0].withValues(
                          alpha: isDark ? 0.20 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: headerGrad[0].withValues(
                            alpha: isDark ? 0.25 : 0.20,
                          ),
                        ),
                      ),
                      child: Text(
                        _selectedKind,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white70
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Text(
                'Tür',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kindOptions.map((k) {
                  final active = _selectedKind == k;
                  final c = widget.colorForKind(k);
                  return ChoiceChip(
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    selected: active,
                    showCheckmark: false,
                    avatar: Icon(
                      _kindIcon(k),
                      size: 16,
                      color: active ? Colors.white : c.withValues(alpha: 0.95),
                    ),
                    label: Text(
                      k,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: active
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppColors.textPrimary),
                      ),
                    ),
                    selectedColor: c.withValues(alpha: 0.95),
                    backgroundColor: isDark
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFF8FAFC),
                    side: BorderSide(
                      color: c.withValues(alpha: active ? 0.0 : 0.28),
                    ),
                    onSelected: (_) => setState(() => _selectedKind = k),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lessonController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Ders',
                        hintText: 'Örn: Vatandaşlık',
                        prefixIcon: const Icon(Icons.book_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _topicController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Konu',
                        hintText: 'Örn: Temel Haklar',
                        prefixIcon: const Icon(Icons.topic_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextField(
                controller: _taskController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Görev',
                  hintText: 'Örn: Konu çalış / Test çöz / Tekrar',
                  prefixIcon: const Icon(Icons.checklist_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                textInputAction: TextInputAction.done,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  hintText: 'Örn: Yanlışları not al, 2 test daha çöz',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        _TaskEditorResult.save(_buildTask()),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: Text(e == null ? 'Ekle' : 'Kaydet'),
                    ),
                  ),
                  if (e != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const _TaskEditorResult.delete(),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Sil'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Not: Saat/dakika bilgisi programda gösterilmez.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
