import 'package:flutter/material.dart';
import '../theme.dart';
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

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Bugün'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Hafta'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Analiz'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

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

        final screens = <Widget>[
          _FullScreenFrame(
            navbar: navbar,
            aiChatOpen: _aiChatOpen,
            onToggleAiChat: _toggleAiChat,
            onCloseAiChat: _closeAiChat,
            child: TodayScreen(),
          ),
          _FullScreenFrame(
            navbar: navbar,
            aiChatOpen: _aiChatOpen,
            onToggleAiChat: _toggleAiChat,
            onCloseAiChat: _closeAiChat,
            child: WeekScreen(reloadSignal: _weekReloadSignal),
          ),
          _FullScreenFrame(
            navbar: navbar,
            aiChatOpen: _aiChatOpen,
            onToggleAiChat: _toggleAiChat,
            onCloseAiChat: _closeAiChat,
            child: InsightsScreen(),
          ),
          _FullScreenFrame(
            navbar: navbar,
            aiChatOpen: _aiChatOpen,
            onToggleAiChat: _toggleAiChat,
            onCloseAiChat: _closeAiChat,
            child: ProfileScreen(),
          ),
        ];

        return Scaffold(
          backgroundColor: kBg,
          body: IndexedStack(index: _index, children: screens),
        );
      },
    );
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      if (index == 1) {
        _weekReloadSignal++;
      }
    });
  }

  void _toggleAiChat() {
    setState(() => _aiChatOpen = !_aiChatOpen);
  }

  void _closeAiChat() {
    setState(() => _aiChatOpen = false);
  }
}

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
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kAccent.withAlpha(20) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? sel : unsel,
                  color: selected ? kAccent : kText2,
                  size: 21,
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

// ── Bottom nav (mobile) ───────────────────────────────────────────────────────

class _NavSeparator extends StatelessWidget {
  const _NavSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: EdgeInsets.symmetric(horizontal: 18),
      color: kBorder.withAlpha(appTheme.isLight ? 150 : 120),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
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
            width: expanded ? double.infinity : 42,
            height: expanded ? null : 42,
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
                    child: Center(child: Icon(icon, color: kAccent, size: 22)),
                  ),
          ),
        );
      },
    );
  }
}

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

class _AiChatPopup extends StatefulWidget {
  const _AiChatPopup({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_AiChatPopup> createState() => _AiChatPopupState();
}

class _AiChatPopupState extends State<_AiChatPopup> {
  final _controller = TextEditingController();
  final List<({String text, bool fromUser})> _messages = [
    (
      text: 'Merhaba, çalışma planın hakkında neye bakmamı istersin?',
      fromUser: false,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add((text: text, fromUser: true));
      _messages.add((
        text:
            'Şimdilik bu alan UI prototipi. İstersen bunu gerçek AI endpointine bağlayabiliriz.',
        fromUser: false,
      ));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 330,
        height: 360,
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
                      'Talk with AI',
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
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: kBorder.withAlpha(130)),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(12),
                itemCount: _messages.length,
                separatorBuilder: (_, _) => SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 250),
                      padding: EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: message.fromUser
                            ? kAccent.withAlpha(42)
                            : kBorder.withAlpha(appTheme.isLight ? 45 : 55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: kText1,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: kText1, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: Icon(Icons.arrow_upward_rounded, size: 18),
                    style: IconButton.styleFrom(backgroundColor: kAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

// ── Full Screen Frame ────────────────────────────────────────────────────────

class _FullScreenFrame extends StatelessWidget {
  const _FullScreenFrame({
    required this.child,
    required this.navbar,
    required this.aiChatOpen,
    required this.onToggleAiChat,
    required this.onCloseAiChat,
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final navRect = Rect.fromLTWH(
            _outerMargin.left,
            _outerMargin.top,
            constraints.maxWidth - _outerMargin.horizontal,
            _navHeight,
          );
          final contentTop = navRect.bottom + _panelGap;
          final contentRect = Rect.fromLTRB(
            _outerMargin.left,
            contentTop,
            constraints.maxWidth - _outerMargin.right,
            constraints.maxHeight - _outerMargin.bottom,
          );

          return Stack(
            children: [
              Positioned.fromRect(
                rect: navRect,
                child: _FramedPanel(
                  radius: _frameRadius,
                  clipTop: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 34),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(alignment: Alignment.center, child: navbar),
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
                  right: _outerMargin.right + 18,
                  child: _AiChatPopup(onClose: onCloseAiChat),
                ),
            ],
          );
        },
      ),
    );
  }
}

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
            if (!appTheme.isLight)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DottedPatternPainter(
                    color: kBorder.withValues(alpha: 0.38),
                    dotSpacing: 22,
                    dotSize: 1.5,
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
