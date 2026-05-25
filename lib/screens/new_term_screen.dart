import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../theme.dart';

class NewTermScreen extends StatefulWidget {
  const NewTermScreen({super.key});

  @override
  State<NewTermScreen> createState() => _NewTermScreenState();
}

class _NewTermScreenState extends State<NewTermScreen> {
  List<Map<String, dynamic>> _lessons = [];
  bool _loading = true;
  bool _termStarted = false;
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _initTerm();
  }

  Future<void> _initTerm() async {
    try {
      await ApiClient.startTerm();
      if (!mounted) return;
      setState(() => _termStarted = true);
      await _loadLessons();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadLessons() async {
    setState(() => _loading = true);
    try {
      final raw = await ApiClient.getLessons();
      if (!mounted) return;
      setState(() {
        _lessons = raw.map((l) => Map<String, dynamic>.from(l as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openAddForm() => setState(() => _showAddForm = true);

  Future<void> _handleLessonSaved() async {
    setState(() => _showAddForm = false);
    await _loadLessons();
  }

  void _done() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: kText1, size: 18),
          onPressed: _done,
        ),
        title: Text(
          'New Term',
          style: TextStyle(
            color: kText1,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEW TERM',
                        style: TextStyle(
                          color: kText2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add Lessons',
                        style: TextStyle(
                          color: kText1,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add the lessons you will take this term one by one.',
                        style: TextStyle(color: kText2, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: kAccent))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          children: [
                            if (_showAddForm)
                              _AddLessonForm(
                                onSaved: _handleLessonSaved,
                                onCancel: () =>
                                    setState(() => _showAddForm = false),
                              )
                            else if (_lessons.isEmpty)
                              _buildEmpty(),
                            if (_showAddForm && _lessons.isNotEmpty)
                              const SizedBox(height: 18),
                            if (_lessons.isNotEmpty) ...[
                              Text(
                                'Lessons',
                                style: TextStyle(
                                  color: kText2,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._lessons.map((lesson) {
                                return _LessonRow(lesson: lesson);
                              }),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _termStarted
          ? FloatingActionButton(
              onPressed: _showAddForm ? null : _openAddForm,
              backgroundColor: kAccent,
              child: Icon(Icons.add, color: kBg),
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _done,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _lessons.isEmpty ? 'Add later' : 'Completed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, color: kText2, size: 52),
          const SizedBox(height: 14),
          Text(
            'No lessons added yet',
            style: TextStyle(
              color: kText1,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add your first lesson.',
            style: TextStyle(color: kText2, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Lesson satırı ────────────────────────────────────────────────────────────────

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson});

  final Map<String, dynamic> lesson;

  static const _colors = [
    Color(0xFF4E9FFF),
    Color(0xFF7C6FFF),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFBE0B),
    Color(0xFF06D6A0),
  ];

  @override
  Widget build(BuildContext context) {
    final id = (lesson['id'] as num?)?.toInt() ?? 0;
    final color = _colors[id % _colors.length];
    final name = lesson['name']?.toString() ?? '';
    final difficulty = (lesson['difficulty'] as num?)?.toInt() ?? 1;
    final exams = (lesson['exams'] as List?) ?? const [];
    final deadlines = (lesson['deadlines'] as List?) ?? const [];
    final importantCount = exams.length + deadlines.length;
    final firstImportantDate = _firstImportantDate(exams, deadlines);

    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .take(2)
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: kText1,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (importantCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    firstImportantDate == null
                        ? '$importantCount important date'
                        : '$importantCount important date · $firstImportantDate',
                    style: TextStyle(color: kText2, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: List.generate(5, (i) {
              return Container(
                width: 3,
                height: 6.0 + i * 2,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: i < difficulty ? color : kBorder,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String? _firstImportantDate(List<dynamic> exams, List<dynamic> deadlines) {
    final dates = <String>[];
    for (final item in exams) {
      if (item is Map && item['examDate'] != null) {
        dates.add(item['examDate'].toString());
      }
    }
    for (final item in deadlines) {
      if (item is Map && item['deadlineDate'] != null) {
        dates.add(item['deadlineDate'].toString());
      }
    }
    dates.sort();
    if (dates.isEmpty) return null;
    final value = dates.first;
    return value.length >= 10 ? value.substring(0, 10) : value;
  }
}

// ── Add lessonme sayfası ────────────────────────────────────────────────────────

enum _ImportantDateType { exam, deadline }

class _ImportantDateDraft {
  _ImportantDateDraft({required this.type, required this.date, String? title})
    : titleCtrl = TextEditingController(text: title ?? '');

  _ImportantDateType type;
  DateTime date;
  final TextEditingController titleCtrl;

  void dispose() => titleCtrl.dispose();
}

class _AddLessonForm extends StatefulWidget {
  const _AddLessonForm({required this.onSaved, required this.onCancel});

  final Future<void> Function() onSaved;
  final VoidCallback onCancel;

  @override
  State<_AddLessonForm> createState() => _AddLessonFormState();
}

class _AddLessonFormState extends State<_AddLessonForm> {
  final _nameCtrl = TextEditingController();
  int _difficulty = 3;
  final List<_ImportantDateDraft> _importantDates = [
    _ImportantDateDraft(
      type: _ImportantDateType.exam,
      date: DateTime.now().add(const Duration(days: 30)),
    ),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final item in _importantDates) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Lesson name cannot be empty.');
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await ApiClient.createLesson(name, _difficulty);
      final lessonId = (created['id'] as num).toInt();
      for (final item in _importantDates) {
        final date = item.date.toIso8601String().substring(0, 10);
        if (item.type == _ImportantDateType.exam) {
          await ApiClient.addExam(lessonId, date);
        } else {
          await ApiClient.addDeadline(
            lessonId,
            date,
            title: item.titleCtrl.text.trim(),
          );
        }
      }
      if (!mounted) return;
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _addImportantDate(_ImportantDateType type) {
    setState(() {
      _importantDates.add(
        _ImportantDateDraft(
          type: type,
          date: DateTime.now().add(
            Duration(days: type == _ImportantDateType.exam ? 30 : 7),
          ),
        ),
      );
    });
  }

  void _addDefaultImportantDate() => _addImportantDate(_ImportantDateType.exam);

  void _removeImportantDate(int index) {
    final removed = _importantDates.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
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
              Text(
                'Add lesson',
                style: TextStyle(
                  color: kText1,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _saving ? null : widget.onCancel,
                icon: Icon(Icons.close_rounded, color: kText2, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: kBorder.withAlpha(80),
                  minimumSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: TextStyle(color: kText1),
            decoration: InputDecoration(
              labelText: 'Lesson name',
              hintText: 'e.g. Linear Algebra',
              filled: true,
              fillColor: kBg.withAlpha(120),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kAccent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Difficulty', style: TextStyle(color: kText2, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final n = i + 1;
              final selected = n == _difficulty;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _difficulty = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: selected
                          ? kAccent.withAlpha(34)
                          : kBg.withAlpha(120),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? kAccent : kBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: selected ? kAccent : kText2,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Important dates',
                style: TextStyle(color: kText2, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _saving ? null : _addDefaultImportantDate,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add date'),
                style: TextButton.styleFrom(
                  foregroundColor: kAccent,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_importantDates.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBg.withAlpha(90),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Text(
                'No important dates yet.',
                style: TextStyle(color: kText2, fontSize: 13),
              ),
            )
          else
            ...List.generate(_importantDates.length, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _importantDates.length - 1 ? 0 : 8,
                ),
                child: _ImportantDateRow(
                  item: _importantDates[index],
                  onChanged: () => setState(() {}),
                  onPickDate: () => _pickDate(index),
                  onRemove: () => _removeImportantDate(index),
                ),
              );
            }),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kText2,
                    side: BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(int index) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _importantDates[index].date,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.dark(primary: kAccent)),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() => _importantDates[index].date = d);
    }
  }
}

class _ImportantDateRow extends StatelessWidget {
  const _ImportantDateRow({
    required this.item,
    required this.onChanged,
    required this.onPickDate,
    required this.onRemove,
  });

  final _ImportantDateDraft item;
  final VoidCallback onChanged;
  final VoidCallback onPickDate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isExam = item.type == _ImportantDateType.exam;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBorder.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_ImportantDateType>(
                  segments: const [
                    ButtonSegment(
                      value: _ImportantDateType.exam,
                      icon: Icon(Icons.school_outlined, size: 16),
                      label: Text('Exam'),
                    ),
                    ButtonSegment(
                      value: _ImportantDateType.deadline,
                      icon: Icon(Icons.assignment_outlined, size: 16),
                      label: Text('Deadline'),
                    ),
                  ],
                  selected: {item.type},
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) =>
                          states.contains(WidgetState.selected) ? kBg : kText2,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? kAccent
                          : kSurface,
                    ),
                    side: WidgetStateProperty.all(BorderSide(color: kBorder)),
                  ),
                  onSelectionChanged: (value) {
                    item.type = value.first;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, color: kText2, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPickDate,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: kAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.date.toIso8601String().substring(0, 10),
                          style: TextStyle(
                            color: kText1,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isExam) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item.titleCtrl,
                    style: TextStyle(color: kText1, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Project deadline',
                      hintStyle: TextStyle(color: kText2, fontSize: 12),
                      filled: true,
                      fillColor: kSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kAccent),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
