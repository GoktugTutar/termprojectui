import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_time.dart';
import '../theme.dart';

const _kDanger = Color(0xFFFF5C7A);
const _kWarning = Color(0xFFF2B14A);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _isTestMode = false;

  String _preferredStudyTime = 'morning';
  String _studyStyle = 'normal';
  final List<Map<String, dynamic>> _busySlots = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        ApiClient.getMe(),
        ApiClient.getMode(),
      ]);
      if (!mounted) return;
      final user = results[0];
      final modeInfo = results[1];
      setState(() {
        _user = user;
        _preferredStudyTime =
            user['preferredStudyTime']?.toString() ?? 'morning';
        _studyStyle = user['studyStyle']?.toString() ?? 'normal';
        _busySlots
          ..clear()
          ..addAll(
            ((user['busySlots'] as List?) ?? [])
                .map((s) => Map<String, dynamic>.from(s as Map))
                .toList(),
          );
        _isTestMode = modeInfo['mode']?.toString() == 'test';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);
    try {
      await ApiClient.setupUser({
        'preferredStudyTime': _preferredStudyTime,
        'studyStyle': _studyStyle,
      });
      if (!mounted) return;
      _snack('Preferences saved!');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _saveBusySlots() async {
    setState(() => _saving = true);
    try {
      await ApiClient.updateBusySlots(_busySlots);
      if (!mounted) return;
      _snack('Busy slots saved!');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  void _openBusySlotSheet({Map<String, dynamic>? existing, int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BusySlotSheet(
        existing: existing,
        editIndex: editIndex,
        busySlots: _busySlots,
        onChanged: () => setState(() {}),
        onSave: _saveBusySlots,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: kAccent)),
      );
    }

    final email = _user?['email']?.toString() ?? '';
    final displayName = email.isNotEmpty ? email.split('@').first : 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: kAccent,
          backgroundColor: kSurface,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  // Header / kicker
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 12, 0, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setup',
                          style: TextStyle(
                            color: kText2,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Profile',
                          style: TextStyle(
                            color: kText1,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar row
                  Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kAccent, Color(0xFF5AB6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: kBg,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: kText1,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '12 weeks · 314 blocks completed',
                              style: TextStyle(color: kText2, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Preferred study time
                  _SectionLabel('Preferred study time'),
                  SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.8,
                    children: [
                      _TimeChip(
                        v: 'morning',
                        label: 'Morning',
                        range: '08–11',
                        icon: Icons.wb_sunny_outlined,
                        pref: _preferredStudyTime,
                        onTap: () =>
                            setState(() => _preferredStudyTime = 'morning'),
                      ),
                      _TimeChip(
                        v: 'afternoon',
                        label: 'Afternoon',
                        range: '12–15',
                        icon: Icons.wb_cloudy_outlined,
                        pref: _preferredStudyTime,
                        onTap: () =>
                            setState(() => _preferredStudyTime = 'afternoon'),
                      ),
                      _TimeChip(
                        v: 'evening',
                        label: 'Evening',
                        range: '18–21',
                        icon: Icons.nights_stay_outlined,
                        pref: _preferredStudyTime,
                        onTap: () =>
                            setState(() => _preferredStudyTime = 'evening'),
                      ),
                      _TimeChip(
                        v: 'night',
                        label: 'Night',
                        range: '21–24',
                        icon: Icons.bedtime_outlined,
                        pref: _preferredStudyTime,
                        onTap: () =>
                            setState(() => _preferredStudyTime = 'night'),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  // Study style
                  _SectionLabel('Study style'),
                  SizedBox(height: 8),
                  Column(
                    children: [
                      _StyleCard(
                        v: 'deep_focus',
                        label: 'Deep focus',
                        sub: '1 long block · max 2h',
                        rule: 'maxSessions=1, max=4 blocks',
                        value: _studyStyle,
                        onChange: (s) => setState(() => _studyStyle = s),
                      ),
                      SizedBox(height: 8),
                      _StyleCard(
                        v: 'distributed',
                        label: 'Distributed',
                        sub: '3 short blocks · spread across day',
                        rule: 'maxSessions=3, max=2 blocks',
                        value: _studyStyle,
                        onChange: (s) => setState(() => _studyStyle = s),
                      ),
                      SizedBox(height: 8),
                      _StyleCard(
                        v: 'normal',
                        label: 'Balanced',
                        sub: '2 medium blocks · default',
                        rule: 'maxSessions=2, max=3 blocks',
                        value: _studyStyle,
                        onChange: (s) => setState(() => _studyStyle = s),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  FilledButton(
                    onPressed: _saving ? null : _savePreferences,
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccent,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save preferences',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                  SizedBox(height: 24),
                  // Busy slots
                  Row(
                    children: [
                      Text(
                        'BUSY SLOTS · ${_busySlots.length}',
                        style: TextStyle(
                          color: kText2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () => _openBusySlotSheet(),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 12, color: kAccent),
                            SizedBox(width: 4),
                            Text(
                              'Add',
                              style: TextStyle(
                                color: kAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_busySlots.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No busy slots added yet.',
                        style: TextStyle(color: kText2, fontSize: 13),
                      ),
                    )
                  else
                    Column(
                      children: List.generate(_busySlots.length, (i) {
                        final slot = _busySlots[i];
                        final dayIdx = (slot['dayOfWeek'] as int? ?? 1) - 1;
                        const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final dayLetter = dayIdx >= 0 && dayIdx < 7
                            ? dayLetters[dayIdx]
                            : '?';
                        final fatigue =
                            (slot['fatigueLevel'] as num?)?.toInt() ?? 3;
                        final label = slot['label']?.toString() ?? '';
                        return Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: GestureDetector(
                            onTap: () => _openBusySlotSheet(
                              existing: slot,
                              editIndex: i,
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: kSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBorder),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      dayLetter,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: kText2,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (label.isNotEmpty)
                                          Text(
                                            label,
                                            style: TextStyle(
                                              color: kText1,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        Text(
                                          '${slot['startTime']} – ${slot['endTime']}',
                                          style: TextStyle(
                                            color: kText2,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _FatigueDots(level: fatigue),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  SizedBox(height: 24),
                  // Developer / Test mode (sadece MODE=test'te gösterilir)
                  if (_isTestMode) ...[
                    _SectionLabel('Developer'),
                    SizedBox(height: 8),
                    _TestModeCard(onSave: _snack),
                    SizedBox(height: 24),
                  ],
                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: _kDanger,
                      ),
                      label: Text(
                        'Sign out',
                        style: TextStyle(color: _kDanger),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kDanger),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: kText2,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Time chip ─────────────────────────────────────────────────────────────────

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.v,
    required this.label,
    required this.range,
    required this.icon,
    required this.pref,
    required this.onTap,
  });

  final String v;
  final String label;
  final String range;
  final IconData icon;
  final String pref;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = pref == v;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: on ? kAccent.withAlpha(46) : kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? kAccent : kBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: on ? kAccent : kBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: on ? kBg : kText2, size: 15),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: on ? kText1 : kText2,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(range, style: TextStyle(color: kText2, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Style card ────────────────────────────────────────────────────────────────

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.v,
    required this.label,
    required this.sub,
    required this.rule,
    required this.value,
    required this.onChange,
  });

  final String v;
  final String label;
  final String sub;
  final String rule;
  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final on = value == v;
    return GestureDetector(
      onTap: () => onChange(v),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: on ? kAccent.withAlpha(46) : kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? kAccent : kBorder, width: 0.5),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? kAccent : kText2, width: 1.5),
                color: on ? kAccent : Colors.transparent,
              ),
              child: on
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: kBg,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: on ? kText1 : kText2,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(sub, style: TextStyle(color: kText2, fontSize: 12)),
                ],
              ),
            ),
            // Monospace rule
            SizedBox(
              width: 110,
              child: Text(
                rule,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: kText2.withAlpha(180),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fatigue dots ──────────────────────────────────────────────────────────────

class _FatigueDots extends StatelessWidget {
  const _FatigueDots({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    if (level >= 4) {
      dotColor = _kDanger;
    } else if (level >= 3) {
      dotColor = _kWarning;
    } else {
      dotColor = kAccent;
    }

    return Row(
      children: List.generate(5, (i) {
        final filled = i < level;
        return Container(
          width: 4,
          height: 14,
          margin: EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: filled ? dotColor : kBorder,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

// ── Test mode card ────────────────────────────────────────────────────────────

class _TestModeCard extends StatefulWidget {
  const _TestModeCard({required this.onSave});

  final void Function(String msg, {bool error}) onSave;

  @override
  State<_TestModeCard> createState() => _TestModeCardState();
}

class _TestModeCardState extends State<_TestModeCard> {
  DateTime _now = AppTime.now();

  Future<void> _edit() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.dark(primary: kAccent)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_now),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.dark(primary: kAccent)),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    try {
      await ApiClient.setTestClock(dt.toIso8601String());
      AppTime.setOverride(dt);
      setState(() => _now = dt);
      widget.onSave('Test clock: ${dt.toIso8601String().substring(0, 16)}');
    } catch (e) {
      widget.onSave(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kDanger.withAlpha(46),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.access_time, size: 14, color: _kDanger),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'mod=test',
                      style: TextStyle(
                        color: kText1,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Override the system clock — algorithm reads from this.',
                      style: TextStyle(color: kText2, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text('Now:', style: TextStyle(color: kText2, fontSize: 12)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _now.toIso8601String().substring(0, 16).replaceAll('T', ' '),
                  style: TextStyle(
                    color: kText1,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _edit,
                child: Container(
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: kAccent.withAlpha(46),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kBorder),
                  ),
                  child: Center(
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        color: kAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Busy slot sheet ───────────────────────────────────────────────────────────

class _BusySlotSheet extends StatefulWidget {
  const _BusySlotSheet({
    this.existing,
    this.editIndex,
    required this.busySlots,
    required this.onChanged,
    required this.onSave,
  });

  final Map<String, dynamic>? existing;
  final int? editIndex;
  final List<Map<String, dynamic>> busySlots;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;

  @override
  State<_BusySlotSheet> createState() => _BusySlotSheetState();
}

class _BusySlotSheetState extends State<_BusySlotSheet> {
  int _dayOfWeek = 1;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  int _fatigue = 3;
  bool _saving = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _dayOfWeek = widget.existing?['dayOfWeek'] as int? ?? 1;
    _startCtrl = TextEditingController(
      text: widget.existing?['startTime']?.toString() ?? '09:00',
    );
    _endCtrl = TextEditingController(
      text: widget.existing?['endTime']?.toString() ?? '11:00',
    );
    _fatigue = (widget.existing?['fatigueLevel'] as num?)?.toInt() ?? 3;
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  bool _isValid() {
    final re = RegExp(r'^\d{2}:\d{2}$');
    return re.hasMatch(_startCtrl.text.trim()) &&
        re.hasMatch(_endCtrl.text.trim());
  }

  Future<void> _confirm() async {
    if (!_isValid()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Time format must be HH:MM')));
      return;
    }
    final slot = {
      'dayOfWeek': _dayOfWeek,
      'startTime': _startCtrl.text.trim(),
      'endTime': _endCtrl.text.trim(),
      'fatigueLevel': _fatigue,
    };
    if (widget.editIndex != null) {
      widget.busySlots[widget.editIndex!] = slot;
    } else {
      widget.busySlots.add(slot);
    }
    widget.onChanged();
    setState(() => _saving = true);
    await widget.onSave();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _delete() {
    if (widget.editIndex != null) {
      widget.busySlots.removeAt(widget.editIndex!);
      widget.onChanged();
      widget.onSave();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            SizedBox(height: 20),
            Row(
              children: [
                Text(
                  widget.editIndex != null ? 'Edit busy slot' : 'Add busy slot',
                  style: TextStyle(
                    color: kText1,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                if (widget.editIndex != null)
                  GestureDetector(
                    onTap: _delete,
                    child: Icon(Icons.delete_outline, color: _kDanger),
                  ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'DAY',
              style: TextStyle(
                color: kText2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (i) {
                final selected = i + 1 == _dayOfWeek;
                return GestureDetector(
                  onTap: () => setState(() => _dayOfWeek = i + 1),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 120),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? kAccent : kBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _dayNames[i],
                      style: TextStyle(
                        color: selected ? Colors.white : kText2,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startCtrl,
                    style: TextStyle(color: kText1),
                    decoration: InputDecoration(
                      labelText: 'Start',
                      hintText: '09:00',
                      hintStyle: TextStyle(color: kText2),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endCtrl,
                    style: TextStyle(color: kText1),
                    decoration: InputDecoration(
                      labelText: 'End',
                      hintText: '11:00',
                      hintStyle: TextStyle(color: kText2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text('Fatigue', style: TextStyle(color: kText2, fontSize: 13)),
                SizedBox(width: 12),
                ...List.generate(5, (i) {
                  final n = i + 1;
                  final sel = n == _fatigue;
                  return GestureDetector(
                    onTap: () => setState(() => _fatigue = n),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 120),
                      width: 36,
                      height: 36,
                      margin: EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: sel ? kAccent : kBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '$n',
                          style: TextStyle(
                            color: sel ? Colors.white : kText2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.editIndex != null ? 'Update' : 'Add',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
