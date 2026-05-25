import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/lesson_model.dart';
import '../theme.dart';
import 'new_term_screen.dart';

const _kDanger = Color(0xFFFF5C7A);
const _kWarning = Color(0xFFF2B14A);

const _dayFullLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String? _busyDateKey(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.length >= 10) return text.substring(0, 10);
  return text;
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _localDateOnly(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class _ProfileBusySlot {
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int fatigueLevel;
  final String iconKey;
  final bool isRoutine;
  final String? date;

  const _ProfileBusySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.fatigueLevel,
    required this.iconKey,
    required this.isRoutine,
    this.date,
  });

  factory _ProfileBusySlot.fromJson(Map<String, dynamic> json) =>
      _ProfileBusySlot(
        dayOfWeek: (json['dayOfWeek'] as num).toInt(),
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        fatigueLevel: (json['fatigueLevel'] as num? ?? 1).toInt(),
        iconKey: json['iconKey']?.toString() ?? 'energy',
        isRoutine: json['isRoutine'] as bool? ?? json['date'] == null,
        date: _busyDateKey(json['date']),
      );

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'fatigueLevel': fatigueLevel,
    'iconKey': iconKey,
    'isRoutine': isRoutine,
    if (date != null) 'date': date,
  };
}

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
  List<_ProfileBusySlot> _busySlots = [];

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
      final busySlots =
          ((user['busySlots'] as List?) ?? [])
              .map(
                (slot) =>
                    _ProfileBusySlot.fromJson(slot as Map<String, dynamic>),
              )
              .toList()
            ..sort((a, b) {
              final dateCompare = (a.date ?? '').compareTo(b.date ?? '');
              if (dateCompare != 0) return dateCompare;
              final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
              if (dayCompare != 0) return dayCompare;
              return a.startTime.compareTo(b.startTime);
            });
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
        _busySlots = busySlots;
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
    final today = DateTime(now.year, now.month, now.day);
    for (final exam in lesson.exams) {
      try {
        final date = _localDateOnly(DateTime.parse(exam.examDate));
        final diff = date.difference(today).inDays;
        if (diff < 0) continue;
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
        title: Text('End Term', style: TextStyle(color: kText1)),
        content: Text(
          'The active term will be ended. Lessons and data will not be deleted; only the term will be closed.',
          style: TextStyle(color: kText2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: kText2)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kDanger),
            child: Text('End'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ApiClient.endTerm();
      if (!mounted) return;
      _snack('Term ended.');
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

  Future<void> _openAddLesson() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _ProfileAddLessonSheet(),
    );
    if (saved == true && mounted) {
      await _load();
    }
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
                  Row(
                    children: [
                      Expanded(child: _SectionLabel('Lessons')),
                      _MiniAddButton(onTap: _openAddLesson),
                    ],
                  ),
                  SizedBox(height: 10),
                  _ProfileLessonsPanel(
                    lessons: _lessons,
                    daysToExam: _daysToExam,
                  ),
                  SizedBox(height: 24),
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
                        value: _studyStyle,
                        onChange: (s) => setState(() => _studyStyle = s),
                      ),
                      SizedBox(height: 8),
                      _StyleCard(
                        v: 'distributed',
                        label: 'Distributed',
                        value: _studyStyle,
                        onChange: (s) => setState(() => _studyStyle = s),
                      ),
                      SizedBox(height: 8),
                      _StyleCard(
                        v: 'normal',
                        label: 'Balanced',
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
                  // Checklist history ısı haritası
                  if (_isTestMode && _checklistHistory.isNotEmpty) ...[
                    _SectionLabel('Checklist history'),
                    SizedBox(height: 10),
                    _ChecklistHeatmap(history: _checklistHistory),
                    SizedBox(height: 24),
                  ],
                  // Term yönetimi
                  _SectionLabel('Term'),
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
                            'End Term',
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
                          label: Text('New Term'),
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

class _SectionActionHeader extends StatelessWidget {
  const _SectionActionHeader({
    required this.text,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SectionLabel(text)),
        TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: TextButton.styleFrom(
            foregroundColor: kAccent,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }
}

class _MiniAddButton extends StatelessWidget {
  const _MiniAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add lesson',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kAccent.withAlpha(34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccent.withAlpha(150)),
          ),
          child: Icon(Icons.add_rounded, color: kAccent, size: 18),
        ),
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
    required this.value,
    required this.onChange,
  });

  final String v;
  final String label;
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
              child: Text(
                label,
                style: TextStyle(
                  color: on ? kText1 : kText2,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBusySlotsPanel extends StatelessWidget {
  const _ProfileBusySlotsPanel({required this.slots});

  final List<_ProfileBusySlot> slots;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 112, maxHeight: 320),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: slots.isEmpty
          ? Center(
              child: Text(
                'No busy time added yet.',
                style: TextStyle(color: kText2, fontSize: 13),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: slots.length,
              separatorBuilder: (_, _) => SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _ProfileBusySlotRow(slot: slots[index]),
            ),
    );
  }
}

class _ProfileBusySlotRow extends StatelessWidget {
  const _ProfileBusySlotRow({required this.slot});

  final _ProfileBusySlot slot;

  IconData get _icon {
    switch (slot.iconKey) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'commute':
        return Icons.directions_bus_outlined;
      case 'health':
        return Icons.local_hospital_outlined;
      case 'family':
        return Icons.home_outlined;
      default:
        return Icons.bolt_outlined;
    }
  }

  Color get _tone {
    if (slot.fatigueLevel >= 4) return _kDanger;
    if (slot.fatigueLevel == 3) return _kWarning;
    return kAccent;
  }

  @override
  Widget build(BuildContext context) {
    final day = _dayFullLabels[(slot.dayOfWeek - 1).clamp(0, 6)];
    final scope = slot.isRoutine ? 'Her hafta' : 'This week';
    final when = slot.isRoutine ? day : '${slot.date ?? day} · $day';

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBorder.withAlpha(appTheme.isLight ? 50 : 42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder.withAlpha(120)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _tone.withAlpha(appTheme.isLight ? 34 : 48),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _tone, size: 19),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$scope · ${slot.startTime}-${slot.endTime}',
                  style: TextStyle(
                    color: kText1,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3),
                Text(
                  when,
                  style: TextStyle(color: kText2, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            '${slot.fatigueLevel}/5',
            style: TextStyle(
              color: _tone,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
  final Map<String, _LessonGradeEntry> _grades = {};

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  @override
  void didUpdateWidget(covariant _ProfileLessonsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessons.length != widget.lessons.length) {
      _loadGrades();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = <String, _LessonGradeEntry>{};
    for (final lesson in widget.lessons) {
      final backendResult = lesson.examResults.isNotEmpty
          ? lesson.examResults.first
          : null;
      final grade =
          backendResult?.grade ?? prefs.getString(_gradeValueKey(lesson.id));
      final happy =
          backendResult?.satisfied ?? prefs.getBool(_gradeHappyKey(lesson.id));
      if ((grade != null && grade.trim().isNotEmpty) || happy != null) {
        loaded[lesson.id] = _LessonGradeEntry(
          grade: grade?.trim() ?? '',
          happy: happy,
          failReason: backendResult?.failReason,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _grades
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _editGrade(Lesson lesson) async {
    final current = _grades[lesson.id];
    final gradeController = TextEditingController(text: current?.grade ?? '');
    bool? happy = current?.happy;
    String? failReason = lesson.examResults.isNotEmpty
        ? lesson.examResults.first.failReason
        : null;
    String aiComment = '';
    String? aiError;
    bool aiLoading = false;
    final lessonId = int.tryParse(lesson.id);
    final exam = _resultExamForLesson(lesson);

    Future<void> loadCoachComment(
      void Function(void Function()) setDialogState,
      BuildContext dialogContext,
    ) async {
      if (lessonId == null || exam == null || failReason == null) return;
      setDialogState(() {
        aiLoading = true;
        aiError = null;
        aiComment = '';
      });
      try {
        final saved = await ApiClient.saveExamResult(
          lessonId: lessonId,
          examId: exam.id,
          grade: gradeController.text.trim(),
          satisfied: false,
          failReason: failReason,
        );
        final resultId = (saved['id'] as num).toInt();
        final coach = await ApiClient.getExamResultCoachMessage(resultId);
        if (!dialogContext.mounted) return;
        setDialogState(() {
          final message = coach['message']?.toString().trim() ?? '';
          aiComment = message.isNotEmpty
              ? message
              : "I saved this reason. I'll take it into account in future plan insights using your pre-exam study and stress data.";
          aiLoading = false;
        });
      } catch (e) {
        if (!dialogContext.mounted) return;
        setDialogState(() {
          aiError = e.toString().replaceAll('Exception: ', '');
          aiLoading = false;
        });
      }
    }

    final result = await showDialog<_LessonGradeEntry?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: kSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 300),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        lesson.lessonName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: kText1,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: gradeController,
                        autofocus: true,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: TextStyle(
                          color: kText1,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Your grade',
                          hintText: '92',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _GradeMoodButton(
                              label: 'Yes',
                              icon: Icons.sentiment_satisfied_alt_rounded,
                              selected: happy == true,
                              onTap: () => setDialogState(() {
                                happy = true;
                                failReason = null;
                                aiComment = '';
                                aiError = null;
                              }),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _GradeMoodButton(
                              label: 'No',
                              icon: Icons.sentiment_dissatisfied_rounded,
                              selected: happy == false,
                              onTap: () => setDialogState(() => happy = false),
                            ),
                          ),
                        ],
                      ),
                      if (happy == false) ...[
                        SizedBox(height: 14),
                        Text(
                          'Why do you think it went poorly?',
                          style: TextStyle(
                            color: kText1,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        ..._examFailReasonOptions.map(
                          (option) => Padding(
                            padding: EdgeInsets.only(bottom: 7),
                            child: _FailReasonButton(
                              label: option.label,
                              selected: failReason == option.value,
                              onTap: () {
                                setDialogState(() => failReason = option.value);
                                loadCoachComment(setDialogState, dialogContext);
                              },
                            ),
                          ),
                        ),
                        if (aiLoading)
                          Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: kAccent,
                              backgroundColor: kBorder,
                            ),
                          ),
                        if (aiError != null)
                          Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              aiError!,
                              style: TextStyle(color: _kDanger, fontSize: 12),
                            ),
                          ),
                        if (aiComment.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: kAccent.withAlpha(22),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kAccent.withAlpha(60)),
                            ),
                            child: Text(
                              aiComment,
                              style: TextStyle(
                                color: kText1,
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                      SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(
                              dialogContext,
                              _LessonGradeEntry(
                                grade: gradeController.text.trim(),
                                happy: happy,
                                failReason: happy == false ? failReason : null,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: kAccent,
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    gradeController.dispose();
    if (result == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (result.isEmpty) {
      try {
        if (lessonId != null && exam != null) {
          await ApiClient.deleteExamResult(lessonId: lessonId, examId: exam.id);
        }
        await prefs.remove(_gradeValueKey(lesson.id));
        await prefs.remove(_gradeHappyKey(lesson.id));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _grades.remove(lesson.id));
      return;
    }

    try {
      if (lessonId != null && exam != null) {
        await ApiClient.saveExamResult(
          lessonId: lessonId,
          examId: exam.id,
          grade: result.grade,
          satisfied: result.happy,
          failReason: result.failReason,
        );
      }
      await prefs.setString(_gradeValueKey(lesson.id), result.grade);
      if (result.happy == null) {
        await prefs.remove(_gradeHappyKey(lesson.id));
      } else {
        await prefs.setBool(_gradeHappyKey(lesson.id), result.happy!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _grades[lesson.id] = result);
  }

  LessonExam? _resultExamForLesson(Lesson lesson) {
    if (lesson.exams.isEmpty) return null;
    final now = AppTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pastExams =
        lesson.exams.where((exam) {
          final parsed = DateTime.tryParse(exam.examDate);
          if (parsed == null) return false;
          return !_localDateOnly(parsed).isAfter(today);
        }).toList()..sort((a, b) {
          final aDate = _localDateOnly(DateTime.parse(a.examDate));
          final bDate = _localDateOnly(DateTime.parse(b.examDate));
          return bDate.compareTo(aDate);
        });
    return pastExams.isNotEmpty ? pastExams.first : lesson.exams.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 336,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: widget.lessons.isEmpty
          ? Center(
              child: Text(
                'No lessons added yet.',
                style: TextStyle(color: kText2, fontSize: 13),
              ),
            )
          : Scrollbar(
              controller: _scrollController,
              thumbVisibility: widget.lessons.length > 2,
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
                    grade: _grades[lesson.id],
                    onGradeTap: () => _editGrade(lesson),
                  );
                },
              ),
            ),
    );
  }
}

String _gradeValueKey(String lessonId) => 'profile_lesson_grade_$lessonId';

String _gradeHappyKey(String lessonId) =>
    'profile_lesson_grade_happy_$lessonId';

class _LessonGradeEntry {
  const _LessonGradeEntry({
    required this.grade,
    required this.happy,
    this.failReason,
  });

  final String grade;
  final bool? happy;
  final String? failReason;

  bool get isEmpty => grade.trim().isEmpty && happy == null;
}

class _ExamFailReasonOption {
  const _ExamFailReasonOption(this.value, this.label);

  final String value;
  final String label;
}

const _examFailReasonOptions = [
  _ExamFailReasonOption(
    'insufficient_preparation',
    'I could not prepare enough',
  ),
  _ExamFailReasonOption(
    'poor_unlessontanding',
    'I studied, but I did not fully understand the topic',
  ),
  _ExamFailReasonOption(
    'exam_anxiety',
    'I knew the material, but I felt exam anxiety',
  ),
  _ExamFailReasonOption(
    'time_management_in_exam',
    'I ran out of time during the exam',
  ),
  _ExamFailReasonOption('poor_sleep_before', 'I slept poorly before the exam'),
  _ExamFailReasonOption(
    'overwhelmed_by_workload',
    'The overall workload felt too heavy',
  ),
  _ExamFailReasonOption('lack_of_focus', 'I studied, but I could not focus'),
];

class _FailReasonButton extends StatelessWidget {
  const _FailReasonButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kAccent.withAlpha(36) : kBorder.withAlpha(34),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? kAccent : kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? kText1 : kText2,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProfileLessonRow extends StatelessWidget {
  const _ProfileLessonRow({
    required this.lesson,
    required this.daysToExam,
    required this.grade,
    required this.onGradeTap,
  });

  final Lesson lesson;
  final int? daysToExam;
  final _LessonGradeEntry? grade;
  final VoidCallback onGradeTap;

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
                        SizedBox(width: 8),
                        _GradeBadge(grade: grade, onTap: onGradeTap),
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
                icon: Icons.workspace_premium_outlined,
                label: 'Grade',
                value: grade?.grade.isNotEmpty == true ? grade!.grade : '—',
                sub: grade?.happy == null
                    ? null
                    : grade!.happy!
                    ? 'happy'
                    : 'not happy',
                tone: grade?.happy == false ? _kWarning : null,
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

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade, required this.onTap});

  final _LessonGradeEntry? grade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasGrade = grade != null && !grade!.isEmpty;
    final tone = grade?.happy == false ? _kWarning : kAccent;
    return Tooltip(
      message: 'Enter grade and satisfaction',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: hasGrade ? tone.withAlpha(28) : kBorder.withAlpha(34),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: hasGrade ? tone.withAlpha(80) : kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, size: 13, color: tone),
              SizedBox(width: 4),
              Text(
                hasGrade && grade!.grade.isNotEmpty ? grade!.grade : 'Grade',
                style: TextStyle(
                  color: hasGrade ? tone : kText2,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradeMoodButton extends StatelessWidget {
  const _GradeMoodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? kAccent.withAlpha(42) : kBorder.withAlpha(34),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kAccent : kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? kAccent : kText2, size: 18),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? kText1 : kText2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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

class _BusyIconChoice {
  const _BusyIconChoice(this.key, this.icon, this.tooltip);

  final String key;
  final IconData icon;
  final String tooltip;
}

const _busyIconChoices = [
  _BusyIconChoice('energy', Icons.bolt_outlined, 'Energy'),
  _BusyIconChoice('work', Icons.work_outline_rounded, 'Work'),
  _BusyIconChoice('commute', Icons.directions_bus_outlined, 'Yol'),
  _BusyIconChoice('health', Icons.local_hospital_outlined, 'Health'),
  _BusyIconChoice('family', Icons.home_outlined, 'Ev'),
];

class _ProfileAddLessonSheet extends StatefulWidget {
  const _ProfileAddLessonSheet();

  @override
  State<_ProfileAddLessonSheet> createState() => _ProfileAddLessonSheetState();
}

class _ProfileAddLessonSheetState extends State<_ProfileAddLessonSheet> {
  final _nameCtrl = TextEditingController();
  int _difficulty = 3;
  bool _hasExam = false;
  DateTime _examDate = AppTime.now().add(Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final created = await ApiClient.createLesson(name, _difficulty);
      if (_hasExam) {
        final lessonId = (created['id'] as num).toInt();
        await ApiClient.addExam(lessonId, _dateKey(_examDate));
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: _kDanger,
        ),
      );
    }
  }

  Future<void> _pickExamDate() async {
    final now = AppTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandle(),
            SizedBox(height: 18),
            _SheetTitle(
              icon: Icons.school_outlined,
              title: 'Add lesson',
              onClose: _saving ? null : () => Navigator.pop(context, false),
            ),
            SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Lesson name',
                hintText: 'Linear Algebra',
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Zorluk',
              style: TextStyle(
                color: kText1,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final value = i + 1;
                final selected = value == _difficulty;
                return Expanded(
                  child: GestureDetector(
                    onTap: _saving
                        ? null
                        : () => setState(() => _difficulty = value),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 150),
                      height: 44,
                      margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: selected ? kAccent.withAlpha(46) : kBorder,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? kAccent : Colors.transparent,
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$value',
                          style: TextStyle(
                            color: selected ? kAccent : kText2,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 16),
            SwitchListTile(
              value: _hasExam,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _hasExam = value),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kAccent,
              title: Text(
                'Add exam date',
                style: TextStyle(color: kText1, fontWeight: FontWeight.w700),
              ),
            ),
            if (_hasExam) ...[
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickExamDate,
                icon: Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_dateKey(_examDate)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kBorder),
                  padding: EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],
            SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
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
              label: Text(_saving ? 'Saving...' : 'Save'),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAddBusySlotSheet extends StatefulWidget {
  const _ProfileAddBusySlotSheet({required this.existingSlots});

  final List<_ProfileBusySlot> existingSlots;

  @override
  State<_ProfileAddBusySlotSheet> createState() =>
      _ProfileAddBusySlotSheetState();
}

class _ProfileAddBusySlotSheetState extends State<_ProfileAddBusySlotSheet> {
  int _dayOfWeek = AppTime.now().weekday;
  String _startTime = '09:00';
  String _endTime = '10:00';
  int _fatigueLevel = 2;
  String _iconKey = 'energy';
  bool _saving = false;
  String? _error;

  static final _timeOptions = List.generate(37, (i) {
    final minutes = 6 * 60 + i * 30;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  });

  int _toMinutes(String value) {
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  Future<void> _save() async {
    if (_toMinutes(_endTime) <= _toMinutes(_startTime)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final slots = widget.existingSlots.map((slot) => slot.toJson()).toList();
      slots.add({
        'dayOfWeek': _dayOfWeek,
        'startTime': _startTime,
        'endTime': _endTime,
        'fatigueLevel': _fatigueLevel,
        'iconKey': _iconKey,
        'isRoutine': true,
      });
      await ApiClient.updateBusySlots(slots);
      if (!mounted) return;
      Navigator.pop(context, true);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandle(),
            SizedBox(height: 18),
            _SheetTitle(
              icon: Icons.repeat_rounded,
              title: 'Add routine busy time',
              onClose: _saving ? null : () => Navigator.pop(context, false),
            ),
            SizedBox(height: 6),
            Text(
              'Repeats every week and affects planning for all weeks.',
              style: TextStyle(color: kText2, fontSize: 12),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _dayOfWeek,
              items: List.generate(7, (index) {
                final day = index + 1;
                return DropdownMenuItem(
                  value: day,
                  child: Text(_dayFullLabels[index]),
                );
              }),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _dayOfWeek = value ?? 1),
              decoration: InputDecoration(labelText: 'Day'),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _startTime,
                    items: _timeOptions
                        .map(
                          (time) =>
                              DropdownMenuItem(value: time, child: Text(time)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _startTime = value!),
                    decoration: InputDecoration(labelText: 'Start'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _endTime,
                    items: _timeOptions
                        .map(
                          (time) =>
                              DropdownMenuItem(value: time, child: Text(time)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _endTime = value!),
                    decoration: InputDecoration(labelText: 'End'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Yorgunluk',
                  style: TextStyle(
                    color: kText1,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _fatigueLevel.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _fatigueLevel.toString(),
                    activeColor: kAccent,
                    inactiveColor: kBorder,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _fatigueLevel = value.round()),
                  ),
                ),
                Text(
                  '$_fatigueLevel/5',
                  style: TextStyle(color: kText2, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Icon',
              style: TextStyle(
                color: kText1,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _busyIconChoices.map((choice) {
                final selected = choice.key == _iconKey;
                return Tooltip(
                  message: choice.tooltip,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _saving
                        ? null
                        : () => setState(() => _iconKey = choice.key),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? kAccent.withAlpha(appTheme.isLight ? 34 : 48)
                            : kBorder.withAlpha(appTheme.isLight ? 42 : 56),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? kAccent : kBorder,
                          width: selected ? 1.4 : 0.8,
                        ),
                      ),
                      child: Icon(
                        choice.icon,
                        color: selected ? kAccent : kText2,
                        size: 20,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: _kDanger, fontSize: 12)),
            ],
            SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
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
              label: Text(_saving ? 'Saving...' : 'Save'),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: kBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({
    required this.icon,
    required this.title,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kAccent.withAlpha(34),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kAccent, size: 20),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: kText1,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Close',
          icon: Icon(Icons.close_rounded, color: kText2, size: 20),
        ),
      ],
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

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatTodayLabel(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return '${date.day} ${_monthNames[date.month - 1]} ${_dayNames[date.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    // history öğelerini haftalar halinde grupla (Monday başlangıçlı)
    // İlk öğenin hangi gün olduğunu bul
    final weeks = <List<Map<String, dynamic>?>>[];
    if (history.isEmpty) return const SizedBox.shrink();

    final todayStr = AppTime.todayStr();
    final todayDate = DateTime.tryParse(todayStr);
    final todayWeekdayIndex = todayDate == null ? -1 : todayDate.weekday - 1;
    final firstDate = DateTime.parse(history.first['date'] as String);
    // Monday = 1, önceki günleri null ile doldur
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
                  'Today: ${_formatTodayLabel(todayStr)}',
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
          // Weeklar
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
              Text('Completed', style: TextStyle(color: kText2, fontSize: 11)),
              SizedBox(width: 14),
              _LegendDot(color: const Color(0xFFFF5C7A)),
              SizedBox(width: 4),
              Text(
                'Not entered',
                style: TextStyle(color: kText2, fontSize: 11),
              ),
              SizedBox(width: 14),
              _LegendDot(color: kBorder),
              SizedBox(width: 4),
              Text('Empty day', style: TextStyle(color: kText2, fontSize: 11)),
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
              'Today',
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
                    'Today',
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
