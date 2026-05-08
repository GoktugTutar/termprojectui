import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
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
  final Set<int> _completedIds = {};
  int _stressLevel = 2;
  int _fatigueLevel = 3;
  bool _submitting = false;
  bool _sleepAsked = false;

  @override
  void initState() {
    super.initState();
    _today = _todayStr();
    _load();
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted && !_sleepAsked) _showSleepModal();
      });
    }
  }

  String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getWeekPlan();
      final plan = WeeklyPlan.fromJson(data);
      final todayBlocks = plan.blocksForDate(_today);
      for (final b in todayBlocks) {
        if (b.completed) _completedIds.add(b.id);
      }
      final cl = await ApiClient.getChecklist(_today);
      if (cl != null) {
        _stressLevel = (cl['stressLevel'] as num? ?? 2).toInt();
        _fatigueLevel = (cl['fatigueLevel'] as num? ?? 3).toInt();
      }
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

  int get _completedCount => _todayBlocks
      .where((b) => _completedIds.contains(b.id))
      .length;

  double get _progress =>
      _todayBlocks.isEmpty ? 0 : _completedCount / _todayBlocks.length;

  void _showSleepModal() {
    setState(() => _sleepAsked = true);
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (_) => const _SleepDialog(),
    );
  }

  Future<void> _submitChecklist() async {
    final items = <Map<String, dynamic>>[];
    final seen = <int>{};
    for (final b in _todayBlocks) {
      if (seen.add(b.lessonId)) {
        final planned = _todayBlocks
            .where((bl) => bl.lessonId == b.lessonId)
            .fold(0, (s, bl) => s + bl.blockCount);
        final done = _todayBlocks
            .where((bl) =>
                bl.lessonId == b.lessonId && _completedIds.contains(bl.id))
            .fold(0, (s, bl) => s + bl.blockCount);
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

    final now = DateTime.now();
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
                        completed: _completedCount,
                        total: total,
                        progress: _progress,
                      ),
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
                        return _BlockRow(
                          block: block,
                          isCompleted: _completedIds.contains(block.id),
                          onToggle: () => setState(() {
                            if (_completedIds.contains(block.id)) {
                              _completedIds.remove(block.id);
                            } else {
                              _completedIds.add(block.id);
                            }
                          }),
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
    required this.completed,
    required this.total,
    required this.progress,
  });

  final int completed;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
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
                      '$completed',
                      style: const TextStyle(
                          color: kText1,
                          fontSize: 22,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'of $total',
                      style: const TextStyle(color: kText2, fontSize: 11),
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
                  label: 'Today',
                  value: total > 0
                      ? '${(progress * 100).round()}%'
                      : '—',
                  sub: 'blocks done',
                ),
                Divider(
                    height: 16,
                    thickness: 0.5,
                    color: kBorder),
                const _Stat(
                  label: 'Last 7 days',
                  value: '—',
                  sub: 'completion rate',
                ),
              ],
            ),
          ),
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
    required this.isCompleted,
    required this.onToggle,
  });

  final ScheduledBlock block;
  final bool isCompleted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = lessonColor(block.lessonId);
    final blocks30 = block.blockCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: AnimatedOpacity(
        opacity: isCompleted ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                              '· $blocks30 block${blocks30 > 1 ? 's' : ''}',
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
                        const SizedBox(height: 6),
                        Text(
                          block.lessonName,
                          style: TextStyle(
                            color: kText1,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: kText2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: SizedBox(
                    width: 56,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted
                                ? kAccent
                                : kBorder.withAlpha(200),
                            width: 1.5,
                          ),
                          color: isCompleted
                              ? kAccent
                              : Colors.transparent,
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check,
                                size: 16, color: kBg)
                            : null,
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
