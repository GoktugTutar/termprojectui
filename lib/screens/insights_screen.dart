import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/lesson_model.dart';
import '../theme.dart';

const _kDanger = Color(0xFFFF5C7A);
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
  String _multiplierStr = '—';
  String _completionStr = '—';
  Map<String, dynamic>? _profile;
  String _stressStr = '—';
  String _aiMessage = '';
  bool _weeklySubmitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('_load called');
    setState(() => _loading = true);
    try {
      final feedbackData = await ApiClient.getFeedbackMessages();
      final rawLessons = await ApiClient.getLessons();

      // Fetch student profile (single call replaces 7 checklist calls)
      Map<String, dynamic>? profile;
      String multiplierStr = '1.00';
      String completionStr = '—';
      String stressStr = '—';
      try {
        profile = await ApiClient.getStudentProfile();
        final rate = (profile['completionRate7d'] as num? ?? 0).toDouble();
        completionStr = '${(rate * 100).round()}%';
        final stress = (profile['avgStress7d'] as num? ?? 0).toDouble();
        stressStr = stress.toStringAsFixed(1);
        // Multiplier from overload alert
        final hasOverload = (feedbackData['messages'] as List? ?? []).any(
          (m) => m['type']?.toString() == 'asiri_yuk',
        );
        if (hasOverload) multiplierStr = '0.85';
      } catch (_) {}

      // Parse lessons outside setState so errors are catchable
      final lessons = <Lesson>[];
      for (final l in rawLessons) {
        try {
          lessons.add(Lesson.fromJson(l as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[INSIGHTS] lesson parse error: $e  raw=$l');
        }
      }
      debugPrint(
        '[INSIGHTS] rawLessons=${rawLessons.length} parsed=${lessons.length}',
      );

      bool weeklySubmitted = false;
      try {
        weeklySubmitted = await ApiClient.getWeeklyFeedbackStatus();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _messages = feedbackData['messages'] as List? ?? [];
        _lessons = lessons;
        _profile = profile;
        _multiplierStr = multiplierStr;
        _completionStr = completionStr;
        _aiMessage = feedbackData['aiMessage'] as String? ?? '';
        _stressStr = stressStr;
        _weeklySubmitted = weeklySubmitted;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[INSIGHTS] _load error: $e');
      debugPrint('[INSIGHTS] $st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openWeeklySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WeeklyFeedbackSheet(lessons: _lessons, onSent: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: kAccent))
            : RefreshIndicator(
                onRefresh: _load,
                color: kAccent,
                backgroundColor: kSurface,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 720),
                    child: CustomScrollView(
                      slivers: [
                        _buildHeader(),
                        _buildCta(),
                        _buildTrends(),
                        if (_profile != null) _buildProfileCard(),
                        _buildMessages(),
                        if (_aiMessage.isNotEmpty) _buildAiMessage(),
                        SliverToBoxAdapter(child: SizedBox(height: 100)),
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
        padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feedback engine',
              style: TextStyle(
                color: kText2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Insights',
              style: TextStyle(
                color: kText1,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '${_messages.length} active trigger${_messages.length != 1 ? 's' : ''}',
              style: TextStyle(color: kText2, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta() {
    final submitted = _weeklySubmitted;
    final cardColor = submitted ? _kSuccess : kAccent;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: GestureDetector(
          onTap: submitted ? null : _openWeeklySheet,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor.withAlpha(46), cardColor.withAlpha(15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardColor.withAlpha(90)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    submitted ? Icons.check : Icons.auto_awesome,
                    color: kBg,
                    size: 20,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly feedback',
                        style: TextStyle(
                          color: kText1,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        submitted
                            ? 'Bu haftalık gönderdin — multiplier ayarlandı'
                            : "Tells Step 1 what next week's multiplier should be",
                        style: TextStyle(color: kText2, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!submitted) Icon(Icons.chevron_right, color: cardColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final p = _profile!;
    final consistency = (p['consistencyScore'] as num? ?? 0).toDouble();
    final sweet = (p['sweetSpotBlocks'] as num? ?? 2).toDouble();
    final stressExam = (p['stressNearExam'] as num? ?? 3).toDouble();
    final fatigue = (p['avgFatigue7d'] as num? ?? 3).toDouble();
    final submissions = (p['totalSubmissions'] as num? ?? 0).toInt();

    // Parse day-of-week rates
    List<double> dowRates = [0, 0, 0, 0, 0, 0, 0];
    try {
      final raw = p['dowCompletionRates'] as String? ?? '[0,0,0,0,0,0,0]';
      final parsed = (json.decode(raw) as List)
          .map((v) => (v as num).toDouble())
          .toList();
      if (parsed.length == 7) dowRates = parsed;
    } catch (_) {}

    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: kText2),
                  SizedBox(width: 6),
                  Text(
                    'STUDENT PROFILE',
                    style: TextStyle(
                      color: kText2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '$submissions submissions',
                    style: TextStyle(color: kText2, fontSize: 11),
                  ),
                ],
              ),
              SizedBox(height: 14),
              // Day-of-week bar chart
              Text(
                'Weekly pattern',
                style: TextStyle(color: kText2, fontSize: 12),
              ),
              SizedBox(height: 8),
              Row(
                children: List.generate(7, (i) {
                  final rate = dowRates[i];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                      child: Column(
                        children: [
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: kBorder,
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: rate.clamp(0.05, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: rate >= 0.8
                                        ? kAccent
                                        : rate >= 0.5
                                        ? kAccent.withAlpha(150)
                                        : kAccent.withAlpha(60),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            days[i],
                            style: TextStyle(color: kText2, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 14),
              Divider(height: 1, thickness: 0.5, color: kBorder),
              SizedBox(height: 14),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _ProfileStat(
                      label: 'Sweet spot',
                      value: '${sweet.toStringAsFixed(1)} blocks',
                      sub: 'per session',
                      icon: Icons.bolt_rounded,
                    ),
                  ),
                  Expanded(
                    child: _ProfileStat(
                      label: 'Consistency',
                      value: '${(consistency * 100).round()}%',
                      sub: 'last 14 days',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  Expanded(
                    child: _ProfileStat(
                      label: 'Pre-exam stress',
                      value: stressExam.toStringAsFixed(1),
                      sub: 'avg score',
                      icon: Icons.warning_amber_outlined,
                    ),
                  ),
                  Expanded(
                    child: _ProfileStat(
                      label: 'Fatigue avg',
                      value: fatigue.toStringAsFixed(1),
                      sub: 'this week',
                      icon: Icons.bedtime_outlined,
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

  Widget _buildTrends() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Row(
          children: [
            Expanded(
              child: _TrendCard(
                label: 'Multiplier',
                value: _multiplierStr,
                sub: 'last week',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _TrendCard(
                label: 'Completion',
                value: _completionStr,
                sub: 'last 7 days',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _TrendCard(
                label: 'Stress avg',
                value: _stressStr,
                sub: 'this week',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kAccent.withAlpha(30), kAccent.withAlpha(10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kAccent.withAlpha(80)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kAccent.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: kAccent,
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _aiMessage,
                  style: TextStyle(color: kText1, fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, color: _kSuccess, size: 40),
              SizedBox(height: 10),
              Text(
                'No alerts or suggestions right now.',
                style: TextStyle(color: kText1, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final today = AppTime.now().toIso8601String().substring(0, 10);
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
      items.add(_SectionLabel('Today'));
      items.addAll(
        todayMsgs.map((m) => _MessageCard(message: m as Map<String, dynamic>)),
      );
    }
    if (earlierMsgs.isNotEmpty) {
      items.add(_SectionLabel('Earlier this week'));
      items.addAll(
        earlierMsgs.map(
          (m) => _MessageCard(message: m as Map<String, dynamic>),
        ),
      );
    }
    if (items.isEmpty) {
      items.addAll(
        _messages.map((m) => _MessageCard(message: m as Map<String, dynamic>)),
      );
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
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: kText2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: kText2, fontSize: 10)),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: kText1,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            sub,
            style: TextStyle(color: kText2.withAlpha(160), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatefulWidget {
  const _MessageCard({required this.message});

  final Map<String, dynamic> message;

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  // null = henüz yanıt yok, true/false = bool kartında yanıt
  bool? _boolAnswer;
  // saat veya time_of_day seçimi
  int? _selectedHour;
  String? _selectedTime;
  bool _saving = false;
  bool _done = false; // kart tamamlandı → küçük onay göster

  Map<String, dynamic> get _sc =>
      (widget.message['suggestedConstraint'] as Map<String, dynamic>?) ?? {};

  String get _kind => _sc['kind']?.toString() ?? '';
  bool get _hasConstraint => _sc.isNotEmpty;

  Future<void> _applyBool(bool accept) async {
    if (_saving) return;
    setState(() { _saving = true; _boolAnswer = accept; });
    try {
      if (accept) {
        final params = _sc['params'] as Map<String, dynamic>?;
        await ApiClient.createConstraint(
          _sc['type'] as String,
          params: params,
        );
      }
      if (!mounted) return;
      setState(() { _saving = false; _done = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _boolAnswer = null; });
    }
  }

  Future<void> _applyHour(int hour) async {
    if (_saving) return;
    setState(() { _saving = true; _selectedHour = hour; });
    try {
      await ApiClient.createConstraint(
        _sc['type'] as String,
        params: {'hour': hour},
      );
      if (!mounted) return;
      setState(() { _saving = false; _done = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _selectedHour = null; });
    }
  }

  Future<void> _applyTimeOfDay(String preferredTime) async {
    if (_saving) return;
    final dow = (_sc['dayOfWeek'] as num?)?.toInt();
    if (dow == null) return;
    setState(() { _saving = true; _selectedTime = preferredTime; });
    try {
      await ApiClient.createConstraint(
        'day_study_time',
        params: {'dayOfWeek': dow, 'preferredTime': preferredTime},
      );
      if (!mounted) return;
      setState(() { _saving = false; _done = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _selectedTime = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.message['type']?.toString() ?? 'info';
    final tag = widget.message['tag']?.toString() ??
        type.toUpperCase().replaceAll('_', ' ');
    final title = widget.message['title']?.toString() ??
        widget.message['message']?.toString() ?? '';
    final body = widget.message['body']?.toString() ??
        widget.message['suggestion']?.toString();
    final cta = widget.message['cta']?.toString();

    final (color, icon, bg) = switch (type) {
      'critical' => (_kDanger, Icons.warning_amber_rounded, _kDanger.withAlpha(30)),
      'warning'  => (_kWarning, Icons.local_fire_department_outlined, _kWarning.withAlpha(30)),
      'positive' => (_kSuccess, Icons.check_circle_outline, _kSuccess.withAlpha(30)),
      _ => (kAccent, Icons.info_outline, kAccent.withAlpha(30)),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: EdgeInsets.all(16),
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tip etiketi
                  Text(
                    tag.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(height: 4),
                  // Ana mesaj
                  Text(
                    title,
                    style: TextStyle(
                      color: kText1,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (body != null && body.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(color: kText2, fontSize: 13, height: 1.45),
                    ),
                  ],
                  // Eski CTA (suggestedConstraint yoksa)
                  if (!_hasConstraint && cta != null && cta.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Row(children: [
                      _PillBtn(cta, accent: true),
                      SizedBox(width: 8),
                      _PillBtn('Dismiss'),
                    ]),
                  ],
                  // ── Constraint önerisi ─────────────────────────────────────
                  if (_hasConstraint) ...[
                    SizedBox(height: 12),
                    _ConstraintSuggestionSection(
                      sc: _sc,
                      kind: _kind,
                      done: _done,
                      saving: _saving,
                      boolAnswer: _boolAnswer,
                      selectedHour: _selectedHour,
                      selectedTime: _selectedTime,
                      onBool: _applyBool,
                      onHour: _applyHour,
                      onTimeOfDay: _applyTimeOfDay,
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

// ── Constraint önerisi alt bölümü ─────────────────────────────────────────────

class _ConstraintSuggestionSection extends StatelessWidget {
  const _ConstraintSuggestionSection({
    required this.sc,
    required this.kind,
    required this.done,
    required this.saving,
    required this.boolAnswer,
    required this.selectedHour,
    required this.selectedTime,
    required this.onBool,
    required this.onHour,
    required this.onTimeOfDay,
  });

  final Map<String, dynamic> sc;
  final String kind;
  final bool done;
  final bool saving;
  final bool? boolAnswer;
  final int? selectedHour;
  final String? selectedTime;
  final ValueChanged<bool> onBool;
  final ValueChanged<int> onHour;
  final ValueChanged<String> onTimeOfDay;

  static const _timeOptions = [
    ('morning',   'Sabah',   '08–11'),
    ('afternoon', 'Öğle',    '12–15'),
    ('evening',   'Akşam',   '18–21'),
    ('night',     'Gece',    '21–24'),
  ];

  @override
  Widget build(BuildContext context) {
    final question = sc['question']?.toString() ?? '';

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kAccent.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(children: [
            Icon(Icons.lightbulb_outline_rounded, size: 14, color: kAccent),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                question,
                style: TextStyle(
                  color: kText1,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          SizedBox(height: 10),

          // Tamamlandı durumu
          if (done)
            Row(children: [
              Icon(Icons.check_circle_rounded, size: 15, color: _kSuccess),
              SizedBox(width: 6),
              Text(
                'Saved — will apply on next plan.',
                style: TextStyle(color: _kSuccess, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ])
          // Bool (Evet/Hayır)
          else if (kind == 'bool')
            Row(children: [
              _AnswerChip(
                label: 'Yes',
                selected: boolAnswer == true,
                positive: true,
                loading: saving && boolAnswer == true,
                onTap: () => onBool(true),
              ),
              SizedBox(width: 8),
              _AnswerChip(
                label: 'No',
                selected: boolAnswer == false,
                positive: false,
                loading: saving && boolAnswer == false,
                onTap: () => onBool(false),
              ),
            ])
          // Saat seçimi (hour_end / hour_start)
          else if (kind == 'hour_end' || kind == 'hour_start') ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...((sc['options'] as List? ?? []).map((o) {
                  final h = (o as num).toInt();
                  final label = h == 24
                      ? '24:00'
                      : '${h.toString().padLeft(2, '0')}:00';
                  final isSelected = selectedHour == h;
                  return _AnswerChip(
                    label: label,
                    selected: isSelected,
                    positive: true,
                    loading: saving && isSelected,
                    onTap: () => onHour(h),
                  );
                })),
                _AnswerChip(
                  label: 'Skip',
                  selected: false,
                  positive: false,
                  loading: false,
                  onTap: () => onBool(false), // false = kullanıcı reddetti
                ),
              ],
            ),
          ]
          // Günlük zaman seçimi
          else if (kind == 'time_of_day') ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._timeOptions.map((opt) {
                  final (val, label, range) = opt;
                  final isSelected = selectedTime == val;
                  return _TimeOfDayChip(
                    label: label,
                    range: range,
                    selected: isSelected,
                    loading: saving && isSelected,
                    onTap: () => onTimeOfDay(val),
                  );
                }),
                _AnswerChip(
                  label: 'Skip',
                  selected: false,
                  positive: false,
                  loading: false,
                  onTap: () => onBool(false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.label,
    required this.selected,
    required this.positive,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool positive;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color base = positive ? kAccent : kText2;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? base.withAlpha(46) : kBorder.withAlpha(40),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? base : kBorder,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: base),
              )
            : Text(
                label,
                style: TextStyle(
                  color: selected ? base : kText2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _TimeOfDayChip extends StatelessWidget {
  const _TimeOfDayChip({
    required this.label,
    required this.range,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final String range;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kAccent.withAlpha(46) : kBorder.withAlpha(40),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kAccent : kBorder,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? kAccent : kText2,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    range,
                    style: TextStyle(color: kText2, fontSize: 10),
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
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: accent ? kAccent.withAlpha(46) : kBorder,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: accent ? kAccent : kText1,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Weekly feedback sheet ─────────────────────────────────────────────────────

class _WeeklyFeedbackSheet extends StatefulWidget {
  const _WeeklyFeedbackSheet({required this.lessons, required this.onSent});

  final List<Lesson> lessons;
  final VoidCallback onSent;

  @override
  State<_WeeklyFeedbackSheet> createState() => _WeeklyFeedbackSheetState();
}

class _WeeklyFeedbackSheetState extends State<_WeeklyFeedbackSheet> {
  String? _weekload;
  final Map<String, int> _perLesson = {};
  bool _saving = false;

  static const _opts = [
    ('cok_yogundu', 'Too heavy', 'multiplier → 0.85'),
    ('tam_uygundu', 'Just right', 'multiplier → 1.00'),
    ('yetersizdi', 'Could do more', 'multiplier → 1.10'),
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
          .map(
            (l) => {
              'lessonId': int.parse(l.id),
              'needsMoreTime': _perLesson[l.id] ?? 0,
            },
          )
          .toList();
      await ApiClient.submitWeeklyFeedback(
        weekloadFeedback: _weekload ?? 'tam_uygundu',
        lessonFeedbacks: lessonFeedbacks,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_weeklyFeedbackPromptKey(), true);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSent();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _weeklyFeedbackPromptKey() {
    final now = AppTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(
      Duration(days: now.weekday == DateTime.sunday ? 6 : now.weekday - 1),
    );
    final week = weekStart.toIso8601String().substring(0, 10);
    return 'weekly_feedback_prompt_dismissed_$week';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Weekly feedback',
                  style: TextStyle(
                    color: kText1,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kBorder,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 16, color: kText2),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'How was the load this week?',
              style: TextStyle(
                color: kText1,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10),
            ...(_opts.map((opt) {
              final (value, label, sub) = opt;
              final selected = _weekload == value;
              return GestureDetector(
                onTap: () => setState(() => _weekload = value),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? kAccent.withAlpha(46) : kBorder,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? kAccent : Colors.transparent,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: kText1,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              sub,
                              style: TextStyle(color: kText2, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? kAccent : kText2,
                            width: 1.5,
                          ),
                          color: selected ? kAccent : Colors.transparent,
                        ),
                        child: selected
                            ? Icon(Icons.check, size: 12, color: kBg)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            })),
            if (widget.lessons.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(
                'Per lesson',
                style: TextStyle(
                  color: kText1,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 10),
              ...widget.lessons.map((l) {
                final id = int.tryParse(l.id) ?? 0;
                final color = lessonColor(id);
                final v = _perLesson[l.id] ?? 0;
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.lessonName,
                          style: TextStyle(
                            color: kText1,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _SegmentedControl(
                        value: v,
                        options: [(-1, 'Less'), (0, '✓'), (1, 'More')],
                        onChanged: (nv) =>
                            setState(() => _perLesson[l.id] = nv),
                      ),
                    ],
                  ),
                );
              }),
            ],
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Submit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final (v, label) = opt;
          final selected = v == value;
          return GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? kAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : kText2,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: kAccent),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: kText1,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(color: kText2, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
