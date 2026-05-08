import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/lesson_model.dart';
import '../theme.dart';

const _kDanger  = Color(0xFFFF5C7A);
const _kWarning = Color(0xFFF2B14A);
const _kSuccess = Color(0xFF5BD49B);

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _messages = [];
  List<Lesson> _lessons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final msgs = await ApiClient.getFeedbackMessages();
      final rawLessons = await ApiClient.getLessons();
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _lessons = rawLessons
            .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openWeeklySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _WeeklyFeedbackSheet(
        lessons: _lessons,
        onSent: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : RefreshIndicator(
                onRefresh: _load,
                color: kAccent,
                backgroundColor: kSurface,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: CustomScrollView(
                      slivers: [
                        _buildHeader(),
                        _buildCta(),
                        _buildTrends(),
                        _buildMessages(),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feedback engine',
                style: TextStyle(
                    color: kText2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            const Text('Insights',
                style: TextStyle(
                    color: kText1,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              '${_messages.length} active trigger${_messages.length != 1 ? 's' : ''}',
              style: const TextStyle(color: kText2, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: GestureDetector(
          onTap: _openWeeklySheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kAccent.withAlpha(46),
                  kAccent.withAlpha(15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kAccent.withAlpha(90)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: kAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome,
                      color: kBg, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly feedback',
                          style: TextStyle(
                              color: kText1,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text(
                          "Tells Step 1 what next week's multiplier should be",
                          style:
                              TextStyle(color: kText2, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: kAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrends() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Row(
          children: const [
            Expanded(
                child: _TrendCard(
                    label: 'Multiplier',
                    value: '1.00',
                    sub: 'last week')),
            SizedBox(width: 8),
            Expanded(
                child: _TrendCard(
                    label: 'Completion',
                    value: '—',
                    sub: 'last 7 days')),
            SizedBox(width: 8),
            Expanded(
                child: _TrendCard(
                    label: 'Stress avg',
                    value: '—',
                    sub: 'this week')),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: const [
              Icon(Icons.check_circle_outline,
                  color: _kSuccess, size: 40),
              SizedBox(height: 10),
              Text('No alerts or suggestions right now.',
                  style: TextStyle(color: kText1, fontSize: 15),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayMsgs = _messages.where((m) {
      final ts = m['createdAt']?.toString() ?? m['ts']?.toString() ?? '';
      return ts.startsWith(today);
    }).toList();
    final earlierMsgs = _messages.where((m) {
      final ts = m['createdAt']?.toString() ?? m['ts']?.toString() ?? '';
      return !ts.startsWith(today);
    }).toList();

    final items = <Widget>[];
    if (todayMsgs.isNotEmpty) {
      items.add(const _SectionLabel('Today'));
      items.addAll(todayMsgs.map(
          (m) => _MessageCard(message: m as Map<String, dynamic>)));
    }
    if (earlierMsgs.isNotEmpty) {
      items.add(const _SectionLabel('Earlier this week'));
      items.addAll(earlierMsgs.map(
          (m) => _MessageCard(message: m as Map<String, dynamic>)));
    }
    if (items.isEmpty) {
      items.addAll(_messages.map(
          (m) => _MessageCard(message: m as Map<String, dynamic>)));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => items[i],
        childCount: items.length,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: kText2,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: kText2, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: kText1,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          Text(sub,
              style: TextStyle(
                  color: kText2.withAlpha(160), fontSize: 11)),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final type = message['type']?.toString() ?? 'info';
    final tag  = message['tag']?.toString() ??
        type.toUpperCase().replaceAll('_', ' ');
    final title = message['title']?.toString() ??
        message['message']?.toString() ?? '';
    final body = message['body']?.toString() ??
        message['suggestion']?.toString();
    final cta  = message['cta']?.toString();

    final (color, icon, bg) = switch (type) {
      'critical' => (_kDanger,   Icons.warning_amber_rounded,
          _kDanger.withAlpha(30)),
      'warning'  => (_kWarning,  Icons.local_fire_department_outlined,
          _kWarning.withAlpha(30)),
      'positive' => (_kSuccess,  Icons.check_circle_outline,
          _kSuccess.withAlpha(30)),
      _          => (kAccent,    Icons.info_outline,
          kAccent.withAlpha(30)),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 4),
                  Text(title,
                      style: const TextStyle(
                          color: kText1,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(body,
                        style: const TextStyle(
                            color: kText2,
                            fontSize: 13,
                            height: 1.45)),
                  ],
                  if (cta != null && cta.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _PillBtn(cta, accent: true),
                        const SizedBox(width: 8),
                        const _PillBtn('Dismiss'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillBtn extends StatelessWidget {
  const _PillBtn(this.label, {this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: accent ? kAccent.withAlpha(46) : kBorder,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                color: accent ? kAccent : kText1,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Weekly feedback sheet ─────────────────────────────────────────────────────

class _WeeklyFeedbackSheet extends StatefulWidget {
  const _WeeklyFeedbackSheet({
    required this.lessons,
    required this.onSent,
  });

  final List<Lesson> lessons;
  final VoidCallback onSent;

  @override
  State<_WeeklyFeedbackSheet> createState() =>
      _WeeklyFeedbackSheetState();
}

class _WeeklyFeedbackSheetState extends State<_WeeklyFeedbackSheet> {
  String? _weekload;
  final Map<String, int> _perLesson = {};
  bool _saving = false;

  static const _opts = [
    ('cok_yogundu', 'Too heavy',     'multiplier → 0.85'),
    ('tam_uygundu', 'Just right',    'multiplier → 1.00'),
    ('yetersizdi',  'Could do more', 'multiplier → 1.10'),
  ];

  @override
  void initState() {
    super.initState();
    for (final l in widget.lessons) {
      _perLesson[l.id] = 0;
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final lessonFeedbacks = widget.lessons
          .map((l) => {
                'lessonId': int.parse(l.id),
                'needsMoreTime': _perLesson[l.id] ?? 0,
              })
          .toList();
      await ApiClient.submitWeeklyFeedback(
        weekloadFeedback: _weekload ?? 'tam_uygundu',
        lessonFeedbacks: lessonFeedbacks,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSent();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Weekly feedback',
                    style: TextStyle(
                        color: kText1,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: kBorder, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        size: 16, color: kText2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('How was the load this week?',
                style: TextStyle(
                    color: kText1,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...(_opts.map((opt) {
              final (value, label, sub) = opt;
              final selected = _weekload == value;
              return GestureDetector(
                onTap: () =>
                    setState(() => _weekload = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? kAccent.withAlpha(46)
                        : kBorder,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? kAccent
                          : Colors.transparent,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    color: kText1,
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w600)),
                            Text(sub,
                                style: const TextStyle(
                                    color: kText2,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? kAccent
                                : kText2,
                            width: 1.5,
                          ),
                          color: selected
                              ? kAccent
                              : Colors.transparent,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                size: 12, color: kBg)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            })),
            if (widget.lessons.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Per lesson',
                  style: TextStyle(
                      color: kText1,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...widget.lessons.map((l) {
                final id = int.tryParse(l.id) ?? 0;
                final color = lessonColor(id);
                final v = _perLesson[l.id] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l.lessonName,
                            style: const TextStyle(
                                color: kText1,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                      _SegmentedControl(
                        value: v,
                        options: const [
                          (-1, 'Less'),
                          (0, '✓'),
                          (1, 'More'),
                        ],
                        onChanged: (nv) => setState(
                            () => _perLesson[l.id] = nv),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Submit',
                        style: TextStyle(
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<(int, String)> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final (v, label) = opt;
          final selected = v == value;
          return GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? kAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : kText2,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
