import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'main_scaffold.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();

  // Login controllers
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();

  // Register controllers — sadece email + şifre
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();
  final _regPassConfirm = TextEditingController();

  late final PageController _pageController;

  bool _loading = false;
  bool _loginObscure = true;
  bool _regObscure = true;
  bool _regConfirmObscure = true;
  bool _darkMode = true;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82, initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    _regPassConfirm.dispose();
    super.dispose();
  }

  /// E-posta ve şifre ile oturum açar; başarılı olursa ana sayfaya geçer.
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

  /// Yeni kullanıcı kaydı oluşturur; başarılı olursa ana sayfaya geçer.
  Future<void> _register() async {
    if (!_registerKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final token = await ApiClient.register(
        _regEmail.text.trim(),
        _regPass.text.trim(),
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
    final palette = _palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: palette.panel,
        content: Text(msg, style: TextStyle(color: palette.text)),
      ),
    );
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  _AuthPalette get _palette =>
      _darkMode ? _AuthPalette.dark() : _AuthPalette.light();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 980;
    final palette = _palette;

    return Scaffold(
      backgroundColor: palette.backgroundStart,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.backgroundStart,
                    palette.backgroundMid,
                    palette.backgroundEnd,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: _darkMode
                      ? Alignment(0.15, -0.3)
                      : Alignment(0.0, -0.15),
                  radius: 1.0,
                  colors: [
                    palette.glow.withAlpha(_darkMode ? 50 : 70),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 18),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ModeSwitch(
                        darkMode: _darkMode,
                        palette: palette,
                        onChanged: (value) {
                          setState(() => _darkMode = value);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = wide ? 1320.0 : 860.0;
                        final frameHeight = (constraints.maxHeight - 70).clamp(
                          480.0,
                          wide ? 620.0 : 720.0,
                        );

                        return ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: frameHeight,
                                child: PageView(
                                  controller: _pageController,
                                  onPageChanged: (index) {
                                    setState(() => _pageIndex = index);
                                  },
                                  padEnds: true,
                                  children: [
                                    _buildFrame(
                                      title: 'Sign In',
                                      subtitle:
                                          'Hesabina gir ve haftalik programina ulas.',
                                      palette: palette,
                                      child: _buildLoginForm(palette),
                                      footer: Align(
                                        alignment: Alignment.bottomRight,
                                        child: TextButton.icon(
                                          onPressed: () => _goTo(1),
                                          iconAlignment: IconAlignment.end,
                                          icon: Icon(
                                            Icons.arrow_outward_rounded,
                                            size: 18,
                                          ),
                                          label: Text('Sign Up'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: palette.accent,
                                            textStyle: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    _buildFrame(
                                      title: 'Sign Up',
                                      subtitle:
                                          'Yeni hesap olustur ve takibe basla.',
                                      palette: palette,
                                      child: _buildRegisterForm(palette),
                                      footer: Align(
                                        alignment: Alignment.bottomLeft,
                                        child: TextButton.icon(
                                          onPressed: () => _goTo(0),
                                          icon: Icon(
                                            Icons.arrow_back_rounded,
                                            size: 18,
                                          ),
                                          label: Text('Back to Sign In'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: palette.accent,
                                            textStyle: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12),
                              _AuthPager(
                                currentIndex: _pageIndex,
                                palette: palette,
                                onTap: _goTo,
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildFrame({
    required String title,
    required String subtitle,
    required _AuthPalette palette,
    required Widget child,
    required Widget footer,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 840,
              constraints: BoxConstraints(minHeight: 470),
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: palette.panel.withAlpha(_darkMode ? 215 : 185),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: palette.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 30,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                      color: palette.text,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: palette.muted,
                    ),
                  ),
                  SizedBox(height: 22),
                  Expanded(child: SingleChildScrollView(child: child)),
                  SizedBox(height: 12),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(_AuthPalette palette) {
    return Form(
      key: _loginKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _loginEmail,
            label: 'E-posta',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Gecerli e-posta girin' : null,
            palette: palette,
          ),
          SizedBox(height: 14),
          _field(
            controller: _loginPass,
            label: 'Sifre',
            icon: Icons.lock_outline,
            obscure: _loginObscure,
            suffixIcon: IconButton(
              icon: Icon(
                _loginObscure ? Icons.visibility_off : Icons.visibility,
                color: palette.accent,
              ),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'En az 6 karakter' : null,
            palette: palette,
          ),
          SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _login,
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: _darkMode
                  ? Colors.white
                  : palette.backgroundStart,
              padding: EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Sign In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  /// Kayıt formu: sadece e-posta, şifre ve şifre tekrar alanları.
  Widget _buildRegisterForm(_AuthPalette palette) {
    return Form(
      key: _registerKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _regEmail,
            label: 'E-posta',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Gecerli e-posta girin' : null,
            palette: palette,
          ),
          SizedBox(height: 14),
          _field(
            controller: _regPass,
            label: 'Sifre',
            icon: Icons.lock_outline,
            obscure: _regObscure,
            suffixIcon: IconButton(
              icon: Icon(
                _regObscure ? Icons.visibility_off : Icons.visibility,
                color: palette.accent,
              ),
              onPressed: () => setState(() => _regObscure = !_regObscure),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'En az 6 karakter' : null,
            palette: palette,
          ),
          SizedBox(height: 14),
          _field(
            controller: _regPassConfirm,
            label: 'Sifre Tekrar',
            icon: Icons.lock_clock_outlined,
            obscure: _regConfirmObscure,
            suffixIcon: IconButton(
              icon: Icon(
                _regConfirmObscure ? Icons.visibility_off : Icons.visibility,
                color: palette.accent,
              ),
              onPressed: () =>
                  setState(() => _regConfirmObscure = !_regConfirmObscure),
            ),
            validator: (v) => v != _regPass.text ? 'Sifreler eslesmiyor' : null,
            palette: palette,
          ),
          SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _register,
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: _darkMode
                  ? Colors.white
                  : palette.backgroundStart,
              padding: EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Kayit Ol ve Basla',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: EdgeInsets.all(6),
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
          SizedBox(width: 6),
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
        duration: Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (_AuthPalette.dark().accent == palette.accent
                      ? Colors.white
                      : palette.backgroundStart)
                : palette.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AuthPager extends StatelessWidget {
  const _AuthPager({
    required this.currentIndex,
    required this.palette,
    required this.onTap,
  });

  final int currentIndex;
  final _AuthPalette palette;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panel.withAlpha(110),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PagerDot(
            active: currentIndex == 0,
            palette: palette,
            onTap: () => onTap(0),
          ),
          SizedBox(width: 18),
          _PagerDot(
            active: currentIndex == 1,
            palette: palette,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _PagerDot extends StatelessWidget {
  const _PagerDot({
    required this.active,
    required this.palette,
    required this.onTap,
  });

  final bool active;
  final _AuthPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        width: active ? 70 : 20,
        height: 20,
        decoration: BoxDecoration(
          color: active ? palette.pagerActive : palette.pagerInactive,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _AuthPalette {
  _AuthPalette({
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
    required this.pagerActive,
    required this.pagerInactive,
  });

  factory _AuthPalette.dark() {
    return _AuthPalette(
      backgroundStart: Color(0xFF0D0B11),
      backgroundMid: Color(0xFF09070B),
      backgroundEnd: Color(0xFF050507),
      panel: Color(0xC1141319),
      text: Color(0xFFF5F1F8),
      muted: Color(0xFFB5AFC0),
      accent: Color(0xFFE85CFF),
      border: Color(0xFF1F2E88),
      inputFill: Color(0x80131218),
      shadow: Color(0xFF000000),
      glow: Color(0xFFE85CFF),
      pagerActive: Color(0xFFE85CFF),
      pagerInactive: Color(0x66FFFFFF),
    );
  }

  factory _AuthPalette.light() {
    return _AuthPalette(
      backgroundStart: Color(0xFFEAF6DE),
      backgroundMid: Color(0xFFE6F2D9),
      backgroundEnd: Color(0xFFDDECCB),
      panel: Color(0xE8F4F9EC),
      text: Color(0xFF13342F),
      muted: Color(0xFF4E6762),
      accent: Color(0xFFB391F5),
      border: Color(0xFF86A39D),
      inputFill: Color(0xCCF7FBF2),
      shadow: Color(0xFF9FB3A2),
      glow: Color(0xB4EAF8D8),
      pagerActive: Color(0xFFFA6D72),
      pagerInactive: Color(0x667A8B84),
    );
  }

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
  final Color pagerActive;
  final Color pagerInactive;
}
