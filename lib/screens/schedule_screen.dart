import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_time.dart';
import '../models/planner_model.dart';

/// Program ekranı: haftalık plan blokları ve günlük checklist yönetimi.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  WeeklyPlan? _plan;
  DailyChecklist? _todayChecklist;
  bool _loading = false;
  late ColorScheme _cs;

  Color get _appBarBgColor => _cs.primary;
  Color get _errorSnackBarBgColor => Colors.red;
  Color get _primaryFabBgColor => _cs.primary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Veri yükleme ────────────────────────────────────────────────────────────

  /// Haftalık planı ve bugünün checklist'ini yükler.
  Future<void> _loadData() async {
    setState(() => _loading = true);
    WeeklyPlan? plan;
    DailyChecklist? checklist;

    // Haftalık plan yükle
    try {
      final data = await ApiClient.getWeekPlan();
      plan = WeeklyPlan.fromJson(data);
    } catch (_) {}

    // Bugünün checklist'ini yükle
    try {
      final today = _todayString();
      final data = await ApiClient.getChecklist(today);
      if (data != null) {
        checklist = _parseChecklist(data, plan);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _plan = plan;
      _todayChecklist = checklist;
      _loading = false;
    });
  }

  /// API'den dönen ham checklist verisini [DailyChecklist] modeline dönüştürür.
  /// Lesson adlarını haftalık plan bloklarından tamamlar.
  DailyChecklist _parseChecklist(Map<String, dynamic> data, WeeklyPlan? plan) {
    // Lesson adı haritası: lessonId → lessonName
    final lessonNames = <int, String>{};
    if (plan != null) {
      for (final b in plan.blocks) {
        lessonNames[b.lessonId] = b.lessonName;
      }
    }

    final rawItems = (data['items'] as List? ?? []);
    final items = rawItems.map((raw) {
      final r = raw as Map<String, dynamic>;
      final lessonId = (r['lessonId'] as num).toInt();
      return ChecklistItem(
        id: (r['id'] as num).toInt(),
        lessonId: lessonId,
        lessonName: lessonNames[lessonId] ?? 'Lesson',
        plannedBlocks: (r['plannedBlocks'] as num).toInt(),
        completedBlocks: (r['completedBlocks'] as num? ?? 0).toInt(),
        delayed: r['delayed'] as bool? ?? false,
      );
    }).toList();

    return DailyChecklist(
      id: (data['id'] as num).toInt(),
      date: (data['date'] as String).substring(0, 10),
      stressLevel: (data['stressLevel'] as num? ?? 3).toInt(),
      fatigueLevel: (data['fatigueLevel'] as num? ?? 3).toInt(),
      items: items,
    );
  }

  // ── Eylemler ────────────────────────────────────────────────────────────────

  /// Checklist gönderme dialogunu açar.
  Future<void> _openSubmitChecklist() async {
    if (_plan == null) {
      _showErr('Create a weekly plan first.');
      return;
    }

    final today = _todayString();
    final todayBlocks = _plan!.blocksForDate(today);
    if (todayBlocks.isEmpty) {
      _showErr('There is no planned lesson block for today.');
      return;
    }

    await _showChecklistSubmitDialog(todayBlocks);
  }

  void _showMsg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showErr(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: _errorSnackBarBgColor),
  );

  /// Bugünün tarihini "YYYY-MM-DD" formatında döndürür.
  String _todayString() => AppTime.todayStr();

  // ── Checklist dialog ────────────────────────────────────────────────────────

  /// Bugün için checklist gönderme dialogunu gösterir.
  Future<void> _showChecklistSubmitDialog(
    List<ScheduledBlock> todayBlocks,
  ) async {
    // Her blok için tamamlanan blok sayısını tutan map: lessonId → completedBlocks
    final completedMap = <int, int>{};
    final delayedMap = <int, bool>{};
    for (final b in todayBlocks) {
      completedMap.putIfAbsent(b.lessonId, () => 0);
      delayedMap.putIfAbsent(b.lessonId, () => false);
    }

    // Lessonleri tekil listele (aynı lesson birden fazla blokta olabilir)
    final uniqueBlocks = <int, ScheduledBlock>{};
    for (final b in todayBlocks) {
      uniqueBlocks.putIfAbsent(b.lessonId, () => b);
    }

    int stressLevel = 3;
    int fatigueLevel = 3;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Daily Checklist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stres seviyesi
                Row(
                  children: [
                    Text('Stress: '),
                    Expanded(
                      child: Slider(
                        value: stressLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: stressLevel.toString(),
                        onChanged: (v) => setS(() => stressLevel = v.toInt()),
                      ),
                    ),
                    Text('$stressLevel/5'),
                  ],
                ),
                // Fatigue seviyesi
                Row(
                  children: [
                    Text('Fatigue: '),
                    Expanded(
                      child: Slider(
                        value: fatigueLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: fatigueLevel.toString(),
                        onChanged: (v) => setS(() => fatigueLevel = v.toInt()),
                      ),
                    ),
                    Text('$fatigueLevel/5'),
                  ],
                ),
                Divider(),
                // Her lesson için tamamlanan blok sayısı
                ...uniqueBlocks.values.map((block) {
                  // Bu lessone ait toplam planlanan blok
                  final totalPlanned = todayBlocks
                      .where((b) => b.lessonId == block.lessonId)
                      .fold(0, (sum, b) => sum + b.blockCount);
                  final completed = completedMap[block.lessonId] ?? 0;
                  final delayed = delayedMap[block.lessonId] ?? false;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.isReview
                              ? '${block.lessonName} (Tekrar)'
                              : block.lessonName,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Planned: $totalPlanned blocks (${totalPlanned * 30} min)',
                          style: TextStyle(fontSize: 12),
                        ),
                        Row(
                          children: [
                            Text('Completed blocks: '),
                            Expanded(
                              child: Slider(
                                value: completed.toDouble(),
                                min: 0,
                                max: totalPlanned.toDouble(),
                                divisions: totalPlanned > 0 ? totalPlanned : 1,
                                label: completed.toString(),
                                onChanged: (v) => setS(
                                  () =>
                                      completedMap[block.lessonId] = v.toInt(),
                                ),
                              ),
                            ),
                            Text('$completed'),
                          ],
                        ),
                        // Ertelendi toggle
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Ertelendi',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: delayed,
                          onChanged: (v) =>
                              setS(() => delayedMap[block.lessonId] = v),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  // Her lesson için item oluştur
                  final items = uniqueBlocks.values.map((block) {
                    final totalPlanned = todayBlocks
                        .where((b) => b.lessonId == block.lessonId)
                        .fold(0, (sum, b) => sum + b.blockCount);
                    return {
                      'lessonId': block.lessonId,
                      'plannedBlocks': totalPlanned,
                      'completedBlocks': completedMap[block.lessonId] ?? 0,
                      'delayed': delayedMap[block.lessonId] ?? false,
                    };
                  }).toList();

                  await ApiClient.submitChecklist(
                    date: _todayString(),
                    stressLevel: stressLevel,
                    fatigueLevel: fatigueLevel,
                    items: items,
                  );
                  await _loadData();
                  if (!mounted) return;
                  _showMsg('Checklist saved!');
                } catch (e) {
                  if (!mounted) return;
                  _showErr(e.toString().replaceAll('Exception: ', ''));
                }
                if (!mounted) return;
                setState(() => _loading = false);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _cs = cs;
    final wideLayout = MediaQuery.sizeOf(context).width >= 1100;
    final today = _todayString();

    final scrollView = CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          expandedHeight: wideLayout ? 148 : 120,
          pinned: true,
          backgroundColor: _appBarBgColor,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('Schedule', style: TextStyle(color: cs.onPrimary)),
            background: Container(color: _appBarBgColor),
          ),
        ),

        // Masaüstü hızlı işlemler
        if (wideLayout) SliverToBoxAdapter(child: _buildDesktopActions(cs)),

        // Bugünün checklist özeti
        if (_todayChecklist != null) ...[
          _sectionHeader("Today's Checklist - $today"),
          SliverToBoxAdapter(child: _buildChecklistSummary(cs)),
        ],

        // Haftalık plan
        if (_plan != null) ...[
          _sectionHeader('Weekly Plan — ${_plan!.weekStart}'),
          SliverToBoxAdapter(child: _buildWeeklyPlan(cs, today)),
        ],

        // Boş durum
        if (_plan == null && _todayChecklist == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: cs.outline,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No schedule yet',
                    style: TextStyle(fontSize: 18, color: cs.outline),
                  ),
                  SizedBox(height: 8),
                  Text(
                    wideLayout
                        ? 'You can create a schedule from the quick actions above'
                        : 'Create a schedule using the button below',
                    style: TextStyle(color: cs.outline),
                  ),
                ],
              ),
            ),
          ),

        SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );

    return Scaffold(
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: wideLayout
                  ? Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 1180),
                        child: scrollView,
                      ),
                    )
                  : scrollView,
            ),
      floatingActionButton: wideLayout ? null : _buildSpeedDial(cs),
    );
  }

  // ── Alt widget'lar ───────────────────────────────────────────────────────────

  /// Masaüstü hızlı işlem kartı.
  Widget _buildDesktopActions(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hizli Islemler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Save daily checklist.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openSubmitChecklist,
                icon: Icon(Icons.checklist_rounded),
                label: Text('Save Checklist'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mobil FAB — kontrol listesi kaydet.
  Widget _buildSpeedDial(ColorScheme cs) {
    return FloatingActionButton(
      onPressed: _openSubmitChecklist,
      backgroundColor: _primaryFabBgColor,
      child: Icon(Icons.checklist_rounded, color: cs.onPrimary),
    );
  }

  SliverToBoxAdapter _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Checklist özeti ──────────────────────────────────────────────────────────

  /// Bugünkü checklist özetini kart olarak gösterir.
  Widget _buildChecklistSummary(ColorScheme cs) {
    final cl = _todayChecklist!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mood_outlined, color: cs.primary),
                  SizedBox(width: 8),
                  Text(
                    'Stress: ${cl.stressLevel}/5  •  Fatigue: ${cl.fatigueLevel}/5',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 8),
              ...cl.items.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.completedBlocks >= item.plannedBlocks
                        ? Icons.check_circle
                        : item.delayed
                        ? Icons.cancel_outlined
                        : Icons.radio_button_unchecked,
                    color: item.completedBlocks >= item.plannedBlocks
                        ? Colors.green
                        : item.delayed
                        ? Colors.red
                        : cs.primary,
                  ),
                  title: Text(item.lessonName),
                  subtitle: Text(
                    '${item.completedBlocks}/${item.plannedBlocks} blocks completed'
                    '${item.delayed ? ' • Ertelendi' : ''}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Haftalık plan görünümü ───────────────────────────────────────────────────

  /// Haftalık planı gün bazında liste olarak gösterir.
  Widget _buildWeeklyPlan(ColorScheme cs, String today) {
    if (_plan == null) return SizedBox.shrink();

    // 7 günü sırayla göster; her gün için o güne ait blokları listele
    final weekDays = List.generate(7, (i) {
      final dt = DateTime.parse(_plan!.weekStart).add(Duration(days: i));
      return dt.toIso8601String().substring(0, 10);
    });

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: weekDays.map((date) {
          final blocks = _plan!.blocksForDate(date);
          final isToday = date == today;

          return Card(
            margin: EdgeInsets.only(bottom: 8),
            color: isToday ? cs.primaryContainer.withAlpha(60) : null,
            child: ExpansionTile(
              initiallyExpanded: isToday,
              leading: CircleAvatar(
                backgroundColor: isToday
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                child: Text(
                  _shortDay(date),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isToday ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
              title: Text(
                date,
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? cs.primary : null,
                ),
              ),
              subtitle: blocks.isEmpty
                  ? Text('No lessons')
                  : Text(
                      '${blocks.length} blocks  •  '
                      '${blocks.fold(0, (sum, b) => sum + b.blockCount) * 30} min',
                    ),
              children: blocks.isEmpty
                  ? [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No planned lessons for this day.'),
                      ),
                    ]
                  : blocks.map((b) => _blockTile(b, cs)).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Tek bir ScheduledBlock için liste tile'ı.
  Widget _blockTile(ScheduledBlock block, ColorScheme cs) {
    final minutes = block.blockCount * 30;
    return ListTile(
      dense: true,
      leading: Icon(
        block.isReview
            ? Icons.replay_outlined
            : block.completed
            ? Icons.check_circle_outline
            : Icons.book_outlined,
        color: block.isReview
            ? cs.tertiary
            : block.completed
            ? Colors.green
            : cs.primary,
        size: 20,
      ),
      title: Text(
        block.isReview ? '${block.lessonName} (Tekrar)' : block.lessonName,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${block.startTime} – ${block.endTime}  •  $minutes min'),
      trailing: block.completed
          ? Icon(Icons.check, color: Colors.green, size: 18)
          : null,
    );
  }

  /// Tarih stringinden kısa gün adı üretir (orn: "Mon").
  String _shortDay(String date) {
    try {
      final dt = DateTime.parse(date);
      const labels = ['Mon', 'Tue', 'Car', 'Thu', 'Fri', 'Sat', 'Sun'];
      return labels[(dt.weekday - 1) % 7];
    } catch (_) {
      return '?';
    }
  }
}
