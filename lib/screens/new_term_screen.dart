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

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddLessonSheet(onSaved: _loadLessons),
    );
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
          'Yeni Dönem',
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
                        'YENİ DÖNEM',
                        style: TextStyle(
                          color: kText2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Derslerini Ekle',
                        style: TextStyle(
                          color: kText1,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bu dönemde alacağın dersleri tek tek ekle.',
                        style: TextStyle(color: kText2, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(color: kAccent),
                        )
                      : _lessons.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: _lessons.length,
                          itemBuilder: (ctx, i) =>
                              _LessonRow(lesson: _lessons[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _termStarted
          ? FloatingActionButton(
              onPressed: _openAddSheet,
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
                _lessons.isEmpty ? 'Daha sonra ekle' : 'Tamamlandı',
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
            'Henüz ders eklenmedi',
            style: TextStyle(
              color: kText1,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sağ alttaki + butonuna bas.',
            style: TextStyle(color: kText2, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Ders satırı ────────────────────────────────────────────────────────────────

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
            child: Text(
              name,
              style: TextStyle(
                color: kText1,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
}

// ── Ders ekleme sayfası ────────────────────────────────────────────────────────

class _AddLessonSheet extends StatefulWidget {
  const _AddLessonSheet({required this.onSaved});

  final VoidCallback onSaved;

  @override
  State<_AddLessonSheet> createState() => _AddLessonSheetState();
}

class _AddLessonSheetState extends State<_AddLessonSheet> {
  final _nameCtrl = TextEditingController();
  int _difficulty = 3;
  bool _hasExam = false;
  DateTime _examDate = DateTime.now().add(const Duration(days: 30));
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
        await ApiClient.addExam(
          lessonId,
          _examDate.toIso8601String().substring(0, 10),
        );
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Ders Ekle',
                  style: TextStyle(
                    color: kText1,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
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
            const SizedBox(height: 20),
            Text('Ders adı', style: TextStyle(color: kText2, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: TextStyle(color: kText1),
              decoration: InputDecoration(
                hintText: 'örn. Lineer Cebir',
                hintStyle: TextStyle(color: kText2),
                filled: true,
                fillColor: kBorder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Zorluk · 1 kolay – 5 çok zor',
              style: TextStyle(color: kText2, fontSize: 13),
            ),
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
                      height: 46,
                      margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: selected ? kAccent.withAlpha(46) : kBorder,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              selected ? kAccent : Colors.transparent,
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
            const SizedBox(height: 20),
            Text(
              'Sınav var mı?',
              style: TextStyle(color: kText2, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _hasExam = !_hasExam),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _hasExam ? kAccent : kBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        _hasExam ? 'EVET' : 'HAYIR',
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
                  Expanded(child: _buildExamDatePicker()),
                ],
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Kaydet',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamDatePicker() {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _examDate,
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.dark(primary: kAccent),
            ),
            child: child!,
          ),
        );
        if (d != null) setState(() => _examDate = d);
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kBorder,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 13, color: kAccent),
            const SizedBox(width: 6),
            Text(
              _examDate.toIso8601String().substring(0, 10),
              style: TextStyle(
                color: kText1,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
