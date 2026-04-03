import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/lesson_model.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Profile state
  Map<String, dynamic>? _user;
  List<Lesson> _lessons = [];
  bool _loading = true;

  // Profile form
  final _profileKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _gpaCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();
  double _stress = 5;
  final List<String> _busyTimes = [];

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
        _user = user;
        _lessons = lessons
            .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
            .toList();
        _nameCtrl.text = user['name'] ?? '';
        _gpaCtrl.text = user['gpa']?.toString() ?? '';
        _semesterCtrl.text = user['semester'] ?? '';
        _stress = ((user['stress'] as int?) ?? 5).toDouble();
        _busyTimes.clear();
        if (user['busyTimes'] != null) {
          _busyTimes.addAll(
              (user['busyTimes'] as List).map((e) => e.toString()));
        }
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
          'gpa': double.tryParse(_gpaCtrl.text),
        if (_semesterCtrl.text.isNotEmpty)
          'semester': _semesterCtrl.text.trim(),
        'stress': _stress.toInt(),
        'busyTimes': List<String>.from(_busyTimes),
      };
      await ApiClient.updateProfile(body);
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

  void _showMsg(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  void _showErr(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.red));

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
            constraints: BoxConstraints(maxWidth: wideLayout ? 1180 : double.infinity),
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
                    title: Text('Profil', style: TextStyle(color: cs.onPrimary)),
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
                                child: Icon(Icons.person, size: 36, color: cs.onPrimary),
                              ),
                              if (_user?['email'] != null)
                                Text(
                                  _user!['email'],
                                  style: TextStyle(color: cs.onPrimary, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Text('Kisisel Bilgiler',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.primary)),
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
                              labelText: 'Donem',
                              prefixIcon: Icon(Icons.event_note_outlined),
                              border: OutlineInputBorder(),
                            ),
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
                              labelText: 'Donem',
                              prefixIcon: Icon(Icons.event_note_outlined),
                              border: OutlineInputBorder(),
                            ),
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
                        min: 0,
                        max: 10,
                        divisions: 10,
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

  Widget _buildBusyTimes(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mesgul Saatler',
                style: TextStyle(color: cs.onSurfaceVariant)),
            TextButton.icon(
              icon: const Icon(Icons.calendar_month, size: 16),
              label: const Text('Ekle'),
              onPressed: _showAddBusyTimeCalendar,
            ),
          ],
        ),
        if (_busyTimes.isEmpty)
          Text('Mesgul saat yok',
              style: TextStyle(fontSize: 12, color: cs.outline))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _busyTimes
                .map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      onDeleted: () =>
                          setState(() => _busyTimes.remove(t)),
                      deleteIconColor: cs.error,
                    ))
                .toList(),
          ),
      ],
    );
  }

  Future<void> _showAddBusyTimeCalendar() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Mesgul Oldugunuz Gunu Secin',
    );

    if (date == null) return;

    if (!mounted) return;
    final TimeOfDay? timeStart = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Baslangic Saati',
    );

    if (timeStart == null) return;

    if (!mounted) return;
    final TimeOfDay? timeEnd = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: timeStart.hour + 1, minute: timeStart.minute),
      helpText: 'Bitis Saati',
    );

    if (timeEnd == null) return;

    final String dayName = DateFormat('EEEE', 'tr_TR').format(date);
    final String formattedDate = DateFormat('dd.MM.yyyy').format(date);
    final String busyTime = "$dayName ($formattedDate) ${timeStart.format(context)}-${timeEnd.format(context)}";

    setState(() {
      _busyTimes.add(busyTime);
    });
  }

  Widget _lessonTile(Lesson lesson) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text('${lesson.difficulty}',
              style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(lesson.lessonName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${lesson.semester} • ${lesson.deadlines.length} sinav\n'
            '${lesson.delay > 0 ? "Gecikme: ${lesson.delay}" : ""}'),
        isThreeLine: lesson.delay > 0,
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
              child: const Text('Iptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
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
        text: _user?['semester'] ?? '');
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
                    const Text('Ders Ekle',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
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
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Gerekli' : null,
                      decoration: const InputDecoration(
                        labelText: 'Donem (orn: 2024-2025 Bahar)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
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
                    ]),
                    const Divider(),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sinav Tarihleri',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
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
                    ...deadlines.map((d) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.event, size: 18),
                          title: Text(
                              '${d['type']} — ${d['date']}'),
                          subtitle: d['label'] != null
                              ? Text(d['label'])
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                setS(() => deadlines.remove(d)),
                          ),
                        )),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Iptal')),
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
                                  'lessonName':
                                      nameCtrl.text.trim(),
                                  'difficulty': difficulty,
                                  'deadlines': deadlines,
                                  'semester': semCtrl.text.trim(),
                                }
                              ]);
                              await _load();
                              _showMsg('Ders eklendi!');
                            } catch (e) {
                              _showErr(e
                                  .toString()
                                  .replaceAll('Exception: ', ''));
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
  }

  Future<void> _showEditLessonDialog(Lesson lesson) async {
    final nameCtrl =
        TextEditingController(text: lesson.lessonName);
    final semCtrl =
        TextEditingController(text: lesson.semester);
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
                    const Text('Ders Duzenle',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
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
                      decoration: const InputDecoration(
                        labelText: 'Donem',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
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
                    ]),
                    const Divider(),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sinav Tarihleri',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
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
                    ...deadlines.map((d) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.event, size: 18),
                          title: Text(
                              '${d['type']} — ${d['date']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                setS(() => deadlines.remove(d)),
                          ),
                        )),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Iptal')),
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
                              if (nameCtrl.text.trim() !=
                                  lesson.lessonName) {
                                body['newLessonName'] =
                                    nameCtrl.text.trim();
                              }
                              body['difficulty'] = difficulty;
                              body['deadlines'] = deadlines;
                              body['semester'] = semCtrl.text.trim();
                              await ApiClient.updateLesson(body);
                              await _load();
                              _showMsg('Ders guncellendi!');
                            } catch (e) {
                              _showErr(e
                                  .toString()
                                  .replaceAll('Exception: ', ''));
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
  }

  Future<Map<String, dynamic>?> _showDeadlineDialog(
      BuildContext parentCtx) async {
    String type = 'midterm';
    DateTime selectedDate = DateTime.now();
    final labelCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Sinav Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: 'Tur',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'midterm', child: Text('Vize')),
                  DropdownMenuItem(
                      value: 'final', child: Text('Final')),
                  DropdownMenuItem(
                      value: 'homework', child: Text('Odev')),
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
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
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
                child: const Text('Iptal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'type': type,
                'date': selectedDate.toIso8601String().substring(0, 10),
                if (labelCtrl.text.isNotEmpty) 'label': labelCtrl.text,
              }),
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
