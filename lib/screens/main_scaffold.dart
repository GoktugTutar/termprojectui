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
          _FullScreenFrame(navbar: navbar, child: TodayScreen()),
          _FullScreenFrame(
            navbar: navbar,
            child: WeekScreen(reloadSignal: _weekReloadSignal),
          ),
          _FullScreenFrame(navbar: navbar, child: InsightsScreen()),
          _FullScreenFrame(navbar: navbar, child: ProfileScreen()),
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kBorder.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(destinations.length, (i) {
              final (unsel, sel, label) = destinations[i];
              final selected = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  margin: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? kAccent.withAlpha(24)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? sel : unsel,
                        color: selected ? kAccent : kText2,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                    ],
                  ),
                ),
              );
            }),
            SizedBox(width: 6),
            _ThemeToggle(expanded: false),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav (mobile) ───────────────────────────────────────────────────────

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
            width: expanded ? double.infinity : 52,
            height: expanded ? null : 48,
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 14 : 0,
              vertical: expanded ? 12 : 0,
            ),
            decoration: BoxDecoration(
              color: kAccent.withAlpha(24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kAccent.withAlpha(45)),
            ),
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
                : Center(child: Icon(icon, color: kAccent, size: 22)),
          ),
        );
      },
    );
  }
}

// ── Dotted Pattern Painter ────────────────────────────────────────────────────

class _DottedPatternPainter extends CustomPainter {
  final Color color;
  final double dotSpacing;
  final double dotSize;

  _DottedPatternPainter({
    required this.color,
    this.dotSpacing = 24,
    this.dotSize = 2,
  });

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
  const _FullScreenFrame({required this.child, required this.navbar});

  final Widget child;
  final Widget navbar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Pattern background
              Positioned.fill(
                child: CustomPaint(
                  painter: _DottedPatternPainter(
                    color: kBorder.withValues(alpha: 0.25),
                    dotSpacing: 20,
                    dotSize: 1.5,
                  ),
                ),
              ),
              // Content with navbar
              Column(
                children: [
                  // Navbar at top
                  Padding(padding: EdgeInsets.all(12), child: navbar),
                  // Content below
                  Expanded(child: child),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
