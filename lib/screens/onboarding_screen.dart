import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../theme.dart';
import 'main_scaffold.dart';

const _kDanger = Color(0xFFFF5C7A);


String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ── Ana ekran ─────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Adımlar: 0=tercihler, 1=dersler, 2=busy times
  int _step = 0;
  static const int _totalSteps = 3;

  bool _initLoading = true;
  bool _finishing = false;

  // ── Adım 0: Tercihler ─────────────────────────────────────────────────────
  String _preferredStudyTime = 'morning';
  String _studyStyle = 'normal';

  // ── Adım 1: Dersler ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _lessons = [];

  // ── Adım 2: Busy grid ─────────────────────────────────────────────────────
  // [gün 0-6][saat 0-15]
  //   0 = boş (müsait)
  //   1 = orta yoğun   → fatigueLevel: 2
  //   2 = çok yoğun    → fatigueLevel: 4
  static const int _gridStartHour = 7;   // 07:00
  static const int _gridHourCount = 16;  // 07:00 – 23:00
  static const List<String> _shortDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  final List<List<int>> _busyGrid =
      List.generate(7, (_) => List.filled(_gridHourCount, 0));

  // Sürükle ile seçim için hedef değer (-1 = sürüklenmiyor)
  int _dragSetValue = -1;

  // ── Ders metotları ────────────────────────────────────────────────────────

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

  // Grid'i API formatına çevirir — bitişik aynı-seviye hücreleri birleştirir
  List<Map<String, dynamic>> _buildBusySlots() {
    final slots = <Map<String, dynamic>>[];
    for (int d = 0; d < 7; d++) {
      int h = 0;
      while (h < _gridHourCount) {
        final level = _busyGrid[d][h];
        if (level == 0) {
          h++;
          continue;
        }
        final runStart = h;
        final runLevel = level;
        while (h < _gridHourCount && _busyGrid[d][h] == runLevel) {
          h++;
        }
        final startH = _gridStartHour + runStart;
        final endH = _gridStartHour + h;
        slots.add({
          'dayOfWeek': d + 1,
          'startTime': '${startH.toString().padLeft(2, '0')}:00',
          'endTime': endH >= 24
              ? '00:00'
              : '${endH.toString().padLeft(2, '0')}:00',
          'fatigueLevel': runLevel, // 1-5 doğrudan DB'ye yazılır
          'isRoutine': true,
          'iconKey': 'energy',
        });
      }
    }
    return slots;
  }

  bool get _busyGridIsEmpty =>
      _busyGrid.every((day) => day.every((v) => v == 0));

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      await ApiClient.setupUser({
        'preferredStudyTime': _preferredStudyTime,
        'studyStyle': _studyStyle,
      });
      final slots = _buildBusySlots();
      if (slots.isNotEmpty) {
        await ApiClient.updateBusySlots(slots);
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

  // ── Grid pointer handling ─────────────────────────────────────────────────

  void _handleGridPointer(
    Offset localPos,
    double cellW,
    double cellH,
    double headerH,
    double labelW,
    bool isDown,
  ) {
    final x = localPos.dx - labelW;
    final y = localPos.dy - headerH;
    if (x < 0 || y < 0) return;
    final day = (x / cellW).floor().clamp(0, 6);
    final hour = (y / cellH).floor();
    if (hour < 0 || hour >= _gridHourCount) return;

    setState(() {
      if (isDown) {
        _dragSetValue = (_busyGrid[day][hour] + 1) % 6; // 0→1→2→3→4→5→0
      }
      if (_dragSetValue >= 0) {
        _busyGrid[day][hour] = _dragSetValue;
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _StepBar(step: _step, total: _totalSteps),
            Expanded(child: _buildCurrentStep()),
            _buildBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildPreferencesStep();
      case 1:
        return _buildLessonsStep();
      case 2:
        return _buildBusyStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Adım 0: Tercihler ─────────────────────────────────────────────────────

  Widget _buildPreferencesStep() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1 / $_totalSteps',
                  style: TextStyle(
                      color: kText2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text('Çalışma tercihlerini belirle',
                  style: TextStyle(
                      color: kText1,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  'Algoritma bu bilgilere göre sana özel program oluşturur.',
                  style: TextStyle(color: kText2, fontSize: 13)),
              const SizedBox(height: 24),
              Text('En verimli çalışma saatin',
                  style: TextStyle(
                      color: kText1,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.6,
                children: [
                  _PrefTile(
                    label: 'Sabah',
                    detail: '08:00 – 11:00',
                    icon: Icons.wb_sunny_outlined,
                    selected: _preferredStudyTime == 'morning',
                    onTap: () =>
                        setState(() => _preferredStudyTime = 'morning'),
                  ),
                  _PrefTile(
                    label: 'Öğleden Sonra',
                    detail: '12:00 – 15:00',
                    icon: Icons.wb_cloudy_outlined,
                    selected: _preferredStudyTime == 'afternoon',
                    onTap: () =>
                        setState(() => _preferredStudyTime = 'afternoon'),
                  ),
                  _PrefTile(
                    label: 'Akşam',
                    detail: '18:00 – 21:00',
                    icon: Icons.nights_stay_outlined,
                    selected: _preferredStudyTime == 'evening',
                    onTap: () =>
                        setState(() => _preferredStudyTime = 'evening'),
                  ),
                  _PrefTile(
                    label: 'Gece',
                    detail: '21:00 – 24:00',
                    icon: Icons.bedtime_outlined,
                    selected: _preferredStudyTime == 'night',
                    onTap: () =>
                        setState(() => _preferredStudyTime = 'night'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Çalışma stili',
                  style: TextStyle(
                      color: kText1,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  'Algoritma bunu oturum uzunluklarını belirlemek için kullanır.',
                  style: TextStyle(color: kText2, fontSize: 12)),
              const SizedBox(height: 12),
              _StyleCard(
                value: 'deep_focus',
                label: 'Derin Odak',
                description:
                    'Az seans, uzun çalışma blokları (3–4 blok / seans)',
                icon: Icons.center_focus_strong_outlined,
                selectedValue: _studyStyle,
                onChanged: (v) => setState(() => _studyStyle = v),
              ),
              const SizedBox(height: 10),
              _StyleCard(
                value: 'normal',
                label: 'Dengeli',
                description: 'Orta uzunlukta seanslar (2–3 blok / seans)',
                icon: Icons.balance_outlined,
                selectedValue: _studyStyle,
                onChanged: (v) => setState(() => _studyStyle = v),
              ),
              const SizedBox(height: 10),
              _StyleCard(
                value: 'distributed',
                label: 'Dağıtılmış',
                description:
                    'Çok seans, kısa çalışma blokları (1–2 blok / seans)',
                icon: Icons.grid_view_rounded,
                selectedValue: _studyStyle,
                onChanged: (v) => setState(() => _studyStyle = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Adım 1: Dersler ───────────────────────────────────────────────────────

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
                  Text('2 / $_totalSteps',
                      style: TextStyle(
                          color: kText2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text('Derslerini ekle',
                      style: TextStyle(
                          color: kText1,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
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
                  ? Center(
                      child: CircularProgressIndicator(color: kAccent))
                  : _lessons.isEmpty
                      ? _buildLessonsEmpty()
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _lessons.length,
                          itemBuilder: (_, i) =>
                              _OnboardingLessonRow(lesson: _lessons[i]),
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
          Text('Henüz ders eklenmedi',
              style: TextStyle(
                  color: kText1,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Aşağıdaki butona basarak ders ekle.',
              style: TextStyle(color: kText2, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Adım 2: Busy grid ─────────────────────────────────────────────────────

  Widget _buildBusyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('3 / $_totalSteps',
                  style: TextStyle(
                      color: kText2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text('Meşgul zamanlarını işaretle',
                  style: TextStyle(
                      color: kText1,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Tıkla veya sürükle — algoritma bu saatlerin dışına ders koyar.',
                style: TextStyle(color: kText2, fontSize: 13),
              ),
            ],
          ),
        ),

        // Renk skalası açıklaması + temizle butonu
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Row(
            children: [
              // 5 kademeli renk skalası
              ...List.generate(5, (i) {
                final level = i + 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _kLevelColors[level].withAlpha(210),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$level',
                        style: TextStyle(
                          color: kText2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Spacer(),
              if (!_busyGridIsEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    for (final day in _busyGrid) {
                      day.fillRange(0, day.length, 0);
                    }
                  }),
                  icon: Icon(Icons.clear_all_rounded, size: 16, color: kText2),
                  label: Text('Temizle',
                      style: TextStyle(color: kText2, fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
        ),

        // Haftalık grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _buildWeeklyGrid(),
          ),
        ),

        // Alt ipucu
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            'İpucu: Tekrar tıkla → Orta → Yoğun → Temizle',
            style: TextStyle(color: kText2, fontSize: 11),
          ),
        ),
      ],
    );
  }

  // Haftalık grid widget'ı — LayoutBuilder ile hücre boyutlarını hesaplar
  Widget _buildWeeklyGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelW = 38.0;
        const headerH = 26.0;
        final cellW = (constraints.maxWidth - labelW) / 7;
        final cellH =
            (constraints.maxHeight - headerH) / _gridHourCount;

        return Listener(
          onPointerDown: (e) => _handleGridPointer(
              e.localPosition, cellW, cellH, headerH, labelW, true),
          onPointerMove: (e) => _handleGridPointer(
              e.localPosition, cellW, cellH, headerH, labelW, false),
          onPointerUp: (_) => setState(() => _dragSetValue = -1),
          onPointerCancel: (_) => setState(() => _dragSetValue = -1),
          child: Column(
            children: [
              // Gün başlıkları
              SizedBox(
                height: headerH,
                child: Row(
                  children: [
                    SizedBox(width: labelW),
                    ..._shortDays.map(
                      (d) => SizedBox(
                        width: cellW,
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              color: kText2,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Saat satırları
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Saat etiketleri (sol)
                    SizedBox(
                      width: labelW,
                      child: Column(
                        children: List.generate(_gridHourCount, (h) {
                          final hour = _gridStartHour + h;
                          final showLabel = h % 2 == 0;
                          return SizedBox(
                            height: cellH,
                            child: showLabel
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${hour.toString().padLeft(2, '0')}:00',
                                      style: TextStyle(
                                        color: kText2,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        }),
                      ),
                    ),

                    // Gün sütunları
                    ...List.generate(
                      7,
                      (d) => SizedBox(
                        width: cellW,
                        child: Column(
                          children: List.generate(
                            _gridHourCount,
                            (h) => _GridCell(
                              value: _busyGrid[d][h],
                              height: cellH,
                              isTopEdge: h == 0,
                              isLeftEdge: d == 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Alt butonlar ──────────────────────────────────────────────────────────

  Widget _buildBottom() {
    final isLast = _step == _totalSteps - 1;
    final canBack = _step > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (canBack) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kText1,
                  side: BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Geri'),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // "Ders ekle" butonu — sadece ders adımında
          if (_step == 1) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _initLoading ? null : _openAddLesson,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ders ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          Expanded(
            child: FilledButton(
              onPressed: (_initLoading || _finishing)
                  ? null
                  : isLast
                      ? _finish
                      : () => setState(() => _step++),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isLast
                          ? (_busyGridIsEmpty
                              ? 'Atla ve Başla'
                              : 'Başla')
                          : (_step == 1 && _lessons.isEmpty
                              ? 'Geç'
                              : 'İleri'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid hücre renkleri ───────────────────────────────────────────────────────

// 5 kademe — soluk maviden kırmızıya ısı haritası
const _kLevelColors = [
  Color(0xFF000000), // 0: kullanılmaz (boş)
  Color(0xFF64B5F6), // 1: çok az yoğun  — açık mavi
  Color(0xFF9575CD), // 2: az yoğun      — mor
  Color(0xFFFFB300), // 3: orta           — amber
  Color(0xFFFF6D00), // 4: yoğun          — turuncu
  Color(0xFFE53935), // 5: çok yoğun      — kırmızı
];

Color _cellColor(int value) {
  if (value <= 0 || value > 5) {
    return const Color(0xFF000000).withAlpha(12); // boş
  }
  return _kLevelColors[value].withAlpha(210);
}

// ── Grid hücresi ──────────────────────────────────────────────────────────────

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.value,
    required this.height,
    this.isTopEdge = false,
    this.isLeftEdge = false,
  });

  final int value;
  final double height;
  final bool isTopEdge;
  final bool isLeftEdge;

  @override
  Widget build(BuildContext context) {
    final color = _cellColor(value);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(0.8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}


// ── Step bar ──────────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final labels = ['Tercihler', 'Dersler', 'Meşgul saatler'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(total * 2 - 1, (i) {
          if (i.isOdd) {
            final idx = i ~/ 2;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  color: step > idx ? kAccent : kBorder,
                ),
              ),
            );
          } else {
            final idx = i ~/ 2;
            return _StepDot(
              active: step >= idx,
              done: step > idx,
              label: labels[idx],
            );
          }
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.active,
    required this.done,
    required this.label,
  });
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
              ? const Icon(Icons.check_rounded,
                  size: 13, color: Colors.white)
              : active
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? kText1 : kText2,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Tercih tile ───────────────────────────────────────────────────────────────

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.label,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kAccent.withAlpha(34) : kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kAccent : kBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? kAccent : kBorder.withAlpha(90),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(icon, color: selected ? Colors.white : kText2, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: kText1,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  Text(detail,
                      style: TextStyle(color: kText2, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stil kartı ────────────────────────────────────────────────────────────────

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.selectedValue,
    required this.onChanged,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? kAccent.withAlpha(34) : kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kAccent : kBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? kAccent : kBorder.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: selected ? Colors.white : kText2, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: kText1,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: TextStyle(color: kText2, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? kAccent : kBorder,
                  width: 1.6,
                ),
                color: selected ? kAccent : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ders satırı ───────────────────────────────────────────────────────────────

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
            width: 38, height: 38,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    color: kText1,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Row(
            children: List.generate(5, (i) => Container(
              width: 3,
              height: 6.0 + i * 2,
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

// ── Ders ekleme sheet ─────────────────────────────────────────────────────────

class _OnboardingLessonSheet extends StatefulWidget {
  const _OnboardingLessonSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<_OnboardingLessonSheet> createState() =>
      _OnboardingLessonSheetState();
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Ders ekle',
                    style: TextStyle(
                        color: kText1,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: kBorder, shape: BoxShape.circle),
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
              decoration: const InputDecoration(
                labelText: 'Ders adı',
                hintText: 'örn. Lineer Cebir',
              ),
            ),
            const SizedBox(height: 16),
            Text('Zorluk · 1 kolay – 5 çok zor',
                style: TextStyle(color: kText2, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final n = i + 1;
                final sel = n == _difficulty;
                return Expanded(
                  child: GestureDetector(
                    onTap:
                        _saving ? null : () => setState(() => _difficulty = n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 46,
                      margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: sel ? kAccent.withAlpha(46) : kBorder,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? kAccent : Colors.transparent,
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text('$n',
                            style: TextStyle(
                              color: sel ? kAccent : kText2,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _hasExam,
              onChanged:
                  _saving ? null : (v) => setState(() => _hasExam = v),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kAccent,
              title: Text('Sınav tarihi ekle',
                  style: TextStyle(
                      color: kText1, fontWeight: FontWeight.w600)),
            ),
            if (_hasExam) ...[
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final now = AppTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _examDate,
                          firstDate:
                              DateTime(now.year, now.month, now.day),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _examDate = picked);
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_dateKey(_examDate)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
