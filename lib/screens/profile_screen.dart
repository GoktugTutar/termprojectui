import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/lesson_model.dart';
import '../theme.dart';
import 'new_term_screen.dart';

const _kDanger = Color(0xFFFF5C7A);
const _kWarning = Color(0xFFF2B14A);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _isTestMode = false;
  List<Map<String, dynamic>> _checklistHistory = [];
  List<Lesson> _lessons = [];

  String _preferredStudyTime = 'morning';
  String _studyStyle = 'normal';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.getMe(),
        ApiClient.getMode(),
        ApiClient.getChecklistHistory(),
        ApiClient.getLessons(),
      ]);
      if (!mounted) return;
      final user = results[0] as Map<String, dynamic>;
      final modeInfo = results[1] as Map<String, dynamic>;
      final history = results[2] as List<Map<String, dynamic>>;
      final lessons =
          (results[3] as List)
              .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
              .toList()
            ..sort((a, b) {
              final da = _daysToExam(a) ?? 9999;
              final db = _daysToExam(b) ?? 9999;
              return da.compareTo(db);
            });
      setState(() {
        _user = user;
        _preferredStudyTime =
            user['preferredStudyTime']?.toString() ?? 'morning';
        _studyStyle = user['studyStyle']?.toString() ?? 'normal';
        _isTestMode = modeInfo['mode']?.toString() == 'test';
        _checklistHistory = history;
        _lessons = lessons;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int? _daysToExam(Lesson lesson) {
    int? best;
    final now = AppTime.now();
    for (final exam in lesson.exams) {
      try {
        final date = DateTime.parse(exam.examDate);
        final diff = date.difference(now).inDays;
        if (best == null || diff < best) best = diff;
      } catch (_) {}
    }
    return best;
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);
    try {
      await ApiClient.setupUser({
        'preferredStudyTime': _preferredStudyTime,
        'studyStyle': _studyStyle,
      });
      if (!mounted) return;
      _snack('Preferences saved!');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _endTerm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: Text('Dönemi Bitir', style: TextStyle(color: kText1)),
        content: Text(
          'Aktif dönem sonlandırılacak. Dersler ve veriler silinmez, yalnızca dönem kapatılır.',
          style: TextStyle(color: kText2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal', style: TextStyle(color: kText2)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kDanger),
            child: Text('Bitir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ApiClient.endTerm();
      if (!mounted) return;
      _snack('Dönem sonlandırıldı.');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  void _startNewTerm() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewTermScreen()));
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
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

    final email = _user?['email']?.toString() ?? '';
    final displayName = email.isNotEmpty ? email.split('@').first : 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

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
              constraints: BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  // Header / kicker
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 12, 0, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setup',
                          style: TextStyle(
                            color: kText2,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Profile',
                          style: TextStyle(
                            color: kText1,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar row
                  Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kAccent, Color(0xFF5AB6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: kBg,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: kText1,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '12 weeks · 314 blocks completed',
                              style: TextStyle(color: kText2, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Preferred study time
                  _SectionLabel('Preferred study time'),
                  SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.8,
                    children: [
                      _TimeChip(
                        v: 'morning',
                        label: 'Morning',
                        range: '08–11',
                        icon: Icons.wb_sunny_outlined,
                        pref: _preferredStudyTime,
                        onTap: () =>
                            setState(() => _preferredStudyTime = 'morning'),
                      ),
                      _TimeChip(
                        v: 'afternoon',
                        label: 'Afternoon',
                        range: '12–15',
                        icon: Icons.wb_cloudy_outlined,
                        pref: _preferredStudyTime,
                        onTap: () =>
                            setState(() => _preferredStudyTime = 'afternoon'),
                      ),
                      _TimeChip(
                        v: 'evening',
                        label: 'Evening',
                        range: '18–21',
                        icon: Icons.nights_stay_outlined,
                        pref: _preferredStudyTime,
                        onTap: () =>
                            setState(() => _preferredStudyTime = 'evening'),
                      ),
                      _TimeChip(
                        v: 'night',
                        label: 'Night',
                        range: '21–24',
                        icon: Icons.bedtime_outlined,
                        pref: _preferredStudyTime,
                        onTap: () =>
                            setState(() => _preferredStudyTime = 'night'),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  // Study style
                  _SectionLabel('Study style'),
                  SizedBox(height: 8),
                  Column(
                    children: [
                      _StyleCard(
                        v: 'deep_focus',
                        label: 'Deep focus',
                        sub: '1 long block · max 2h',
                        rule: 'maxSessions=1, max=4 blocks',
                        value: _studyStyle,
                        onChange: (s) => setState(() => _studyStyle = s),
                      ),
                      SizedBox(height: 8),
                      _StyleCard(
                        v: 'distributed',
                        label: 'Distributed',
                        sub: '3 short blocks · spread across day',
                        rule: 'maxSessions=3, max=2 blocks',
                        value: _studyStyle,
                        onChange: (s) => setState(() => _studyStyle = s),
                      ),
                      SizedBox(height: 8),
                      _StyleCard(
                        v: 'normal',
                        label: 'Balanced',
                        sub: '2 medium blocks · default',
                        rule: 'maxSessions=2, max=3 blocks',
                        value: _studyStyle,
                        onChange: (s) => setState(() => _studyStyle = s),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  FilledButton(
                    onPressed: _saving ? null : _savePreferences,
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
                            'Save preferences',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                  SizedBox(height: 24),
                  _SectionLabel('Dersler'),
                  SizedBox(height: 10),
                  _ProfileLessonsPanel(
                    lessons: _lessons,
                    daysToExam: _daysToExam,
                  ),
                  SizedBox(height: 24),
                  // Checklist geçmişi ısı haritası
                  if (_isTestMode && _checklistHistory.isNotEmpty) ...[
                    _SectionLabel('Checklist geçmişi'),
                    SizedBox(height: 10),
                    _ChecklistHeatmap(history: _checklistHistory),
                    SizedBox(height: 24),
                  ],
                  // Dönem yönetimi
                  _SectionLabel('Dönem'),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _endTerm,
                          icon: Icon(
                            Icons.archive_outlined,
                            size: 16,
                            color: _kDanger,
                          ),
                          label: Text(
                            'Dönemi Bitir',
                            style: TextStyle(color: _kDanger),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _kDanger),
                            padding: EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _startNewTerm,
                          icon: Icon(Icons.add_circle_outline, size: 16),
                          label: Text('Yeni Dönem'),
                          style: FilledButton.styleFrom(
                            backgroundColor: kAccent,
                            padding: EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Developer / Test mode (sadece MODE=test'te gösterilir)
                  if (_isTestMode) ...[
                    _SectionLabel('Developer'),
                    SizedBox(height: 8),
                    _TestModeCard(onSave: _snack),
                    SizedBox(height: 24),
                  ],
                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: _kDanger,
                      ),
                      label: Text(
                        'Sign out',
                        style: TextStyle(color: _kDanger),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kDanger),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: kText2,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Time chip ─────────────────────────────────────────────────────────────────

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.v,
    required this.label,
    required this.range,
    required this.icon,
    required this.pref,
    required this.onTap,
  });

  final String v;
  final String label;
  final String range;
  final IconData icon;
  final String pref;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = pref == v;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: on ? kAccent.withAlpha(46) : kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? kAccent : kBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: on ? kAccent : kBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: on ? kBg : kText2, size: 15),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: on ? kText1 : kText2,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(range, style: TextStyle(color: kText2, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Style card ────────────────────────────────────────────────────────────────

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.v,
    required this.label,
    required this.sub,
    required this.rule,
    required this.value,
    required this.onChange,
  });

  final String v;
  final String label;
  final String sub;
  final String rule;
  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final on = value == v;
    return GestureDetector(
      onTap: () => onChange(v),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: on ? kAccent.withAlpha(46) : kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? kAccent : kBorder, width: 0.5),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? kAccent : kText2, width: 1.5),
                color: on ? kAccent : Colors.transparent,
              ),
              child: on
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: kBg,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: on ? kText1 : kText2,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(sub, style: TextStyle(color: kText2, fontSize: 12)),
                ],
              ),
            ),
            // Monospace rule
            SizedBox(
              width: 110,
              child: Text(
                rule,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: kText2.withAlpha(180),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLessonsPanel extends StatefulWidget {
  const _ProfileLessonsPanel({required this.lessons, required this.daysToExam});

  final List<Lesson> lessons;
  final int? Function(Lesson lesson) daysToExam;

  @override
  State<_ProfileLessonsPanel> createState() => _ProfileLessonsPanelState();
}

class _ProfileLessonsPanelState extends State<_ProfileLessonsPanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 612,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: widget.lessons.isEmpty
          ? Center(
              child: Text(
                'Henüz ders eklenmemiş.',
                style: TextStyle(color: kText2, fontSize: 13),
              ),
            )
          : Scrollbar(
              controller: _scrollController,
              thumbVisibility: widget.lessons.length > 4,
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: widget.lessons.length,
                separatorBuilder: (_, _) => SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final lesson = widget.lessons[index];
                  return _ProfileLessonRow(
                    lesson: lesson,
                    daysToExam: widget.daysToExam(lesson),
                  );
                },
              ),
            ),
    );
  }
}

class _ProfileLessonRow extends StatelessWidget {
  const _ProfileLessonRow({required this.lesson, required this.daysToExam});

  final Lesson lesson;
  final int? daysToExam;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(lesson.id) ?? 0;
    final color = lessonColor(id);
    final initials = lesson.lessonName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(2)
        .join('');

    String priority = 'LOW';
    Color priorityColor = kText2;
    if (daysToExam != null) {
      if (daysToExam! <= 3) {
        priority = 'CRITICAL';
        priorityColor = _kDanger;
      } else if (daysToExam! <= 7) {
        priority = 'HIGH';
        priorityColor = _kWarning;
      } else if (daysToExam! <= 14) {
        priority = 'MEDIUM';
        priorityColor = kAccent;
      }
    }

    final examValue = daysToExam == null || lesson.exams.isEmpty
        ? '—'
        : lesson.exams.first.dateOnly;
    final totalDelay = lesson.keyfiDelayCount + lesson.zorunluDelayCount;
    final needsMore = lesson.needsMoreTime == 1
        ? '+1'
        : lesson.needsMoreTime == -1
        ? '-1'
        : '0';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withAlpha(85)),
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.lessonName,
                      style: TextStyle(
                        color: kText1,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        _ProfileDiffBars(
                          difficulty: lesson.difficulty,
                          color: color,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'difficulty ${lesson.difficulty}',
                          style: TextStyle(color: kText2, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    priority,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (daysToExam != null)
                    Text(
                      '${daysToExam!.clamp(0, 9999)}d to exam',
                      style: TextStyle(
                        color: kText2,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, thickness: 0.5, color: kBorder),
          ),
          Row(
            children: [
              _ProfilePico(
                icon: Icons.calendar_today_outlined,
                label: 'Exam',
                value: examValue,
              ),
              _ProfilePico(
                icon: Icons.repeat,
                label: 'Delays',
                value: '$totalDelay',
                sub: lesson.keyfiDelayCount > 0 ? 'slot mode' : null,
                tone: totalDelay >= 3 ? _kWarning : null,
              ),
              _ProfilePico(
                icon: Icons.auto_awesome_outlined,
                label: 'Need more',
                value: needsMore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileDiffBars extends StatelessWidget {
  const _ProfileDiffBars({required this.difficulty, required this.color});

  final int difficulty;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 8.0, 10.0, 12.0, 14.0];
    return Row(
      children: List.generate(5, (i) {
        final filled = i < difficulty;
        return Container(
          width: 3,
          height: heights[i],
          margin: EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: filled ? color : kBorder,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _ProfilePico extends StatelessWidget {
  const _ProfilePico({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: kText2),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: kText2,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: tone ?? kText1,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub != null)
            Text(
              sub!,
              style: TextStyle(
                color: kAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

// ── Test mode card ────────────────────────────────────────────────────────────

class _TestModeCard extends StatefulWidget {
  const _TestModeCard({required this.onSave});

  final void Function(String msg, {bool error}) onSave;

  @override
  State<_TestModeCard> createState() => _TestModeCardState();
}

class _TestModeCardState extends State<_TestModeCard> {
  DateTime _now = AppTime.now();

  Future<void> _edit() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.dark(primary: kAccent)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_now),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.dark(primary: kAccent)),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    try {
      await ApiClient.setTestClock(dt.toIso8601String());
      AppTime.setOverride(dt);
      setState(() => _now = dt);
      widget.onSave('Test clock: ${dt.toIso8601String().substring(0, 16)}');
    } catch (e) {
      widget.onSave(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kDanger.withAlpha(46),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.access_time, size: 14, color: _kDanger),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'mod=test',
                      style: TextStyle(
                        color: kText1,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Override the system clock — algorithm reads from this.',
                      style: TextStyle(color: kText2, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text('Now:', style: TextStyle(color: kText2, fontSize: 12)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _now.toIso8601String().substring(0, 16).replaceAll('T', ' '),
                  style: TextStyle(
                    color: kText1,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _edit,
                child: Container(
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: kAccent.withAlpha(46),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kBorder),
                  ),
                  child: Center(
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        color: kAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Checklist heatmap ─────────────────────────────────────────────────────────

class _ChecklistHeatmap extends StatelessWidget {
  const _ChecklistHeatmap({required this.history});

  final List<Map<String, dynamic>> history;

  static const _dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const _dayNames = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  static const _monthNames = [
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

  String _formatTodayLabel(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return '${date.day} ${_monthNames[date.month - 1]} ${_dayNames[date.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    // history öğelerini haftalar halinde grupla (Pazartesi başlangıçlı)
    // İlk öğenin hangi gün olduğunu bul
    final weeks = <List<Map<String, dynamic>?>>[];
    if (history.isEmpty) return const SizedBox.shrink();

    final todayStr = AppTime.todayStr();
    final todayDate = DateTime.tryParse(todayStr);
    final todayWeekdayIndex = todayDate == null ? -1 : todayDate.weekday - 1;
    final firstDate = DateTime.parse(history.first['date'] as String);
    // Pazartesi = 1, önceki günleri null ile doldur
    final leadingNulls = (firstDate.weekday - 1) % 7;
    final padded = <Map<String, dynamic>?>[
      ...List.filled(leadingNulls, null),
      ...history,
    ];

    for (int i = 0; i < padded.length; i += 7) {
      final week = padded.sublist(i, (i + 7).clamp(0, padded.length));
      // 7'ye tamamla
      while (week.length < 7) {
        week.add(null);
      }
      weeks.add(week);
    }

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kAccent.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kAccent.withAlpha(120)),
                ),
                child: Icon(Icons.today_outlined, size: 15, color: kAccent),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bugün: ${_formatTodayLabel(todayStr)}',
                  style: TextStyle(
                    color: kText1,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Gün etiketleri
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(7, (i) {
              return Expanded(
                child: _DayHeader(
                  label: _dayLabels[i],
                  isToday: i == todayWeekdayIndex,
                ),
              );
            }),
          ),
          SizedBox(height: 6),
          // Haftalar
          ...weeks.map((week) {
            return Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Row(
                children: List.generate(7, (i) {
                  final day = i < week.length ? week[i] : null;
                  return Expanded(
                    child: _HeatmapCell(day: day, todayStr: todayStr),
                  );
                }),
              ),
            );
          }),
          SizedBox(height: 8),
          // Legend
          Row(
            children: [
              _LegendDot(color: const Color(0xFF34C759)),
              SizedBox(width: 4),
              Text('Tamamlandı', style: TextStyle(color: kText2, fontSize: 11)),
              SizedBox(width: 14),
              _LegendDot(color: const Color(0xFFFF5C7A)),
              SizedBox(width: 4),
              Text('Girilmedi', style: TextStyle(color: kText2, fontSize: 11)),
              SizedBox(width: 14),
              _LegendDot(color: kBorder),
              SizedBox(width: 4),
              Text('Boş gün', style: TextStyle(color: kText2, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.isToday});

  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isToday ? kAccent.withAlpha(55) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isToday
                  ? Border.all(color: kAccent.withAlpha(150))
                  : Border.all(color: Colors.transparent),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: isToday ? kText1 : kText2,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: 3),
          if (isToday)
            Text(
              'Bugün',
              style: TextStyle(
                color: kAccent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({required this.day, required this.todayStr});

  final Map<String, dynamic>? day;
  final String todayStr;

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }

    final hasBlocks = day!['hasBlocks'] as bool? ?? false;
    final hasChecklist = day!['hasChecklist'] as bool? ?? false;
    final dateStr = day!['date'] as String? ?? '';
    final isToday = dateStr == todayStr;
    final dayNum = dateStr.isNotEmpty
        ? int.tryParse(dateStr.split('-').last)
        : null;

    final Color color;
    if (!hasBlocks) {
      color = kBorder.withAlpha(120);
    } else if (hasChecklist) {
      color = const Color(0xFF34C759);
    } else {
      final date = DateTime.tryParse(dateStr);
      final now = AppTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final isTodayOrFuture =
          date != null &&
          !DateTime(date.year, date.month, date.day).isBefore(todayDate);
      color = isTodayOrFuture
          ? kBorder.withAlpha(120)
          : const Color(0xFFFF5C7A);
    }

    final bool darkText =
        color == const Color(0xFF34C759) || color == const Color(0xFFFF5C7A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showTodayLabel = isToday && constraints.maxWidth >= 42;
        return Padding(
          padding: EdgeInsets.all(2),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: isToday ? Border.all(color: kAccent, width: 2) : null,
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: kAccent.withAlpha(70),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: dayNum != null
                  ? _HeatmapCellText(
                      dayNum: dayNum,
                      isToday: isToday,
                      showTodayLabel: showTodayLabel,
                      textColor: darkText
                          ? Colors.white.withAlpha(230)
                          : kText1.withAlpha(220),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _HeatmapCellText extends StatelessWidget {
  const _HeatmapCellText({
    required this.dayNum,
    required this.isToday,
    required this.showTodayLabel,
    required this.textColor,
  });

  final int dayNum;
  final bool isToday;
  final bool showTodayLabel;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    if (!isToday) {
      return Center(
        child: Text(
          '$dayNum',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            if (showTodayLabel) ...[
              SizedBox(height: 3),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Bugün',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
