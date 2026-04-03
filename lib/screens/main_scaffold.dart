import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'profile_screen.dart';
import 'schedule_screen.dart';

const _posterPink = Color(0xFFF4CACA);
const _posterPinkDeep = Color(0xFFEFB8B8);
const _posterBlue = Color(0xFF2436FF);
const _posterBlueSoft = Color(0xFF5260FF);
const _glassWhite = Color(0x66FFF7F7);

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  final _mobileScreens = const [ScheduleScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final base = Theme.of(context);
      final scheme =
          const ColorScheme.light(
            primary: _posterBlue,
            onPrimary: Colors.white,
            secondary: _posterBlueSoft,
            onSecondary: Colors.white,
            surface: Color(0x80FFF2F2),
            onSurface: _posterBlue,
            error: _posterBlue,
            onError: Colors.white,
          ).copyWith(
            surfaceContainerHighest: const Color(0xAAFFEAEA),
            surfaceContainerHigh: const Color(0x99FFF4F4),
            surfaceContainer: const Color(0x73FFF7F7),
            outline: const Color(0x4D3345FF),
            outlineVariant: const Color(0x223345FF),
            onSurfaceVariant: const Color(0xCC3345FF),
          );

      return Theme(
        data: base.copyWith(
          colorScheme: scheme,
          scaffoldBackgroundColor: _posterPink,
          cardColor: const Color(0x7AFFF6F6),
          dividerColor: const Color(0x223345FF),
          textTheme: base.textTheme.apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xEE2436FF),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
        ),
        child: const _WebSlidingWorkspace(),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _mobileScreens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: cs.surface,
        indicatorColor: cs.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Program',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _WebSlidingWorkspace extends StatefulWidget {
  const _WebSlidingWorkspace();

  @override
  State<_WebSlidingWorkspace> createState() => _WebSlidingWorkspaceState();
}

class _WebSlidingWorkspaceState extends State<_WebSlidingWorkspace>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _ambientController;

  int _currentIndex = 0;
  int? _armedDirection;
  Offset _pointer = const Offset(0.5, 0.5);

  final List<_WorkspacePage> _pages = const [
    _WorkspacePage(title: 'Profil', child: ProfileScreen()),
    _WorkspacePage(title: 'Program', child: ScheduleScreen()),
    _WorkspacePage(title: 'Genel Bakis', child: _OverviewPanel()),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.56,
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _moveTo(int nextIndex) {
    if (nextIndex < 0 ||
        nextIndex >= _pages.length ||
        nextIndex == _currentIndex) {
      return;
    }
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleHover(int direction) {
    if (_armedDirection == direction) return;
    _armedDirection = direction;
    _moveTo(_currentIndex + direction);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final size = MediaQuery.sizeOf(context);
        setState(() {
          _pointer = Offset(
            (event.position.dx / size.width).clamp(0.0, 1.0),
            (event.position.dy / size.height).clamp(0.0, 1.0),
          );
        });
      },
      child: Scaffold(
        backgroundColor: _posterPink,
        body: AnimatedBuilder(
          animation: _ambientController,
          builder: (context, _) {
            final t = _ambientController.value;
            return Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_posterPink, _posterPinkDeep],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.15, -0.25),
                        radius: 1.0,
                        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -30 + (t * 24),
                  top: 140 + (_pointer.dy - 0.5) * 36,
                  child: const _GlassBubble(size: Size(560, 760)),
                ),
                Positioned(
                  right: -10 - (t * 36),
                  top: 10 + math.sin(t * math.pi * 2) * 20,
                  child: const _GlassBubble(size: Size(560, 760)),
                ),
                Positioned(
                  left: 300 + (_pointer.dx - 0.5) * 40,
                  top: 180,
                  child: const _GlassBubble(size: Size(320, 460)),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: ColoredBox(color: Colors.white.withAlpha(14)),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: MouseRegion(
                          onEnter: (_) => _handleHover(-1),
                          onExit: (_) => _armedDirection = null,
                          cursor: SystemMouseCursors.click,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const Expanded(flex: 2, child: SizedBox.expand()),
                      Expanded(
                        child: MouseRegion(
                          onEnter: (_) => _handleHover(1),
                          onExit: (_) => _armedDirection = null,
                          cursor: SystemMouseCursors.click,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Row(
                          children: [
                            const _GradientText(
                              'Ders Takip',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x55FFF8F8),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0x663345FF),
                                ),
                              ),
                              child: Text(
                                'Pembe + cam deneme',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _pages.length,
                          padEnds: true,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                              _armedDirection = null;
                            });
                          },
                          itemBuilder: (context, index) {
                            return AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                var pageValue = _currentIndex.toDouble();
                                if (_pageController.hasClients &&
                                    _pageController
                                        .position
                                        .hasViewportDimension) {
                                  pageValue =
                                      _pageController.page ??
                                      _currentIndex.toDouble();
                                }
                                final distance = (pageValue - index).abs();
                                final scale =
                                    1 - (distance * 0.12).clamp(0.0, 0.12);
                                final opacity =
                                    1 - (distance * 0.38).clamp(0.0, 0.38);

                                return Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  12,
                                  18,
                                  42,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 760,
                                      maxHeight: 820,
                                    ),
                                    child: _WorkspaceCard(page: _pages[index]),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              width: _currentIndex == index ? 36 : 10,
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: _currentIndex == index
                                    ? _posterBlue
                                    : const Color(0x663345FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkspacePage {
  const _WorkspacePage({required this.title, required this.child});

  final String title;
  final Widget child;
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.page});

  final _WorkspacePage page;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: const Color(0x66FFF8F8),
        border: Border.all(color: const Color(0x663345FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0x26B88989),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: ColoredBox(
            color: const Color(0x61FFF7F7),
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x443345FF)),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0x80FFE9E9), Color(0x50FFF8F8)],
                    ),
                  ),
                  child: Row(
                    children: [
                      _GradientText(
                        page.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.drag_indicator_rounded, color: cs.primary),
                    ],
                  ),
                ),
                Expanded(child: page.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GradientText(
            'Pembe cam sahnede kayan arayuz',
            style: TextStyle(
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Arka planda pudra pembe bir zemin ve ustunde buyuk seffaf cam formlar var. Tipografi ve vurgu rengi ise gorseldeki gibi doygun mavi.',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _StatCard(title: 'Zemin', value: 'Pembe', icon: Icons.palette),
              _StatCard(title: 'Yazi', value: 'Mavi', icon: Icons.text_fields),
              _StatCard(
                title: 'Yapi',
                value: 'Seffaf Cam',
                icon: Icons.auto_awesome,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0x5AFFF7F7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x443345FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GradientText(
                  'Akis Mantigi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _flowRow(
                  context,
                  'Sol alana gelince soldaki panel merkeze geciyor.',
                ),
                _flowRow(
                  context,
                  'Sag alana gelince sagdaki panel merkeze geciyor.',
                ),
                _flowRow(
                  context,
                  'Cam formlar arkada yumusak parallax ile hareket ediyor.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowRow(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 10, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x5AFFF7F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x443345FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x55FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _GradientText(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_posterBlue, _posterBlue],
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}

class _GlassBubble extends StatelessWidget {
  const _GlassBubble({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 18,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size.width),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x75FFFFFF), Color(0x22FFFFFF), Color(0x14E3A7A7)],
          ),
          border: Border.all(color: _glassWhite, width: 2),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: size.width * 0.58,
            height: size.height * 0.58,
            margin: EdgeInsets.only(bottom: size.height * 0.08),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size.width),
              border: Border.all(color: const Color(0x44FFFFFF), width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
