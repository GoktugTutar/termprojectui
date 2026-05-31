import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../core/app_time.dart';
import '../theme.dart';
import '../core/api_client.dart';
import 'today_screen.dart';
import 'week_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  int _weekReloadSignal = 0;
  bool _aiChatOpen = false;
  final ValueNotifier<bool> _weekFullscreen = ValueNotifier(false);
  late final List<Widget?> _tabScreens;

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Today'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Week'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Insights'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _weekFullscreen.addListener(_handleWeekFullscreenChanged);
    _tabScreens = List<Widget?>.filled(_destinations.length, null);
    _ensureTabBuilt(0);
  }

  @override
  void dispose() {
    _weekFullscreen.removeListener(_handleWeekFullscreenChanged);
    _weekFullscreen.dispose();
    super.dispose();
  }

  void _handleWeekFullscreenChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTheme,
      builder: (context, _) {
        final navbar = _TopNav(
          currentIndex: _index,
          onTap: _selectTab,
          destinations: _destinations,
        );

        return Scaffold(
          backgroundColor: kBg,
          body: IndexedStack(
            index: _index,
            children: List.generate(_destinations.length, (index) {
              return _FullScreenFrame(
                navbar: navbar,
                aiChatOpen: _aiChatOpen,
                onToggleAiChat: _toggleAiChat,
                onCloseAiChat: _closeAiChat,
                contentFullscreenListenable: index == 1
                    ? _weekFullscreen
                    : null,
                child: _tabScreens[index] ?? SizedBox.shrink(),
              );
            }),
          ),
        );
      },
    );
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      if (index == 1) {
        _weekReloadSignal++;
        _tabScreens[1] = WeekScreen(
          reloadSignal: _weekReloadSignal,
          fullscreenController: _weekFullscreen,
        );
      } else {
        _weekFullscreen.value = false;
        _ensureTabBuilt(index);
      }
    });
  }

  void _ensureTabBuilt(int index) {
    if (_tabScreens[index] != null) return;
    _tabScreens[index] = switch (index) {
      0 => TodayScreen(onOpenInsights: () => _selectTab(2)),
      1 => WeekScreen(
        reloadSignal: _weekReloadSignal,
        fullscreenController: _weekFullscreen,
      ),
      2 => InsightsScreen(),
      3 => ProfileScreen(),
      _ => SizedBox.shrink(),
    };
  }

  void _toggleAiChat() => setState(() => _aiChatOpen = !_aiChatOpen);
  void _closeAiChat() => setState(() => _aiChatOpen = false);
}

// ── Top Nav ───────────────────────────────────────────────────────────────────

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> destinations;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final itemSize = compact ? 34.0 : 42.0;
    final iconSize = compact ? 18.0 : 21.0;
    final items = <Widget>[];
    for (var i = 0; i < destinations.length; i++) {
      final (unsel, sel, label) = destinations[i];
      final selected = i == currentIndex;
      items
        ..add(
          Tooltip(
            message: label,
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 180),
                width: itemSize,
                height: itemSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kAccent.withAlpha(20) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? sel : unsel,
                  color: selected ? kAccent : kText2,
                  size: iconSize,
                ),
              ),
            ),
          ),
        )
        ..add(_NavSeparator());
    }
    items.add(_ThemeToggle(expanded: false));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

class _NavSeparator extends StatelessWidget {
  const _NavSeparator();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Container(
      width: 1,
      height: compact ? 18 : 22,
      margin: EdgeInsets.symmetric(horizontal: compact ? 8 : 18),
      color: kBorder.withAlpha(appTheme.isLight ? 150 : 120),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return AnimatedBuilder(
      animation: appTheme,
      builder: (context, _) {
        final light = appTheme.isLight;
        final icon = light
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined;
        final label = light ? 'Dark mode' : 'Light mode';
        return GestureDetector(
          onTap: appTheme.toggle,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 180),
            width: expanded ? double.infinity : (compact ? 34 : 42),
            height: expanded ? null : (compact ? 34 : 42),
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 14 : 0,
              vertical: expanded ? 12 : 0,
            ),
            decoration: expanded
                ? BoxDecoration(
                    color: kAccent.withAlpha(24),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kAccent.withAlpha(45)),
                  )
                : BoxDecoration(color: Colors.transparent),
            child: expanded
                ? Row(
                    children: [
                      Icon(icon, color: kAccent, size: 20),
                      SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: kAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Tooltip(
                    message: label,
                    child: Center(
                      child: Icon(
                        icon,
                        color: kAccent,
                        size: compact ? 18 : 22,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

// ── Talk with AI button ───────────────────────────────────────────────────────

class _TalkWithAiButton extends StatelessWidget {
  const _TalkWithAiButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: active ? kAccent : kAccent.withAlpha(26),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kAccent.withAlpha(active ? 180 : 70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: active ? Colors.white : kAccent,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Talk with AI',
              style: TextStyle(
                color: active ? Colors.white : kAccent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDateLabel extends StatelessWidget {
  const _NavDateLabel();

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final now = AppTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _days[now.weekday - 1],
          style: TextStyle(
            color: kText1,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 2),
        Text(
          DateFormat('dd.MM.yyyy').format(now),
          style: TextStyle(
            color: kText2,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── What-if sabit sorular ─────────────────────────────────────────────────────

class _WhatIfQuestion {
  const _WhatIfQuestion({
    required this.label,
    required this.scenario,
    this.needsLesson = false,
    this.needsDay = false,
  });

  final String label;
  final String scenario;
  final bool needsLesson;
  final bool needsDay;
}

const _kWhatIfQuestions = [
  _WhatIfQuestion(
    label: 'What happens if I study more?',
    scenario: 'daha_fazla_calis',
  ),
  _WhatIfQuestion(
    label: 'How am I doing in this lesson?',
    scenario: 'ders_durumu',
    needsLesson: true,
  ),
  _WhatIfQuestion(
    label: 'What study style suits me best?',
    scenario: 'calisma_tarzi',
  ),
  _WhatIfQuestion(
    label: 'What if I focus more on one lesson?',
    scenario: 'derse_odaklan',
    needsLesson: true,
  ),
  _WhatIfQuestion(
    label: 'What if I cannot study that day?',
    scenario: 'gun_bos',
    needsDay: true,
  ),
];

const _kDayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

// ── AI Chat Popup ─────────────────────────────────────────────────────────────

class _AiChatPopup extends StatefulWidget {
  const _AiChatPopup({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_AiChatPopup> createState() => _AiChatPopupState();
}

class _AiChatPopupState extends State<_AiChatPopup> {
  final List<({String text, bool fromUser})> _messages = [
    (
      text: "Hi! Pick a scenario about your study plan and I'll analyze it.",
      fromUser: false,
    ),
  ];

  bool _loading = false;
  bool _chipsVisible = true;
  _WhatIfQuestion? _pendingQuestion;

  List<dynamic> _lessons = [];
  bool _lessonsLoaded = false;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onChipTapped(_WhatIfQuestion q) async {
    setState(() => _chipsVisible = false);

    if (q.needsLesson) {
      await _ensureLessonsLoaded();
      if (!mounted) return;
      setState(() {
        _pendingQuestion = q;
        _messages.add((text: q.label, fromUser: true));
        _messages.add((
          text: 'Which lesson should I look at?',
          fromUser: false,
        ));
      });
      _scrollToBottom();
      return;
    }

    if (q.needsDay) {
      setState(() {
        _pendingQuestion = q;
        _messages.add((text: q.label, fromUser: true));
        _messages.add((text: 'Which day will be empty?', fromUser: false));
      });
      _scrollToBottom();
      return;
    }

    setState(() => _messages.add((text: q.label, fromUser: true)));
    await _callWhatIf(q.scenario);
  }

  Future<void> _onLessonSelected(dynamic lesson) async {
    final q = _pendingQuestion!;
    setState(() {
      _pendingQuestion = null;
      _messages.add((text: lesson['name'] as String, fromUser: true));
    });
    await _callWhatIf(q.scenario, focusLessonId: lesson['id'] as int?);
  }

  Future<void> _onDaySelected(String dayName) async {
    final q = _pendingQuestion!;
    setState(() {
      _pendingQuestion = null;
      _messages.add((text: dayName, fromUser: true));
    });
    await _callWhatIf(q.scenario, emptyDayName: dayName);
  }

  Future<void> _callWhatIf(
    String scenario, {
    int? focusLessonId,
    String? emptyDayName,
  }) async {
    setState(() => _loading = true);
    _scrollToBottom();

    try {
      final res = await ApiClient.whatIf(
        scenario: scenario,
        focusLessonId: focusLessonId,
        emptyDayName: emptyDayName,
      );
      final msg = res['message'] as String? ?? 'Could not get a response.';
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add((text: msg, fromUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add((
          text: 'Connection error. Please try again.',
          fromUser: false,
        ));
      });
    }
    _scrollToBottom();
  }

  Future<void> _ensureLessonsLoaded() async {
    if (_lessonsLoaded) return;
    try {
      _lessons = await ApiClient.getLessons();
      _lessonsLoaded = true;
    } catch (_) {
      _lessons = [];
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _reset() {
    setState(() {
      _messages.add((
        text: 'Would you like me to check anything else?',
        fromUser: false,
      ));
      _pendingQuestion = null;
      _chipsVisible = true;
    });
    _scrollToBottom();
  }

  // Kaç ekstra item var (chips, loading, reset butonu)
  int get _extraCount {
    if (_loading) return 1;
    if (_chipsVisible) return 1;
    if (_pendingQuestion?.needsLesson == true) return 1;
    if (_pendingQuestion?.needsDay == true) return 1;
    return 1; // reset butonu
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 330,
        height: 420,
        decoration: BoxDecoration(
          color: kSurface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kAccent.withAlpha(90)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(appTheme.isLight ? 26 : 110),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            // Başlık
            Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: kAccent.withAlpha(34),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: kAccent,
                      size: 17,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Coach',
                      style: TextStyle(
                        color: kText1,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close_rounded, color: kText2, size: 18),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: kBorder.withAlpha(130)),

            // Mesaj listesi
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.all(12),
                itemCount: _messages.length + _extraCount,
                separatorBuilder: (_, _) => SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    final m = _messages[index];
                    return _buildBubble(m.text, m.fromUser);
                  }

                  // Loading
                  if (_loading) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: kBorder.withAlpha(55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SizedBox(
                          width: 48,
                          child: LinearProgressIndicator(
                            color: kAccent,
                            backgroundColor: kAccent.withAlpha(30),
                            minHeight: 2,
                          ),
                        ),
                      ),
                    );
                  }

                  // İlk chip listesi
                  if (_chipsVisible) return _buildQuestionChips();

                  // Lesson seçimi
                  if (_pendingQuestion?.needsLesson == true) {
                    return _buildLessonChips();
                  }

                  // Gün seçimi
                  if (_pendingQuestion?.needsDay == true) {
                    return _buildDayChips();
                  }

                  // Reset butonu
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _reset,
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: kAccent,
                      ),
                      label: Text(
                        'Ask another question',
                        style: TextStyle(color: kAccent, fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        backgroundColor: kAccent.withAlpha(18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(String text, bool fromUser) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 250),
        padding: EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: fromUser
              ? kAccent.withAlpha(42)
              : kBorder.withAlpha(appTheme.isLight ? 45 : 55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: kText1,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _kWhatIfQuestions.map((q) {
        return GestureDetector(
          onTap: _loading ? null : () => _onChipTapped(q),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: kAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAccent.withAlpha(70)),
            ),
            child: Text(
              q.label,
              style: TextStyle(
                color: kAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLessonChips() {
    if (_lessons.isEmpty) {
      return Text(
        'No lesson found.',
        style: TextStyle(color: kText2, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _lessons.map((l) {
        return GestureDetector(
          onTap: () => _onLessonSelected(l),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              l['name'] as String? ?? '?',
              style: TextStyle(
                color: kText1,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _kDayNames.map((day) {
        return GestureDetector(
          onTap: () => _onDaySelected(day),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              day,
              style: TextStyle(
                color: kText1,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Dotted pattern painter ────────────────────────────────────────────────────

class _DottedPatternPainter extends CustomPainter {
  const _DottedPatternPainter({
    required this.color,
    this.dotSpacing = 24,
    this.dotSize = 2,
  });

  final Color color;
  final double dotSpacing;
  final double dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double y = 0; y < size.height; y += dotSpacing) {
      for (double x = 0; x < size.width; x += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedPatternPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dotSpacing != dotSpacing ||
        oldDelegate.dotSize != dotSize;
  }
}

// ── Full Screen Frame ─────────────────────────────────────────────────────────

class _FullScreenFrame extends StatelessWidget {
  const _FullScreenFrame({
    required this.child,
    required this.navbar,
    required this.aiChatOpen,
    required this.onToggleAiChat,
    required this.onCloseAiChat,
    this.contentFullscreenListenable,
  });

  static const _outerMargin = EdgeInsets.fromLTRB(54, 0, 32, 54);
  static const _navHeight = 96.0;
  static const _panelGap = 30.0;
  static const _frameRadius = 16.0;

  final Widget child;
  final Widget navbar;
  final bool aiChatOpen;
  final VoidCallback onToggleAiChat;
  final VoidCallback onCloseAiChat;
  final ValueListenable<bool>? contentFullscreenListenable;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final outerMargin = compact
              ? EdgeInsets.fromLTRB(8, 0, 8, 10)
              : _outerMargin;
          final panelGap = compact ? 12.0 : _panelGap;
          final navPadding = compact ? 12.0 : 34.0;
          final navRect = Rect.fromLTWH(
            outerMargin.left,
            outerMargin.top,
            constraints.maxWidth - outerMargin.horizontal,
            _navHeight,
          );
          final contentTop = navRect.bottom + panelGap;
          final contentRect = Rect.fromLTRB(
            outerMargin.left,
            contentTop,
            constraints.maxWidth - outerMargin.right,
            constraints.maxHeight - outerMargin.bottom,
          );
          final contentFullscreen = contentFullscreenListenable?.value ?? false;

          if (contentFullscreen) {
            return _FramedPanel(radius: 0, clipTop: false, child: child);
          }

          return Stack(
            children: [
              Positioned.fromRect(
                rect: navRect,
                child: _FramedPanel(
                  radius: _frameRadius,
                  clipTop: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: navPadding),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!compact)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _NavDateLabel(),
                          ),
                        Align(alignment: Alignment.center, child: navbar),
                        if (!compact)
                          Align(
                            alignment: Alignment.centerRight,
                            child: _TalkWithAiButton(
                              active: aiChatOpen,
                              onTap: onToggleAiChat,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: contentRect,
                child: _FramedPanel(radius: _frameRadius, child: child),
              ),
              if (aiChatOpen)
                Positioned(
                  top: navRect.bottom + 12,
                  right: compact
                      ? outerMargin.right + 4
                      : outerMargin.right + 18,
                  child: _AiChatPopup(onClose: onCloseAiChat),
                ),
              if (compact)
                AnimatedPositioned(
                  duration: Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  top: navRect.top + (navRect.height - 48) / 2,
                  right: aiChatOpen ? outerMargin.right : -36,
                  child: _AiEdgeTab(active: aiChatOpen, onTap: onToggleAiChat),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AiEdgeTab extends StatelessWidget {
  const _AiEdgeTab({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Talk with AI',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 54,
            height: 48,
            decoration: BoxDecoration(
              color: active ? kAccent : kAccent.withAlpha(34),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kAccent.withAlpha(active ? 180 : 95)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(appTheme.isLight ? 18 : 85),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: active ? Colors.white : kAccent,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Framed Panel ──────────────────────────────────────────────────────────────

class _FramedPanel extends StatelessWidget {
  const _FramedPanel({
    required this.child,
    required this.radius,
    this.clipTop = true,
  });

  final Widget child;
  final double radius;
  final bool clipTop;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(clipTop ? radius : 0),
      bottom: Radius.circular(radius),
    );

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: borderRadius,
        border: Border.all(
          color: appTheme.isLight
              ? Color(0xFFDCCEFF)
              : kAccent.withValues(alpha: 0.72),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DottedPatternPainter(
                  color: appTheme.isLight
                      ? kBorder.withValues(alpha: 0.24)
                      : kBorder.withValues(alpha: 0.38),
                  dotSpacing: 22,
                  dotSize: appTheme.isLight ? 1.25 : 1.5,
                ),
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}
