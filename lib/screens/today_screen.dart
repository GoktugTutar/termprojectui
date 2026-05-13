import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/planner_model.dart';
import '../theme.dart';

const kWarning = Color(0xFFF2B14A);
const kDanger  = Color(0xFFFF5C7A);

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
  int _stressLevel = 2;
  int _fatigueLevel = 3;
  bool _submitting = false;
  bool _sleepAsked = false;
  List<({String lessonName, String title, DateTime date, int daysLeft})> _upcomingDeadlines = [];
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _today = _todayStr();
    _load();
    
    final hour = AppTime.now().hour;
    if (hour >= 6 && hour < 12) {
      Future.delayed(const Duration(milliseconds: 380), () async {
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        final lastAsked = prefs.getString('sleep_modal_date') ?? '';
        final today = AppTime.now().toIso8601String().substring(0, 10);
        if (lastAsked != today) _showSleepModal();
      });
    }
  }

  String _todayStr() => AppTime.now().toIso8601String().substring(0, 10);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      Map<String, dynamic> data = await ApiClient.getWeekPlan();
      WeeklyPlan plan = WeeklyPlan.fromJson(data);
      // Auto-create if no plan, or today falls outside the plan's week
      final today = AppTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);
      bool needsNewPlan = plan.blocks.isEmpty;
      if (!needsNewPlan && plan.weekStart.isNotEmpty) {
        // Plan covers weekStart to weekStart+6 days
        final ws = DateTime.parse(plan.weekStart);
        final we = ws.add(const Duration(days: 6));
        final todayDate = DateTime(today.year, today.month, today.day);
        needsNewPlan = todayDate.isBefore(ws) || todayDate.isAfter(we);
      }
      
      if (needsNewPlan) {
        data = await ApiClient.createWeeklyPlan();
        plan = WeeklyPlan.fromJson(data);
      }
      final todayBlocks = plan.blocksForDate(_today);
      final cl = await ApiClient.getChecklist(_today);
      if (cl != null) {
        _stressLevel = (cl['stressLevel'] as num? ?? 2).toInt();
        _fatigueLevel = (cl['fatigueLevel'] as num? ?? 3).toInt();
        // Pre-fill studied minutes from saved completedBlocks
        for (final item in (cl['items'] as List? ?? [])) {
          final lid = (item['lessonId'] as num).toInt();
          final cb = (item['completedBlocks'] as num? ?? 0).toInt();
          _studiedMinutes[lid] = cb * 30;
        }
      }
      // Load upcoming deadlines
      try {
        final raw = await ApiClient.getLessons();
        final now = AppTime.now();
        final deadlines = <({String lessonName, String title, DateTime date, int daysLeft})>[];
        for (final l in raw) {
          final lessonName = (l['name'] as String? ?? '');
          final dlList = (l['deadlines'] as List?) ?? [];
          for (final d in dlList) {
            final date = DateTime.tryParse(d['deadlineDate'] as String? ?? '');
            if (date == null) continue;
            final daysLeft = date.difference(DateTime(now.year, now.month, now.day)).inDays;
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

      // Load alerts
      try {
        final rawAlerts = await ApiClient.getFeedbackMessages();
        if (mounted) {
          setState(() => _alerts = rawAlerts
              .map((a) => a as Map<String, dynamic>)
              .toList());
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<ScheduledBlock> get _todayBlocks =>
      _plan?.blocksForDate(_today) ?? [];

  int get _totalPlannedMinutes {
    final seen = <int>{};
    int total = 0;
    for (final b in _todayBlocks) {
      if (seen.add(b.lessonId)) {
        total += _todayBlocks
            .where((bl) => bl.lessonId == b.lessonId)
            .fold(0, (s, bl) => s + bl.blockCount) * 30;
      }
    }
    return total;
  }

  int get _totalStudiedMinutes =>
      _studiedMinutes.values.fold(0, (a, b) => a + b);

  int get _completedBlocks => (_totalStudiedMinutes / 30).floor();
  int get _totalBlocks => (_totalPlannedMinutes / 30).floor();

  double get _progress => _totalPlannedMinutes == 0
      ? 0
      : (_totalStudiedMinutes / _totalPlannedMinutes).clamp(0.0, 1.0);

  void _showSleepModal() {
    setState(() => _sleepAsked = true);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('sleep_modal_date',
          AppTime.now().toIso8601String().substring(0, 10));
    });
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (_) => const _SleepDialog(),
    );
  }

  int _minutesToBlocks(int minutes) => (minutes / 30).round().clamp(0, 999);

  Future<void> _submitChecklist() async {
    final items = <Map<String, dynamic>>[];
    final seen = <int>{};
    for (final b in _todayBlocks) {
      if (seen.add(b.lessonId)) {
        final planned = _todayBlocks
            .where((bl) => bl.lessonId == b.lessonId)
            .fold(0, (s, bl) => s + bl.blockCount);
        final done = _minutesToBlocks(_studiedMinutes[b.lessonId] ?? 0);
        items.add({
          'lessonId': b.lessonId,
          'plannedBlocks': planned,
          'completedBlocks': done,
          'delayed': done == 0,
        });
      }
    }
    setState(() => _submitting = true);
    try {
      await ApiClient.submitChecklist(
        stressLevel: _stressLevel,
        fatigueLevel: _fatigueLevel,
        items: items,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kAccent)),
      );
    }

    final now = AppTime.now();
    final h = now.hour;
    final greet = h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
    const dowLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dow = (now.weekday - 1) % 7;
    final kicker = '${dowLabels[dow]} · ${DateFormat('dd MMM').format(now)}';
    final total = _todayBlocks.length;
    final totalMins = _todayBlocks.fold(0, (s, b) => s + b.blockCount) * 30;
    final subtitle = total == 0
        ? 'No blocks today — a rest day.'
        : '$total block${total > 1 ? 's' : ''} · ${(totalMins / 60).toStringAsFixed(1)}h of focus';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: kAccent,
          backgroundColor: kSurface,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _ScreenHeader(
                      kicker: kicker,
                      title: '$greet.',
                      subtitle: subtitle,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: _ProgressCard(
                        completedBlocks: _completedBlocks,
                        totalBlocks: _totalBlocks,
                        studiedMinutes: _totalStudiedMinutes,
                        plannedMinutes: _totalPlannedMinutes,
                        progress: _progress,
                      ),
                    ),
                  ),
                  if (_alerts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        child: _AlertBanner(alerts: _alerts),
                      ),
                    ),
                  if (_upcomingDeadlines.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        child: _ComingUpCard(deadlines: _upcomingDeadlines),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: Row(
                        children: [
                          const Text(
                            "Today's plan",
                            style: TextStyle(
                                color: kText1,
                                fontSize: 17,
                                fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Row(
                            children: const [
                              Text('Week',
                                  style: TextStyle(
                                      color: kAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Icon(Icons.chevron_right,
                                  color: kAccent, size: 14),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_todayBlocks.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: kSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorder),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.coffee_outlined,
                                  color: kText2, size: 28),
                              SizedBox(height: 8),
                              Text('Rest day',
                                  style: TextStyle(
                                      color: kText1,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(height: 4),
                              Text(
                                  'Step 0 lightened your week — enjoy the gap.',
                                  style:
                                      TextStyle(color: kText2, fontSize: 13),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final block = _todayBlocks[i];
                        final plannedMins = _todayBlocks
                            .where((bl) => bl.lessonId == block.lessonId)
                            .fold(0, (s, bl) => s + bl.blockCount) * 30;
                        return _BlockRow(
                          block: block,
                          studiedMinutes: _studiedMinutes[block.lessonId] ?? 0,
                          plannedMinutes: plannedMins,
                          onMinutesChanged: (v) => setState(
                              () => _studiedMinutes[block.lessonId] = v),
                        );
                      },
                      childCount: _todayBlocks.length,
                    ),
                  ),
                  if (_todayBlocks.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                        child: const Text(
                          "Tonight's check-in",
                          style: TextStyle(
                              color: kText1,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: _CheckInCard(
                          stress: _stressLevel,
                          fatigue: _fatigueLevel,
                          submitting: _submitting,
                          onStressChanged: (v) =>
                              setState(() => _stressLevel = v),
                          onFatigueChanged: (v) =>
                              setState(() => _fatigueLevel = v),
                          onSubmit: _submitChecklist,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ),
      ),
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
        padding: const EdgeInsets.all(24),
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
              child: const Icon(Icons.bedtime_outlined,
                  color: kAccent, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              'Did you sleep well?',
              style: TextStyle(
                  color: kText1,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'We use this to adjust today\'s session length only.',
              style: TextStyle(color: kText2, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kText1,
                      side: const BorderSide(color: kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Yes'),
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

// ── Screen header ─────────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.kicker,
    required this.title,
    required this.subtitle,
  });

  final String kicker;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker,
              style: const TextStyle(
                  color: kText2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  color: kText1,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(color: kText2, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Progress card ─────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
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

  String _fmtMins(int m) {
    if (m == 0) return '0m';
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '${min}m';
    if (min == 0) return '${h}h';
    return '${h}h ${min}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CustomPaint(
                  painter: _RingPainter(progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fmtMins(studiedMinutes),
                          style: const TextStyle(
                              color: kText1,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'studied',
                          style: const TextStyle(color: kText2, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _Stat(
                      label: 'Progress',
                      value: totalBlocks > 0
                          ? '${(progress * 100).round()}%'
                          : '—',
                      sub: 'of ${_fmtMins(plannedMinutes)} planned',
                    ),
                    Divider(height: 16, thickness: 0.5, color: kBorder),
                    _Stat(
                      label: 'Blocks',
                      value: '$completedBlocks / $totalBlocks',
                      sub: 'completed (30 min each)',
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Blocks completed breakdown
          if (totalBlocks > 0) ...[
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.5, color: kBorder),
            const SizedBox(height: 12),
            Row(
              children: List.generate(totalBlocks, (i) {
                final filled = i < completedBlocks;
                return Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: i < totalBlocks - 1 ? 3 : 0),
                    decoration: BoxDecoration(
                      color: filled ? kAccent : kBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedBlocks block${completedBlocks != 1 ? 's' : ''} done',
                  style: const TextStyle(color: kText2, fontSize: 11),
                ),
                Text(
                  '${totalBlocks - completedBlocks} remaining',
                  style: TextStyle(
                    color: completedBlocks >= totalBlocks ? kAccent : kText2,
                    fontSize: 11,
                    fontWeight: completedBlocks >= totalBlocks
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    const c = kText1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: kText2, fontSize: 11)),
            Text(sub,
                style: TextStyle(
                    color: kText2.withAlpha(128), fontSize: 12)),
          ],
        ),
        Text(value,
            style: TextStyle(
                color: c,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Block row ─────────────────────────────────────────────────────────────────

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.studiedMinutes,
    required this.plannedMinutes,
    required this.onMinutesChanged,
  });

  final ScheduledBlock block;
  final int studiedMinutes;
  final int plannedMinutes;
  final ValueChanged<int> onMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final color = lessonColor(block.lessonId);
    final planned = block.blockCount;
    final completedBlocks = (studiedMinutes / 30).round();
    final isFull = completedBlocks >= planned;
    final fillRatio = plannedMinutes == 0
        ? 0.0
        : (studiedMinutes / plannedMinutes).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFull ? kAccent.withAlpha(80) : kBorder,
          ),
        ),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${block.startTime} – ${block.endTime}',
                                style: const TextStyle(
                                    color: kText2,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '· $planned block${planned > 1 ? 's' : ''}',
                                style: TextStyle(
                                    color: kText2.withAlpha(160),
                                    fontSize: 12),
                              ),
                              if (block.isReview) ...[
                                const SizedBox(width: 6),
                                _Chip('REVIEW', kAccent),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            block.lessonName,
                            style: const TextStyle(
                              color: kText1,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Studied time display
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 14, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          studiedMinutes == 0 ? '—' : '${studiedMinutes}m',
                          style: TextStyle(
                            color: isFull ? kAccent : kText1,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'of ${plannedMinutes}m',
                          style: const TextStyle(
                              color: kText2, fontSize: 11),
                        ),
                        // block pip indicators
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(planned, (i) {
                            final done = i < completedBlocks;
                            return Container(
                              width: 8,
                              height: 8,
                              margin: EdgeInsets.only(
                                  left: i > 0 ? 3 : 0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done ? kAccent : kBorder,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fillRatio,
                  minHeight: 4,
                  backgroundColor: kBorder,
                  valueColor: AlwaysStoppedAnimation(
                    isFull ? kAccent : color,
                  ),
                ),
              ),
            ),
            // Minutes slider
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 13, color: kText2),
                  Expanded(
                    child: Slider(
                      value: studiedMinutes.toDouble(),
                      min: 0,
                      max: (plannedMinutes * 1.5).ceilToDouble(),
                      divisions: ((plannedMinutes * 1.5) / 10)
                          .ceil()
                          .clamp(1, 999),
                      activeColor: isFull ? kAccent : color,
                      inactiveColor: kBorder,
                      onChanged: (v) => onMinutesChanged(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${studiedMinutes}m',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: kText2,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
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
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Check-in card ─────────────────────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.stress,
    required this.fatigue,
    required this.submitting,
    required this.onStressChanged,
    required this.onFatigueChanged,
    required this.onSubmit,
  });

  final int stress;
  final int fatigue;
  final bool submitting;
  final ValueChanged<int> onStressChanged;
  final ValueChanged<int> onFatigueChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Stress · 1 calm – 5 overwhelmed',
              style: TextStyle(color: kText2, fontSize: 12),
            ),
          ),
          _ScaleRow(
              value: stress,
              onChanged: onStressChanged,
              warn: false),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Fatigue · 1 fresh – 5 drained',
              style: TextStyle(color: kText2, fontSize: 12),
            ),
          ),
          _ScaleRow(
              value: fatigue,
              onChanged: onFatigueChanged,
              warn: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: submitting ? null : onSubmit,
              style: OutlinedButton.styleFrom(
                foregroundColor: kText1,
                side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: kAccent, strokeWidth: 2))
                  : const Text('Submit check-in',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleRow extends StatelessWidget {
  const _ScaleRow({
    required this.value,
    required this.onChanged,
    required this.warn,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final accent = warn ? kWarning : kAccent;
    return Row(
      children: List.generate(5, (i) {
        final n = i + 1;
        final selected = n == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 38,
              margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
              decoration: BoxDecoration(
                color: selected ? accent.withAlpha(46) : kBorder,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? accent : Colors.transparent,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  '$n',
                  style: TextStyle(
                    color: selected ? accent : kText2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

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

// ── Alert banner ─────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alerts});

  final List<Map<String, dynamic>> alerts;

  Color _colorForType(String type) {
    switch (type) {
      case 'critical':
      case 'sinav_yakin':
        return const Color(0xFFFF5C7A);
      case 'warning':
      case 'asiri_yuk':
      case 'yuksek_stres':
      case 'hareketsizlik':
        return const Color(0xFFF2B14A);
      default:
        return kAccent;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'sinav_yakin':
        return Icons.warning_amber_rounded;
      case 'yuksek_stres':
        return Icons.sentiment_very_dissatisfied_outlined;
      case 'hareketsizlik':
        return Icons.bedtime_outlined;
      case 'asiri_yuk':
        return Icons.local_fire_department_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = alerts.first;
    final type = first['type']?.toString() ?? 'info';
    final message = first['message']?.toString() ?? '';
    final color = _colorForType(type);
    final icon = _iconForType(type);
    final extra = alerts.length - 1;

    return GestureDetector(
      onTap: () {
        // Navigate to Insights tab (index 3)
        // We use the root navigator to find MainScaffold and switch tab
        final scaffold = context.findAncestorStateOfType<State>();
        if (scaffold != null) {
          // sendPrompt not available here — user taps to insights manually
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (extra > 0)
                    Text(
                      '+$extra more alert${extra > 1 ? 's' : ''} · See Insights',
                      style: const TextStyle(
                          color: kText2, fontSize: 11),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Coming up card ────────────────────────────────────────────────────────────

class _ComingUpCard extends StatelessWidget {
  const _ComingUpCard({required this.deadlines});

  final List<({String lessonName, String title, DateTime date, int daysLeft})> deadlines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assignment_outlined, size: 14, color: kText2),
              SizedBox(width: 6),
              Text(
                'COMING UP',
                style: TextStyle(
                  color: kText2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
              padding: const EdgeInsets.only(bottom: 10),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title.isNotEmpty ? d.title : d.lessonName,
                          style: const TextStyle(
                            color: kText1,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          d.title.isNotEmpty ? d.lessonName : '',
                          style: const TextStyle(color: kText2, fontSize: 12),
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