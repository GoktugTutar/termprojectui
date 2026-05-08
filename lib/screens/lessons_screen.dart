import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/lesson_model.dart';
import '../theme.dart';

const _kDanger  = Color(0xFFFF5C7A);
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
        _lessons = raw
            .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
            .toList()
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LessonSheet(lesson: lesson, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: kAccent))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: kAccent,
                          backgroundColor: kSurface,
                          child: _lessons.isEmpty
                              ? _buildEmpty()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 8, 20, 100),
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
        child: const Icon(Icons.add, color: kBg),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 4 · Step 6',
              style: TextStyle(
                  color: kText2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 6),
          const Text('Lessons',
              style: TextStyle(
                  color: kText1,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            '${_lessons.length} active · weight & priority computed weekly',
            style: const TextStyle(color: kText2, fontSize: 14),
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
          const Icon(Icons.book_outlined, color: kText2, size: 48),
          const SizedBox(height: 12),
          const Text('No lessons yet',
              style: TextStyle(
                  color: kText1,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Tap + to add your first lesson.',
              style: TextStyle(color: kText2)),
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

    final totalDelay =
        lesson.keyfiDelayCount + lesson.zorunluDelayCount;

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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
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
                          letterSpacing: -0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.lessonName,
                          style: const TextStyle(
                              color: kText1,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _DiffBars(
                              difficulty: lesson.difficulty,
                              color: color),
                          const SizedBox(width: 8),
                          Text(
                            'difficulty ${lesson.difficulty}',
                            style: const TextStyle(
                                color: kText2, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(priority,
                        style: TextStyle(
                            color: priorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4)),
                    if (daysToExam != null)
                      Text('${daysToExam!.clamp(0, 9999)}d to exam',
                          style: const TextStyle(
                              color: kText2,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
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
          margin: const EdgeInsets.only(right: 2),
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
              const SizedBox(width: 5),
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: kText2,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: tone ?? kText1,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(
                    color: kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
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
  DateTime _examDate =
      DateTime.now().add(const Duration(days: 14));

  bool get _isEdit => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.lesson!.lessonName;
      _difficulty = widget.lesson!.difficulty;
      if (widget.lesson!.exams.isNotEmpty) _hasExam = true;
    }
  }

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
      if (_isEdit) {
        await ApiClient.updateLesson(
          int.parse(widget.lesson!.id),
          name: name,
          difficulty: _difficulty,
        );
      } else {
        final created = await ApiClient.createLesson(name, _difficulty);
        if (_hasExam) {
          final lessonId = (created['id'] as num).toInt();
          await ApiClient.addExam(
            lessonId,
            _examDate.toIso8601String().substring(0, 10),
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Delete lesson',
            style: TextStyle(color: kText1)),
        content: Text(
          'Delete "${widget.lesson!.lessonName}"?',
          style: const TextStyle(color: kText2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: kText2)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: _kDanger),
            child: const Text('Delete'),
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
            // Sheet head
            Row(
              children: [
                Text(
                  _isEdit ? 'Edit lesson' : 'New lesson',
                  style: const TextStyle(
                      color: kText1,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: kBorder,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        size: 16, color: kText2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Name field
            const Text('Name',
                style: TextStyle(color: kText2, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: kText1),
              decoration: InputDecoration(
                hintText: 'e.g. Linear Algebra',
                hintStyle: const TextStyle(color: kText2),
                filled: true,
                fillColor: kBorder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Difficulty
            const Text('Difficulty · 1 easy – 5 brutal',
                style: TextStyle(color: kText2, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final n = i + 1;
                final selected = n == _difficulty;
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _difficulty = n),
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 150),
                      height: 46,
                      margin: EdgeInsets.only(
                          right: i < 4 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: selected
                            ? kAccent.withAlpha(46)
                            : kBorder,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? kAccent
                              : Colors.transparent,
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$n',
                          style: TextStyle(
                            color: selected
                                ? kAccent
                                : kText2,
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
            const SizedBox(height: 20),
            // Exam
            const Text('Exam scheduled',
                style: TextStyle(color: kText2, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _hasExam = !_hasExam),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 30,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                    decoration: BoxDecoration(
                      color: _hasExam ? kAccent : kBorder,
                      borderRadius:
                          BorderRadius.circular(999),
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
                  const SizedBox(width: 8),
                  Expanded(child: _buildDatePicker()),
                ],
              ],
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _delete,
                child: Container(
                  width: double.infinity,
                  height: 46,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _kDanger.withAlpha(100)),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.delete_outline,
                          size: 14, color: _kDanger),
                      SizedBox(width: 6),
                      Text('Delete lesson',
                          style: TextStyle(
                              color: _kDanger,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Text('Save',
                        style: TextStyle(
                            fontWeight: FontWeight.w600)),
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
            data: Theme.of(ctx).copyWith(
              colorScheme:
                  const ColorScheme.dark(primary: kAccent),
            ),
            child: child!,
          ),
        );
        if (d != null) setState(() => _examDate = d);
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kBorder,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: kAccent),
            const SizedBox(width: 10),
            Text(
              _examDate.toIso8601String().substring(0, 10),
              style: const TextStyle(
                  color: kText1, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
