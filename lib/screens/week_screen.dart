import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/lesson_model.dart';
import '../models/planner_model.dart';
import '../theme.dart';

const _startHour = 8;
const _endHour = 24;
const _slotH = 28.0; // px per 30-min slot
const _gutterW = 42.0;
const _totalH = (_endHour - _startHour) * 2.0 * _slotH; // 896.0

const _kDanger = Color(0xFFFF5C7A);
const _kWarning = Color(0xFFF2B14A);
const _kFatigueLow = Color(0xFF2FAE70);

class _BusyIconChoice {
  const _BusyIconChoice({
    required this.key,
    required this.icon,
    required this.tooltip,
  });

  final String key;
  final IconData icon;
  final String tooltip;
}

const _busyIconChoices = [
  _BusyIconChoice(key: 'phone', icon: Icons.call_rounded, tooltip: 'Telefon'),
  _BusyIconChoice(key: 'wifi', icon: Icons.wifi_rounded, tooltip: 'Online'),
  _BusyIconChoice(key: 'group', icon: Icons.groups_rounded, tooltip: 'Grup'),
  _BusyIconChoice(key: 'search', icon: Icons.search_rounded, tooltip: 'Arama'),
  _BusyIconChoice(
    key: 'calendar',
    icon: Icons.calendar_month_rounded,
    tooltip: 'Takvim',
  ),
  _BusyIconChoice(key: 'video', icon: Icons.videocam_rounded, tooltip: 'Video'),
  _BusyIconChoice(key: 'energy', icon: Icons.bolt_rounded, tooltip: 'Enerji'),
];

Color _fatigueColor(int level) {
  if (level <= 2) return _kFatigueLow;
  if (level <= 3) return _kWarning;
  return _kDanger;
}

IconData _busyIconForKey(String key) {
  for (final choice in _busyIconChoices) {
    if (choice.key == key) return choice.icon;
  }
  return Icons.bolt_rounded;
}

/// Kullanıcının meşgul slotu (UI katmanı için).
class _BusySlot {
  final int dayOfWeek; // 1=Pzt … 7=Paz
  final String startTime;
  final String endTime;
  final int fatigueLevel;
  final String iconKey;
  final bool isRoutine;
  final String? date;
  final bool localOnly;

  _BusySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.fatigueLevel,
    required this.iconKey,
    required this.isRoutine,
    this.date,
    this.localOnly = false,
  });

  factory _BusySlot.fromJson(Map<String, dynamic> j) => _BusySlot(
    dayOfWeek: (j['dayOfWeek'] as num).toInt(),
    startTime: j['startTime'] as String,
    endTime: j['endTime'] as String,
    fatigueLevel: (j['fatigueLevel'] as num? ?? 1).toInt(),
    iconKey: j['iconKey']?.toString() ?? 'energy',
    isRoutine: j['isRoutine'] as bool? ?? j['date'] == null,
    date: j['date']?.toString(),
    localOnly: j['localOnly'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'fatigueLevel': fatigueLevel,
    'iconKey': iconKey,
    'isRoutine': isRoutine,
    if (date != null) 'date': date,
    if (localOnly) 'localOnly': true,
  };

  bool appliesToDate(String dateKey) {
    if (isRoutine || date == null) return dayOfWeek == _dateToDow(dateKey);
    return date == dateKey;
  }
}

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, this.reloadSignal = 0});

  final int reloadSignal;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  WeeklyPlan? _plan;
  List<_BusySlot> _busySlots = [];
  List<_BusySlot>? _calendarBusySlots;
  List<Lesson> _lessons = [];
  bool _loading = true;
  int _selectedDayIndex = 0;
  int _viewIndex = 0;
  String _lastToday = '';
  DateTime? _calendarMonth;
  Timer? _clockTimer;

  final _vScroll = ScrollController();

  static const _calendarBusyPrefsKey = 'calendar_busy_slots_v1';

  List<_BusySlot> get _safeCalendarBusySlots => _calendarBusySlots ?? const [];

  static const _dowLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthShorts = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
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
  static const _dowFullLabels = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  @override
  void initState() {
    super.initState();
    final now = AppTime.now();
    _selectedDayIndex = (now.weekday - 1).clamp(0, 6);
    _calendarMonth = DateTime(now.year, now.month);
    _lastToday = AppTime.todayStr();
    _clockTimer = Timer.periodic(Duration(minutes: 1), (_) {
      if (!mounted) return;
      final today = AppTime.todayStr();
      if (today != _lastToday) {
        final now = AppTime.now();
        _lastToday = today;
        _selectedDayIndex = (now.weekday - 1).clamp(0, 6);
        _calendarMonth = DateTime(now.year, now.month);
        _load();
        return;
      }
      setState(() {});
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant WeekScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadSignal != oldWidget.reloadSignal) {
      _load();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _vScroll.dispose();
    super.dispose();
  }

  /// Haftalık plan ve kullanıcı profilini (busySlots için) paralel yükler.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        ApiClient.getWeekPlan(),
        ApiClient.getMe(),
        ApiClient.getLessons(),
        SharedPreferences.getInstance(),
      ]);
      if (!mounted) return;
      final planData = Map<String, dynamic>.from(results[0] as Map);
      final userData = Map<String, dynamic>.from(results[1] as Map);
      final lessonList = (results[2] as List)
          .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
          .toList();
      final prefs = results[3] as SharedPreferences;
      final localBusy = _decodeCalendarBusySlots(
        prefs.getString(_calendarBusyPrefsKey),
      );
      final busyList = ((userData['busySlots'] as List?) ?? [])
          .map((b) => _BusySlot.fromJson(b as Map<String, dynamic>))
          .toList();
      final today = AppTime.todayStr();
      setState(() {
        _plan = WeeklyPlan.fromJson(planData);
        _busySlots = busyList;
        _calendarBusySlots = localBusy;
        _lessons = lessonList;
        _lastToday = today;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_BusySlot> _decodeCalendarBusySlots(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List;
      return list
          .map((item) => _BusySlot.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCalendarBusySlot(_BusySlot slot) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [..._safeCalendarBusySlots, slot];
    await prefs.setString(
      _calendarBusyPrefsKey,
      json.encode(updated.map((slot) => slot.toJson()).toList()),
    );
    if (!mounted) return;
    setState(() => _calendarBusySlots = updated);
  }

  List<_BusySlot> _busySlotsForDate(String dateKey) {
    final slots = <_BusySlot>[];
    final seen = <String>{};

    void addSlot(_BusySlot slot) {
      if (!slot.appliesToDate(dateKey)) return;
      final key =
          '${slot.dayOfWeek}|${slot.startTime}|${slot.endTime}|${slot.isRoutine}|${slot.date ?? ''}';
      if (seen.add(key)) slots.add(slot);
    }

    for (final slot in _safeCalendarBusySlots) {
      addSlot(slot);
    }
    for (final slot in _busySlots) {
      addSlot(slot);
    }
    return slots;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Plan yeniden oluşturuldu!')));
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
      final dt = DateTime.parse(
        _plan!.weekStart,
      ).toLocal().add(Duration(days: i));
      return dt.toIso8601String().substring(0, 10);
    });
  }

  String get _weekLabel {
    if (_plan == null) return '';
    try {
      final ws = DateTime.parse(_plan!.weekStart).toLocal();
      final we = ws.add(Duration(days: 6));
      if (ws.month == we.month && ws.year == we.year) {
        return '${ws.day}-${we.day} ${_monthShorts[ws.month - 1]}';
      }
      return '${ws.day} ${_monthShorts[ws.month - 1]} - ${we.day} ${_monthShorts[we.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  String get _monthLabel =>
      '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}';

  DateTime get _visibleMonth {
    final month = _calendarMonth;
    if (month != null) return month;
    final now = AppTime.now();
    return DateTime(now.year, now.month);
  }

  void _setVisibleMonth(DateTime month) {
    _calendarMonth = DateTime(month.year, month.month);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildViewSwitchBar(),
            _buildHeader(),
            if (_viewIndex == 0 && !wide && _plan != null) _buildDayStrip(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: kAccent))
                  : _plan == null
                  ? _buildEmpty()
                  : _viewIndex == 1
                  ? _buildMonthCalendar()
                  : wide
                  ? _buildWideGrid()
                  : _buildNarrowGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 3),
      child: Align(
        alignment: Alignment.center,
        child: _ProgramViewSwitch(
          currentIndex: _viewIndex,
          onChanged: (index) => setState(() => _viewIndex = index),
        ),
      ),
    );
  }

  /// Üst başlık: tarih aralığı.
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _viewIndex == 0
                      ? (_weekLabel.isNotEmpty ? _weekLabel : 'Week')
                      : _monthLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kText1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dar ekran gün seçici şeridi — bugün accent-soft arka plan, seçili gün border.
  Widget _buildDayStrip() {
    final today = AppTime.todayStr();
    return SizedBox(
      height: 50,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Row(
          children: [
            SizedBox(width: _gutterW),
            ...List.generate(7, (i) {
              final date = _weekDates.length > i ? _weekDates[i] : '';
              final isToday = date == today;
              final isSelected = i == _selectedDayIndex;
              final dayNum = date.length >= 10 ? date.substring(8, 10) : '?';
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = i),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 150),
                    margin: EdgeInsets.symmetric(horizontal: 1),
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
                        SizedBox(height: 2),
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
    final date = _weekDates.isEmpty ? '' : _weekDates[_selectedDayIndex];
    final dow = _selectedDayIndex + 1; // 1=Pzt … 7=Paz
    final blocks = _plan?.blocksForDate(date) ?? [];
    final busy = _busySlotsForDate(date);
    return _TimeGrid(
      dates: [date],
      blocksByDate: {date: blocks},
      busyByDow: {dow: busy},
      todayDate: AppTime.todayStr(),
      vScroll: _vScroll,
      onBlockTap: _showBlockDetail,
    );
  }

  /// Geniş ekran 7 sütun grid görünümü.
  Widget _buildWideGrid() {
    final today = AppTime.todayStr();
    final blocksByDate = {
      for (final d in _weekDates)
        d: _plan?.blocksForDate(d) ?? <ScheduledBlock>[],
    };
    final busyByDow = {
      for (int i = 0; i < 7; i++) i + 1: _busySlotsForDate(_weekDates[i]),
    };
    return Column(
      children: [
        // Gün başlık satırı (geniş ekranda gün şeridinin yerini alır)
        Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Row(
            children: [
              SizedBox(width: _gutterW),
              ...List.generate(7, (i) {
                final date = _weekDates.length > i ? _weekDates[i] : '';
                final isToday = date == today;
                final dayNum = date.length >= 10 ? date.substring(8, 10) : '';
                return Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    margin: EdgeInsets.symmetric(horizontal: 1),
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
                        SizedBox(height: 2),
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

  Widget _buildMonthCalendar() {
    final days = _calendarDaysFor(_visibleMonth);
    final today = AppTime.todayStr();

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 16),
      child: Column(
        children: [
          _MonthControls(
            label: _monthLabel,
            onPrevious: () => setState(
              () => _setVisibleMonth(
                DateTime(_visibleMonth.year, _visibleMonth.month - 1),
              ),
            ),
            onToday: () {
              final now = AppTime.now();
              setState(() => _setVisibleMonth(DateTime(now.year, now.month)));
            },
            onNext: () => setState(
              () => _setVisibleMonth(
                DateTime(_visibleMonth.year, _visibleMonth.month + 1),
              ),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: _dowFullLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: kText2,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: MediaQuery.sizeOf(context).width >= 720
                    ? 1.35
                    : 0.78,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                final dateKey = _dateKey(date);
                final inMonth = date.month == _visibleMonth.month;
                final events = _calendarEventsForDate(date);
                return _MonthDayTile(
                  date: date,
                  inMonth: inMonth,
                  isToday: dateKey == today,
                  events: events,
                  onAdd: () => _showAddCalendarEntry(date),
                  onTap: events.isEmpty
                      ? null
                      : () => _showDayEvents(date, events),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _calendarDaysFor(DateTime month) {
    final first = DateTime(month.year, month.month);
    final leadingDays = first.weekday - 1;
    final gridStart = first.subtract(Duration(days: leadingDays));
    return List.generate(42, (i) => gridStart.add(Duration(days: i)));
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<_CalendarEvent> _calendarEventsForDate(DateTime date) {
    final dateKey = _dateKey(date);
    final events = <_CalendarEvent>[];

    for (final slot in _busySlotsForDate(dateKey)) {
      final color = _fatigueColor(slot.fatigueLevel);
      events.add(
        _CalendarEvent(
          type: _CalendarEntryType.busy,
          label: slot.isRoutine ? 'Rutin busy' : 'Busy time',
          subtitle: '${slot.startTime} - ${slot.endTime}',
          color: color,
          icon: _busyIconForKey(slot.iconKey),
          faded: slot.isRoutine,
        ),
      );
    }

    for (final lesson in _lessons) {
      final lessonId = int.tryParse(lesson.id) ?? 0;
      final color = lessonColor(lessonId);

      for (final _ in lesson.exams.where((e) => e.dateOnly == dateKey)) {
        events.add(
          _CalendarEvent(
            type: _CalendarEntryType.exam,
            label: 'Sınav',
            subtitle: lesson.lessonName,
            color: color,
            icon: Icons.school_outlined,
          ),
        );
      }

      for (final deadline in lesson.deadlines.where(
        (d) => d.dateOnly == dateKey,
      )) {
        events.add(
          _CalendarEvent(
            type: _CalendarEntryType.deadline,
            label: deadline.title?.trim().isNotEmpty == true
                ? deadline.title!.trim()
                : 'Ödev',
            subtitle: lesson.lessonName,
            color: color,
            icon: Icons.assignment_outlined,
          ),
        );
      }
    }

    return events;
  }

  /// Blok detay bottom sheet gösterir.
  void _showBlockDetail(ScheduledBlock block) {
    final color = lessonColor(block.lessonId);
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BlockDetailSheet(block: block, color: color),
    );
  }

  void _showDayEvents(DateTime date, List<_CalendarEvent> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DayEventsSheet(
        dateLabel: '${date.day} ${_monthNames[date.month - 1]}',
        events: events,
      ),
    );
  }

  Future<void> _showAddCalendarEntry(DateTime date) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierColor: Colors.black.withAlpha(170),
      builder: (_) => _CalendarEntryDialog(date: date),
    );
    if (result is _BusySlot) {
      await _saveCalendarBusySlot(result);
      await _load();
    } else if (result == true) {
      await _load();
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, color: kText2, size: 48),
          SizedBox(height: 12),
          Text(
            'No weekly plan',
            style: TextStyle(
              color: kText1,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Run the algorithm to generate a plan.',
            style: TextStyle(color: kText2),
          ),
          SizedBox(height: 24),
          GestureDetector(
            onTap: _recalculate,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Create Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramViewSwitch extends StatelessWidget {
  const _ProgramViewSwitch({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface.withAlpha(appTheme.isLight ? 245 : 220),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder.withAlpha(150)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitchButton(
            icon: Icons.view_week_outlined,
            tooltip: 'Program',
            selected: currentIndex == 0,
            onTap: () => onChanged(0),
          ),
          _SwitchButton(
            icon: Icons.calendar_month_outlined,
            tooltip: 'Aylık',
            selected: currentIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 160),
          width: 30,
          height: 26,
          decoration: BoxDecoration(
            color: selected ? kAccent.withAlpha(34) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected ? Border.all(color: kAccent.withAlpha(90)) : null,
          ),
          child: Icon(icon, size: 16, color: selected ? kAccent : kText2),
        ),
      ),
    );
  }
}

class _MonthControls extends StatelessWidget {
  const _MonthControls({
    required this.label,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconControl(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        SizedBox(width: 6),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: kText1,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onToday,
          style: TextButton.styleFrom(
            foregroundColor: kAccent,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Bugün',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(width: 6),
        _IconControl(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _IconControl extends StatelessWidget {
  const _IconControl({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: icon == Icons.chevron_left_rounded ? 'Önceki ay' : 'Sonraki ay',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder.withAlpha(150)),
          ),
          child: Icon(icon, color: kText1, size: 18),
        ),
      ),
    );
  }
}

enum _CalendarEntryType { busy, exam, deadline }

class _CalendarEvent {
  const _CalendarEvent({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.faded = false,
  });

  final _CalendarEntryType type;
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool faded;
}

class _MonthDayTile extends StatelessWidget {
  const _MonthDayTile({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.events,
    required this.onAdd,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final List<_CalendarEvent> events;
  final VoidCallback onAdd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.take(2).toList();
    final extraCount = events.length - visibleEvents.length;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        padding: EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isToday
              ? kAccent.withAlpha(24)
              : inMonth
              ? kSurface.withAlpha(appTheme.isLight ? 238 : 175)
              : kSurface.withAlpha(appTheme.isLight ? 120 : 65),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday
                ? kAccent
                : events.isNotEmpty
                ? kBorder
                : kBorder.withAlpha(90),
            width: isToday ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: inMonth ? kText1 : kText2.withAlpha(150),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (events.isNotEmpty) ...[
                  Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: events.first.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                if (events.isEmpty) Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAdd,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kAccent.withAlpha(appTheme.isLight ? 24 : 34),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kAccent.withAlpha(80)),
                    ),
                    child: Icon(Icons.add_rounded, color: kAccent, size: 14),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            ...visibleEvents.map((event) {
              final eventOpacity = event.faded ? 0.48 : 1.0;
              return Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Opacity(
                  opacity: eventOpacity,
                  child: Container(
                    constraints: BoxConstraints(minHeight: 17),
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: event.color.withAlpha(appTheme.isLight ? 34 : 45),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: event.color.withAlpha(95),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          event.icon,
                          size: 9,
                          color: inMonth ? event.color : kText2,
                        ),
                        SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event.label,
                            style: TextStyle(
                              color: inMonth ? kText1 : kText2,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (extraCount > 0)
              Text(
                '+$extraCount daha',
                style: TextStyle(
                  color: kText2,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayEventsSheet extends StatelessWidget {
  const _DayEventsSheet({required this.dateLabel, required this.events});

  final String dateLabel;
  final List<_CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              color: kText1,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          ...events.map((event) {
            final eventOpacity = event.faded ? 0.52 : 1.0;
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Opacity(
                opacity: eventOpacity,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: event.color.withAlpha(appTheme.isLight ? 28 : 42),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: event.color.withAlpha(115)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: event.color.withAlpha(42),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(event.icon, color: event.color, size: 18),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.label,
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
                              event.subtitle,
                              style: TextStyle(color: kText2, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
    );
  }
}

class _CalendarEntryDialog extends StatefulWidget {
  const _CalendarEntryDialog({required this.date});

  final DateTime date;

  @override
  State<_CalendarEntryDialog> createState() => _CalendarEntryDialogState();
}

class _CalendarEntryDialogState extends State<_CalendarEntryDialog> {
  _CalendarEntryType _type = _CalendarEntryType.busy;
  List<Lesson> _lessons = [];
  Lesson? _selectedLesson;
  String _startTime = '09:00';
  String _endTime = '10:00';
  int _fatigueLevel = 2;
  String _busyIconKey = 'energy';
  bool _isRoutineBusy = false;
  bool _loadingLessons = true;
  bool _saving = false;
  String? _error;

  final _titleCtrl = TextEditingController();

  static final _timeOptions = List.generate(37, (i) {
    final minutes = 6 * 60 + i * 30;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  });

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    try {
      final data = await ApiClient.getLessons();
      if (!mounted) return;
      final lessons = data
          .map((item) => Lesson.fromJson(item as Map<String, dynamic>))
          .toList();
      setState(() {
        _lessons = lessons;
        _selectedLesson = lessons.isEmpty ? null : lessons.first;
        _loadingLessons = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loadingLessons = false;
      });
    }
  }

  String get _dateKey =>
      '${widget.date.year.toString().padLeft(4, '0')}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

  String get _dateLabel =>
      '${widget.date.day}.${widget.date.month}.${widget.date.year}';

  int _timeToMinutes(String value) {
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  bool get _needsLesson =>
      _type == _CalendarEntryType.exam || _type == _CalendarEntryType.deadline;

  Widget _buildBusyIconPicker() {
    final color = _fatigueColor(_fatigueLevel);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _busyIconChoices.map((choice) {
        final selected = choice.key == _busyIconKey;
        return Tooltip(
          message: choice.tooltip,
          child: GestureDetector(
            onTap: _saving
                ? null
                : () => setState(() => _busyIconKey = choice.key),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 160),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? color.withAlpha(appTheme.isLight ? 34 : 48)
                    : kBorder.withAlpha(appTheme.isLight ? 42 : 56),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color : kBorder.withAlpha(120),
                  width: selected ? 1.5 : 0.8,
                ),
              ),
              child: Icon(
                choice.icon,
                color: selected ? color : kText2,
                size: 20,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _save() async {
    final start = _timeToMinutes(_startTime);
    final end = _timeToMinutes(_endTime);
    if (end <= start) {
      setState(() => _error = 'Bitiş saati başlangıçtan sonra olmalı.');
      return;
    }
    if (_needsLesson && _selectedLesson == null) {
      setState(() => _error = 'Önce bir ders seçmelisin.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_type == _CalendarEntryType.busy) {
        final slot = _BusySlot(
          dayOfWeek: widget.date.weekday,
          startTime: _startTime,
          endTime: _endTime,
          fatigueLevel: _fatigueLevel,
          iconKey: _busyIconKey,
          isRoutine: _isRoutineBusy,
          date: _isRoutineBusy ? null : _dateKey,
          localOnly: true,
        );
        if (_isRoutineBusy) {
          final user = await ApiClient.getMe();
          final slots = ((user['busySlots'] as List?) ?? [])
              .map((slot) => Map<String, dynamic>.from(slot as Map))
              .toList();
          slots.add(slot.toJson()..remove('localOnly'));
          await ApiClient.updateBusySlots(slots);
          await ApiClient.recalculate();
        }
        if (!mounted) return;
        Navigator.pop(context, slot);
        return;
      } else if (_type == _CalendarEntryType.exam) {
        await ApiClient.addExam(int.parse(_selectedLesson!.id), _dateKey);
      } else {
        final rawTitle = _titleCtrl.text.trim();
        final title = rawTitle.isEmpty
            ? 'Ödev $_startTime-$_endTime'
            : '$rawTitle ($_startTime-$_endTime)';
        await ApiClient.addDeadline(
          int.parse(_selectedLesson!.id),
          _dateKey,
          title: title,
        );
      }

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
    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kAccent.withAlpha(34),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_rounded, color: kAccent, size: 21),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dateLabel,
                      style: TextStyle(
                        color: kText1,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: kText2, size: 20),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
              SizedBox(height: 14),
              SegmentedButton<_CalendarEntryType>(
                segments: const [
                  ButtonSegment(
                    value: _CalendarEntryType.busy,
                    icon: Icon(Icons.block_rounded, size: 16),
                    label: Text('Busy'),
                  ),
                  ButtonSegment(
                    value: _CalendarEntryType.exam,
                    icon: Icon(Icons.school_outlined, size: 16),
                    label: Text('Sınav'),
                  ),
                  ButtonSegment(
                    value: _CalendarEntryType.deadline,
                    icon: Icon(Icons.assignment_outlined, size: 16),
                    label: Text('Ödev'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStatePropertyAll(kText1),
                ),
              ),
              SizedBox(height: 14),
              if (_loadingLessons && _needsLesson)
                Center(child: CircularProgressIndicator(color: kAccent))
              else ...[
                if (_needsLesson)
                  DropdownButtonFormField<Lesson>(
                    initialValue: _selectedLesson,
                    items: _lessons
                        .map(
                          (lesson) => DropdownMenuItem(
                            value: lesson,
                            child: Text(
                              lesson.lessonName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (lesson) => setState(() => _selectedLesson = lesson),
                    decoration: InputDecoration(labelText: 'Ders'),
                  ),
                if (_type == _CalendarEntryType.deadline) ...[
                  SizedBox(height: 10),
                  TextField(
                    controller: _titleCtrl,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: 'Ödev başlığı',
                      hintText: 'Proje teslimi',
                    ),
                  ),
                ],
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _startTime,
                        items: _timeOptions
                            .map(
                              (time) => DropdownMenuItem(
                                value: time,
                                child: Text(time),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _startTime = value!),
                        decoration: InputDecoration(labelText: 'Başlangıç'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _endTime,
                        items: _timeOptions
                            .map(
                              (time) => DropdownMenuItem(
                                value: time,
                                child: Text(time),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _endTime = value!),
                        decoration: InputDecoration(labelText: 'Bitiş'),
                      ),
                    ),
                  ],
                ),
                if (_type == _CalendarEntryType.busy) ...[
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Yorgunluk',
                        style: TextStyle(
                          color: kText1,
                          fontWeight: FontWeight.w700,
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
                              : (value) => setState(
                                  () => _fatigueLevel = value.round(),
                                ),
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
                    'Busy icon',
                    style: TextStyle(
                      color: kText1,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildBusyIconPicker(),
                  SizedBox(height: 8),
                  CheckboxListTile(
                    value: _isRoutineBusy,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _isRoutineBusy = value ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: kAccent,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Bu benim rutinim',
                      style: TextStyle(
                        color: kText1,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Rutin busy time takvimde daha silik görünür.',
                      style: TextStyle(color: kText2, fontSize: 11),
                    ),
                  ),
                ],
              ],
              if (_type == _CalendarEntryType.exam) ...[
                SizedBox(height: 8),
                Text(
                  'Sınavlar şu an gün bazlı kaydediliyor; saat aralığı not olarak tutulmaz.',
                  style: TextStyle(color: kText2, fontSize: 11),
                ),
              ],
              if (_error != null) ...[
                SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: _kDanger, fontSize: 12)),
              ],
              SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving || (_loadingLessons && _needsLesson)
                    ? null
                    : _save,
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
                label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, 82),
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
                        style: TextStyle(
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
                final showNow =
                    isToday && now.hour >= _startHour && now.hour < _endHour;
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
  double _minToTop(int minutes) => (minutes - _startHour * 60) * _slotH / 30;

  /// İki zaman arasındaki piksel yüksekliği.
  double _minToHeight(int sm, int em) => (em - sm) * _slotH / 30;

  Widget _blockNameOverlay(ScheduledBlock block) {
    final sm = _timeToMin(block.startTime);
    final em = _timeToMin(block.endTime);
    if (sm < _startHour * 60 || em > _endHour * 60 || sm >= em) {
      return SizedBox.shrink();
    }

    final color = lessonColor(block.lessonId);
    final name = block.lessonName.trim().isEmpty
        ? 'Ders'
        : block.lessonName.trim();
    final label = block.isReview ? '$name (Tekrar)' : name;

    return Positioned(
      top: _minToTop(sm) + 3,
      left: 5,
      right: 5,
      height: 20,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kSurface.withAlpha(appTheme.isLight ? 245 : 235),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withAlpha(175), width: 0.7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(appTheme.isLight ? 22 : 80),
                blurRadius: 7,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: kText1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isToday ? kAccent.withAlpha(10) : Colors.transparent,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Tam-saat yatay çizgiler
          ...List.generate(
            _endHour - _startHour,
            (i) => Positioned(
              top: i * 2 * _slotH,
              left: 0,
              right: 0,
              child: Container(height: 0.5, color: kBorder),
            ),
          ),
          // Yarım-saat işaret çizgileri (daha soluk)
          ...List.generate(
            _endHour - _startHour,
            (i) => Positioned(
              top: (i * 2 + 1) * _slotH,
              left: 0,
              right: 0,
              child: Container(height: 0.5, color: kBorder.withAlpha(100)),
            ),
          ),
          // Busy slotlar: çapraz çizgili + kesikli border + yorgunluk noktası
          ...busySlots.map((b) {
            final sm = _timeToMin(b.startTime);
            final em = _timeToMin(b.endTime);
            if (sm < _startHour * 60 || em > _endHour * 60 || sm >= em) {
              return SizedBox.shrink();
            }
            final top = _minToTop(sm);
            final height = _minToHeight(sm, em);
            final dotColor = _fatigueColor(b.fatigueLevel);
            final opacity = b.isRoutine ? 0.42 : 1.0;
            return Positioned(
              top: top,
              left: 1,
              right: 1,
              height: height,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: kBorder.withAlpha(160),
                      width: 0.5,
                    ),
                    color: Colors.white.withAlpha(10),
                  ),
                  child: CustomPaint(
                    painter: _StripedPainter(Colors.white.withAlpha(18)),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4, 3, 4, 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              SizedBox(width: 3),
                              Text(
                                b.isRoutine ? 'ROUTINE' : 'BUSY',
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
              ),
            );
          }),
          // Planlanmış çalışma blokları
          ...blocks.map((b) {
            final sm = _timeToMin(b.startTime);
            final em = _timeToMin(b.endTime);
            if (sm < _startHour * 60 || em > _endHour * 60 || sm >= em) {
              return SizedBox.shrink();
            }
            final top = _minToTop(sm);
            final height = (_minToHeight(sm, em) - 2).clamp(
              14.0,
              double.infinity,
            );
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
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: b.isReview
                          ? Colors.transparent
                          : color.withAlpha(38),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: color.withAlpha(100),
                        width: 0.5,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 3,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: color),
                          ),
                        ),
                        b.isReview
                            ? CustomPaint(
                                painter: _StripedPainter(color.withAlpha(0x33)),
                                child: _BlockContent(block: b, color: color),
                              )
                            : _BlockContent(block: b, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // Ders adları her çalışma slotunun en üstünde ayrı katman olarak görünür.
          ...blocks.map(_blockNameOverlay),
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
                    decoration: BoxDecoration(
                      color: _kDanger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(top: 2.25),
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

/// Ders adı ayrı overlay olarak çizildiği için blok içinde sadece ek zaman bilgisi kalır.
class _BlockContent extends StatelessWidget {
  const _BlockContent({required this.block, required this.color});

  final ScheduledBlock block;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTime = constraints.maxHeight >= 42;
        if (!showTime) return SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.fromLTRB(7, 26, 4, 3),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              '${block.startTime} - ${block.endTime}',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: color.withAlpha(220),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

// ── Striped Painter ───────────────────────────────────────────────────────────

/// Çapraz çizgi deseni boyayan CustomPainter — busy slot ve review blok arka planı.
class _StripedPainter extends CustomPainter {
  _StripedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const step = 7.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripedPainter old) => old.color != color;
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
          'delayed': completedBlocks < planned,
        });
      }

      await ApiClient.submitChecklist(
        date: widget.block.date,
        stressLevel: (existing?['stressLevel'] as num? ?? 2).toInt(),
        fatigueLevel: (existing?['fatigueLevel'] as num? ?? 3).toInt(),
        items: items,
      );

      if (!mounted) return;

      final today = AppTime.todayStr();
      final isLate = widget.block.date.compareTo(today) < 0;
      final isIncomplete = _completedBlocks < widget.block.blockCount;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLate && isIncomplete && _studiedMinutes > 0
                ? 'Logged ${_studiedMinutes}m for ${widget.block.date}.'
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
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
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text('Study block', style: TextStyle(fontSize: 13, color: kText2)),
          SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.block.lessonName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: kText1,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${widget.block.date} · ${widget.block.startTime} – ${widget.block.endTime}',
            style: TextStyle(fontSize: 13, color: kText2),
          ),
          SizedBox(height: 16),
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
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: EdgeInsets.only(bottom: 8),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: _isFull ? kAccent : kText2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Time studied',
                        style: TextStyle(fontSize: 13, color: kText2),
                      ),
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
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillRatio,
                    minHeight: 4,
                    backgroundColor: kBorder,
                    valueColor: AlwaysStoppedAnimation(
                      _isFull ? kAccent : widget.color,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 13, color: kText2),
                    Expanded(
                      child: Slider(
                        value: _studiedMinutes.toDouble(),
                        min: 0,
                        max: (_plannedMinutes * 1.5).ceilToDouble(),
                        divisions: ((_plannedMinutes * 1.5) / 10).ceil().clamp(
                          1,
                          999,
                        ),
                        activeColor: _isFull ? kAccent : widget.color,
                        inactiveColor: kBorder,
                        onChanged: (v) =>
                            setState(() => _studiedMinutes = v.round()),
                      ),
                    ),
                    Text(
                      '${_studiedMinutes}m',
                      style: TextStyle(
                        color: kText2,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _studiedMinutes == 0 ? 'Mark as skipped' : 'Save',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
      padding: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              child: Icon(icon, size: 16, color: tone ?? kText2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, color: kText2)),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tone ?? kText1,
              ),
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
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}
