import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/planner_model.dart';

/// Program ekranı: haftalık plan blokları ve günlük checklist yönetimi.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  WeeklyPlan? _plan;
  DailyChecklist? _todayChecklist;
  bool _loading = false;
  bool _fabOpen = false;
  late final AnimationController _fabAnim;
  late ColorScheme _cs;

  Color get _appBarBgColor => _cs.primary;
  Color get _errorSnackBarBgColor => Colors.red;
  Color get _primaryFabBgColor => _cs.primary;
  Color get _errorFabBgColor => _cs.error;
  Color get _secondaryFabBgColor => _cs.secondaryContainer;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadData();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
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
  /// Ders adlarını haftalık plan bloklarından tamamlar.
  DailyChecklist _parseChecklist(
    Map<String, dynamic> data,
    WeeklyPlan? plan,
  ) {
    // Ders adı haritası: lessonId → lessonName
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
        lessonName: lessonNames[lessonId] ?? 'Ders',
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

  /// Haftalık planı POST /planner/create ile oluşturur.
  Future<void> _generateWeekly() async {
    _closeFab();
    setState(() => _loading = true);
    try {
      final data = await ApiClient.createWeeklyPlan();
      if (!mounted) return;
      setState(() => _plan = WeeklyPlan.fromJson(data));
      _showMsg('Haftalik plan olusturuldu!');
    } catch (e) {
      if (!mounted) return;
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// Checklist gönderme dialogunu açar.
  Future<void> _openSubmitChecklist() async {
    _closeFab();
    if (_plan == null) {
      _showErr('Once haftalik plan olusturun.');
      return;
    }

    final today = _todayString();
    final todayBlocks = _plan!.blocksForDate(today);
    if (todayBlocks.isEmpty) {
      _showErr('Bugun icin planlanmis ders blogu yok.');
      return;
    }

    await _showChecklistSubmitDialog(todayBlocks);
  }

  /// FAB açma/kapama.
  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    if (_fabOpen) {
      _fabAnim.forward();
    } else {
      _fabAnim.reverse();
    }
  }

  void _closeFab() {
    setState(() => _fabOpen = false);
    _fabAnim.reverse();
  }

  void _showMsg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showErr(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: _errorSnackBarBgColor),
  );

  /// Bugünün tarihini "YYYY-MM-DD" formatında döndürür.
  String _todayString() => DateTime.now().toIso8601String().substring(0, 10);

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

    // Dersleri tekil listele (aynı ders birden fazla blokta olabilir)
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
          title: const Text('Gunluk Kontrol Listesi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stres seviyesi
                Row(
                  children: [
                    const Text('Stres: '),
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
                // Yorgunluk seviyesi
                Row(
                  children: [
                    const Text('Yorgunluk: '),
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
                const Divider(),
                // Her ders için tamamlanan blok sayısı
                ...uniqueBlocks.values.map((block) {
                  // Bu derse ait toplam planlanan blok
                  final totalPlanned = todayBlocks
                      .where((b) => b.lessonId == block.lessonId)
                      .fold(0, (sum, b) => sum + b.blockCount);
                  final completed = completedMap[block.lessonId] ?? 0;
                  final delayed = delayedMap[block.lessonId] ?? false;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.isReview
                              ? '${block.lessonName} (Tekrar)'
                              : block.lessonName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Planlanan: $totalPlanned blok (${totalPlanned * 30} dk)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Row(
                          children: [
                            const Text('Tamamlanan blok: '),
                            Expanded(
                              child: Slider(
                                value: completed.toDouble(),
                                min: 0,
                                max: totalPlanned.toDouble(),
                                divisions: totalPlanned > 0 ? totalPlanned : 1,
                                label: completed.toString(),
                                onChanged: (v) => setS(
                                  () => completedMap[block.lessonId] =
                                      v.toInt(),
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
                          title: const Text(
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
              child: const Text('Iptal'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  // Her ders için item oluştur
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
                    stressLevel: stressLevel,
                    fatigueLevel: fatigueLevel,
                    items: items,
                  );
                  await _loadData();
                  if (!mounted) return;
                  _showMsg('Kontrol listesi kaydedildi!');
                } catch (e) {
                  if (!mounted) return;
                  _showErr(e.toString().replaceAll('Exception: ', ''));
                }
                if (!mounted) return;
                setState(() => _loading = false);
              },
              child: const Text('Kaydet'),
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
            title: Text('Program', style: TextStyle(color: cs.onPrimary)),
            background: Container(color: _appBarBgColor),
          ),
        ),

        // Masaüstü hızlı işlemler
        if (wideLayout) SliverToBoxAdapter(child: _buildDesktopActions(cs)),

        // Bugünün checklist özeti
        if (_todayChecklist != null) ...[
          _sectionHeader('Bugunku Kontrol Listesi — $today'),
          SliverToBoxAdapter(child: _buildChecklistSummary(cs)),
        ],

        // Haftalık plan
        if (_plan != null) ...[
          _sectionHeader('Haftalik Plan — ${_plan!.weekStart}'),
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
                  const SizedBox(height: 16),
                  Text(
                    'Henuz plan yok',
                    style: TextStyle(fontSize: 18, color: cs.outline),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wideLayout
                        ? 'Ustteki hizli islemlerden plan olusturabilirsin'
                        : 'Asagidaki butona basarak plan olusturun',
                    style: TextStyle(color: cs.outline),
                  ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );

    return GestureDetector(
      onTap: _fabOpen ? _closeFab : null,
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: wideLayout
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: scrollView,
                        ),
                      )
                    : scrollView,
              ),
        floatingActionButton: wideLayout ? null : _buildSpeedDial(cs),
      ),
    );
  }

  // ── Alt widget'lar ───────────────────────────────────────────────────────────

  /// Masaüstü hızlı işlem kartı.
  Widget _buildDesktopActions(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 6),
                    Text(
                      'Haftalik plan olustur veya gunluk kontrol listesi kaydet.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _generateWeekly,
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Haftalik Plan Olustur'),
              ),
              OutlinedButton.icon(
                onPressed: _openSubmitChecklist,
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Kontrol Listesi Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mobil speed dial FAB.
  Widget _buildSpeedDial(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _fabOpen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _miniFab(
                      icon: Icons.checklist_rounded,
                      label: 'Kontrol Listesi Kaydet',
                      onTap: _openSubmitChecklist,
                      cs: cs,
                    ),
                    const SizedBox(height: 8),
                    _miniFab(
                      icon: Icons.calendar_month_rounded,
                      label: 'Haftalik Plan Olustur',
                      onTap: _generateWeekly,
                      cs: cs,
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: _fabOpen ? _errorFabBgColor : _primaryFabBgColor,
          child: AnimatedRotation(
            turns: _fabOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              _fabOpen ? Icons.close : Icons.add,
              color: _fabOpen ? cs.onError : cs.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniFab({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: label,
            onPressed: onTap,
            backgroundColor: _secondaryFabBgColor,
            child: Icon(icon, color: cs.onSecondaryContainer, size: 20),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Checklist özeti ──────────────────────────────────────────────────────────

  /// Bugünkü checklist özetini kart olarak gösterir.
  Widget _buildChecklistSummary(ColorScheme cs) {
    final cl = _todayChecklist!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mood_outlined, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Stres: ${cl.stressLevel}/5  •  Yorgunluk: ${cl.fatigueLevel}/5',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                    '${item.completedBlocks}/${item.plannedBlocks} blok tamamlandi'
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
    if (_plan == null) return const SizedBox.shrink();

    // 7 günü sırayla göster; her gün için o güne ait blokları listele
    final weekDays = List.generate(7, (i) {
      final dt = DateTime.parse(_plan!.weekStart).add(Duration(days: i));
      return dt.toIso8601String().substring(0, 10);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: weekDays.map((date) {
          final blocks = _plan!.blocksForDate(date);
          final isToday = date == today;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
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
                  ? const Text('Ders yok')
                  : Text(
                      '${blocks.length} blok  •  '
                      '${blocks.fold(0, (sum, b) => sum + b.blockCount) * 30} dk',
                    ),
              children: blocks.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Bu gun icin planlanmis ders yok.'),
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
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${block.startTime} – ${block.endTime}  •  $minutes dk'),
      trailing: block.completed
          ? const Icon(Icons.check, color: Colors.green, size: 18)
          : null,
    );
  }

  /// Tarih stringinden kısa gün adı üretir (orn: "Pzt").
  String _shortDay(String date) {
    try {
      final dt = DateTime.parse(date);
      const labels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
      return labels[(dt.weekday - 1) % 7];
    } catch (_) {
      return '?';
    }
  }
}
