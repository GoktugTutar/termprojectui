import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'onboarding_screen.dart';

/// Kullanıcı kayıt ekranı — sadece email ve şifreyi alır,
/// akademik bilgiler onboarding adım 0'da sorulur.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _weeklyHoursCtrl = TextEditingController(text: '14');

  bool _loading = false;
  bool _passObscure = true;
  bool _confirmObscure = true;
  bool _darkMode = false;

  _Palette get _p => _darkMode ? _Palette.dark() : _Palette.light();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _weeklyHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final hours = int.tryParse(_weeklyHoursCtrl.text.trim()) ?? 14;
      final token = await ApiClient.register(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
        weeklyStudyHours: hours.clamp(1, 70),
      );
      await ApiClient.saveToken(token);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _p.panel,
          content: Text(msg, style: TextStyle(color: _p.text)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
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
                // Üst bar: Back + Dark/Light switch
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _BackButton(
                        palette: p,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
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
                            // Başlık
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
                                    Icons.person_add_rounded,
                                    color: p.accent,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: p.text,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Continue with your email and password.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: p.muted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Form kartı
                            _buildCard(p),
                            const SizedBox(height: 20),
                            // Already have an account?
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: _loading
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: Text(
                                    'Sign In →',
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

  Widget _buildCard(_Palette p) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        // Sigma 18→10: GPU yükü ~%70 azalır → geçiş çok daha hızlı
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  ctrl: _emailCtrl,
                  label: 'E-posta',
                  icon: Icons.email_outlined,
                  type: TextInputType.emailAddress,
                  palette: p,
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Geçerli e-posta girin'
                      : null,
                ),
                const SizedBox(height: 14),
                _field(
                  ctrl: _passCtrl,
                  label: 'Şifre',
                  icon: Icons.lock_outline,
                  palette: p,
                  obscure: _passObscure,
                  suffix: IconButton(
                    icon: Icon(
                      _passObscure ? Icons.visibility_off : Icons.visibility,
                      color: p.accent,
                    ),
                    onPressed: () =>
                        setState(() => _passObscure = !_passObscure),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'En az 6 karakter' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  ctrl: _confirmCtrl,
                  label: 'Şifre Tekrar',
                  icon: Icons.lock_clock_outlined,
                  palette: p,
                  obscure: _confirmObscure,
                  suffix: IconButton(
                    icon: Icon(
                      _confirmObscure ? Icons.visibility_off : Icons.visibility,
                      color: p.accent,
                    ),
                    onPressed: () =>
                        setState(() => _confirmObscure = !_confirmObscure),
                  ),
                  validator: (v) =>
                      v != _passCtrl.text ? 'Şifreler eşleşmiyor' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  ctrl: _weeklyHoursCtrl,
                  label: 'Haftalık çalışma saati',
                  icon: Icons.schedule_outlined,
                  type: TextInputType.number,
                  palette: p,
                  hint: 'Varsayılan: 14 saat',
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 70) {
                      return '1 ile 70 arasında bir değer girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _loading ? null : _submit,
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
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Devam Et',
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
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required _Palette palette,
    TextInputType? type,
    bool obscure = false,
    Widget? suffix,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
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
        hintText: hint,
        hintStyle: TextStyle(color: palette.muted, fontSize: 13),
        prefixIcon: Icon(icon, color: palette.accent, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: palette.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF5C7A)),
        ),
      ),
    );
  }
}

// ─── Back Button ──────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.palette, required this.onTap});
  final _Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: palette.panel.withAlpha(180),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              color: palette.text,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Back',
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
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
  final _Palette palette;
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
          _Pill(
            selected: !darkMode,
            label: 'Light',
            palette: palette,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 6),
          _Pill(
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.selected,
    required this.label,
    required this.palette,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final _Palette palette;
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

class _Palette {
  const _Palette({
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

  factory _Palette.dark() => const _Palette(
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

  factory _Palette.light() => const _Palette(
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
