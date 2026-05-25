import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'main_scaffold.dart';
import 'register_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginKey = GlobalKey<FormState>();

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();

  bool _loading = false;
  bool _loginObscure = true;
  bool _darkMode = false;

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPass.dispose();
    super.dispose();
  }

  _AuthPalette get _palette =>
      _darkMode ? _AuthPalette.dark() : _AuthPalette.light();

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final token = await ApiClient.login(
        _loginEmail.text.trim(),
        _loginPass.text.trim(),
      );
      await ApiClient.saveToken(token);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainScaffold()),
      );
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    final p = _palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: p.panel,
        content: Text(msg, style: TextStyle(color: p.text)),
      ),
    );
  }

  void _goToRegister() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegisterScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;

    return Scaffold(
      backgroundColor: p.backgroundStart,
      body: Stack(
        children: [
          // Gradient arka plan
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.backgroundStart, p.backgroundMid, p.backgroundEnd],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: _darkMode
                      ? const Alignment(0.15, -0.3)
                      : const Alignment(0.0, -0.15),
                  radius: 1.0,
                  colors: [
                    p.glow.withAlpha(_darkMode ? 50 : 70),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ModeSwitch(
                        darkMode: _darkMode,
                        palette: p,
                        onChanged: (v) => setState(() => _darkMode = v),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo / başlık alanı
                            Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: p.accent.withAlpha(30),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: p.accent.withAlpha(80),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.school_rounded,
                                    color: p.accent,
                                    size: 38,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Welcome',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: p.text,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to your account',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: p.muted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 36),
                            // Login formu kartı
                            _buildLoginCard(p),
                            const SizedBox(height: 24),
                            // Sign Up linki
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: _loading ? null : _goToRegister,
                                  child: Text(
                                    'Sign Up →',
                                    style: TextStyle(
                                      color: p.accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(_AuthPalette p) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: p.panel.withAlpha(_darkMode ? 215 : 185),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: p.shadow,
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Form(
            key: _loginKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  controller: _loginEmail,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                  palette: p,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _loginPass,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscure: _loginObscure,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _loginObscure ? Icons.visibility_off : Icons.visibility,
                      color: p.accent,
                    ),
                    onPressed: () =>
                        setState(() => _loginObscure = !_loginObscure),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'En az 6 karakter' : null,
                  palette: p,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: _darkMode
                        ? Colors.white
                        : p.backgroundStart,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required _AuthPalette palette,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: palette.muted, fontSize: 13),
        prefixIcon: Icon(icon, color: palette.accent, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: palette.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.accent, width: 1.3),
        ),
      ),
    );
  }
}

// ─── Mode Switch ──────────────────────────────────────────────────────────────

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.darkMode,
    required this.palette,
    required this.onChanged,
  });

  final bool darkMode;
  final _AuthPalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.panel.withAlpha(180),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModePill(
            selected: !darkMode,
            label: 'Light',
            palette: palette,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 6),
          _ModePill(
            selected: darkMode,
            label: 'Dark',
            palette: palette,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.selected,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final _AuthPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : palette.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Palette ──────────────────────────────────────────────────────────────────

class _AuthPalette {
  const _AuthPalette({
    required this.backgroundStart,
    required this.backgroundMid,
    required this.backgroundEnd,
    required this.panel,
    required this.text,
    required this.muted,
    required this.accent,
    required this.border,
    required this.inputFill,
    required this.shadow,
    required this.glow,
  });

  factory _AuthPalette.dark() => const _AuthPalette(
    backgroundStart: Color(0xFF070719),
    backgroundMid: Color(0xFF0B0921),
    backgroundEnd: Color(0xFF050507),
    panel: Color(0xD00D0A24),
    text: Color(0xFFF4F0FF),
    muted: Color(0xFF9B8DCC),
    accent: Color(0xFF8A6CFF),
    border: Color(0xFF3D2D84),
    inputFill: Color(0x8013122D),
    shadow: Color(0xFF000000),
    glow: Color(0xFF49E9FF),
  );

  factory _AuthPalette.light() => const _AuthPalette(
    backgroundStart: Color(0xFFC5FFB8),
    backgroundMid: Color(0xFFE9FFE4),
    backgroundEnd: Color(0xFFFFFDF8),
    panel: Color(0xF8FFFDF8),
    text: Color(0xFF073C35),
    muted: Color(0xFF48685F),
    accent: Color(0xFFA78BFA),
    border: Color(0xFF8F9D93),
    inputFill: Color(0xEEFFFDF8),
    shadow: Color(0x66073C35),
    glow: Color(0xBFC5FFB8),
  );

  final Color backgroundStart;
  final Color backgroundMid;
  final Color backgroundEnd;
  final Color panel;
  final Color text;
  final Color muted;
  final Color accent;
  final Color border;
  final Color inputFill;
  final Color shadow;
  final Color glow;
}
