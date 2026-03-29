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
      setState(() {
        _todayChecklist =
            items.map((i) => ChecklistItem.fromJson(i)).toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _generateWeekly() async {
    _closeFab();
    setState(() => _loading = true);
    try {
      final data = await ApiClient.createWeeklyPlan();
      setState(() => _plan = WeeklySchedule.fromJson(data));
      _showMsg('Haftalik plan olusturuldu!');
    } catch (e) {
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
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
      setState(() {
        _plan = WeeklySchedule(
          generatedAt: DateTime.now().toIso8601String(),
          weekStart: data['date'] as String,
          slots: slots,
        );
      });
      _showMsg('Gunluk plan guncellendi!');
    } catch (e) {
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
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
      _showMsg('Kontrol listesi olusturuldu!');
    } catch (e) {
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
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
      SnackBar(content: Text(m), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _fabOpen ? _closeFab : null,
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadToday,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 120,
                      pinned: true,
                      backgroundColor: cs.primary,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text('Program',
                            style: TextStyle(color: cs.onPrimary)),
                        background: Container(color: cs.primary),
                      ),
                    ),
                    if (_todayChecklist.isNotEmpty) ...[
                      _sectionHeader('Bugunku Kontrol Listesi'),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) =>
                              _checklistTile(_todayChecklist[i]),
                          childCount: _todayChecklist.length,
                        ),
                      ),
                    ],
                    if (_plan != null) ...[
                      _sectionHeader(
                          'Haftalik Plan — ${_plan!.weekStart}'),
                      ..._buildWeekSlots(),
                    ],
                    if (_plan == null && _todayChecklist.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 64, color: cs.outline),
                              const SizedBox(height: 16),
                              Text('Henuz plan yok',
                                  style: TextStyle(
                                      fontSize: 18, color: cs.outline)),
                              const SizedBox(height: 8),
                              Text(
                                  'Asagidaki butona basarak plan olusturun',
                                  style: TextStyle(color: cs.outline)),
                            ],
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 100)),
                  ],
                ),
              ),
        floatingActionButton: _buildSpeedDial(cs),
      ),
    );
  }

  Widget _buildSpeedDial(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FABs — shown when open
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
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: _fabOpen ? cs.error : cs.primary,
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
            backgroundColor: cs.secondaryContainer,
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
                  _showMsg('Bildirildi!');
                } catch (e) {
                  _showErr(e.toString().replaceAll('Exception: ', ''));
                }
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

  List<SliverToBoxAdapter> _buildWeekSlots() {
    final byDay = _plan!.byDay;
    final days = byDay.keys.toList()..sort();
    return days.map((day) {
      final slots = byDay[day]!;
      final label = slots.first.dayLabel ?? day;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...slots.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.book_outlined,
                                size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s.lessonName)),
                            Text('${s.hours.toStringAsFixed(1)} saat',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
