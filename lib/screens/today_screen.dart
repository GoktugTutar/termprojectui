import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/planner_model.dart';
import '../theme.dart';

const kWarning = Color(0xFFF2B14A);
const kDanger = Color(0xFFFF5C7A);
const _kHeaderToCardOffset = 114.0;

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '${mins}m';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  WeeklyPlan? _plan;
  bool _loading = true;
  String _today = '';
  final Map<int, int> _studiedMinutes = {}; // lessonId → minutes studied
  List<String> _missingChecklistDates = [];
  bool _todayChecklistSubmitted = false;
  bool _resolvingMissingChecklists = false;
  String _quickNote = '';
  Timer? _clockTimer;
  List<({String lessonName, String title, DateTime date, int daysLeft})>
  _upcomingDeadlines = [];

  @override
  void initState() {
    super.initState();
    _today = _todayStr();
    _clockTimer = Timer.periodic(Duration(minutes: 1), (_) {
      if (!mounted) return;
      final today = _todayStr();
      if (today != _today) {
        setState(() {
          _today = today;
          _studiedMinutes.clear();
        });
        _load();
        return;
      }
      setState(() {});
    });
    _load();

    final hour = AppTime.now().hour;
    if (hour >= 6 && hour < 12) {
      Future.delayed(Duration(milliseconds: 380), () async {
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        final lastAsked = prefs.getString('sleep_modal_date') ?? '';
        final today = AppTime.todayStr();
        if (lastAsked != today) _showSleepModal();
      });
    }
  }

  String _todayStr() => AppTime.todayStr();

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      Map<String, dynamic> data = await ApiClient.getWeekPlan();
      WeeklyPlan plan = WeeklyPlan.fromJson(data);
      // Auto-create if no plan, or today falls outside the plan's week
      final today = AppTime.now();
      bool needsNewPlan = plan.blocks.isEmpty;
      if (!needsNewPlan && plan.weekStart.isNotEmpty) {
        // Plan covers weekStart to weekStart+6 days
        final ws = DateTime.parse(plan.weekStart);
        final we = ws.add(Duration(days: 6));
        final todayDate = DateTime(today.year, today.month, today.day);
        needsNewPlan = todayDate.isBefore(ws) || todayDate.isAfter(we);
      }

      if (needsNewPlan) {
        data = await ApiClient.createWeeklyPlan();
        plan = WeeklyPlan.fromJson(data);
      }
      final status = await ApiClient.getChecklistStatus(_today);
      final missingDates = ((status['missingDates'] as List?) ?? [])
          .map((d) => d.toString())
          .toList();
      final todayLessonIds = plan.blocks
          .where((b) => b.date == _today)
          .map((b) => b.lessonId)
          .toSet();
      final loadedStudiedMinutes = <int, int>{};
      final cl = status['checklist'];
      final submitted = cl != null;
      if (cl != null) {
        // Pre-fill studied minutes from saved completedBlocks
        for (final item in ((cl as Map)['items'] as List? ?? [])) {
          final lid = (item['lessonId'] as num).toInt();
          final cb = (item['completedBlocks'] as num? ?? 0).toInt();
          if (todayLessonIds.contains(lid)) {
            loadedStudiedMinutes[lid] = cb * 30;
          }
        }
      }
      // Load upcoming deadlines
      try {
        final raw = await ApiClient.getLessons();
        final now = AppTime.now();
        final deadlines =
            <
              ({String lessonName, String title, DateTime date, int daysLeft})
            >[];
        for (final l in raw) {
          final lessonName = (l['name'] as String? ?? '');
          final dlList = (l['deadlines'] as List?) ?? [];
          for (final d in dlList) {
            final date = DateTime.tryParse(d['deadlineDate'] as String? ?? '');
            if (date == null) continue;
            final daysLeft = date
                .difference(DateTime(now.year, now.month, now.day))
                .inDays;
            if (daysLeft >= 0 && daysLeft <= 14) {
              deadlines.add((
                lessonName: lessonName,
                title: (d['title'] as String?) ?? '',
                date: date,
                daysLeft: daysLeft,
              ));
            }
          }
        }
        deadlines.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
        if (mounted) setState(() => _upcomingDeadlines = deadlines);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _plan = plan;
        _missingChecklistDates = missingDates;
        _todayChecklistSubmitted = submitted;
        _studiedMinutes
          ..clear()
          ..addAll(loadedStudiedMinutes);
        _loading = false;
      });
      if (missingDates.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _resolveMissingChecklists();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<ScheduledBlock> get _todayBlocks => _plan?.blocksForDate(_today) ?? [];

  List<ScheduledBlock> get _primaryTodayBlocks {
    final seen = <int>{};
    return _todayBlocks.where((b) => seen.add(b.lessonId)).toList();
  }

  List<ScheduledBlock> _primaryBlocksForDate(String date) {
    final seen = <int>{};
    return _blocksForDate(date).where((b) => seen.add(b.lessonId)).toList();
  }

  List<ScheduledBlock> _blocksForDate(String date) =>
      _plan?.blocksForDate(date) ?? [];

  int get _totalPlannedMinutes {
    final seen = <int>{};
    int total = 0;
    for (final b in _todayBlocks) {
      if (seen.add(b.lessonId)) {
        total +=
            _todayBlocks
                .where((bl) => bl.lessonId == b.lessonId)
                .fold(0, (s, bl) => s + bl.blockCount) *
            30;
      }
    }
    return total;
  }

  Set<int> get _todayLessonIds => _todayBlocks.map((b) => b.lessonId).toSet();

  int get _totalStudiedMinutes {
    final todayLessonIds = _todayLessonIds;
    return _studiedMinutes.entries
        .where((entry) => todayLessonIds.contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value);
  }

  int get _completedBlocks => (_totalStudiedMinutes / 30).floor();
  int get _totalBlocks => (_totalPlannedMinutes / 30).floor();

  double get _progress => _totalPlannedMinutes == 0
      ? 0
      : (_totalStudiedMinutes / _totalPlannedMinutes).clamp(0.0, 1.0);

  int _plannedMinutesForLesson(int lessonId) =>
      _todayBlocks
          .where((b) => b.lessonId == lessonId)
          .fold(0, (s, b) => s + b.blockCount) *
      30;

  int _plannedBlocksForLesson(int lessonId) => _todayBlocks
      .where((b) => b.lessonId == lessonId)
      .fold(0, (s, b) => s + b.blockCount);

  bool _hasReviewForLesson(int lessonId) =>
      _todayBlocks.any((b) => b.lessonId == lessonId && b.isReview);

  String _timeRangeForLesson(int lessonId) {
    final blocks = _todayBlocks.where((b) => b.lessonId == lessonId).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (blocks.isEmpty) return '';
    return '${blocks.first.startTime} - ${blocks.last.endTime}';
  }

  DateTime _parseDateStr(String date) {
    final parts = date.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  String _checklistTitleForDate(String date) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    final dt = _parseDateStr(date);
    return '${dt.day} ${months[dt.month - 1]} ${days[dt.weekday - 1]} checklist';
  }

  Future<void> _resolveMissingChecklists() async {
    if (_resolvingMissingChecklists || _missingChecklistDates.isEmpty) return;
    setState(() => _resolvingMissingChecklists = true);
    var savedAny = false;
    try {
      for (final date in List<String>.from(_missingChecklistDates)) {
        if (!mounted) return;
        final saved = await _showChecklistSubmitDialog(
          date: date,
          blocks: _blocksForDate(date),
        );
        if (!saved) break;
        savedAny = true;
      }
    } finally {
      if (mounted) setState(() => _resolvingMissingChecklists = false);
    }
    if (savedAny && mounted) await _load();
  }

  Future<void> _saveTodayChecklist() async {
    final saved = await _showChecklistSubmitDialog(
      date: _today,
      blocks: _todayBlocks,
      initialStudiedMinutes: _studiedMinutes,
    );
    if (saved && mounted) await _load();
  }

  Future<bool> _showChecklistSubmitDialog({
    required String date,
    required List<ScheduledBlock> blocks,
    Map<int, int>? initialStudiedMinutes,
  }) async {
    final uniqueBlocks = _primaryBlocksForDate(date);
    final completedMap = <int, int>{};
    for (final block in uniqueBlocks) {
      final planned = blocks
          .where((b) => b.lessonId == block.lessonId)
          .fold(0, (sum, b) => sum + b.blockCount);
      final minutes = initialStudiedMinutes?[block.lessonId] ?? 0;
      completedMap[block.lessonId] = (minutes / 30)
          .round()
          .clamp(0, planned)
          .toInt();
    }

    var stressLevel = 3;
    var fatigueLevel = 3;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _DialogIcon(icon: Icons.checklist_rounded),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _checklistTitleForDate(date),
                            style: TextStyle(
                              color: kText1,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: Icon(Icons.close_rounded, color: kText2),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    _ChecklistMetricSlider(
                      label: 'Stres',
                      value: stressLevel,
                      onChanged: (value) =>
                          setDialogState(() => stressLevel = value),
                    ),
                    SizedBox(height: 10),
                    _ChecklistMetricSlider(
                      label: 'Yorgunluk',
                      value: fatigueLevel,
                      onChanged: (value) =>
                          setDialogState(() => fatigueLevel = value),
                    ),
                    Divider(height: 28, color: kBorder),
                    if (uniqueBlocks.isEmpty)
                      _EmptyPanelState(
                        icon: Icons.event_available_outlined,
                        title: 'Planlanmış ders yok',
                        subtitle:
                            'Bu gün yalnızca günlük durum olarak kapanacak.',
                      )
                    else
                      ...uniqueBlocks.map((block) {
                        final planned = blocks
                            .where((b) => b.lessonId == block.lessonId)
                            .fold(0, (sum, b) => sum + b.blockCount);
                        final completed = completedMap[block.lessonId] ?? 0;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                block.lessonName,
                                style: TextStyle(
                                  color: kText1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '$completed / $planned blok tamamlandı',
                                style: TextStyle(color: kText2, fontSize: 12),
                              ),
                              Slider(
                                value: completed.toDouble(),
                                min: 0,
                                max: planned.toDouble(),
                                divisions: planned > 0 ? planned : 1,
                                label: completed.toString(),
                                activeColor: kAccent,
                                inactiveColor: kBorder,
                                onChanged: (value) => setDialogState(
                                  () => completedMap[block.lessonId] = value
                                      .round(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        final items = uniqueBlocks.map((block) {
                          final planned = blocks
                              .where((b) => b.lessonId == block.lessonId)
                              .fold(0, (sum, b) => sum + b.blockCount);
                          final completed = completedMap[block.lessonId] ?? 0;
                          return {
                            'lessonId': block.lessonId,
                            'plannedBlocks': planned,
                            'completedBlocks': completed,
                            'delayed': completed < planned,
                          };
                        }).toList();
                        try {
                          await ApiClient.submitChecklist(
                            date: date,
                            stressLevel: stressLevel,
                            fatigueLevel: fatigueLevel,
                            items: items,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceAll('Exception: ', ''),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.check_rounded, size: 18),
                      label: Text('Kaydet'),
                      style: FilledButton.styleFrom(
                        backgroundColor: kAccent,
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  void _showSleepModal() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('sleep_modal_date', AppTime.todayStr());
    });
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (_) => _SleepDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: kAccent)),
      );
    }

    final now = AppTime.now();
    final h = now.hour;
    final greet = h < 12
        ? 'Good morning'
        : h < 18
        ? 'Good afternoon'
        : 'Good evening';
    const dowLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dow = (now.weekday - 1) % 7;
    final kicker = '${dowLabels[dow]} · ${DateFormat('dd MMM').format(now)}';
    final total = _todayBlocks.length;
    final totalMins = _todayBlocks.fold(0, (s, b) => s + b.blockCount) * 30;
    final subtitle = total == 0
        ? 'No blocks today — a rest day.'
        : '$total block${total > 1 ? 's' : ''} · ${(totalMins / 60).toStringAsFixed(1)}h of focus';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: kAccent,
          backgroundColor: kSurface,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1180),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 110),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 860;
                          final left = _TodayLeftColumn(
                            kicker: kicker,
                            title: '$greet.',
                            subtitle: subtitle,
                            blocks: _primaryTodayBlocks,
                            deadlines: _upcomingDeadlines,
                            plannedBlocksForLesson: _plannedBlocksForLesson,
                            plannedMinutesForLesson: _plannedMinutesForLesson,
                            timeRangeForLesson: _timeRangeForLesson,
                            hasReviewForLesson: _hasReviewForLesson,
                            noteText: _quickNote,
                            onNoteChanged: (value) =>
                                setState(() => _quickNote = value),
                          );
                          final right = _ChecklistPanel(
                            blocks: _primaryTodayBlocks,
                            missingDates: _missingChecklistDates,
                            submitted: _todayChecklistSubmitted,
                            resolvingMissing: _resolvingMissingChecklists,
                            completedBlocks: _completedBlocks,
                            totalBlocks: _totalBlocks,
                            studiedMinutes: _totalStudiedMinutes,
                            plannedMinutes: _totalPlannedMinutes,
                            progress: _progress,
                            studiedMinutesForLesson: (lessonId) =>
                                _studiedMinutes[lessonId] ?? 0,
                            plannedMinutesForLesson: _plannedMinutesForLesson,
                            onMinutesChanged: (lessonId, value) => setState(
                              () => _studiedMinutes[lessonId] = value,
                            ),
                            onCompleteMissing: _resolveMissingChecklists,
                            onSaveChecklist: _saveTodayChecklist,
                          );

                          if (!wide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [left, SizedBox(height: 18), right],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 11, child: left),
                              SizedBox(width: 24),
                              Expanded(
                                flex: 9,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: _kHeaderToCardOffset,
                                  ),
                                  child: right,
                                ),
                              ),
                            ],
                          );
                        },
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
}

// ── Today dashboard layout ────────────────────────────────────────────────────

class _TodayLeftColumn extends StatelessWidget {
  const _TodayLeftColumn({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.blocks,
    required this.deadlines,
    required this.plannedBlocksForLesson,
    required this.plannedMinutesForLesson,
    required this.timeRangeForLesson,
    required this.hasReviewForLesson,
    required this.noteText,
    required this.onNoteChanged,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final List<ScheduledBlock> blocks;
  final List<({String lessonName, String title, DateTime date, int daysLeft})>
  deadlines;
  final int Function(int lessonId) plannedBlocksForLesson;
  final int Function(int lessonId) plannedMinutesForLesson;
  final String Function(int lessonId) timeRangeForLesson;
  final bool Function(int lessonId) hasReviewForLesson;
  final String noteText;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodayIdentityHeader(kicker: kicker, title: title, subtitle: subtitle),
        SizedBox(height: 22),
        _TodayToDoCard(
          blocks: blocks,
          plannedBlocksForLesson: plannedBlocksForLesson,
          plannedMinutesForLesson: plannedMinutesForLesson,
          timeRangeForLesson: timeRangeForLesson,
          hasReviewForLesson: hasReviewForLesson,
        ),
        SizedBox(height: 18),
        _ComingUpCard(deadlines: deadlines),
        SizedBox(height: 14),
        _QuickToolsRow(noteText: noteText, onNoteChanged: onNoteChanged),
      ],
    );
  }
}

class _TodayIdentityHeader extends StatelessWidget {
  const _TodayIdentityHeader({
    required this.kicker,
    required this.title,
    required this.subtitle,
  });

  final String kicker;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BitmojiSlot(),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker,
                style: TextStyle(
                  color: kText2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: kText1,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: kText2, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BitmojiSlot extends StatelessWidget {
  const _BitmojiSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kSurface,
        border: Border.all(color: kBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kAccent.withAlpha(28),
          ),
          child: Icon(Icons.person_outline_rounded, color: kAccent, size: 34),
        ),
      ),
    );
  }
}

class _TodayToDoCard extends StatelessWidget {
  const _TodayToDoCard({
    required this.blocks,
    required this.plannedBlocksForLesson,
    required this.plannedMinutesForLesson,
    required this.timeRangeForLesson,
    required this.hasReviewForLesson,
  });

  final List<ScheduledBlock> blocks;
  final int Function(int lessonId) plannedBlocksForLesson;
  final int Function(int lessonId) plannedMinutesForLesson;
  final String Function(int lessonId) timeRangeForLesson;
  final bool Function(int lessonId) hasReviewForLesson;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 210),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.task_alt_rounded,
            title: 'Bugün yapılacaklar',
          ),
          SizedBox(height: 14),
          if (blocks.isEmpty)
            _EmptyPanelState(
              icon: Icons.coffee_outlined,
              title: 'Rest day',
              subtitle: 'Bugün planlanmış çalışma bloğu yok.',
            )
          else
            ...List.generate(blocks.length, (i) {
              final block = blocks[i];
              return _TodayPlanItem(
                block: block,
                timeRange: timeRangeForLesson(block.lessonId),
                plannedBlocks: plannedBlocksForLesson(block.lessonId),
                plannedMinutes: plannedMinutesForLesson(block.lessonId),
                hasReview: hasReviewForLesson(block.lessonId),
                isLast: i == blocks.length - 1,
              );
            }),
        ],
      ),
    );
  }
}

class _TodayPlanItem extends StatelessWidget {
  const _TodayPlanItem({
    required this.block,
    required this.timeRange,
    required this.plannedBlocks,
    required this.plannedMinutes,
    required this.hasReview,
    required this.isLast,
  });

  final ScheduledBlock block;
  final String timeRange;
  final int plannedBlocks;
  final int plannedMinutes;
  final bool hasReview;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = lessonColor(block.lessonId);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        block.lessonName,
                        style: TextStyle(
                          color: kText1,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasReview) _MiniBadge(label: 'Review', color: kAccent),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '$timeRange · $plannedBlocks block${plannedBlocks > 1 ? 's' : ''} · ${_formatMinutes(plannedMinutes)}',
                  style: TextStyle(color: kText2, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickToolsRow extends StatelessWidget {
  const _QuickToolsRow({required this.noteText, required this.onNoteChanged});

  final String noteText;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimerToolCard(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withAlpha(170),
                builder: (_) => _TimerDialog(),
              );
            },
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _QuickToolCard(
            icon: Icons.edit_note_rounded,
            title: 'Notlar',
            subtitle: noteText.trim().isEmpty ? 'Not al' : 'Notu düzenle',
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withAlpha(170),
                builder: (_) =>
                    _NotesDialog(initialText: noteText, onSaved: onNoteChanged),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TimerToolCard extends StatelessWidget {
  const _TimerToolCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 136,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.timer_outlined,
                  color: kAccent.withAlpha(appTheme.isLight ? 180 : 210),
                  size: 78,
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saat',
                      style: TextStyle(
                        color: kText1,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Süre tut',
                      style: TextStyle(color: kText2, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}

class _QuickToolCard extends StatelessWidget {
  const _QuickToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 136,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: kAccent, size: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: kText1,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: kText2, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  const _ChecklistPanel({
    required this.blocks,
    required this.missingDates,
    required this.submitted,
    required this.resolvingMissing,
    required this.completedBlocks,
    required this.totalBlocks,
    required this.studiedMinutes,
    required this.plannedMinutes,
    required this.progress,
    required this.studiedMinutesForLesson,
    required this.plannedMinutesForLesson,
    required this.onMinutesChanged,
    required this.onCompleteMissing,
    required this.onSaveChecklist,
  });

  final List<ScheduledBlock> blocks;
  final List<String> missingDates;
  final bool submitted;
  final bool resolvingMissing;
  final int completedBlocks;
  final int totalBlocks;
  final int studiedMinutes;
  final int plannedMinutes;
  final double progress;
  final int Function(int lessonId) studiedMinutesForLesson;
  final int Function(int lessonId) plannedMinutesForLesson;
  final void Function(int lessonId, int value) onMinutesChanged;
  final VoidCallback onCompleteMissing;
  final VoidCallback onSaveChecklist;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 620),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(icon: Icons.checklist_rounded, title: 'Checklist'),
          SizedBox(height: 16),
          if (missingDates.isNotEmpty)
            _ChecklistBlockedState(
              missingDates: missingDates,
              resolving: resolvingMissing,
              onPressed: onCompleteMissing,
            )
          else ...[
            _ChecklistProgress(
              completedBlocks: completedBlocks,
              totalBlocks: totalBlocks,
              studiedMinutes: studiedMinutes,
              plannedMinutes: plannedMinutes,
              progress: progress,
            ),
            Divider(height: 32, color: kBorder),
            if (blocks.isEmpty)
              _EmptyPanelState(
                icon: submitted
                    ? Icons.task_alt_rounded
                    : Icons.event_available_outlined,
                title: submitted ? 'Submitted' : 'Bugün boş',
                subtitle: submitted
                    ? 'Bugünün checklisti kapatıldı.'
                    : 'Bugünü kapatmak için checklist submit edebilirsin.',
              )
            else
              ...List.generate(blocks.length, (i) {
                final block = blocks[i];
                final planned = plannedMinutesForLesson(block.lessonId);
                return _ChecklistLessonRow(
                  block: block,
                  studiedMinutes: studiedMinutesForLesson(block.lessonId),
                  plannedMinutes: planned,
                  isLast: i == blocks.length - 1,
                  enabled: !submitted,
                  onMinutesChanged: (value) =>
                      onMinutesChanged(block.lessonId, value),
                );
              }),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: submitted ? null : onSaveChecklist,
                icon: Icon(
                  submitted ? Icons.task_alt_rounded : Icons.check_rounded,
                  size: 18,
                ),
                label: Text(submitted ? 'Submitted' : 'Submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  disabledBackgroundColor: kBorder,
                  disabledForegroundColor: kText2,
                  padding: EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecklistBlockedState extends StatelessWidget {
  const _ChecklistBlockedState({
    required this.missingDates,
    required this.resolving,
    required this.onPressed,
  });

  final List<String> missingDates;
  final bool resolving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EmptyPanelState(
            icon: Icons.lock_clock_outlined,
            title: 'Önce eksik günler',
            subtitle:
                'Bugünün checklisti için aynı haftadaki önceki checklistleri tamamla.',
          ),
          SizedBox(height: 14),
          ...missingDates.map(
            (date) => Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kBorder.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_note_outlined, color: kAccent, size: 17),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      date,
                      style: TextStyle(
                        color: kText1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Spacer(),
          FilledButton.icon(
            onPressed: resolving ? null : onPressed,
            icon: resolving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kText1,
                    ),
                  )
                : Icon(Icons.checklist_rounded, size: 18),
            label: Text(resolving ? 'Açılıyor...' : 'Eksikleri doldur'),
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              disabledBackgroundColor: kBorder,
              padding: EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistProgress extends StatelessWidget {
  const _ChecklistProgress({
    required this.completedBlocks,
    required this.totalBlocks,
    required this.studiedMinutes,
    required this.plannedMinutes,
    required this.progress,
  });

  final int completedBlocks;
  final int totalBlocks;
  final int studiedMinutes;
  final int plannedMinutes;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CustomPaint(
            painter: _RingPainter(progress),
            child: Center(
              child: Text(
                totalBlocks > 0 ? '${(progress * 100).round()}%' : '-',
                style: TextStyle(
                  color: kText1,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatMinutes(studiedMinutes)} / ${_formatMinutes(plannedMinutes)}',
                style: TextStyle(
                  color: kText1,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '$completedBlocks / $totalBlocks blocks completed',
                style: TextStyle(color: kText2, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistLessonRow extends StatelessWidget {
  const _ChecklistLessonRow({
    required this.block,
    required this.studiedMinutes,
    required this.plannedMinutes,
    required this.isLast,
    required this.enabled,
    required this.onMinutesChanged,
  });

  final ScheduledBlock block;
  final int studiedMinutes;
  final int plannedMinutes;
  final bool isLast;
  final bool enabled;
  final ValueChanged<int> onMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final checked = plannedMinutes > 0 && studiedMinutes >= plannedMinutes;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Container(
        constraints: BoxConstraints(minHeight: 48),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: kBorder.withAlpha(60),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: checked ? kAccent.withAlpha(90) : kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: enabled ? 1 : 0.62,
                child: Text(
                  block.lessonName,
                  style: TextStyle(
                    color: kText1,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(width: 12),
            Checkbox(
              value: checked,
              activeColor: kAccent,
              side: BorderSide(color: kText2, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: enabled
                  ? (value) =>
                        onMinutesChanged(value == true ? plannedMinutes : 0)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: kAccent),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: kText1,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(34),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyPanelState extends StatelessWidget {
  const _EmptyPanelState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: kText2, size: 28),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: kText1, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: kText2, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerDialog extends StatefulWidget {
  const _TimerDialog();

  @override
  State<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<_TimerDialog> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final elapsed = _stopwatch.elapsed;
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }

  void _toggle() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _timer?.cancel();
        _timer = null;
      } else {
        _stopwatch.start();
        _timer ??= Timer.periodic(Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  void _reset() {
    setState(() {
      _stopwatch
        ..stop()
        ..reset();
      _timer?.cancel();
      _timer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _DialogIcon(icon: Icons.timer_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Saat',
                      style: TextStyle(
                        color: kText1,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: kText2),
                  ),
                ],
              ),
              SizedBox(height: 26),
              Center(
                child: Text(
                  _elapsedLabel,
                  style: TextStyle(
                    color: kText1,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: Icon(Icons.restart_alt_rounded, size: 18),
                      label: Text('Sıfırla'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kText1,
                        side: BorderSide(color: kBorder),
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(
                        _stopwatch.isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(_stopwatch.isRunning ? 'Duraklat' : 'Başlat'),
                      style: FilledButton.styleFrom(
                        backgroundColor: kAccent,
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
    );
  }
}

class _NotesDialog extends StatefulWidget {
  const _NotesDialog({required this.initialText, required this.onSaved});

  final String initialText;
  final ValueChanged<String> onSaved;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSaved(_controller.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _DialogIcon(icon: Icons.edit_note_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notlar',
                      style: TextStyle(
                        color: kText1,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: kText2),
                  ),
                ],
              ),
              SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 8,
                maxLines: 12,
                style: TextStyle(color: kText1, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Bugün için notlarını yaz...',
                  hintStyle: TextStyle(color: kText2),
                  filled: true,
                  fillColor: kBorder.withAlpha(60),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kAccent),
                  ),
                ),
              ),
              SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: Icon(Icons.check_rounded, size: 18),
                label: Text('Kaydet'),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogIcon extends StatelessWidget {
  const _DialogIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: kAccent.withAlpha(38),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: kAccent, size: 22),
    );
  }
}

class _ChecklistMetricSlider extends StatelessWidget {
  const _ChecklistMetricSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: TextStyle(color: kText1, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: value.toString(),
            activeColor: kAccent,
            inactiveColor: kBorder,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value/5',
            textAlign: TextAlign.end,
            style: TextStyle(color: kText2, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ── Sleep dialog ──────────────────────────────────────────────────────────────

class _SleepDialog extends StatelessWidget {
  const _SleepDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: kAccent.withAlpha(46),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bedtime_outlined, color: kAccent, size: 28),
            ),
            SizedBox(height: 14),
            Text(
              'Did you sleep well?',
              style: TextStyle(
                color: kText1,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'We use this to adjust today\'s session length only.',
              style: TextStyle(color: kText2, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kText1,
                      side: BorderSide(color: kBorder),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('No'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccent,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Yes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 34.0;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = kBorder
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = kAccent
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Coming up card ────────────────────────────────────────────────────────────

class _ComingUpCard extends StatelessWidget {
  const _ComingUpCard({required this.deadlines});

  final List<({String lessonName, String title, DateTime date, int daysLeft})>
  deadlines;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 250),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.event_note_outlined,
            title: 'Upcoming events',
          ),
          SizedBox(height: 14),
          if (deadlines.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _EmptyPanelState(
                icon: Icons.event_available_outlined,
                title: 'No upcoming events',
                subtitle: 'Yakındaki deadline veya etkinlik görünmüyor.',
              ),
            ),
          ...deadlines.map((d) {
            final Color urgencyColor;
            final String daysLabel;
            if (d.daysLeft == 0) {
              urgencyColor = kDanger;
              daysLabel = 'Today';
            } else if (d.daysLeft == 1) {
              urgencyColor = kDanger;
              daysLabel = 'Tomorrow';
            } else if (d.daysLeft <= 3) {
              urgencyColor = kWarning;
              daysLabel = 'in ${d.daysLeft}d';
            } else {
              urgencyColor = kText2;
              daysLabel = 'in ${d.daysLeft}d';
            }

            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: urgencyColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title.isNotEmpty ? d.title : d.lessonName,
                          style: TextStyle(
                            color: kText1,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          d.title.isNotEmpty ? d.lessonName : '',
                          style: TextStyle(color: kText2, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    daysLabel,
                    style: TextStyle(
                      color: urgencyColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
