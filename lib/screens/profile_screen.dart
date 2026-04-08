import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/lesson_model.dart';

const int _busyScheduleStartHour = 8;
const int _busyScheduleEndHour = 21;
const double _busyScheduleCellHeight = 52;
const double _busyScheduleHourColumnWidth = 68;
const double _busyScheduleDayColumnWidth = 132;

class _BusyTimeEntry {
  const _BusyTimeEntry({
    required this.dayLabel,
    required this.startHour,
    required this.endHour,
    this.reason,
  });

  final String dayLabel;
  final int startHour;
  final int endHour;
  final String? reason;

  String toDisplayString() {
    final base = '$dayLabel ${_formatHour(startHour)}-${_formatHour(endHour)}';
    final cleanReason = reason?.trim() ?? '';
    if (cleanReason.isEmpty || cleanReason.toLowerCase() == 'mesgul') {
      return base;
    }
    return '$base ($cleanReason)';
  }

  static String _formatHour(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00';
}

class _BusyTimeFormResult {
  const _BusyTimeFormResult.save(this.value) : delete = false;

  const _BusyTimeFormResult.delete() : value = null, delete = true;

  final String? value;
  final bool delete;
}

class _BusyTimeDisplayItem {
  const _BusyTimeDisplayItem({
    required this.index,
    required this.entry,
    required this.visibleStartHour,
    required this.visibleEndHour,
  });

  final int index;
  final _BusyTimeEntry entry;
  final int visibleStartHour;
  final int visibleEndHour;
}

class _BusyTimeFormScreen extends StatefulWidget {
  const _BusyTimeFormScreen({
    required this.weekdayLabels,
    required this.existingBusyTimes,
    this.initialValue,
    this.editIndex,
  });

  final List<String> weekdayLabels;
  final List<String> existingBusyTimes;
  final _BusyTimeEntry? initialValue;
  final int? editIndex;

  @override
  State<_BusyTimeFormScreen> createState() => _BusyTimeFormScreenState();
}

class _BusyTimeFormScreenState extends State<_BusyTimeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonCtrl;
  late String _selectedDay;
  late int _startHour;
  late int _endHour;
  String? _timeError;

  bool get _isEditing => widget.editIndex != null;

  List<int> get _startHourOptions => List<int>.generate(
    _busyScheduleEndHour - _busyScheduleStartHour,
    (index) => _busyScheduleStartHour + index,
  );

  List<int> get _endHourOptions => List<int>.generate(
    _busyScheduleEndHour - _busyScheduleStartHour,
    (index) => _busyScheduleStartHour + index + 1,
  );

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController(
      text: widget.initialValue?.reason ?? '',
    );
    _selectedDay = widget.initialValue?.dayLabel ?? widget.weekdayLabels.first;
    _startHour = math.max(
      _busyScheduleStartHour,
      math.min(widget.initialValue?.startHour ?? 9, _busyScheduleEndHour - 1),
    );
    _endHour = math.max(
      _startHour + 1,
      math.min(widget.initialValue?.endHour ?? 10, _busyScheduleEndHour),
    );
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_endHour <= _startHour) {
      setState(() => _timeError = 'Bitis saati baslangictan sonra olmali.');
      return;
    }

    final result = _BusyTimeEntry(
      dayLabel: _selectedDay,
      startHour: _startHour,
      endHour: _endHour,
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
    ).toDisplayString();

    final duplicateIndex = widget.existingBusyTimes.indexOf(result);
    if (duplicateIndex != -1 && duplicateIndex != widget.editIndex) {
      setState(() => _timeError = 'Bu mesgul saat zaten ekli.');
      return;
    }

    Navigator.of(context).pop(_BusyTimeFormResult.save(result));
  }

  Future<void> _delete() async {
    if (!_isEditing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mesgul Saati Sil'),
        content: const Text('Bu busy time kaydi silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const _BusyTimeFormResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Mesgul Saat Duzenle' : 'Mesgul Saat Ekle'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Sil',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tum parametreleri bu ekrandan girin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Gun, baslangic, bitis ve aciklamayi tek seferde duzenleyebilirsiniz.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDay,
                          decoration: const InputDecoration(
                            labelText: 'Gun',
                            border: OutlineInputBorder(),
                          ),
                          items: widget.weekdayLabels
                              .map(
                                (day) => DropdownMenuItem(
                                  value: day,
                                  child: Text(day),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedDay = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 420;
                            final startField = DropdownButtonFormField<int>(
                              initialValue: _startHour,
                              decoration: const InputDecoration(
                                labelText: 'Baslangic',
                                border: OutlineInputBorder(),
                              ),
                              items: _startHourOptions
                                  .map(
                                    (hour) => DropdownMenuItem(
                                      value: hour,
                                      child: Text(
                                        _BusyTimeEntry._formatHour(hour),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _startHour = value;
                                    if (_endHour <= _startHour) {
                                      _endHour = _startHour + 1;
                                    }
                                    _timeError = null;
                                  });
                                }
                              },
                            );
                            final endField = DropdownButtonFormField<int>(
                              initialValue: _endHour,
                              decoration: const InputDecoration(
                                labelText: 'Bitis',
                                border: OutlineInputBorder(),
                              ),
                              items: _endHourOptions
                                  .map(
                                    (hour) => DropdownMenuItem(
                                      value: hour,
                                      child: Text(
                                        _BusyTimeEntry._formatHour(hour),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _endHour = value;
                                    _timeError = null;
                                  });
                                }
                              },
                            );

                            if (stacked) {
                              return Column(
                                children: [
                                  startField,
                                  const SizedBox(height: 12),
                                  endField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: startField),
                                const SizedBox(width: 12),
                                Expanded(child: endField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonCtrl,
                          maxLines: 2,
                          onChanged: (_) => setState(() => _timeError = null),
                          decoration: const InputDecoration(
                            labelText: 'Busy Time Adi',
                            hintText: 'Orn: Spor, Kulup, Is',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_timeError != null) ...[
                          const SizedBox(height: 12),
                          Text(_timeError!, style: TextStyle(color: cs.error)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: cs.primaryContainer.withAlpha(120),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Onizleme',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _BusyTimeEntry(
                            dayLabel: _selectedDay,
                            startHour: _startHour,
                            endHour: _endHour,
                            reason: _reasonCtrl.text.trim().isEmpty
                                ? null
                                : _reasonCtrl.text.trim(),
                          ).toDisplayString(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: Icon(_isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(
                    _isEditing ? 'Mesgul Saati Guncelle' : 'Mesgul Saati Ekle',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<String> _weekdayLabels = [
    'Pazartesi',
    'Sali',
    'Carsamba',
    'Persembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  // Profile state
  Map<String, dynamic>? _user;
  List<Lesson> _lessons = [];
  bool _loading = true;

  // Profile form
  final _profileKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _gpaCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();
  double _stress = 3;
  final List<String> _busyTimes = [];

  void _applyUserData(Map<String, dynamic> user) {
    _user = user;
    _nameCtrl.text = user['name'] ?? '';
    _gpaCtrl.text = user['gpa']?.toString() ?? '';
    _semesterCtrl.text = user['semester']?.toString() ?? '';
    _stress = ((user['stress'] as int?) ?? 3).toDouble();
    _busyTimes
      ..clear()
      ..addAll(
        (user['busyTimes'] as List? ?? const []).map((e) => e.toString()),
      );
    _sortBusyTimes();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gpaCtrl.dispose();
    _semesterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await ApiClient.getMe();
      final lessons = await ApiClient.getLessons();
      if (!mounted) return;
      setState(() {
        _lessons = lessons
            .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
            .toList();
        _applyUserData(user);
      });
    } catch (e) {
      if (!mounted) return;
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        if (_nameCtrl.text.isNotEmpty) 'name': _nameCtrl.text.trim(),
        if (_gpaCtrl.text.isNotEmpty)
          'gpa': double.tryParse(_gpaCtrl.text.replaceAll(',', '.')),
        if (_semesterCtrl.text.isNotEmpty)
          'semester': _semesterCtrl.text.trim(),
        'stress': _stress.toInt(),
        'busyTimes': List<String>.from(_busyTimes),
      };
      final updated = await ApiClient.updateProfile(body);
      if (!mounted) return;
      setState(() => _applyUserData(updated));
      if (!mounted) return;
      _showMsg('Profil guncellendi!');
    } catch (e) {
      if (!mounted) return;
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  void _showMsg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showErr(String m) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));

  String? _semesterValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (int.tryParse(value.trim()) == null) {
      return 'Sayisal donem girin';
    }
    return null;
  }

  _BusyTimeEntry? _parseBusyTime(String value) {
    final match = RegExp(
      r'^(Pazartesi|Sali|Carsamba|Persembe|Cuma|Cumartesi|Pazar)\s+(\d{2}):(\d{2})-(\d{2}):(\d{2})(?:\s+\(([^)]+)\))?$',
    ).firstMatch(value.trim());

    if (match == null) return null;

    final startHour = int.parse(match.group(2)!);
    final endHour = int.parse(match.group(4)!);
    if (endHour <= startHour) return null;

    return _BusyTimeEntry(
      dayLabel: match.group(1)!,
      startHour: startHour,
      endHour: endHour,
      reason: match.group(6)?.trim(),
    );
  }

  void _sortBusyTimes() {
    _busyTimes.sort((a, b) {
      final first = _parseBusyTime(a);
      final second = _parseBusyTime(b);
      if (first == null || second == null) {
        return a.compareTo(b);
      }

      final dayCompare = _weekdayLabels
          .indexOf(first.dayLabel)
          .compareTo(_weekdayLabels.indexOf(second.dayLabel));
      if (dayCompare != 0) return dayCompare;

      final startCompare = first.startHour.compareTo(second.startHour);
      if (startCompare != 0) return startCompare;

      return first.endHour.compareTo(second.endHour);
    });
  }

  String _formatCredit(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String _shortDayLabel(String day) {
    switch (day) {
      case 'Pazartesi':
        return 'Pzt';
      case 'Sali':
        return 'Sal';
      case 'Carsamba':
        return 'Car';
      case 'Persembe':
        return 'Per';
      case 'Cuma':
        return 'Cum';
      case 'Cumartesi':
        return 'Cmt';
      case 'Pazar':
        return 'Paz';
      default:
        return day;
    }
  }

  List<int> _scheduleHours() {
    return List<int>.generate(
      _busyScheduleEndHour - _busyScheduleStartHour,
      (index) => _busyScheduleStartHour + index,
    );
  }

  List<_BusyTimeDisplayItem> _busyItemsForDay(String day) {
    final items = <_BusyTimeDisplayItem>[];

    for (var i = 0; i < _busyTimes.length; i++) {
      final parsed = _parseBusyTime(_busyTimes[i]);
      if (parsed == null || parsed.dayLabel != day) continue;

      final visibleStart = math.max(parsed.startHour, _busyScheduleStartHour);
      final visibleEnd = math.min(parsed.endHour, _busyScheduleEndHour);
      if (visibleEnd <= visibleStart) continue;

      items.add(
        _BusyTimeDisplayItem(
          index: i,
          entry: parsed,
          visibleStartHour: visibleStart,
          visibleEndHour: visibleEnd,
        ),
      );
    }

    items.sort((a, b) {
      final startCompare = a.visibleStartHour.compareTo(b.visibleStartHour);
      if (startCompare != 0) return startCompare;
      return a.visibleEndHour.compareTo(b.visibleEndHour);
    });

    return items;
  }

  bool _hourIsCovered(List<_BusyTimeDisplayItem> items, int hour) {
    return items.any(
      (item) => hour >= item.visibleStartHour && hour < item.visibleEndHour,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wideLayout = MediaQuery.sizeOf(context).width >= 1100;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: wideLayout ? 1180 : double.infinity,
            ),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: wideLayout ? 164 : 140,
                  pinned: true,
                  backgroundColor: cs.primary,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.logout, color: cs.onPrimary),
                      onPressed: _logout,
                      tooltip: 'Cikis Yap',
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Profil',
                      style: TextStyle(color: cs.onPrimary),
                    ),
                    background: Container(
                      color: cs.primary,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: cs.onPrimary.withAlpha(50),
                                child: Icon(
                                  Icons.person,
                                  size: 36,
                                  color: cs.onPrimary,
                                ),
                              ),
                              if (_user?['email'] != null)
                                Text(
                                  _user!['email'],
                                  style: TextStyle(
                                    color: cs.onPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildBusyTimesSummary(cs)),
                SliverToBoxAdapter(child: _buildProfileSection(cs)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Derslerim',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _showAddLessonDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ders Ekle'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _lessons.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Henuz ders eklenmedi',
                              style: TextStyle(color: cs.outline),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _lessonTile(_lessons[i]),
                          childCount: _lessons.length,
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(ColorScheme cs) {
    return Form(
      key: _profileKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Kisisel Bilgiler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 520;
                    if (stacked) {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _gpaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final d = double.tryParse(v);
                              if (d == null || d < 0 || d > 4) {
                                return '0-4 arasi';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'GPA (0-4)',
                              prefixIcon: Icon(Icons.grade_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _semesterCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Donem No',
                              prefixIcon: Icon(Icons.event_note_outlined),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _semesterValidator,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _gpaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final d = double.tryParse(v);
                              if (d == null || d < 0 || d > 4) {
                                return '0-4 arasi';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'GPA (0-4)',
                              prefixIcon: Icon(Icons.grade_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _semesterCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Donem No',
                              prefixIcon: Icon(Icons.event_note_outlined),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _semesterValidator,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text('Stres Seviyesi: ${_stress.toInt()}'),
                    Expanded(
                      child: Slider(
                        value: _stress,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: _stress.toInt().toString(),
                        onChanged: (v) => setState(() => _stress = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildBusyTimes(cs),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Profili Kaydet'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusyTimesSummary(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Haftalik Busy Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_busyTimes.length} kayit',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '08:00-21:00 arasi haftalik schedule asagida yer aliyor. Bos hucrelerdeki + ile yeni busy time ekleyebilir, mevcut bloklarda duzenleme yapabilirsiniz.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusyTimes(ColorScheme cs) {
    final hours = _scheduleHours();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mesguliyet Takvimi',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Yeni Busy Time'),
              onPressed: () => _showBusyTimeForm(
                initialValue: const _BusyTimeEntry(
                  dayLabel: 'Pazartesi',
                  startHour: _busyScheduleStartHour,
                  endHour: _busyScheduleStartHour + 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Bos hucrelerdeki + ile yeni kayit acin. Dolu bloklardaki duzenle alani ile ismi degistirebilir veya silebilirsiniz.',
          style: TextStyle(fontSize: 12, color: cs.outline),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _busyScheduleHourColumnWidth,
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withAlpha(130),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Saat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...hours.map(
                      (hour) => Container(
                        width: _busyScheduleHourColumnWidth,
                        height: _busyScheduleCellHeight,
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: cs.outlineVariant),
                          ),
                        ),
                        child: Text(
                          _BusyTimeEntry._formatHour(hour),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ..._weekdayLabels.map(
                (day) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildBusyDayColumn(day, hours, cs),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusyDayColumn(String day, List<int> hours, ColorScheme cs) {
    final items = _busyItemsForDay(day);

    return SizedBox(
      width: _busyScheduleDayColumnWidth,
      child: Column(
        children: [
          Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(130),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _shortDayLabel(day),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: hours.length * _busyScheduleCellHeight,
            child: Stack(
              children: [
                Column(
                  children: hours.map((hour) {
                    final isCovered = _hourIsCovered(items, hour);
                    return Container(
                      width: _busyScheduleDayColumnWidth,
                      height: _busyScheduleCellHeight,
                      decoration: BoxDecoration(
                        color: isCovered
                            ? cs.surfaceContainerHighest.withAlpha(70)
                            : cs.surface,
                        border: Border(
                          bottom: BorderSide(color: cs.outlineVariant),
                          left: BorderSide(color: cs.outlineVariant),
                          right: BorderSide(color: cs.outlineVariant),
                        ),
                      ),
                      child: isCovered
                          ? const SizedBox.shrink()
                          : Center(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _showBusyTimeForm(
                                  initialValue: _BusyTimeEntry(
                                    dayLabel: day,
                                    startHour: hour,
                                    endHour: hour + 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_circle_outline,
                                        size: 18,
                                        color: cs.primary,
                                      ),
                                      Text(
                                        'Yeni',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    );
                  }).toList(),
                ),
                ...items.map((item) => _buildBusyBlock(item, cs)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusyBlock(_BusyTimeDisplayItem item, ColorScheme cs) {
    final top =
        (item.visibleStartHour - _busyScheduleStartHour) *
        _busyScheduleCellHeight;
    final height =
        (item.visibleEndHour - item.visibleStartHour) * _busyScheduleCellHeight;
    final blockLabel = item.entry.reason?.trim().isNotEmpty == true
        ? item.entry.reason!.trim()
        : 'Mesgul';

    return Positioned(
      top: top + 4,
      left: 4,
      right: 4,
      height: math.max(height - 8, 44.0),
      child: Material(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showBusyTimeForm(editIndex: item.index),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        blockLabel,
                        maxLines: height <= _busyScheduleCellHeight ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: cs.onPrimaryContainer,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${_BusyTimeEntry._formatHour(item.visibleStartHour)}-${_BusyTimeEntry._formatHour(item.visibleEndHour)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onPrimaryContainer.withAlpha(220),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBusyTimeForm({
    int? editIndex,
    _BusyTimeEntry? initialValue,
  }) async {
    final existing = editIndex == null
        ? initialValue
        : _parseBusyTime(_busyTimes[editIndex]);
    if (editIndex != null && existing == null) {
      _showErr('Mesgul saat bilgisi okunamadi.');
      return;
    }

    final result = await Navigator.of(context).push<_BusyTimeFormResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _BusyTimeFormScreen(
          weekdayLabels: _weekdayLabels,
          existingBusyTimes: List<String>.from(_busyTimes),
          initialValue: existing,
          editIndex: editIndex,
        ),
      ),
    );
    if (!mounted || result == null) return;

    setState(() {
      if (result.delete) {
        if (editIndex != null) {
          _busyTimes.removeAt(editIndex);
        }
      } else if (result.value != null) {
        if (editIndex == null) {
          _busyTimes.add(result.value!);
        } else {
          _busyTimes[editIndex] = result.value!;
        }
      }
      _sortBusyTimes();
    });
  }

  Widget _lessonTile(Lesson lesson) {
    final cs = Theme.of(context).colorScheme;
    final lessonDetails = <String>[
      if (lesson.semester.trim().isNotEmpty) '${lesson.semester}. donem',
      if (lesson.credit > 0) '${_formatCredit(lesson.credit)} kredi',
      '${lesson.deadlines.length} sinav',
    ];
    if (lesson.delay > 0) {
      lessonDetails.add('Gecikme: ${lesson.delay}');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            '${lesson.difficulty}',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          lesson.lessonName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(lessonDetails.join(' • ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditLessonDialog(lesson),
              tooltip: 'Duzenle',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.error),
              onPressed: () => _deleteLesson(lesson),
              tooltip: 'Sil',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dersi Sil'),
        content: Text('"${lesson.lessonName}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await ApiClient.deleteLesson(lesson.id);
      await _load();
      _showMsg('Ders silindi');
    } catch (e) {
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
    setState(() => _loading = false);
  }

  Future<void> _showAddLessonDialog() async {
    final nameCtrl = TextEditingController();
    final semCtrl = TextEditingController(
      text: _user?['semester']?.toString() ?? '',
    );
    final creditCtrl = TextEditingController(text: '3');
    int difficulty = 3;
    final deadlines = <Map<String, dynamic>>[];
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ders Ekle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Gerekli' : null,
                      decoration: const InputDecoration(
                        labelText: 'Ders Adi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: semCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Gerekli';
                        if (int.tryParse(v.trim()) == null) {
                          return 'Sayisal girin';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Donem No (orn: 4)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: creditCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Gerekli';
                        if (double.tryParse(v.trim().replaceAll(',', '.')) ==
                            null) {
                          return 'Sayisal girin';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Kredi',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Zorluk: '),
                        Expanded(
                          child: Slider(
                            value: difficulty.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: difficulty.toString(),
                            onChanged: (v) =>
                                setS(() => difficulty = v.toInt()),
                          ),
                        ),
                        Text('$difficulty/5'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sinav Tarihleri',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ekle'),
                          onPressed: () async {
                            final d = await _showDeadlineDialog(ctx);
                            if (d != null) {
                              setS(() => deadlines.add(d));
                            }
                          },
                        ),
                      ],
                    ),
                    ...deadlines.asMap().entries.map(
                      (entry) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.event, size: 18),
                        title: Text(
                          '${entry.value['type']} — ${entry.value['date']}',
                        ),
                        subtitle: entry.value['label'] != null
                            ? Text(entry.value['label'])
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () async {
                                final updated = await _showDeadlineDialog(
                                  ctx,
                                  initialDeadline: entry.value,
                                );
                                if (updated != null) {
                                  setS(() => deadlines[entry.key] = updated);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () =>
                                  setS(() => deadlines.removeAt(entry.key)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Iptal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            Navigator.pop(ctx);
                            setState(() => _loading = true);
                            try {
                              await ApiClient.registerLessons([
                                {
                                  'lessonName': nameCtrl.text.trim(),
                                  'credit': double.tryParse(
                                    creditCtrl.text.trim().replaceAll(',', '.'),
                                  ),
                                  'difficulty': difficulty,
                                  'deadlines': deadlines,
                                  'semester': semCtrl.text.trim(),
                                },
                              ]);
                              await _load();
                              _showMsg('Ders eklendi!');
                            } catch (e) {
                              _showErr(
                                e.toString().replaceAll('Exception: ', ''),
                              );
                            }
                            setState(() => _loading = false);
                          },
                          child: const Text('Kaydet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    semCtrl.dispose();
    creditCtrl.dispose();
  }

  Future<void> _showEditLessonDialog(Lesson lesson) async {
    final nameCtrl = TextEditingController(text: lesson.lessonName);
    final semCtrl = TextEditingController(text: lesson.semester);
    final creditCtrl = TextEditingController(
      text: _formatCredit(lesson.credit),
    );
    int difficulty = lesson.difficulty;
    final deadlines = lesson.deadlines
        .map((d) => d.toJson())
        .toList()
        .cast<Map<String, dynamic>>();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ders Duzenle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Gerekli' : null,
                      decoration: const InputDecoration(
                        labelText: 'Ders Adi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: semCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Gerekli';
                        if (int.tryParse(v.trim()) == null) {
                          return 'Sayisal girin';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Donem No',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: creditCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Gerekli';
                        if (double.tryParse(v.trim().replaceAll(',', '.')) ==
                            null) {
                          return 'Sayisal girin';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Kredi',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Zorluk: '),
                        Expanded(
                          child: Slider(
                            value: difficulty.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: difficulty.toString(),
                            onChanged: (v) =>
                                setS(() => difficulty = v.toInt()),
                          ),
                        ),
                        Text('$difficulty/5'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sinav Tarihleri',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ekle'),
                          onPressed: () async {
                            final d = await _showDeadlineDialog(ctx);
                            if (d != null) {
                              setS(() => deadlines.add(d));
                            }
                          },
                        ),
                      ],
                    ),
                    ...deadlines.asMap().entries.map(
                      (entry) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.event, size: 18),
                        title: Text(
                          '${entry.value['type']} — ${entry.value['date']}',
                        ),
                        subtitle: entry.value['label'] != null
                            ? Text(entry.value['label'])
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () async {
                                final updated = await _showDeadlineDialog(
                                  ctx,
                                  initialDeadline: entry.value,
                                );
                                if (updated != null) {
                                  setS(() => deadlines[entry.key] = updated);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () =>
                                  setS(() => deadlines.removeAt(entry.key)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Iptal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            Navigator.pop(ctx);
                            setState(() => _loading = true);
                            try {
                              final body = <String, dynamic>{
                                'lessonName': lesson.lessonName,
                              };
                              if (nameCtrl.text.trim() != lesson.lessonName) {
                                body['newLessonName'] = nameCtrl.text.trim();
                              }
                              body['credit'] = double.tryParse(
                                creditCtrl.text.trim().replaceAll(',', '.'),
                              );
                              body['difficulty'] = difficulty;
                              body['deadlines'] = deadlines;
                              body['semester'] = semCtrl.text.trim();
                              await ApiClient.updateLesson(body);
                              await _load();
                              _showMsg('Ders guncellendi!');
                            } catch (e) {
                              _showErr(
                                e.toString().replaceAll('Exception: ', ''),
                              );
                            }
                            setState(() => _loading = false);
                          },
                          child: const Text('Guncelle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    semCtrl.dispose();
    creditCtrl.dispose();
  }

  Future<Map<String, dynamic>?> _showDeadlineDialog(
    BuildContext parentCtx, {
    Map<String, dynamic>? initialDeadline,
  }) async {
    String type = initialDeadline?['type']?.toString() ?? 'midterm';
    DateTime selectedDate =
        DateTime.tryParse(initialDeadline?['date']?.toString() ?? '') ??
        DateTime.now();
    final labelCtrl = TextEditingController(
      text: initialDeadline?['label']?.toString() ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(
            initialDeadline == null ? 'Sinav Ekle' : 'Sinav Bilgisi Duzenle',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Tur',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'midterm', child: Text('Vize')),
                  DropdownMenuItem(value: 'final', child: Text('Final')),
                  DropdownMenuItem(value: 'homework', child: Text('Odev')),
                ],
                onChanged: (v) => setS(() => type = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(selectedDate.toIso8601String().substring(0, 10)),
                subtitle: const Text('Tarih Sec'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setS(() => selectedDate = d);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Etiket (istegle bagli, orn: HW1)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Iptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'type': type,
                'date': selectedDate.toIso8601String().substring(0, 10),
                if (labelCtrl.text.isNotEmpty) 'label': labelCtrl.text,
              }),
              child: Text(initialDeadline == null ? 'Ekle' : 'Guncelle'),
            ),
          ],
        ),
      ),
    );

    labelCtrl.dispose();
    return result;
  }
}
