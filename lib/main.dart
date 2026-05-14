import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'core/app_time.dart';
import 'screens/auth_screen.dart';
import 'screens/main_scaffold.dart';
import 'theme.dart';

void main() => runApp(App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    appTheme.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTheme,
      builder: (context, _) {
        return MaterialApp(
          title: 'Study Planner',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: appTheme.themeMode,
          builder: (context, child) =>
              _DottedAppBackground(child: child ?? SizedBox.shrink()),
          initialRoute: '/',
          routes: {'/': (_) => _Splash()},
        );
      },
    );
  }
}

class _DottedAppBackground extends StatelessWidget {
  const _DottedAppBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
      child: CustomPaint(
        painter: _DottedGridPainter(
          dotColor: appTheme.isLight
              ? kAccent.withAlpha(44)
              : kAccent.withAlpha(76),
          glowColor: appTheme.isLight
              ? kCyan.withAlpha(16)
              : kCyan.withAlpha(18),
        ),
        child: child,
      ),
    );
  }
}

class _DottedGridPainter extends CustomPainter {
  const _DottedGridPainter({required this.dotColor, required this.glowColor});

  final Color dotColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = dotColor;
    const spacing = 28.0;
    for (double y = 18; y < size.height; y += spacing) {
      for (double x = 18; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.25, dotPaint);
      }
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [glowColor, Colors.transparent])
          .createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.36, size.height * 0.16),
              radius: size.width * 0.34,
            ),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  @override
  bool shouldRepaint(_DottedGridPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor || oldDelegate.glowColor != glowColor;
}

class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await AppTime.init(); // backend saatini senkronize et
    final token = await ApiClient.getToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => token != null ? MainScaffold() : AuthScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: CircularProgressIndicator(color: kAccent)),
    );
  }
}
