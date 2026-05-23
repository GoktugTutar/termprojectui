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

BoxDecoration _quickActionDecoration({required bool secondary}) {
  final bg = secondary
      ? (appTheme.isLight ? Color(0xFFA78BFA) : Color(0xFF8A6CFF))
      : (appTheme.isLight ? Color(0xFF0B5A4D) : Color(0xFF123D38));
  final border = secondary
      ? (appTheme.isLight ? Color(0xFF6D55C8) : Color(0xFFA78BFA))
      : (appTheme.isLight ? Color(0xFF073C35) : Color(0xFF49E9FF));

  return BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: border.withAlpha(appTheme.isLight ? 150 : 190)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(appTheme.isLight ? 34 : 90),
        blurRadius: 12,
        offset: Offset(0, 6),
      ),
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
  const TodayScreen({super.key, this.onOpenInsights});

  final VoidCallback? onOpenInsights;

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
  String _aiMessage = ''; // ← ekle
  bool _aiMessageDismissed = false; // ← ekle
  String _quickNote = '';
  String _displayName = 'Öğrenci';
  String _gpaLabel = 'GPA -';
  String _termLabel = 'Dönem -';
  AvatarExpression _avatarExpression = AvatarExpression.normal;
  Timer? _clockTimer;
  bool _isLastDayOfWeek = false;
  bool _sleepAsked = false;
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
        ApiClient.getFeedbackMessages().catchError((_) => <String, dynamic>{}),
        ApiClient.getSleepStatus().catchError(
          (_) => <String, dynamic>{'asked': true},
        ),
      ]);
      Map<String, dynamic> data = parallelInit[0] as Map<String, dynamic>;
      final userData = Map<String, dynamic>.from(parallelInit[1] as Map);
      final raw = parallelInit[2] as List<dynamic>;
      final feedbackData = parallelInit[3] as Map<String, dynamic>;
      final aiMsg = feedbackData['aiMessage'] as String? ?? '';
      final displayName = _displayNameFromUser(userData);
      final gpaLabel = _gpaLabelFromUser(userData);
      final termLabel = _termLabelFromUser(userData);
      WeeklyPlan plan = WeeklyPlan.fromJson(data);
      final hasLessons = raw.isNotEmpty;
      final hasBusySlots = ((userData['busySlots'] as List?) ?? []).isNotEmpty;
      final canCreatePlan = hasLessons && hasBusySlots;
      final sleepStatus = parallelInit[4] as Map<String, dynamic>;
      _sleepAsked = sleepStatus['asked'] as bool? ?? false;

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
      final avatarExpression = _avatarExpressionFromChecklist(cl);
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
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _missingChecklistDates = missingDates;
        _todayChecklistSubmitted = submitted;
        _checklistDisabled = checklistDisabled;
        if (onboardingNotice != _onboardingNotice) _noticeDismissed = false;
        _onboardingNotice = onboardingNotice;

        _displayName = displayName;
        _gpaLabel = gpaLabel;
        _termLabel = termLabel;
        _avatarExpression = avatarExpression;
        _isLastDayOfWeek = isLastDayOfWeek;
        _upcomingEvents = events;
        _sleepAsked = sleepStatus['asked'] as bool? ?? false;
        if (aiMsg.isNotEmpty) {
          // ← ekle
          _aiMessage = aiMsg;
          _aiMessageDismissed = false;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _displayNameFromUser(Map<String, dynamic> userData) {
    final rawName = (userData['name'] ?? userData['fullName'])
        ?.toString()
        .trim();
    if (rawName != null && rawName.isNotEmpty) return rawName;

    final email = (userData['email'] as String? ?? '').trim();
    final prefix = email.split('@').first.trim();
    if (prefix.isNotEmpty) return prefix;
    return 'Öğrenci';
  }

  String _gpaLabelFromUser(Map<String, dynamic> userData) {
    final raw = userData['gpa'];
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString().replaceAll(',', '.') ?? '');
    if (value == null) return 'GPA -';

    var text = value.toStringAsFixed(2);
    if (text.endsWith('00')) {
      text = value.toStringAsFixed(0);
    } else if (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  String _termLabelFromUser(Map<String, dynamic> userData) {
    final term = userData['academicTerm']?.toString().trim();
    if (term == null || term.isEmpty) return 'Dönem -';
    return term;
  }

  AvatarExpression _avatarExpressionFromChecklist(dynamic checklist) {
    if (checklist is! Map) return AvatarExpression.normal;

    final stressLevel = (checklist['stressLevel'] as num?)?.toInt() ?? 3;
    final sleptWell = checklist['sleptWell'] as bool?;

    if (stressLevel >= 4) return AvatarExpression.stressed;
    if (sleptWell == false) return AvatarExpression.sleepy;
    return AvatarExpression.normal;
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

  String _checklistTitleForDate(String date) =>
      '${_formatDateLabel(date)} checklist';

  Future<void> _saveTodayChecklist() async {
    final saved = await _showChecklistSubmitDialog(
      date: _today,
      blocks: _todayBlocks,
      initialStudiedMinutes: _studiedMinutes,
    );
    if (!saved || !mounted) return;
    setState(() => _todayChecklistSubmitted = true);
    if (_isLastDayOfWeek) {
      _showWeeklyFeedbackPrompt();
    }
  }

  Future<void> _showWeeklyFeedbackPrompt() async {
    final goInsights = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        insetPadding: EdgeInsets.symmetric(horizontal: 28),
        contentPadding: EdgeInsets.fromLTRB(28, 26, 28, 10),
        actionsPadding: EdgeInsets.fromLTRB(20, 0, 20, 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Icon(Icons.rate_review_outlined, color: kAccent, size: 30),
        title: Text(
          'Haftanı değerlendir',
          textAlign: TextAlign.center,
          style: TextStyle(color: kText1, fontWeight: FontWeight.w900),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Sonra', style: TextStyle(color: kText2)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            child: Text('Analize git'),
          ),
        ],
      ),
    );

    if (goInsights == true && mounted) {
      widget.onOpenInsights?.call();
    }
  }

  Future<void> _reloadAfterMissingChecklistSaved() async {
    await _load();
    if (!mounted) return;
    if (AppTime.now().weekday == DateTime.sunday) {
      _showWeeklyFeedbackPrompt();
    }
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
                                  stressLevel: 3,
                                  fatigueLevel: 3,
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
                                displayName: _displayName,
                                gpaLabel: _gpaLabel,
                                termLabel: _termLabel,
                                avatarExpression: _avatarExpression,
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
                                      onMissingSaved:
                                          _reloadAfterMissingChecklistSaved,
                                      onSaveChecklist: _saveTodayChecklist,
                                    );
                              final right = checklistWidget;

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
          if (!_sleepAsked)
            Positioned(
              top: 14,
              right: 18,
              child: SizedBox(
                width: math.min(
                  520,
                  math.max(280, MediaQuery.sizeOf(context).width - 36),
                ),
                child: _SleepCard(
                  onAnswer: (sleptWell) async {
                    await ApiClient.submitSleep(sleptWell);
                    setState(() {
                      _sleepAsked = true;
                      if (!sleptWell &&
                          _avatarExpression != AvatarExpression.stressed) {
                        _avatarExpression = AvatarExpression.sleepy;
                      } else if (sleptWell) {
                        _avatarExpression = AvatarExpression.normal;
                      }
                    });
                  },
                ),
              ),
            ),
          if (_aiMessage.isNotEmpty && !_aiMessageDismissed)
            Positioned(
              bottom: 24,
              left: 18,
              right: 18,
              child: _AiMessageBanner(
                message: _aiMessage,
                onClose: () => setState(() => _aiMessageDismissed = true),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiMessageBanner extends StatelessWidget {
  const _AiMessageBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: kSurface.withAlpha(245),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: kAccent.withAlpha(34),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: kAccent, size: 15),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: kText1, fontSize: 13, height: 1.4),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: kText2, size: 16),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 28, minHeight: 28),
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
      constraints: BoxConstraints(minHeight: _kTodayPanelStackHeight),
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
    required this.displayName,
    required this.gpaLabel,
    required this.termLabel,
    required this.avatarExpression,
  });

  final String displayName;
  final String gpaLabel;
  final String termLabel;
  final AvatarExpression avatarExpression;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 80, top: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final identity = _TodayIdentityPanel(
            displayName: displayName,
            gpaLabel: gpaLabel,
            termLabel: termLabel,
          );

          if (compact) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarHeader(expression: avatarExpression),
                  SizedBox(width: 42),
                  Padding(
                    padding: EdgeInsets.only(top: 44),
                    child: SizedBox(width: 220, child: identity),
                  ),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarHeader(expression: avatarExpression),
              SizedBox(width: 58),
              Padding(
                padding: EdgeInsets.only(top: 48),
                child: SizedBox(width: 280, child: identity),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayIdentityPanel extends StatelessWidget {
  const _TodayIdentityPanel({
    required this.displayName,
    required this.gpaLabel,
    required this.termLabel,
  });

  final String displayName;
  final String gpaLabel;
  final String termLabel;

  @override
  Widget build(BuildContext context) {
    final metaColor = appTheme.isLight ? Color(0xFF48685F) : kText2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: kText1,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _IdentityMetaChip(label: gpaLabel, color: metaColor),
            Text(
              '|',
              style: TextStyle(
                color: metaColor.withAlpha(150),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            _IdentityMetaChip(label: termLabel, color: metaColor),
          ],
        ),
      ],
    );
  }
}

class _IdentityMetaChip extends StatelessWidget {
  const _IdentityMetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
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
          decoration: _quickActionDecoration(secondary: false),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.timer_outlined,
                  color: Colors.white.withAlpha(205),
                  size: 78,
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: _QuickActionArrow(
                  color: Colors.white.withAlpha(appTheme.isLight ? 135 : 170),
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
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Süre tut',
                      style: TextStyle(
                        color: Colors.white.withAlpha(190),
                        fontSize: 12,
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
          decoration: _quickActionDecoration(secondary: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  Spacer(),
                  _QuickActionArrow(color: Colors.white.withAlpha(160)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(195),
                      fontSize: 12,
                    ),
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

class _QuickActionArrow extends StatelessWidget {
  const _QuickActionArrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Icon(Icons.arrow_forward_rounded, color: color, size: 15),
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

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.onAnswer});
  final Future<void> Function(bool sleptWell) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text('😴', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dün iyi uyudun mu?',
              style: TextStyle(
                color: kText1,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8),
          _SleepButton(
            label: 'Evet',
            positive: true,
            onTap: () => onAnswer(true),
          ),
          SizedBox(width: 8),
          _SleepButton(
            label: 'Hayır',
            positive: false,
            onTap: () => onAnswer(false),
          ),
        ],
      ),
    );
  }
}

class _SleepButton extends StatefulWidget {
  const _SleepButton({
    required this.label,
    required this.positive,
    required this.onTap,
  });
  final String label;
  final bool positive;
  final VoidCallback onTap;

  @override
  State<_SleepButton> createState() => _SleepButtonState();
}

class _SleepButtonState extends State<_SleepButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.positive ? kAccent : kDanger;
    return GestureDetector(
      onTap: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              widget.onTap();
            },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(_loading ? 60 : 22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: _loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
