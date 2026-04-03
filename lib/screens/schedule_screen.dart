import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/planner_model.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  WeeklySchedule? _plan;
  List<ChecklistItem> _todayChecklist = [];
  bool _loading = false;
  bool _fabOpen = false;
  late final AnimationController _fabAnim;
  late ColorScheme _cs;

  Color get _appBarBgColor => _cs.primary;
  Color get _errorSnackBarBgColor => Colors.red;
  Color get _primaryFabBgColor => _cs.primary;
  Color get _errorFabBgColor => _cs.error;
  Color get _secondaryFabBgColor => _cs.secondaryContainer;
  Color get _tableHeaderBgColor => _cs.primaryContainer.withAlpha(100);

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _loadToday();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    setState(() => _loading = true);
    try {
      final items = await ApiClient.getTodayChecklist();
      if (!mounted) return;
      setState(() {
        _todayChecklist =
            items.map((i) => ChecklistItem.fromJson(i)).toList();
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _generateWeekly() async {
    _closeFab();
    setState(() => _loading = true);
    try {
      final data = await ApiClient.createWeeklyPlan();
      if (!mounted) return;
      setState(() => _plan = WeeklySchedule.fromJson(data));
      _showMsg('Haftalik plan olusturuldu!');
    } catch (e) {
      if (!mounted) return;
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _showDailyUpdateDialog() async {
    _closeFab();
    double? hours;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Gunluk Guncelleme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bugun kac saat calisabilirsiniz?'),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Serbest Saat',
                  suffixText: 'saat',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
            FilledButton(
              onPressed: () {
                hours = double.tryParse(ctrl.text);
                Navigator.pop(ctx);
              },
              child: const Text('Guncelle'),
            ),
          ],
        );
      },
    );
    if (hours == null) return;
    setState(() => _loading = true);
    try {
      final data = await ApiClient.dailyUpdate(hours!);
      final slots = (data['slots'] as List)
          .map((s) => DailySlot.fromJson(s as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _plan = WeeklySchedule(
          generatedAt: DateTime.now().toIso8601String(),
          weekStart: data['date'] as String,
          slots: slots,
        );
      });
      _showMsg('Gunluk plan guncellendi!');
    } catch (e) {
      if (!mounted) return;
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _createChecklist() async {
    _closeFab();
    if (_plan == null) {
      _showErr('Once haftalik plan olusturun');
      return;
    }
    final today =
        DateTime.now().toIso8601String().substring(0, 10);
    final todaySlots =
        _plan!.slots.where((s) => s.day == today).toList();
    if (todaySlots.isEmpty) {
      _showErr('Bugun icin plan yok');
      return;
    }
    setState(() => _loading = true);
    try {
      final slots = todaySlots
          .map((s) => {
                'lessonId': s.lessonId,
                'lessonName': s.lessonName,
                'hours': s.hours,
              })
          .toList();
      await ApiClient.createChecklist(slots);
      await _loadToday();
      if (!mounted) return;
      _showMsg('Kontrol listesi olusturuldu!');
    } catch (e) {
      if (!mounted) return;
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

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

  void _showMsg(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  void _showErr(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: _errorSnackBarBgColor));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _cs = cs;
    final wideLayout = MediaQuery.sizeOf(context).width >= 1100;

    final scrollView = CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: wideLayout ? 148 : 120,
          pinned: true,
          backgroundColor: _appBarBgColor,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('Program', style: TextStyle(color: cs.onPrimary)),
            background: Container(color: _appBarBgColor),
          ),
        ),
        if (wideLayout)
          SliverToBoxAdapter(
            child: _buildDesktopActions(cs),
          ),
        if (_todayChecklist.isNotEmpty) ...[
          _sectionHeader('Bugunku Kontrol Listesi'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _checklistTile(_todayChecklist[i]),
              childCount: _todayChecklist.length,
            ),
          ),
        ],
        if (_plan != null) ...[
          _sectionHeader('Haftalik Plan — ${_plan!.weekStart}'),
          SliverToBoxAdapter(child: _buildVisualSchedule(cs)),
        ],
        if (_plan == null && _todayChecklist.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: cs.outline),
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
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );

    return GestureDetector(
      onTap: _fabOpen ? _closeFab : null,
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadToday,
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
                      'Haftalik plan, gunluk guncelleme ve kontrol listesi islemlerini masaustu yerlesiminden yonet.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _generateWeekly,
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Haftalik Plan'),
              ),
              FilledButton.tonalIcon(
                onPressed: _showDailyUpdateDialog,
                icon: const Icon(Icons.today_rounded),
                label: const Text('Gunluk Guncelle'),
              ),
              OutlinedButton.icon(
                onPressed: _createChecklist,
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Kontrol Listesi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                      label: 'Kontrol Listesi Olustur',
                      onTap: _createChecklist,
                      cs: cs,
                    ),
                    const SizedBox(height: 8),
                    _miniFab(
                      icon: Icons.today_rounded,
                      label: 'Gunluk Guncelle',
                      onTap: _showDailyUpdateDialog,
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
            child: Icon(_fabOpen ? Icons.close : Icons.add,
                color: _fabOpen ? cs.onError : cs.onPrimary),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
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

  Widget _checklistTile(ChecklistItem item) {
    final cs = Theme.of(context).colorScheme;
    Color statusColor;
    IconData statusIcon;
    switch (item.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'early':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'incomplete':
        statusColor = Colors.orange;
        statusIcon = Icons.radio_button_unchecked;
        break;
      case 'not_done':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = cs.primary;
        statusIcon = Icons.pending_outlined;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(item.lessonName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${item.plannedHours} saat planli'),
        trailing: item.status == 'pending'
            ? TextButton(
                onPressed: () => _showSubmitDialog(item),
                child: const Text('Bildir'),
              )
            : Text(
                item.status,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
      ),
    );
  }

  Future<void> _showSubmitDialog(ChecklistItem item) async {
    String status = 'completed';
    final ctrl = TextEditingController(
        text: item.plannedHours.toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(item.lessonName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Planlanan: ${item.plannedHours} saat'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Gercek Calisma (saat)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Durum:'),
              ...[
                ('completed', 'Tamamlandi'),
                ('early', 'Erken Bitti'),
                ('incomplete', 'Eksik Kaldi'),
                ('not_done', 'Yapilmadi'),
              ].map((e) => RadioListTile<String>(
                    dense: true,
                    title: Text(e.$2),
                    value: e.$1,
                    groupValue: status,
                    onChanged: (v) => setS(() => status = v!),
                  )),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Iptal')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  await ApiClient.submitChecklist({
                    'lessonId': item.lessonId,
                    'actualHours': double.tryParse(ctrl.text),
                    'status': status,
                  });
                  await _loadToday();
                  if (!mounted) return;
                  _showMsg('Bildirildi!');
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

  SliverToBoxAdapter _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildVisualSchedule(ColorScheme cs) {
    final daysLabels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
    final hours = List.generate(13, (i) => '${(i + 8).toString().padLeft(2, '0')}:00');
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    
    final grid = List.generate(13, (_) => List<DailySlot?>.generate(7, (_) => null));
    if (_plan == null) return const SizedBox.shrink();
    
    final byDay = _plan!.byDay;
    final dayKeys = byDay.keys.toList()..sort();

    for (int d = 0; d < dayKeys.length && d < 7; d++) {
      final slots = byDay[dayKeys[d]]!;
      for (int h = 0; h < slots.length && h < 13; h++) {
        grid[h][d] = slots[h];
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            constraints: const BoxConstraints(minWidth: 600),
            child: Table(
              border: TableBorder.all(color: cs.outlineVariant, width: 0.5),
              columnWidths: const {
                0: FixedColumnWidth(60),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: _tableHeaderBgColor),
                  children: [
                    const SizedBox(height: 40, child: Center(child: Text('Saat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                    ...daysLabels.map((d) => SizedBox(height: 40, child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))))),
                  ],
                ),
                ...List.generate(13, (hIdx) {
                  return TableRow(
                    children: [
                      SizedBox(
                        height: 50,
                        child: Center(
                          child: Text(
                            hours[hIdx],
                            style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      ...List.generate(7, (dIdx) {
                        final slot = grid[hIdx][dIdx];
                        final isToday = slot != null && slot.day == todayStr;
                        
                        return TableCell(
                          child: InkWell(
                            onTap: slot == null ? null : () {
                              try {
                                final item = _todayChecklist.firstWhere(
                                  (i) => i.lessonId == slot.lessonId,
                                );
                                _showSubmitDialog(item);
                              } catch (_) {
                                if (isToday) {
                                  _showErr('Bu ders bugunku kontrol listesinde bulunamadi.');
                                } else {
                                  _showMsg('Sadece bugunun dersleri icin bildirim yapabilirsiniz.');
                                }
                              }
                            },
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.all(2),
                              color: slot != null 
                                ? (isToday ? cs.primary.withAlpha(40) : cs.primary.withAlpha(15))
                                : null,
                              child: slot != null
                                  ? Center(
                                      child: Text(
                                        slot.lessonName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9, 
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                          color: isToday ? cs.primary : null,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
