import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/lesson_model.dart';
import '../theme.dart';

const _kDanger = Color(0xFFFF5C7A);
const _kWarning = Color(0xFFF2B14A);

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
      final raw = await ApiClient.getLessons();
      if (!mounted) return;
      setState(() {
        _lessons =
            raw.map((l) => Lesson.fromJson(l as Map<String, dynamic>)).toList()
              ..sort((a, b) {
                final ua = _daysToExam(a) ?? 9999;
                final ub = _daysToExam(b) ?? 9999;
                return ua.compareTo(ub);
              });
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int? _daysToExam(Lesson l) {
    int? best;
    final now = DateTime.now();
    for (final e in l.exams) {
      try {
        final d = DateTime.parse(e.examDate);
        final diff = d.difference(now).inDays;
        if (best == null || diff < best) best = diff;
      } catch (_) {}
    }
    return best;
  }

  void _openSheet({Lesson? lesson}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LessonSheet(lesson: lesson, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: kAccent))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: kAccent,
                          backgroundColor: kSurface,
                          child: _lessons.isEmpty
                              ? _buildEmpty()
                              : ListView.builder(
                                  padding: EdgeInsets.fromLTRB(20, 8, 20, 100),
                                  itemCount: _lessons.length,
                                  itemBuilder: (ctx, i) => _LessonCard(
                                    lesson: _lessons[i],
                                    daysToExam: _daysToExam(_lessons[i]),
                                    onOpen: () =>
                                        _openSheet(lesson: _lessons[i]),
                                  ),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSheet(),
        backgroundColor: kAccent,
        child: Icon(Icons.add, color: kBg),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 4 · Step 6',
            style: TextStyle(
              color: kText2,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Lessons',
            style: TextStyle(
              color: kText1,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '${_lessons.length} active · weight & priority computed weekly',
            style: TextStyle(color: kText2, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, color: kText2, size: 48),
          SizedBox(height: 12),
          Text(
            'No lessons yet',
            style: TextStyle(
              color: kText1,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Tap + to add your first lesson.',
            style: TextStyle(color: kText2),
          ),
        ],
      ),
    );
  }
}

// ── Lesson card ───────────────────────────────────────────────────────────────

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.daysToExam,
    required this.onOpen,
  });

  final Lesson lesson;
  final int? daysToExam;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(lesson.id) ?? 0;
    final color = lessonColor(id);

    // Initials: first letter of each word, max 2
    final initials = lesson.lessonName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .take(2)
        .join('');

    // Priority
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

    final totalDelay = lesson.keyfiDelayCount + lesson.zorunluDelayCount;

    // Exam date string
    String examValue = '—';
    if (daysToExam != null && lesson.exams.isNotEmpty) {
      examValue = lesson.exams.first.dateOnly;
    }

    final needsMoreStr = lesson.needsMoreTime == 1
        ? '+1'
        : lesson.needsMoreTime == -1
        ? '–1'
        : '0';

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
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
                // Initials avatar
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
                      initials,
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
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          _DiffBars(
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
                _Pico(
                  icon: Icons.calendar_today_outlined,
                  label: 'Exam',
                  value: examValue,
                ),
                _Pico(
                  icon: Icons.repeat,
                  label: 'Delays',
                  value: '$totalDelay',
                  sub: lesson.keyfiDelayCount > 0 ? 'slot mode' : null,
                  tone: totalDelay >= 3 ? _kWarning : null,
                ),
                _Pico(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Need more',
                  value: needsMoreStr,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffBars extends StatelessWidget {
  const _DiffBars({required this.difficulty, required this.color});

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

class _Pico extends StatelessWidget {
  const _Pico({
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
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: kText2,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
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
          ),
          if (sub != null)
            Text(
              sub!,
              style: TextStyle(
                color: kAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Deadline entry / chip helpers ────────────────────────────────────────────

class _DeadlineEntry {
  _DeadlineEntry({required this.title, required this.date});
  final String title;
  final DateTime date;
}

class _DeadlineChip extends StatelessWidget {
  const _DeadlineChip({
    required this.label,
    this.sub,
    required this.onDelete,
    this.pending = false,
  });
  final String label;
  final String? sub;
  final VoidCallback onDelete;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pending ? kAccent.withAlpha(20) : kBorder,
        borderRadius: BorderRadius.circular(10),
        border: pending
            ? Border.all(color: kAccent.withAlpha(80), width: 0.5)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 14,
            color: pending ? kAccent : kText2,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: pending ? kAccent : kText1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null)
                  Text(sub!, style: TextStyle(color: kText2, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close, size: 14, color: kText2),
          ),
        ],
      ),
    );
  }
}

// ── Lesson sheet ──────────────────────────────────────────────────────────────

class _LessonSheet extends StatefulWidget {
  const _LessonSheet({this.lesson, required this.onSaved});

  final Lesson? lesson;
  final VoidCallback onSaved;

  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet> {
  final _nameCtrl = TextEditingController();
  int _difficulty = 3;
  bool _saving = false;
  bool _hasExam = false;
  DateTime _examDate = DateTime.now().add(Duration(days: 14));
  List<LessonDeadline> _existingDeadlines = [];
  final List<_DeadlineEntry> _pendingDeadlines = [];
  bool _showDeadlineForm = false;
  final _deadlineTitleCtrl = TextEditingController();
  DateTime _deadlineDate = DateTime.now().add(Duration(days: 7));

  bool get _isEdit => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.lesson!.lessonName;
      _difficulty = widget.lesson!.difficulty;
      if (widget.lesson!.exams.isNotEmpty) _hasExam = true;
      _existingDeadlines = List.from(widget.lesson!.deadlines);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _deadlineTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final lessonId = int.parse(widget.lesson!.id);
        await ApiClient.updateLesson(
          lessonId,
          name: name,
          difficulty: _difficulty,
        );
        for (final pd in _pendingDeadlines) {
          await ApiClient.addDeadline(
            lessonId,
            pd.date.toIso8601String().substring(0, 10),
            title: pd.title.isNotEmpty ? pd.title : null,
          );
        }
      } else {
        final created = await ApiClient.createLesson(name, _difficulty);
        final lessonId = (created['id'] as num).toInt();
        if (_hasExam) {
          await ApiClient.addExam(
            lessonId,
            _examDate.toIso8601String().substring(0, 10),
          );
        }
        for (final pd in _pendingDeadlines) {
          await ApiClient.addDeadline(
            lessonId,
            pd.date.toIso8601String().substring(0, 10),
            title: pd.title.isNotEmpty ? pd.title : null,
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
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

  Future<void> _delete() async {
    if (!_isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: Text('Delete lesson', style: TextStyle(color: kText1)),
        content: Text(
          'Delete "${widget.lesson!.lessonName}"?',
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
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.deleteLesson(int.parse(widget.lesson!.id));
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteExistingDeadline(LessonDeadline d) async {
    try {
      await ApiClient.deleteDeadline(int.parse(widget.lesson!.id), d.id);
      setState(() => _existingDeadlines.remove(d));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            // Sheet head
            Row(
              children: [
                Text(
                  _isEdit ? 'Edit lesson' : 'New lesson',
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
            SizedBox(height: 20),
            // Name field
            Text('Name', style: TextStyle(color: kText2, fontSize: 13)),
            SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: kText1),
              decoration: InputDecoration(
                hintText: 'e.g. Linear Algebra',
                hintStyle: TextStyle(color: kText2),
                filled: true,
                fillColor: kBorder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),
            // Difficulty
            Text(
              'Difficulty · 1 easy – 5 brutal',
              style: TextStyle(color: kText2, fontSize: 13),
            ),
            SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final n = i + 1;
                final selected = n == _difficulty;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _difficulty = n),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 150),
                      height: 46,
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
                          '$n',
                          style: TextStyle(
                            color: selected ? kAccent : kText2,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 20),
            // Exam
            Text(
              'Exam scheduled',
              style: TextStyle(color: kText2, fontSize: 13),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _hasExam = !_hasExam),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 150),
                    height: 30,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _hasExam ? kAccent : kBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        _hasExam ? 'YES' : 'NO',
                        style: TextStyle(
                          color: _hasExam ? kBg : kText2,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hasExam) ...[
                  SizedBox(width: 8),
                  Expanded(child: _buildDatePicker()),
                ],
              ],
            ),
            SizedBox(height: 20),
            _buildDeadlinesSection(),
            if (_isEdit) ...[
              SizedBox(height: 8),
              GestureDetector(
                onTap: _delete,
                child: Container(
                  width: double.infinity,
                  height: 46,
                  margin: EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kDanger.withAlpha(100)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 14, color: _kDanger),
                      SizedBox(width: 6),
                      Text(
                        'Delete lesson',
                        style: TextStyle(
                          color: _kDanger,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
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
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _examDate,
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(
              ctx,
            ).copyWith(colorScheme: ColorScheme.dark(primary: kAccent)),
            child: child!,
          ),
        );
        if (d != null) setState(() => _examDate = d);
      },
      child: Container(
        height: 46,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kBorder,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: kAccent),
            SizedBox(width: 10),
            Text(
              _examDate.toIso8601String().substring(0, 10),
              style: TextStyle(color: kText1, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlinesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deadlines / Homework',
          style: TextStyle(color: kText2, fontSize: 13),
        ),
        SizedBox(height: 8),
        if (_existingDeadlines.isNotEmpty) ...[
          ..._existingDeadlines.map(
            (d) => _DeadlineChip(
              label: (d.title != null && d.title!.isNotEmpty)
                  ? d.title!
                  : d.dateOnly,
              sub: (d.title != null && d.title!.isNotEmpty) ? d.dateOnly : null,
              onDelete: () => _deleteExistingDeadline(d),
            ),
          ),
          SizedBox(height: 4),
        ],
        if (_pendingDeadlines.isNotEmpty) ...[
          ..._pendingDeadlines.asMap().entries.map(
            (e) => _DeadlineChip(
              label: e.value.title.isNotEmpty
                  ? e.value.title
                  : e.value.date.toIso8601String().substring(0, 10),
              sub: e.value.title.isNotEmpty
                  ? e.value.date.toIso8601String().substring(0, 10)
                  : null,
              onDelete: () => setState(() => _pendingDeadlines.removeAt(e.key)),
              pending: true,
            ),
          ),
          SizedBox(height: 4),
        ],
        if (_showDeadlineForm)
          _buildDeadlineForm()
        else
          GestureDetector(
            onTap: () => setState(() => _showDeadlineForm = true),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withAlpha(80), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 14, color: kAccent),
                  SizedBox(width: 6),
                  Text(
                    'Add deadline',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeadlineForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _deadlineTitleCtrl,
          style: TextStyle(color: kText1),
          decoration: InputDecoration(
            hintText: 'Title (optional) · e.g. "Project 2"',
            hintStyle: TextStyle(color: kText2),
            filled: true,
            fillColor: kBorder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        SizedBox(height: 8),
        _buildDeadlineDatePicker(),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _showDeadlineForm = false;
                  _deadlineTitleCtrl.clear();
                }),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: kText2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _pendingDeadlines.add(
                    _DeadlineEntry(
                      title: _deadlineTitleCtrl.text.trim(),
                      date: _deadlineDate,
                    ),
                  );
                  _showDeadlineForm = false;
                  _deadlineTitleCtrl.clear();
                  _deadlineDate = DateTime.now().add(Duration(days: 7));
                }),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: kAccent.withAlpha(46),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kAccent, width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      'Add',
                      style: TextStyle(
                        color: kAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeadlineDatePicker() {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _deadlineDate,
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(
              ctx,
            ).copyWith(colorScheme: ColorScheme.dark(primary: kAccent)),
            child: child!,
          ),
        );
        if (d != null) setState(() => _deadlineDate = d);
      },
      child: Container(
        height: 46,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kBorder,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 16, color: kAccent),
            SizedBox(width: 10),
            Text(
              _deadlineDate.toIso8601String().substring(0, 10),
              style: TextStyle(color: kText1, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
