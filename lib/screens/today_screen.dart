import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/planner_model.dart';
import '../theme.dart';
import '../avatar_page.dart';

const kWarning = Color(0xFFF2B14A);
const kDanger = Color(0xFFFF5C7A);
const _kChecklistTopOffset = 54.0;
const _kTodayPanelStackHeight = 522.0;

BoxDecoration _keycapDecoration({
  Color? color,
  Color? borderColor,
  double radius = 8,
  bool pressed = false,
}) {
  final light = appTheme.isLight;
  final shadow = light
      ? Colors.black.withAlpha(185)
      : Colors.black.withAlpha(210);
  final ambient = light
      ? Colors.black.withAlpha(28)
      : Colors.black.withAlpha(72);

  return BoxDecoration(
    color: color ?? kSurface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? (light ? kText1.withAlpha(180) : kBorder),
      width: 1.6,
    ),
    boxShadow: pressed
        ? [BoxShadow(color: shadow, blurRadius: 0, offset: Offset(3, 3))]
        : [
            BoxShadow(color: shadow, blurRadius: 0, offset: Offset(8, 8)),
            BoxShadow(color: ambient, blurRadius: 16, offset: Offset(0, 8)),
          ],
  );
}

String _formatDateLabel(String date) {
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
  final parts = date.split('-').map(int.parse).toList();
  final dt = DateTime(parts[0], parts[1], parts[2]);
  return '${dt.day} ${months[dt.month - 1]} ${days[dt.weekday - 1]}';
}

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
  bool _checklistDisabled = false;
  String? _onboardingNotice;
  bool _noticeDismissed = false;
  String _quickNote = '';
  double _sleepScore = 7;
  double _fatigueScore = 3;
  double _stressScore = 3;
  Timer? _clockTimer;
  bool _isLastDayOfWeek = false;
  bool _weeklyFeedbackSubmitted = false;
  List<({String id, String lessonName})> _feedbackLessons = [];
  List<
    ({
      String lessonName,
      String title,
      DateTime date,
      int daysLeft,
      bool isExam,
    })
  >
  _upcomingEvents = [];

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
      // Fetch week plan and lessons in parallel; lessons must be known before plan
      // creation to avoid generating an empty plan on first login (no courses yet).
      final parallelInit = await Future.wait([
        ApiClient.getWeekPlan(),
        ApiClient.getMe(),
        ApiClient.getLessons().catchError((_) => <dynamic>[]),
      ]);
      Map<String, dynamic> data = parallelInit[0] as Map<String, dynamic>;
      final userData = Map<String, dynamic>.from(parallelInit[1] as Map);
      final raw = parallelInit[2] as List<dynamic>;
      WeeklyPlan plan = WeeklyPlan.fromJson(data);
      final hasLessons = raw.isNotEmpty;
      final hasBusySlots = ((userData['busySlots'] as List?) ?? []).isNotEmpty;
      final canCreatePlan = hasLessons && hasBusySlots;

      final today = AppTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final currentWeekStart = todayDate.subtract(
        Duration(
          days: today.weekday == DateTime.sunday ? 6 : today.weekday - 1,
        ),
      );

      // Create a plan only when:
      // - the stored plan belongs to a past week, OR
      // - the plan is empty but the user now has lessons configured.
      // When no lessons exist yet (first login / setup phase), skip plan creation
      // so the user isn't asked for checklists before entering courses and busy times.
      bool needsNewPlan = false;
      if (plan.weekStart.isNotEmpty) {
        final ws = DateTime.parse(plan.weekStart);
        final planIsCurrentWeek = !ws.isBefore(currentWeekStart);
        needsNewPlan =
            canCreatePlan && (!planIsCurrentWeek || plan.blocks.isEmpty);
        debugPrint(
          '[TODAY] plan.weekStart=${plan.weekStart} currentWeekStart=$currentWeekStart blocks=${plan.blocks.length} hasLessons=$hasLessons hasBusySlots=$hasBusySlots needsNewPlan=$needsNewPlan',
        );
      } else {
        needsNewPlan = canCreatePlan;
        debugPrint(
          '[TODAY] plan.weekStart is empty, hasLessons=$hasLessons hasBusySlots=$hasBusySlots needsNewPlan=$needsNewPlan',
        );
      }

      if (needsNewPlan) {
        data = await ApiClient.createWeeklyPlan();
        plan = WeeklyPlan.fromJson(data);
      }
      final status = await ApiClient.getChecklistStatus(_today);
      final checklistDisabled = status['checklistDisabled'] == true;
      final onboardingNotice = checklistDisabled
          ? (!canCreatePlan
                ? 'Lütfen derslerini ve busy time’larını gir. Bunları ekleyince bu hafta için programın hazırlanacak.'
                : (status['message']?.toString() ??
                      'İlk hafta adaptasyon haftası. Programın hazır; bu hafta checklist sunulmayacak.'))
          : null;

      final missingDates = checklistDisabled
          ? <String>[]
          : ((status['missingDates'] as List?) ?? [])
                .map((d) => d.toString())
                .toList();
      final todayLessonIds = plan.blocks
          .where((b) => b.date == _today)
          .map((b) => b.lessonId)
          .toSet();
      final loadedStudiedMinutes = <int, int>{};
      final cl = status['checklist'];
      final submitted = !checklistDisabled && cl != null;
      if (!checklistDisabled && cl != null) {
        for (final item in ((cl as Map)['items'] as List? ?? [])) {
          final lid = (item['lessonId'] as num).toInt();
          final cb = (item['completedBlocks'] as num? ?? 0).toInt();
          if (todayLessonIds.contains(lid)) {
            loadedStudiedMinutes[lid] = cb * 30;
          }
        }
      }
      final now = AppTime.now();
      final events =
          <
            ({
              String lessonName,
              String title,
              DateTime date,
              int daysLeft,
              bool isExam,
            })
          >[];
      for (final l in raw) {
        final lessonName = (l['name'] as String? ?? '');
        final examList = (l['exams'] as List?) ?? [];
        for (final e in examList) {
          final date = DateTime.tryParse(e['examDate'] as String? ?? '');
          if (date == null) continue;
          final daysLeft = date
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
          if (daysLeft >= 0 && daysLeft <= 60) {
            events.add((
              lessonName: lessonName,
              title: 'Exam',
              date: date,
              daysLeft: daysLeft,
              isExam: true,
            ));
          }
        }
        final dlList = (l['deadlines'] as List?) ?? [];
        for (final d in dlList) {
          final date = DateTime.tryParse(d['deadlineDate'] as String? ?? '');
          if (date == null) continue;
          final daysLeft = date
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
          if (daysLeft >= 0 && daysLeft <= 14) {
            events.add((
              lessonName: lessonName,
              title: (d['title'] as String?) ?? '',
              date: date,
              daysLeft: daysLeft,
              isExam: false,
            ));
          }
        }
      }
      events.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

      final isLastDayOfWeek = AppTime.now().weekday == DateTime.sunday;
      bool weeklyFeedbackSubmitted = false;
      if (isLastDayOfWeek && !checklistDisabled) {
        weeklyFeedbackSubmitted = await ApiClient.getWeeklyFeedbackStatus()
            .catchError((_) => false);
      }
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;
      setState(() {
        _plan = plan;
        _missingChecklistDates = missingDates;
        _todayChecklistSubmitted = submitted;
        _checklistDisabled = checklistDisabled;
        if (onboardingNotice != _onboardingNotice) _noticeDismissed = false;
        _onboardingNotice = onboardingNotice;

        _sleepScore = _readDoublePref(prefs, 'today_sleep_score', 7);
        _fatigueScore = _readDoublePref(prefs, 'today_fatigue_score', 3);
        _stressScore = _readDoublePref(prefs, 'today_stress_score', 3);
        _isLastDayOfWeek = isLastDayOfWeek;
        _weeklyFeedbackSubmitted = weeklyFeedbackSubmitted;
        _upcomingEvents = events;
        _feedbackLessons = raw
            .map(
              (l) => (
                id: (l['id'] as num).toString(),
                lessonName: l['name'] as String? ?? '',
              ),
            )
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  double _readDoublePref(SharedPreferences prefs, String key, double fallback) {
    final value = prefs.get(key);
    if (value is num) return value.toDouble();
    return fallback;
  }

  List<ScheduledBlock> get _todayBlocks => _plan?.blocksForDate(_today) ?? [];

  List<ScheduledBlock> get _primaryTodayBlocks {
    final seen = <int>{};
    return _todayBlocks.where((b) => seen.add(b.lessonId)).toList();
  }

  Future<void> _saveWellbeingValue(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
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

  String _checklistTitleForDate(String date) =>
      '${_formatDateLabel(date)} checklist';

  Future<void> _saveTodayChecklist() async {
    final saved = await _showChecklistSubmitDialog(
      date: _today,
      blocks: _todayBlocks,
      initialStudiedMinutes: _studiedMinutes,
    );
    if (saved && mounted) setState(() => _todayChecklistSubmitted = true);
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
    var saving = false;
    String? errorMsg;
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
                    if (errorMsg != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withAlpha(100),
                            ),
                          ),
                          child: Text(
                            errorMsg!,
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              setDialogState(() {
                                saving = true;
                                errorMsg = null;
                              });
                              final items = uniqueBlocks.map((block) {
                                final planned = blocks
                                    .where((b) => b.lessonId == block.lessonId)
                                    .fold(0, (sum, b) => sum + b.blockCount);
                                final completed =
                                    completedMap[block.lessonId] ?? 0;
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
                                setDialogState(() {
                                  saving = false;
                                  errorMsg = e.toString().replaceAll(
                                    'Exception: ',
                                    '',
                                  );
                                });
                              }
                            },
                      icon: saving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.check_rounded, size: 18),
                      label: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
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
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 110),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 860;
                              final topControls = _TodayTopControls(
                                sleepScore: _sleepScore,
                                fatigueScore: _fatigueScore,
                                stressScore: _stressScore,
                                onSleepChanged: (value) {
                                  setState(() => _sleepScore = value);
                                  _saveWellbeingValue(
                                    'today_sleep_score',
                                    value,
                                  );
                                },
                                onFatigueChanged: (value) {
                                  setState(() => _fatigueScore = value);
                                  _saveWellbeingValue(
                                    'today_fatigue_score',
                                    value,
                                  );
                                },
                                onStressChanged: (value) {
                                  setState(() => _stressScore = value);
                                  _saveWellbeingValue(
                                    'today_stress_score',
                                    value,
                                  );
                                },
                              );
                              final left = _TodayLeftColumn(
                                events: _upcomingEvents,
                                noteText: _quickNote,
                                onNoteChanged: (value) =>
                                    setState(() => _quickNote = value),
                              );
                              final checklistWidget = _checklistDisabled
                                  ? _FirstWeekChecklistPanel()
                                  : _ChecklistPanel(
                                      blocks: _primaryTodayBlocks,
                                      missingDates: _missingChecklistDates,
                                      dateLabel: kicker,
                                      todayDate: _today,
                                      submitted: _todayChecklistSubmitted,
                                      completedBlocks: _completedBlocks,
                                      totalBlocks: _totalBlocks,
                                      studiedMinutes: _totalStudiedMinutes,
                                      plannedMinutes: _totalPlannedMinutes,
                                      progress: _progress,
                                      studiedMinutesForLesson: (lessonId) =>
                                          _studiedMinutes[lessonId] ?? 0,
                                      plannedMinutesForLesson:
                                          _plannedMinutesForLesson,
                                      blocksForDate: _blocksForDate,
                                      onMinutesChanged: (lessonId, value) =>
                                          setState(
                                            () => _studiedMinutes[lessonId] =
                                                value,
                                          ),
                                      onMissingSaved: _load,
                                      onSaveChecklist: _saveTodayChecklist,
                                    );
                              final right =
                                  _isLastDayOfWeek && !_checklistDisabled
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        checklistWidget,
                                        SizedBox(height: 14),
                                        _WeeklyFeedbackCard(
                                          submitted: _weeklyFeedbackSubmitted,
                                          lessons: _feedbackLessons,
                                          onSubmitted: () {
                                            setState(
                                              () => _weeklyFeedbackSubmitted =
                                                  true,
                                            );
                                          },
                                        ),
                                      ],
                                    )
                                  : checklistWidget;

                              if (!wide) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _TodayGreetingTitle(title: '$greet.'),
                                    SizedBox(height: 18),
                                    topControls,
                                    SizedBox(height: 18),
                                    left,
                                    SizedBox(height: 18),
                                    right,
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _TodayGreetingTitle(title: '$greet.'),
                                  SizedBox(height: 18),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 11,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            topControls,
                                            SizedBox(height: 18),
                                            left,
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 24),
                                      Expanded(
                                        flex: 9,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            top: _kChecklistTopOffset,
                                          ),
                                          child: right,
                                        ),
                                      ),
                                    ],
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
          if (_onboardingNotice != null && !_noticeDismissed)
            Positioned(
              top: 14,
              right: 18,
              child: _TopRightNotice(
                message: _onboardingNotice!,
                onClose: () => setState(() => _noticeDismissed = true),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopRightNotice extends StatelessWidget {
  const _TopRightNotice({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 360),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: _keycapDecoration(
          color: kSurface.withAlpha(245),
          borderColor: kAccent.withAlpha(120),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, color: kAccent, size: 18),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: kText1,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            SizedBox(width: 6),
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: kText2, size: 16),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(width: 28, height: 28),
              tooltip: 'Kapat',
            ),
          ],
        ),
      ),
    );
  }
}

class _FirstWeekChecklistPanel extends StatelessWidget {
  const _FirstWeekChecklistPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 360),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _keycapDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.event_available_rounded,
            title: 'Bu hafta checklist yok',
          ),
          SizedBox(height: 18),
          _EmptyPanelState(
            icon: Icons.auto_awesome_rounded,
            title: 'Adaptasyon haftası',
            subtitle:
                'Bu ilk hafta programı tanıman için. Checklist gelecek haftadan itibaren açılacak.',
          ),
        ],
      ),
    );
  }
}

// ── Today dashboard layout ────────────────────────────────────────────────────

class _TodayTopControls extends StatelessWidget {
  const _TodayTopControls({
    required this.sleepScore,
    required this.fatigueScore,
    required this.stressScore,
    required this.onSleepChanged,
    required this.onFatigueChanged,
    required this.onStressChanged,
  });

  final double sleepScore;
  final double fatigueScore;
  final double stressScore;
  final ValueChanged<double> onSleepChanged;
  final ValueChanged<double> onFatigueChanged;
  final ValueChanged<double> onStressChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 80, top: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final wellbeing = _TodayWellbeingPanel(
            sleepScore: sleepScore,
            fatigueScore: fatigueScore,
            stressScore: stressScore,
            onSleepChanged: onSleepChanged,
            onFatigueChanged: onFatigueChanged,
            onStressChanged: onStressChanged,
          );

          if (compact) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarHeader(),
                  SizedBox(width: 24),
                  SizedBox(width: 180, child: wellbeing),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarHeader(),
              SizedBox(width: 34),
              SizedBox(width: 320, child: wellbeing),
            ],
          );
        },
      ),
    );
  }
}

class _TodayLeftColumn extends StatelessWidget {
  const _TodayLeftColumn({
    required this.events,
    required this.noteText,
    required this.onNoteChanged,
  });

  final List<
    ({
      String lessonName,
      String title,
      DateTime date,
      int daysLeft,
      bool isExam,
    })
  >
  events;
  final String noteText;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComingUpCard(events: events),
        SizedBox(height: 14),
        _QuickToolsRow(noteText: noteText, onNoteChanged: onNoteChanged),
      ],
    );
  }
}

class _TodayGreetingTitle extends StatelessWidget {
  const _TodayGreetingTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -72),
      child: Text(
        title,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: kText1,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TodayWellbeingPanel extends StatelessWidget {
  const _TodayWellbeingPanel({
    required this.sleepScore,
    required this.fatigueScore,
    required this.stressScore,
    required this.onSleepChanged,
    required this.onFatigueChanged,
    required this.onStressChanged,
  });

  final double sleepScore;
  final double fatigueScore;
  final double stressScore;
  final ValueChanged<double> onSleepChanged;
  final ValueChanged<double> onFatigueChanged;
  final ValueChanged<double> onStressChanged;

  @override
  Widget build(BuildContext context) {
    final safeSleepScore = sleepScore.isFinite ? sleepScore : 7.0;
    final safeFatigueScore = fatigueScore.isFinite ? fatigueScore : 3.0;
    final safeStressScore = stressScore.isFinite ? stressScore : 3.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _WellbeingBar(
          label: 'Uyku',
          valueText: '${safeSleepScore.toStringAsFixed(1)}h',
          value: safeSleepScore,
          min: 0,
          max: 10,
          divisions: 20,
          onChanged: onSleepChanged,
        ),
        SizedBox(height: 4),
        _WellbeingBar(
          label: 'Yorgunluk',
          valueText: '${safeFatigueScore.round()}/5',
          value: safeFatigueScore,
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: onFatigueChanged,
        ),
        SizedBox(height: 4),
        _WellbeingBar(
          label: 'Stres',
          valueText: '${safeStressScore.round()}/5',
          value: safeStressScore,
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: onStressChanged,
        ),
      ],
    );
  }
}

class _WellbeingBar extends StatelessWidget {
  const _WellbeingBar({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final railColor = appTheme.isLight
        ? kAccent.withAlpha(135)
        : Color(0xFF5B3FD6);
    final railGlow = appTheme.isLight
        ? kAccent.withAlpha(45)
        : Color(0xFF8A6CFF).withAlpha(90);
    final bladeColor = appTheme.isLight ? Color(0xFF00A6C8) : Color(0xFF49E9FF);
    final safeMax = max > min ? max : min + 1;
    final safeValue = value.isFinite
        ? value.clamp(min, safeMax).toDouble()
        : min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: kText1,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            Spacer(),
            Text(
              valueText,
              style: TextStyle(
                color: kText2,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 3),
        SizedBox(
          height: 24,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const sideInset = 8.0;
              final usableWidth = math.max(1.0, constraints.maxWidth - 16);
              final normalized = ((safeValue - min) / (safeMax - min)).clamp(
                0.0,
                1.0,
              );

              void updateFromLocalPosition(Offset localPosition) {
                final raw = ((localPosition.dx - sideInset) / usableWidth)
                    .clamp(0.0, 1.0);
                var next = min + raw * (safeMax - min);
                if (divisions > 0) {
                  final step = (safeMax - min) / divisions;
                  next = min + ((next - min) / step).round() * step;
                }
                onChanged(next.clamp(min, safeMax).toDouble());
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) =>
                    updateFromLocalPosition(details.localPosition),
                onPanUpdate: (details) =>
                    updateFromLocalPosition(details.localPosition),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: sideInset,
                      right: sideInset,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: railGlow,
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: railColor.withAlpha(90),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: railColor.withAlpha(170),
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: sideInset,
                      child: Container(
                        width: 2,
                        height: 14,
                        decoration: BoxDecoration(
                          color: railColor.withAlpha(150),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: sideInset + normalized * usableWidth - 2,
                      child: Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: bladeColor,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: bladeColor.withAlpha(180),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: bladeColor.withAlpha(80),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
          decoration: _keycapDecoration(),
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
          decoration: _keycapDecoration(),
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
    required this.dateLabel,
    required this.todayDate,
    required this.submitted,
    required this.completedBlocks,
    required this.totalBlocks,
    required this.studiedMinutes,
    required this.plannedMinutes,
    required this.progress,
    required this.studiedMinutesForLesson,
    required this.plannedMinutesForLesson,
    required this.blocksForDate,
    required this.onMinutesChanged,
    required this.onMissingSaved,
    required this.onSaveChecklist,
  });

  final List<ScheduledBlock> blocks;
  final List<String> missingDates;
  final String dateLabel;
  final String todayDate;
  final bool submitted;
  final int completedBlocks;
  final int totalBlocks;
  final int studiedMinutes;
  final int plannedMinutes;
  final double progress;
  final int Function(int lessonId) studiedMinutesForLesson;
  final int Function(int lessonId) plannedMinutesForLesson;
  final List<ScheduledBlock> Function(String date) blocksForDate;
  final void Function(int lessonId, int value) onMinutesChanged;
  final Future<void> Function() onMissingSaved;
  final VoidCallback onSaveChecklist;

  @override
  Widget build(BuildContext context) {
    if (missingDates.isNotEmpty) {
      return _MissingChecklistTabsPanel(
        missingDates: missingDates,
        todayDate: todayDate,
        blocksForDate: blocksForDate,
        onSaved: onMissingSaved,
      );
    }

    return Container(
      constraints: BoxConstraints(minHeight: _kTodayPanelStackHeight),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _keycapDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PanelTitle(icon: Icons.checklist_rounded, title: 'Checklist'),
              Spacer(),
              Text(
                dateLabel,
                style: TextStyle(
                  color: kText2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
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
          SizedBox(height: 18),
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
      ),
    );
  }
}

class _MissingChecklistTabsPanel extends StatefulWidget {
  const _MissingChecklistTabsPanel({
    required this.missingDates,
    required this.todayDate,
    required this.blocksForDate,
    required this.onSaved,
  });

  final List<String> missingDates;
  final String todayDate;
  final List<ScheduledBlock> Function(String date) blocksForDate;
  final Future<void> Function() onSaved;

  @override
  State<_MissingChecklistTabsPanel> createState() =>
      _MissingChecklistTabsPanelState();
}

class _MissingChecklistTabsPanelState
    extends State<_MissingChecklistTabsPanel> {
  late String _activeDate;
  final Map<int, int> _studiedMinutes = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activeDate = widget.missingDates.first;
  }

  @override
  void didUpdateWidget(covariant _MissingChecklistTabsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.missingDates.contains(_activeDate)) {
      _activeDate = widget.missingDates.first;
      _studiedMinutes.clear();
      _error = null;
    }
  }

  List<String> get _tabs => [...widget.missingDates, widget.todayDate];

  int _plannedMinutesForLesson(List<ScheduledBlock> blocks, int lessonId) =>
      blocks
          .where((b) => b.lessonId == lessonId)
          .fold(0, (s, b) => s + b.blockCount) *
      30;

  Future<void> _submit() async {
    final blocks = widget.blocksForDate(_activeDate);
    final uniqueBlocks = <ScheduledBlock>[];
    final seen = <int>{};
    for (final block in blocks) {
      if (seen.add(block.lessonId)) uniqueBlocks.add(block);
    }
    final items = <Map<String, dynamic>>[];
    for (final block in uniqueBlocks) {
      final planned = blocks
          .where((b) => b.lessonId == block.lessonId)
          .fold(0, (sum, b) => sum + b.blockCount);
      final completedBlocks = ((_studiedMinutes[block.lessonId] ?? 0) / 30)
          .round()
          .clamp(0, planned)
          .toInt();
      if (items.any((item) => item['lessonId'] == block.lessonId)) continue;
      items.add({
        'lessonId': block.lessonId,
        'plannedBlocks': planned,
        'completedBlocks': completedBlocks,
        'delayed': completedBlocks < planned,
      });
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.submitChecklist(
        date: _activeDate,
        stressLevel: 3,
        fatigueLevel: 3,
        items: items,
      );
      if (!mounted) return;
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.blocksForDate(_activeDate);
    final uniqueBlocks = <ScheduledBlock>[];
    final seen = <int>{};
    for (final block in blocks) {
      if (seen.add(block.lessonId)) uniqueBlocks.add(block);
    }
    final isTodayTab = _activeDate == widget.todayDate;

    return Container(
      constraints: BoxConstraints(minHeight: _kTodayPanelStackHeight),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _keycapDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tabs.map((date) {
                final isToday = date == widget.todayDate;
                final enabled = !isToday;
                final selected = date == _activeDate;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: enabled
                        ? () => setState(() {
                            _activeDate = date;
                            _studiedMinutes.clear();
                            _error = null;
                          })
                        : null,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? kAccent.withAlpha(38)
                            : kBorder.withAlpha(45),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected ? kAccent : kBorder.withAlpha(120),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isToday
                                ? Icons.lock_outline_rounded
                                : Icons.event_note_outlined,
                            color: selected ? kAccent : kText2,
                            size: 13,
                          ),
                          SizedBox(width: 6),
                          Text(
                            isToday ? 'Bugün' : _formatDateLabel(date),
                            style: TextStyle(
                              color: selected ? kAccent : kText2,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 18),
          _PanelTitle(
            icon: Icons.checklist_rounded,
            title: isTodayTab
                ? 'Bugün kilitli'
                : '${_formatDateLabel(_activeDate)} checklist',
          ),
          SizedBox(height: 8),
          Text(
            isTodayTab
                ? 'Önce geçmiş günlerin checklistlerini doldurman gerekiyor.'
                : 'Bu günü kapatınca sıradaki eksik gün açılır.',
            style: TextStyle(color: kText2, fontSize: 12),
          ),
          Divider(height: 30, color: kBorder),
          if (blocks.isEmpty)
            _EmptyPanelState(
              icon: Icons.event_available_outlined,
              title: 'Bu gün boş',
              subtitle: 'Bu tarih için planlanmış çalışma bloğu yok.',
            )
          else
            ...List.generate(uniqueBlocks.length, (i) {
              final block = uniqueBlocks[i];
              final planned = _plannedMinutesForLesson(blocks, block.lessonId);
              return _ChecklistLessonRow(
                block: block,
                studiedMinutes: _studiedMinutes[block.lessonId] ?? 0,
                plannedMinutes: planned,
                isLast: i == uniqueBlocks.length - 1,
                enabled: true,
                onMinutesChanged: (value) =>
                    setState(() => _studiedMinutes[block.lessonId] = value),
              );
            }),
          if (_error != null) ...[
            SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: kDanger, fontSize: 12)),
          ],
          SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.check_rounded, size: 18),
              label: Text(_saving ? 'Kaydediliyor...' : 'Bu günü kaydet'),
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
    final color = lessonColor(block.lessonId);
    final blockLabel =
        '${block.blockCount} block${block.blockCount > 1 ? 's' : ''}';
    final durationLabel = _formatMinutes(block.blockCount * 30);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Opacity(
        opacity: enabled ? 1 : 0.62,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 5),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.lessonName,
                    style: TextStyle(
                      color: kText1,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${block.startTime} - ${block.endTime} · $blockLabel · $durationLabel',
                    style: TextStyle(
                      color: kText2,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
  const _ComingUpCard({required this.events});

  final List<
    ({
      String lessonName,
      String title,
      DateTime date,
      int daysLeft,
      bool isExam,
    })
  >
  events;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 250),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: _keycapDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.event_note_outlined,
            title: 'Upcoming events',
          ),
          SizedBox(height: 14),
          if (events.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _EmptyPanelState(
                icon: Icons.event_available_outlined,
                title: 'No upcoming events',
                subtitle: 'Yakındaki deadline veya etkinlik görünmüyor.',
              ),
            ),
          ...events.map((d) {
            final Color urgencyColor;
            String daysLabel;
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
            if (d.isExam && d.daysLeft > 1) {
              daysLabel = '${d.daysLeft}d to exam';
            } else if (d.isExam && d.daysLeft == 1) {
              daysLabel = 'Tomorrow exam';
            } else if (d.isExam) {
              daysLabel = 'Today exam';
            }
            final title = d.isExam
                ? '${d.lessonName} exam'
                : d.title.isNotEmpty
                ? d.title
                : d.lessonName;
            final subtitle = [
              if (!d.isExam && d.title.isNotEmpty) d.lessonName,
              DateFormat('dd MMM yyyy').format(d.date),
            ].join(' · ');

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
                          title,
                          style: TextStyle(
                            color: kText1,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
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

// ── Weekly Feedback Card ──────────────────────────────────────────────────────

class _WeeklyFeedbackCard extends StatefulWidget {
  const _WeeklyFeedbackCard({
    required this.submitted,
    required this.lessons,
    required this.onSubmitted,
  });

  final bool submitted;
  final List<({String id, String lessonName})> lessons;
  final VoidCallback onSubmitted;

  @override
  State<_WeeklyFeedbackCard> createState() => _WeeklyFeedbackCardState();
}

class _WeeklyFeedbackCardState extends State<_WeeklyFeedbackCard> {
  String? _weekload;
  late final Map<String, int> _perLesson;
  bool _saving = false;
  bool _expanded = false;

  static const _opts = [
    ('cok_yogundu', 'Çok yoğundu', Icons.sentiment_very_dissatisfied_outlined),
    ('tam_uygundu', 'Tam uygundu', Icons.sentiment_satisfied_outlined),
    (
      'yetersizdi',
      'Daha fazlasını yapabilirdim',
      Icons.sentiment_dissatisfied_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _perLesson = {for (final l in widget.lessons) l.id: 0};
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ApiClient.submitWeeklyFeedback(
        weekloadFeedback: _weekload ?? 'tam_uygundu',
        lessonFeedbacks: widget.lessons
            .map(
              (l) => {
                'lessonId': int.parse(l.id),
                'needsMoreTime': _perLesson[l.id] ?? 0,
              },
            )
            .toList(),
      );
      if (!mounted) return;
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: kDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.submitted) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF34C759),
              size: 20,
            ),
            SizedBox(width: 10),
            Text(
              'Haftalık geri bildirim gönderildi.',
              style: TextStyle(color: kText2, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(14),
              bottom: _expanded ? Radius.zero : Radius.circular(14),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: kAccent.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.rate_review_outlined,
                      color: kAccent,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haftalık değerlendirme',
                          style: TextStyle(
                            color: kText1,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Bu haftanı nasıl geçti?',
                          style: TextStyle(color: kText2, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: kText2,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, thickness: 0.5, color: kBorder),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'HAFTALIK YÜK',
                    style: TextStyle(
                      color: kText2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(height: 8),
                  ..._opts.map((opt) {
                    final (value, label, icon) = opt;
                    final selected = _weekload == value;
                    return GestureDetector(
                      onTap: _saving
                          ? null
                          : () => setState(() => _weekload = value),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 130),
                        margin: EdgeInsets.only(bottom: 6),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? kAccent.withAlpha(38)
                              : kBorder.withAlpha(60),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? kAccent : Colors.transparent,
                            width: selected ? 1.2 : 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 18,
                              color: selected ? kAccent : kText2,
                            ),
                            SizedBox(width: 10),
                            Text(
                              label,
                              style: TextStyle(
                                color: selected ? kText1 : kText2,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (widget.lessons.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(
                      'DERS BAZLI',
                      style: TextStyle(
                        color: kText2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...widget.lessons.map((l) {
                      final v = _perLesson[l.id] ?? 0;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.lessonName,
                                style: TextStyle(color: kText1, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            _NeedMoreTimeToggle(
                              value: v,
                              disabled: _saving,
                              onChanged: (nv) =>
                                  setState(() => _perLesson[l.id] = nv),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  SizedBox(height: 14),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccent,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Gönder',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NeedMoreTimeToggle extends StatelessWidget {
  const _NeedMoreTimeToggle({
    required this.value,
    required this.onChanged,
    required this.disabled,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleBtn(
          icon: Icons.remove_rounded,
          active: value == -1,
          activeColor: kDanger,
          disabled: disabled,
          onTap: () => onChanged(value == -1 ? 0 : -1),
        ),
        SizedBox(width: 4),
        SizedBox(
          width: 28,
          child: Center(
            child: Text(
              value == 0 ? '±0' : (value > 0 ? '+$value' : '$value'),
              style: TextStyle(
                color: value == 0 ? kText2 : (value > 0 ? kAccent : kDanger),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(width: 4),
        _ToggleBtn(
          icon: Icons.add_rounded,
          active: value == 1,
          activeColor: kAccent,
          disabled: disabled,
          onTap: () => onChanged(value == 1 ? 0 : 1),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.disabled,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final Color activeColor;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 120),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? activeColor.withAlpha(46) : kBorder.withAlpha(60),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Icon(icon, size: 15, color: active ? activeColor : kText2),
      ),
    );
  }
}
