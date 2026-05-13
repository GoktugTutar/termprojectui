import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/planner_model.dart';
import '../theme.dart';

const _startHour = 8;
const _endHour = 24;
const _slotH = 28.0; // px per 30-min slot
const _gutterW = 42.0;
const _totalH = (_endHour - _startHour) * 2.0 * _slotH; // 896.0

const _kDanger = Color(0xFFFF5C7A);
const _kWarning = Color(0xFFF2B14A);

/// Kullanıcının meşgul slotu (UI katmanı için).
class _BusySlot {
  final int dayOfWeek; // 1=Pzt … 7=Paz
  final String startTime;
  final String endTime;
  final int fatigueLevel;

  const _BusySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.fatigueLevel,
  });

  factory _BusySlot.fromJson(Map<String, dynamic> j) => _BusySlot(
        dayOfWeek: (j['dayOfWeek'] as num).toInt(),
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
        fatigueLevel: (j['fatigueLevel'] as num? ?? 1).toInt(),
      );
}

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  WeeklyPlan? _plan;
  List<_BusySlot> _busySlots = [];
  bool _loading = true;
  int _selectedDayIndex = 0;

  final _vScroll = ScrollController();

  static const _dowLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthShorts = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = (AppTime.now().weekday - 1).clamp(0, 6);
    _load();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    super.dispose();
  }

  /// Haftalık plan ve kullanıcı profilini (busySlots için) paralel yükler.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        ApiClient.getWeekPlan(),
        ApiClient.getMe(),
      ]);
      if (!mounted) return;
      final busyList = ((results[1]['busySlots'] as List?) ?? [])
          .map((b) => _BusySlot.fromJson(b as Map<String, dynamic>))
          .toList();
      setState(() {
        _plan = WeeklyPlan.fromJson(results[0]);
        _busySlots = busyList;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Algoritmayı yeniden çalıştırır ve planı günceller.
  Future<void> _recalculate() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.createWeeklyPlan();
      if (!mounted) return;
      setState(() {
        _plan = WeeklyPlan.fromJson(data);
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan yeniden oluşturuldu!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: _kDanger,
          ),
        );
      }
    }
  }

  List<String> get _weekDates {
    if (_plan == null) return [];
    return List.generate(7, (i) {
      final dt = DateTime.parse(_plan!.weekStart).toLocal().add(Duration(days: i));
      return dt.toIso8601String().substring(0, 10);
    });
  }

  String get _weekLabel {
    if (_plan == null) return '';
    try {
      final ws = DateTime.parse(_plan!.weekStart).toLocal();
      final we = ws.add(const Duration(days: 6));
      return '${ws.day} ${_monthShorts[ws.month - 1]} – ${we.day} ${_monthShorts[we.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            if (!wide && _plan != null) _buildDayStrip(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: kAccent))
                  : _plan == null
                      ? _buildEmpty()
                      : wide
                          ? _buildWideGrid()
                          : _buildNarrowGrid(),
            ),
          ],
        ),
      ),
    );
  }

  /// Üst başlık: kicker + tarih aralığı + Recalculate butonu.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THIS WEEK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kText2,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _weekLabel.isNotEmpty ? _weekLabel : 'Week',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kText1,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _recalculate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: kAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kAccent.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: kAccent, size: 13),
                  SizedBox(width: 5),
                  Text(
                    'Recalculate',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dar ekran gün seçici şeridi — bugün accent-soft arka plan, seçili gün border.
  Widget _buildDayStrip() {
    final today = AppTime.now().toIso8601String().substring(0, 10);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Row(
          children: [
            SizedBox(width: _gutterW),
            ...List.generate(7, (i) {
              final date = _weekDates.length > i ? _weekDates[i] : '';
              final isToday = date == today;
              final isSelected = i == _selectedDayIndex;
              final dayNum =
                  date.length >= 10 ? date.substring(8, 10) : '?';
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isToday
                          ? kAccent.withAlpha(20)
                          : isSelected
                              ? kSurface
                              : Colors.transparent,
                      border: isSelected && !isToday
                          ? Border.all(color: kBorder)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dowLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isToday ? kAccent : kText2,
                            letterSpacing: 0.04,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayNum,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isToday ? kAccent : kText1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Dar ekran tek gün grid görünümü.
  Widget _buildNarrowGrid() {
    final date =
        _weekDates.isEmpty ? '' : _weekDates[_selectedDayIndex];
    final dow = _selectedDayIndex + 1; // 1=Pzt … 7=Paz
    final blocks = _plan?.blocksForDate(date) ?? [];
    final busy = _busySlots.where((b) => b.dayOfWeek == dow).toList();
    return _TimeGrid(
      dates: [date],
      blocksByDate: {date: blocks},
      busyByDow: {dow: busy},
      todayDate: AppTime.now().toIso8601String().substring(0, 10),
      vScroll: _vScroll,
      onBlockTap: _showBlockDetail,
    );
  }

  /// Geniş ekran 7 sütun grid görünümü.
  Widget _buildWideGrid() {
    final today = AppTime.now().toIso8601String().substring(0, 10);
    final blocksByDate = {
      for (final d in _weekDates)
        d: _plan?.blocksForDate(d) ?? <ScheduledBlock>[],
    };
    final busyByDow = {
      for (int i = 0; i < 7; i++)
        i + 1: _busySlots.where((b) => b.dayOfWeek == i + 1).toList(),
    };
    return Column(
      children: [
        // Gün başlık satırı (geniş ekranda gün şeridinin yerini alır)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Row(
            children: [
              SizedBox(width: _gutterW),
              ...List.generate(7, (i) {
                final date =
                    _weekDates.length > i ? _weekDates[i] : '';
                final isToday = date == today;
                final dayNum =
                    date.length >= 10 ? date.substring(8, 10) : '';
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isToday
                          ? kAccent.withAlpha(20)
                          : Colors.transparent,
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dowLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isToday ? kAccent : kText2,
                            letterSpacing: 0.04,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayNum,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isToday ? kAccent : kText1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: _TimeGrid(
            dates: _weekDates,
            blocksByDate: blocksByDate,
            busyByDow: busyByDow,
            todayDate: today,
            vScroll: _vScroll,
            onBlockTap: _showBlockDetail,
          ),
        ),
      ],
    );
  }

  /// Blok detay bottom sheet gösterir.
  void _showBlockDetail(ScheduledBlock block) {
    final color = lessonColor(block.lessonId);
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _BlockDetailSheet(block: block, color: color),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month_outlined,
              color: kText2, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No weekly plan',
            style: TextStyle(
                color: kText1,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text('Run the algorithm to generate a plan.',
              style: TextStyle(color: kText2)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _recalculate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Create Plan',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Time Grid ─────────────────────────────────────────────────────────────────

/// Saat çizgili zaman ızgarası; gutter + n gün sütunundan oluşur.
class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.dates,
    required this.blocksByDate,
    required this.busyByDow,
    required this.todayDate,
    required this.vScroll,
    required this.onBlockTap,
  });

  final List<String> dates;
  final Map<String, List<ScheduledBlock>> blocksByDate;
  final Map<int, List<_BusySlot>> busyByDow;
  final String todayDate;
  final ScrollController vScroll;
  final void Function(ScheduledBlock) onBlockTap;

  @override
  Widget build(BuildContext context) {
    final now = AppTime.now();
    final nowMin = now.hour * 60 + now.minute;

    return SingleChildScrollView(
      controller: vScroll,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 110),
        child: SizedBox(
          height: _totalH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Saat gutter
              SizedBox(
                width: _gutterW,
                child: Stack(
                  children: List.generate(_endHour - _startHour, (i) {
                    final hour = _startHour + i;
                    final top = i * 2 * _slotH;
                    return Positioned(
                      top: top - 6,
                      left: 0,
                      right: 4,
                      child: Text(
                        '${(hour % 24).toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: kText2,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Gün sütunları
              ...List.generate(dates.length, (di) {
                final date = dates[di];
                final blocks = blocksByDate[date] ?? [];
                final isToday = date == todayDate;
                final dow = _dateToDow(date);
                final busy = busyByDow[dow] ?? [];
                final showNow = isToday &&
                    now.hour >= _startHour &&
                    now.hour < _endHour;
                return Expanded(
                  child: _DayColumn(
                    isToday: isToday,
                    blocks: blocks,
                    busySlots: busy,
                    showNow: showNow,
                    nowMin: nowMin,
                    onBlockTap: onBlockTap,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

int _dateToDow(String date) {
  if (date.length < 10) return 1;
  try {
    return DateTime.parse(date).weekday; // 1=Pzt … 7=Paz
  } catch (_) {
    return 1;
  }
}

// ── Day Column ────────────────────────────────────────────────────────────────

/// Tek bir günün saat ızgarası: saat çizgileri, busy slotlar, bloklar, now çizgisi.
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.isToday,
    required this.blocks,
    required this.busySlots,
    required this.showNow,
    required this.nowMin,
    required this.onBlockTap,
  });

  final bool isToday;
  final List<ScheduledBlock> blocks;
  final List<_BusySlot> busySlots;
  final bool showNow;
  final int nowMin;
  final void Function(ScheduledBlock) onBlockTap;

  /// Dakika → piksel Y ofseti (08:00 = 0).
  double _minToTop(int minutes) =>
      (minutes - _startHour * 60) * _slotH / 30;

  /// İki zaman arasındaki piksel yüksekliği.
  double _minToHeight(int sm, int em) => (em - sm) * _slotH / 30;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isToday ? kAccent.withAlpha(10) : Colors.transparent,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Tam-saat yatay çizgiler
          ...List.generate(_endHour - _startHour, (i) => Positioned(
                top: i * 2 * _slotH,
                left: 0,
                right: 0,
                child: Container(height: 0.5, color: kBorder),
              )),
          // Yarım-saat işaret çizgileri (daha soluk)
          ...List.generate(_endHour - _startHour, (i) => Positioned(
                top: (i * 2 + 1) * _slotH,
                left: 0,
                right: 0,
                child: Container(
                    height: 0.5,
                    color: kBorder.withAlpha(100)),
              )),
          // Busy slotlar: çapraz çizgili + kesikli border + yorgunluk noktası
          ...busySlots.map((b) {
            final sm = _timeToMin(b.startTime);
            final em = _timeToMin(b.endTime);
            if (sm < _startHour * 60 ||
                em > _endHour * 60 ||
                sm >= em) {
              return const SizedBox.shrink();
            }
            final top = _minToTop(sm);
            final height = _minToHeight(sm, em);
            final Color dotColor;
            if (b.fatigueLevel >= 4) {
              dotColor = _kDanger;
            } else if (b.fatigueLevel >= 3) {
              dotColor = _kWarning;
            } else {
              dotColor = kText2;
            }
            return Positioned(
              top: top,
              left: 1,
              right: 1,
              height: height,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: kBorder.withAlpha(160), width: 0.5),
                  color: Colors.white.withAlpha(10),
                ),
                child: CustomPaint(
                  painter: _StripedPainter(Colors.white.withAlpha(18)),
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(4, 3, 4, 3),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'BUSY',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: kText2,
                                letterSpacing: 0.04,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // Planlanmış çalışma blokları
          ...blocks.map((b) {
            final sm = _timeToMin(b.startTime);
            final em = _timeToMin(b.endTime);
            if (sm < _startHour * 60 ||
                em > _endHour * 60 ||
                sm >= em) {
              return const SizedBox.shrink();
            }
            final top = _minToTop(sm);
            final height =
                (_minToHeight(sm, em) - 2).clamp(14.0, double.infinity);
            final color = lessonColor(b.lessonId);
            return Positioned(
              top: top + 1,
              left: 1,
              right: 1,
              height: height,
              child: GestureDetector(
                onTap: () => onBlockTap(b),
                child: Opacity(
                  opacity: b.completed ? 0.5 : 1.0,
                  child: Container(
                    clipBehavior: b.isReview
                        ? Clip.antiAlias
                        : Clip.none,
                    decoration: BoxDecoration(
                      color: b.isReview
                          ? Colors.transparent
                          : color.withAlpha(38),
                      borderRadius: BorderRadius.circular(5),
                      border: Border(
                        left:
                            BorderSide(color: color, width: 3),
                        top: BorderSide(
                            color: color.withAlpha(100),
                            width: 0.5),
                        right: BorderSide(
                            color: color.withAlpha(100),
                            width: 0.5),
                        bottom: BorderSide(
                            color: color.withAlpha(100),
                            width: 0.5),
                      ),
                    ),
                    child: b.isReview
                        ? CustomPaint(
                            painter: _StripedPainter(
                                color.withAlpha(0x33)),
                            child: _BlockContent(
                                block: b, color: color),
                          )
                        : _BlockContent(block: b, color: color),
                  ),
                ),
              ),
            );
          }),
          // Now çizgisi (sadece bugün)
          if (showNow)
            Positioned(
              top: _minToTop(nowMin) - 3,
              left: 0,
              right: 0,
              height: 6,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _kDanger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 2.25),
                      height: 1.5,
                      color: _kDanger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Blok içerik etiketi: ders adı + isteğe bağlı REVIEW/EXAM rozeti.
class _BlockContent extends StatelessWidget {
  const _BlockContent({required this.block, required this.color});

  final ScheduledBlock block;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 3, 4, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.lessonName,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.02,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (block.isReview)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '↻ REVIEW',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color.withAlpha(215),
                  letterSpacing: 0.04,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Striped Painter ───────────────────────────────────────────────────────────

/// Çapraz çizgi deseni boyayan CustomPainter — busy slot ve review blok arka planı.
class _StripedPainter extends CustomPainter {
  const _StripedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const step = 7.0;
    for (double i = -size.height;
        i < size.width + size.height;
        i += step) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripedPainter old) =>
      old.color != color;
}

// ── Block Detail Sheet ────────────────────────────────────────────────────────

/// Bloğun detaylarını gösteren modal bottom sheet.
class _BlockDetailSheet extends StatefulWidget {
  const _BlockDetailSheet({required this.block, required this.color});

  final ScheduledBlock block;
  final Color color;

  @override
  State<_BlockDetailSheet> createState() => _BlockDetailSheetState();
}

class _BlockDetailSheetState extends State<_BlockDetailSheet> {
  late int _studiedMinutes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Start at full planned time if already completed, else 0
    final plannedMins = widget.block.blockCount * 30;
    _studiedMinutes = widget.block.completed ? plannedMins : 0;
    // Load existing checklist entry for this date
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final cl = await ApiClient.getChecklist(widget.block.date);
      if (cl == null || !mounted) return;
      final items = (cl['items'] as List?) ?? [];
      for (final item in items) {
        if ((item['lessonId'] as num).toInt() == widget.block.lessonId) {
          final saved = (item['completedBlocks'] as num? ?? 0).toInt() * 30;
          if (mounted) setState(() => _studiedMinutes = saved);
          break;
        }
      }
    } catch (_) {}
  }

  int get _plannedMinutes => widget.block.blockCount * 30;
  int get _completedBlocks => (_studiedMinutes / 30).round();
  bool get _isFull => _completedBlocks >= widget.block.blockCount;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // Get all blocks for this date to build a full checklist submission
      final weekData = await ApiClient.getWeekPlan();
      final allBlocks = (weekData['blocks'] as List? ?? [])
          .map((b) => ScheduledBlock.fromJson(b as Map<String, dynamic>))
          .toList();
      final dateBlocks = allBlocks
          .where((b) => b.date == widget.block.date)
          .toList();

      // Load existing checklist to preserve other lessons' values
      final existing = await ApiClient.getChecklist(widget.block.date);
      final existingItems = <int, int>{}; // lessonId → completedBlocks
      if (existing != null) {
        for (final item in (existing['items'] as List? ?? [])) {
          existingItems[(item['lessonId'] as num).toInt()] =
              (item['completedBlocks'] as num? ?? 0).toInt();
        }
      }

      // Build items: this block gets our new value, others keep existing
      final seen = <int>{};
      final items = <Map<String, dynamic>>[];
      for (final b in dateBlocks) {
        if (!seen.add(b.lessonId)) continue;
        final planned = dateBlocks
            .where((bl) => bl.lessonId == b.lessonId)
            .fold(0, (s, bl) => s + bl.blockCount);
        final completedBlocks = b.lessonId == widget.block.lessonId
            ? _completedBlocks
            : (existingItems[b.lessonId] ?? 0);
        items.add({
          'lessonId': b.lessonId,
          'plannedBlocks': planned,
          'completedBlocks': completedBlocks,
          'delayed': completedBlocks == 0,
        });
      }

      await ApiClient.submitChecklist(
        stressLevel: (existing?['stressLevel'] as num? ?? 2).toInt(),
        fatigueLevel: (existing?['fatigueLevel'] as num? ?? 3).toInt(),
        items: items,
      );


      if (!mounted) return;

      final today = AppTime.now().toIso8601String().substring(0, 10);
      final isLate = widget.block.date.compareTo(today) < 0;
      final isIncomplete = _completedBlocks < widget.block.blockCount;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLate && isIncomplete && _studiedMinutes > 0
                ? 'Logged ${_studiedMinutes}m for ${widget.block.date} — tap Recalculate in the week view to update your plan.'
                : _studiedMinutes == 0
                    ? 'Marked as not studied'
                    : 'Saved: \${_studiedMinutes}m studied',
          ),
          backgroundColor: kSurface,
          duration: Duration(seconds: isLate && isIncomplete ? 5 : 3),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final sm = _timeToMin(widget.block.startTime);
    final em = _timeToMin(widget.block.endTime);
    final durationMin = em - sm;
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr = mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
    final fillRatio = (_studiedMinutes / _plannedMinutes).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Study block',
              style: TextStyle(fontSize: 13, color: kText2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration:
                    BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.block.lessonName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: kText1),
                ),
              ),
            ],
          ),
          Text(
            '${widget.block.date} · ${widget.block.startTime} – ${widget.block.endTime}',
            style: const TextStyle(fontSize: 13, color: kText2),
          ),
          const SizedBox(height: 16),
          if (widget.block.isReview)
            _DetailRow(
              icon: Icons.repeat_rounded,
              label: 'Review block',
              value: 'Pre-exam review',
              tone: widget.color,
            ),
          _DetailRow(
            icon: Icons.access_time_rounded,
            label: 'Duration',
            value: '${widget.block.blockCount} blocks · $durationStr',
          ),
          // Studied time input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: kBorder.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFull ? kAccent.withAlpha(100) : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: kBorder,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.timer_outlined,
                          size: 16,
                          color: _isFull ? kAccent : kText2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Time studied',
                          style:
                              const TextStyle(fontSize: 13, color: kText2)),
                    ),
                    Text(
                      _studiedMinutes == 0
                          ? '—'
                          : '${_studiedMinutes}m / ${_plannedMinutes}m',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isFull ? kAccent : kText1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillRatio,
                    minHeight: 4,
                    backgroundColor: kBorder,
                    valueColor: AlwaysStoppedAnimation(
                        _isFull ? kAccent : widget.color),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 13, color: kText2),
                    Expanded(
                      child: Slider(
                        value: _studiedMinutes.toDouble(),
                        min: 0,
                        max: (_plannedMinutes * 1.5).ceilToDouble(),
                        divisions:
                            ((_plannedMinutes * 1.5) / 10).ceil().clamp(1, 999),
                        activeColor: _isFull ? kAccent : widget.color,
                        inactiveColor: kBorder,
                        onChanged: (v) =>
                            setState(() => _studiedMinutes = v.round()),
                      ),
                    ),
                    Text(
                      '${_studiedMinutes}m',
                      style: const TextStyle(
                          color: kText2,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      _studiedMinutes == 0 ? 'Mark as skipped' : 'Save',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// İkon kutusu + etiket + değer satırı (BlockDetailSheet için).
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kBorder.withAlpha(80),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(icon, size: 16, color: tone ?? kText2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: kText2)),
            ),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tone ?? kText1),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yardımcı ─────────────────────────────────────────────────────────────────

/// "HH:MM" formatındaki zamanı toplam dakikaya çevirir.
int _timeToMin(String t) {
  final parts = t.split(':');
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 +
      (int.tryParse(parts[1]) ?? 0);
}