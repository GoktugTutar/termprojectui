import 'package:flutter/material.dart';
import '../theme.dart';
import 'today_screen.dart';
import 'week_screen.dart';
import 'lessons_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';

// >= 720px → NavigationRail (sidebar), < 720px → BottomNavigationBar
const _kWideBreakpoint = 720.0;

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Bugün'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Hafta'),
    (Icons.book_outlined, Icons.book_rounded, 'Dersler'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Analiz'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTheme,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= _kWideBreakpoint;
        final screens = <Widget>[
          TodayScreen(),
          WeekScreen(),
          LessonsScreen(),
          InsightsScreen(),
          ProfileScreen(),
        ];

        if (wide) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Row(
              children: [
                _SideNav(
                  currentIndex: _index,
                  onTap: (i) => setState(() => _index = i),
                  destinations: _destinations,
                ),
                Container(width: 1, color: kBorder),
                Expanded(
                  child: IndexedStack(index: _index, children: screens),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(index: _index, children: screens),
          bottomNavigationBar: _BottomNav(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            destinations: _destinations,
          ),
        );
      },
    );
  }
}

// ── Sidebar (web / tablet) ────────────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  const _SideNav({
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
      width: 220,
      color: kSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Text(
                'Study\nPlanner',
                style: TextStyle(
                  color: kText1,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
            _ThemeToggle(
              expanded: true,
              margin: EdgeInsets.fromLTRB(12, 0, 12, 16),
            ),
            ...List.generate(destinations.length, (i) {
              final (unsel, sel, label) = destinations[i];
              final selected = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? kAccent.withAlpha(30)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? sel : unsel,
                        color: selected ? kAccent : kText2,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? kAccent : kText2,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Spacer(),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav (mobile) ───────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
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
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              ...List.generate(destinations.length, (i) {
                final (unsel, sel, label) = destinations[i];
                final selected = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? sel : unsel,
                          color: selected ? kAccent : kText2,
                          size: 22,
                        ),
                        SizedBox(height: 3),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 9,
                            color: selected ? kAccent : kText2,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(width: 52, child: _ThemeToggle(expanded: false)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.expanded, this.margin = EdgeInsets.zero});

  final bool expanded;
  final EdgeInsets margin;

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
            margin: margin,
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
