import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../theme.dart';
import 'main_scaffold.dart';

const _kDanger = Color(0xFFFF5C7A);

// Gün isimleri
const _dayLabels = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Ana ekran ─────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0=dersler, 1=busy times
  bool _initLoading = true;
  List<Map<String, dynamic>> _lessons = [];
  List<Map<String, dynamic>> _busySlots = [];
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _initTerm();
  }

  Future<void> _initTerm() async {
    try {
      await ApiClient.startTerm();
      if (!mounted) return;
      await _reloadLessons();
    } catch (e) {
      if (!mounted) return;
      setState(() => _initLoading = false);
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _reloadLessons() async {
    setState(() => _initLoading = true);
    try {
      final raw = await ApiClient.getLessons();
      if (!mounted) return;
      setState(() {
        _lessons = raw.map((l) => Map<String, dynamic>.from(l as Map)).toList();
        _initLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initLoading = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      if (_busySlots.isNotEmpty) {
        await ApiClient.updateBusySlots(_busySlots);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _kDanger : null,
      ),
    );
  }

  void _openAddLesson() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OnboardingLessonSheet(onSaved: _reloadLessons),
    );
  }

  void _openAddBusy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OnboardingBusySheet(
        onSaved: (slot) => setState(() => _busySlots.add(slot)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _StepBar(step: _step),
            Expanded(
              child: _step == 0 ? _buildLessonsStep() : _buildBusyStep(),
            ),
            _buildBottom(),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Dersler ──────────────────────────────────────────────────────────

  Widget _buildLessonsStep() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1 / 2',
                    style: TextStyle(
                      color: kText2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Derslerini ekle',
                    style: TextStyle(
                      color: kText1,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bu dönemde çalışacağın dersleri gir. Zorluk derecesi planlama algoritmasını etkiler.',
                    style: TextStyle(color: kText2, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _initLoading
                  ? Center(child: CircularProgressIndicator(color: kAccent))
                  : _lessons.isEmpty
                  ? _buildLessonsEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _lessons.length,
                      itemBuilder: (_, i) => _OnboardingLessonRow(lesson: _lessons[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonsEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, color: kText2, size: 52),
          const SizedBox(height: 14),
          Text(
            'Henüz ders eklenmedi',
            style: TextStyle(color: kText1, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Aşağıdaki butona basarak ders ekle.',
            style: TextStyle(color: kText2, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Busy times ───────────────────────────────────────────────────────

  Widget _buildBusyStep() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2 / 2',
                    style: TextStyle(
                      color: kText2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Meşgul zamanlarını ekle',
                    style: TextStyle(
                      color: kText1,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Her hafta tekrar eden meşgul saatlerini gir. Algoritma ders bloklarını bu saatlerin dışına yerleştirir.',
                    style: TextStyle(color: kText2, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _busySlots.isEmpty
                  ? _buildBusyEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _busySlots.length,
                      itemBuilder: (_, i) => _OnboardingBusyRow(slot: _busySlots[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusyEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_outlined, color: kText2, size: 52),
          const SizedBox(height: 14),
          Text(
            'Meşgul zaman eklenmedi',
            style: TextStyle(color: kText1, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Yoksa daha sonra profilden ekleyebilirsin.',
            style: TextStyle(color: kText2, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────────

  Widget _buildBottom() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          // Ders/busy ekle butonu
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _initLoading ? null : (_step == 0 ? _openAddLesson : _openAddBusy),
              icon: Icon(Icons.add_rounded, size: 18),
              label: Text(_step == 0 ? 'Ders ekle' : 'Meşgul zaman ekle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kAccent,
                side: BorderSide(color: kAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // İleri / Başla butonu
          Expanded(
            child: FilledButton(
              onPressed: (_initLoading || _finishing)
                  ? null
                  : (_step == 0 ? () => setState(() => _step = 1) : _finish),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _step == 0
                          ? (_lessons.isEmpty ? 'Geç' : 'İleri')
                          : (_busySlots.isEmpty ? 'Atla' : 'Başla'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _StepDot(active: true, done: step > 0, label: 'Dersler'),
          _StepLine(active: step >= 1),
          _StepDot(active: step >= 1, done: false, label: 'Meşgul zamanlar'),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active, required this.done, required this.label});
  final bool active;
  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = active ? kAccent : kBorder;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? kAccent : kSurface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 13, color: Colors.white)
              : active
              ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)))
              : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: active ? kText1 : kText2, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 2,
          color: active ? kAccent : kBorder,
        ),
      ),
    );
  }
}

// ── Ders satırı (onboarding) ───────────────────────────────────────────────────

class _OnboardingLessonRow extends StatelessWidget {
  const _OnboardingLessonRow({required this.lesson});
  final Map<String, dynamic> lesson;

  static const _colors = [
    Color(0xFF4E9FFF), Color(0xFF7C6FFF), Color(0xFFFF6B6B),
    Color(0xFF4ECDC4), Color(0xFFFFBE0B), Color(0xFF06D6A0),
  ];

  @override
  Widget build(BuildContext context) {
    final id = (lesson['id'] as num?)?.toInt() ?? 0;
    final color = _colors[id % _colors.length];
    final name = lesson['name']?.toString() ?? '';
    final difficulty = (lesson['difficulty'] as num?)?.toInt() ?? 1;
    final initials = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase()).take(2).join();

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
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withAlpha(85)),
            ),
            child: Center(
              child: Text(initials.isEmpty ? '?' : initials,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: TextStyle(color: kText1, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Row(
            children: List.generate(5, (i) => Container(
              width: 3, height: 6.0 + i * 2,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: i < difficulty ? color : kBorder,
                borderRadius: BorderRadius.circular(1),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

// ── Busy time satırı (onboarding) ─────────────────────────────────────────────

class _OnboardingBusyRow extends StatelessWidget {
  const _OnboardingBusyRow({required this.slot});
  final Map<String, dynamic> slot;

  Color get _tone {
    final f = (slot['fatigueLevel'] as num?)?.toInt() ?? 1;
    if (f >= 4) return _kDanger;
    if (f == 3) return const Color(0xFFF2B14A);
    return kAccent;
  }

  @override
  Widget build(BuildContext context) {
    final dow = (slot['dayOfWeek'] as num?)?.toInt() ?? 1;
    final day = _dayLabels[(dow - 1).clamp(0, 6)];
    final start = slot['startTime'] as String? ?? '';
    final end = slot['endTime'] as String? ?? '';
    final fatigue = (slot['fatigueLevel'] as num?)?.toInt() ?? 1;

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
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _tone.withAlpha(38),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.repeat_rounded, color: _tone, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$day · $start–$end',
                  style: TextStyle(color: kText1, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Her hafta · yorgunluk $fatigue/5',
                  style: TextStyle(color: kText2, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ders ekleme sheet (onboarding) ────────────────────────────────────────────

class _OnboardingLessonSheet extends StatefulWidget {
  const _OnboardingLessonSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<_OnboardingLessonSheet> createState() => _OnboardingLessonSheetState();
}

class _OnboardingLessonSheetState extends State<_OnboardingLessonSheet> {
  final _nameCtrl = TextEditingController();
  int _difficulty = 3;
  bool _hasExam = false;
  DateTime _examDate = AppTime.now().add(const Duration(days: 30));
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
        await ApiClient.addExam(
          (created['id'] as num).toInt(),
          _dateKey(_examDate),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: _kDanger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Ders ekle', style: TextStyle(color: kText1, fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: kBorder, shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 16, color: kText2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: TextStyle(color: kText1),
              decoration: InputDecoration(
                labelText: 'Ders adı',
                hintText: 'örn. Lineer Cebir',
              ),
            ),
            const SizedBox(height: 16),
            Text('Zorluk · 1 kolay – 5 çok zor', style: TextStyle(color: kText2, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final n = i + 1;
                final sel = n == _difficulty;
                return Expanded(
                  child: GestureDetector(
                    onTap: _saving ? null : () => setState(() => _difficulty = n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 46,
                      margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: sel ? kAccent.withAlpha(46) : kBorder,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? kAccent : Colors.transparent, width: 0.5),
                      ),
                      child: Center(child: Text('$n',
                        style: TextStyle(color: sel ? kAccent : kText2, fontSize: 16, fontWeight: FontWeight.w700))),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _hasExam,
              onChanged: _saving ? null : (v) => setState(() => _hasExam = v),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kAccent,
              title: Text('Sınav tarihi ekle', style: TextStyle(color: kText1, fontWeight: FontWeight.w600)),
            ),
            if (_hasExam) ...[
              OutlinedButton.icon(
                onPressed: _saving ? null : () async {
                  final now = AppTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _examDate,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _examDate = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_dateKey(_examDate)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Busy time ekleme sheet (onboarding) ───────────────────────────────────────

class _OnboardingBusySheet extends StatefulWidget {
  const _OnboardingBusySheet({required this.onSaved});
  final ValueChanged<Map<String, dynamic>> onSaved;

  @override
  State<_OnboardingBusySheet> createState() => _OnboardingBusySheetState();
}

class _OnboardingBusySheetState extends State<_OnboardingBusySheet> {
  int _dayOfWeek = AppTime.now().weekday;
  String _startTime = '09:00';
  String _endTime = '10:00';
  int _fatigueLevel = 2;
  String? _error;

  static final _timeOptions = List.generate(37, (i) {
    final minutes = 6 * 60 + i * 30;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  });

  int _toMin(String t) {
    final p = t.split(':').map(int.parse).toList();
    return p[0] * 60 + p[1];
  }

  void _save() {
    if (_toMin(_endTime) <= _toMin(_startTime)) {
      setState(() => _error = 'Bitiş saati başlangıçtan sonra olmalı.');
      return;
    }
    widget.onSaved({
      'dayOfWeek': _dayOfWeek,
      'startTime': _startTime,
      'endTime': _endTime,
      'fatigueLevel': _fatigueLevel,
      'iconKey': 'energy',
      'isRoutine': true,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Meşgul zaman ekle', style: TextStyle(color: kText1, fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: kBorder, shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 16, color: kText2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Her hafta tekrar eder — profilden sonradan düzenleyebilirsin.',
              style: TextStyle(color: kText2, fontSize: 12)),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _dayOfWeek,
              items: List.generate(7, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(_dayLabels[i]),
              )),
              onChanged: (v) => setState(() => _dayOfWeek = v ?? 1),
              decoration: const InputDecoration(labelText: 'Gün'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _startTime,
                    items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _startTime = v!),
                    decoration: const InputDecoration(labelText: 'Başlangıç'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _endTime,
                    items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _endTime = v!),
                    decoration: const InputDecoration(labelText: 'Bitiş'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Yorgunluk', style: TextStyle(color: kText1, fontWeight: FontWeight.w700)),
                Expanded(
                  child: Slider(
                    value: _fatigueLevel.toDouble(),
                    min: 1, max: 5, divisions: 4,
                    label: _fatigueLevel.toString(),
                    activeColor: kAccent,
                    inactiveColor: kBorder,
                    onChanged: (v) => setState(() => _fatigueLevel = v.round()),
                  ),
                ),
                Text('$_fatigueLevel/5', style: TextStyle(color: kText2, fontSize: 12)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: _kDanger, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Ekle'),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
