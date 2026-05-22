import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'main_scaffold.dart';
import 'onboarding_screen.dart';

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

  // Register controllers
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();
  final _regPassConfirm = TextEditingController();
  final _registerPageController = PageController();
  final List<_RegisterLessonDraft> _lessonDrafts = [_RegisterLessonDraft()];
  final List<_RegisterBusySlotDraft> _busyDrafts = [_RegisterBusySlotDraft()];

  bool _loading = false;
  bool _loginObscure = true;
  bool _regObscure = true;
  bool _regConfirmObscure = true;
  bool _darkMode = false;
  int _registerPage = 0;

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPass.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    _regPassConfirm.dispose();
    _registerPageController.dispose();
    for (final draft in _lessonDrafts) {
      draft.dispose();
    }
    for (final draft in _busyDrafts) {
      draft.dispose();
    }
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

  /// Yeni kullanıcı kaydı oluşturur; başarılı olursa onboarding akışına geçer.
  Future<void> _register() async {
    if (!_registerKey.currentState!.validate()) {
      if (_registerPage != 0) _goToRegisterPage(0);
      return;
    }
    if (_registerPage < 2) {
      _goToRegisterPage(_registerPage + 1);
      return;
    }

    setState(() => _loading = true);
    try {
      final token = await ApiClient.register(
        _regEmail.text.trim(),
        _regPass.text.trim(),
      );
      await ApiClient.saveToken(token);

      for (final draft in _lessonDrafts) {
        final name = draft.name.text.trim();
        if (name.isEmpty) continue;
        final created = await ApiClient.createLesson(name, draft.difficulty);
        final lessonId = (created['id'] as num).toInt();
        if (draft.examDate != null) {
          await ApiClient.addExam(lessonId, _dateKey(draft.examDate!));
        }
      }

      final busySlots = _busyDrafts
          .where(
            (draft) =>
                _timeMinutes(draft.startTime) < _timeMinutes(draft.endTime),
          )
          .map(
            (draft) => {
              'dayOfWeek': draft.dayOfWeek,
              'startTime': draft.startTime,
              'endTime': draft.endTime,
              'fatigueLevel': draft.fatigueLevel,
              'isRoutine': true,
            },
          )
          .toList();
      if (busySlots.isNotEmpty) {
        await ApiClient.updateBusySlots(busySlots);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _timeMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _goToRegisterPage(int page) {
    final target = page.clamp(0, 2).toInt();
    setState(() => _registerPage = target);
    _registerPageController.animateToPage(
      target,
      duration: Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleRegisterStepTap(int page) {
    if (page <= _registerPage) {
      _goToRegisterPage(page);
      return;
    }
    if (_registerPage == 0 && !_registerKey.currentState!.validate()) return;
    _goToRegisterPage(page);
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
                        final frameHeight = wide
                            ? (constraints.maxHeight - 40).clamp(500.0, 620.0)
                            : 500.0;

                        return ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 28 : 20,
                              vertical: 24,
                            ),
                            child: wide
                                ? SizedBox(
                                    height: frameHeight,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _buildFrame(
                                            title: 'Sign In',
                                            subtitle:
                                                'Hesabina gir ve haftalik programina ulas.',
                                            palette: palette,
                                            child: _buildLoginForm(palette),
                                          ),
                                        ),
                                        SizedBox(width: 24),
                                        Expanded(
                                          child: _buildFrame(
                                            title: 'Sign Up',
                                            subtitle:
                                                'Yeni hesap olustur ve takibe basla.',
                                            palette: palette,
                                            child: _buildRegisterForm(palette),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      SizedBox(
                                        height: frameHeight,
                                        child: _buildFrame(
                                          title: 'Sign In',
                                          subtitle:
                                              'Hesabina gir ve haftalik programina ulas.',
                                          palette: palette,
                                          child: _buildLoginForm(palette),
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      SizedBox(
                                        height: frameHeight,
                                        child: _buildFrame(
                                          title: 'Sign Up',
                                          subtitle:
                                              'Yeni hesap olustur ve takibe basla.',
                                          palette: palette,
                                          child: _buildRegisterForm(palette),
                                        ),
                                      ),
                                    ],
                                  ),
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
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: palette.panel.withAlpha(_darkMode ? 215 : 185),
            borderRadius: BorderRadius.circular(34),
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
                  fontSize: 40,
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
              SizedBox(height: 24),
              Expanded(child: SingleChildScrollView(child: child)),
            ],
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

  /// Kayıt formu: kişisel bilgiler, dersler ve busy time adımları.
  Widget _buildRegisterForm(_AuthPalette palette) {
    return Form(
      key: _registerKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RegisterStepper(
            page: _registerPage,
            palette: palette,
            onTap: _handleRegisterStepTap,
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: PageView(
              controller: _registerPageController,
              onPageChanged: (value) => setState(() => _registerPage = value),
              children: [
                _buildRegisterPersonalPage(palette),
                _buildRegisterLessonsPage(palette),
                _buildRegisterBusyPage(palette),
              ],
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              if (_registerPage > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _goToRegisterPage(_registerPage - 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.text,
                      side: BorderSide(color: palette.border),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text('Geri'),
                  ),
                ),
              if (_registerPage > 0) SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _loading ? null : _register,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: _darkMode
                        ? Colors.white
                        : palette.backgroundStart,
                    padding: EdgeInsets.symmetric(vertical: 16),
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
                          _registerPage == 2 ? 'Kayit Ol ve Basla' : 'Devam',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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

  Widget _buildRegisterPersonalPage(_AuthPalette palette) {
    return SingleChildScrollView(
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
          SizedBox(height: 12),
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
          SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildRegisterLessonsPage(_AuthPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dersler',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _lessonDrafts.add(_RegisterLessonDraft())),
              icon: Icon(Icons.add_rounded, color: palette.accent),
              tooltip: 'Ders ekle',
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _lessonDrafts.length,
            separatorBuilder: (_, _) => SizedBox(height: 8),
            itemBuilder: (context, index) {
              final draft = _lessonDrafts[index];
              return _RegisterLessonCard(
                draft: draft,
                palette: palette,
                dateText: draft.examDate == null
                    ? 'Sınav tarihi'
                    : _dateKey(draft.examDate!),
                onPickExam: () => _pickRegisterExamDate(draft),
                onRemove: _lessonDrafts.length == 1
                    ? null
                    : () {
                        setState(() {
                          final removed = _lessonDrafts.removeAt(index);
                          removed.dispose();
                        });
                      },
                onChanged: () => setState(() {}),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterBusyPage(_AuthPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Busy time',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _busyDrafts.add(_RegisterBusySlotDraft())),
              icon: Icon(Icons.add_rounded, color: palette.accent),
              tooltip: 'Busy time ekle',
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _busyDrafts.length,
            separatorBuilder: (_, _) => SizedBox(height: 8),
            itemBuilder: (context, index) {
              final draft = _busyDrafts[index];
              return _RegisterBusyCard(
                draft: draft,
                palette: palette,
                onChanged: () => setState(() {}),
                onRemove: _busyDrafts.length == 1
                    ? null
                    : () => setState(() => _busyDrafts.removeAt(index)),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickRegisterExamDate(_RegisterLessonDraft draft) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.examDate ?? now.add(Duration(days: 30)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(
      () => draft.examDate = DateTime(picked.year, picked.month, picked.day),
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

class _RegisterLessonDraft {
  final TextEditingController name = TextEditingController();
  int difficulty = 3;
  DateTime? examDate;

  void dispose() {
    name.dispose();
  }
}

class _RegisterBusySlotDraft {
  int dayOfWeek = 1;
  String startTime = '09:00';
  String endTime = '10:00';
  int fatigueLevel = 2;

  void dispose() {}
}

class _RegisterStepper extends StatelessWidget {
  const _RegisterStepper({
    required this.page,
    required this.palette,
    required this.onTap,
  });

  static const _labels = ['Kişisel', 'Dersler', 'Busy'];

  final int page;
  final _AuthPalette palette;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (index) {
        final selected = index == page;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == _labels.length - 1 ? 0 : 8,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? palette.accent.withAlpha(35)
                      : palette.inputFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? palette.accent : palette.border,
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? palette.accent : Colors.transparent,
                        border: Border.all(color: palette.accent),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: selected ? Colors.white : palette.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _labels[index],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? palette.text : palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _RegisterLessonCard extends StatelessWidget {
  const _RegisterLessonCard({
    required this.draft,
    required this.palette,
    required this.dateText,
    required this.onPickExam,
    required this.onChanged,
    this.onRemove,
  });

  final _RegisterLessonDraft draft;
  final _AuthPalette palette;
  final String dateText;
  final VoidCallback onPickExam;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: draft.name,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  decoration: _inputDecoration(
                    label: 'Dersin adı',
                    icon: Icons.menu_book_outlined,
                  ),
                ),
              ),
              if (onRemove != null) ...[
                SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.remove_circle_outline, color: palette.muted),
                  tooltip: 'Dersi kaldır',
                ),
              ],
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Zorluk',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: Slider(
                  value: draft.difficulty.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: palette.accent,
                  inactiveColor: palette.pagerInactive,
                  label: draft.difficulty.toString(),
                  onChanged: (value) {
                    draft.difficulty = value.round();
                    onChanged();
                  },
                ),
              ),
              Text(
                '${draft.difficulty}/5',
                style: TextStyle(
                  color: palette.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onPickExam,
            icon: Icon(Icons.event_outlined, size: 18),
            label: Text(dateText),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              side: BorderSide(color: palette.border),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.muted, fontSize: 12),
      prefixIcon: Icon(icon, color: palette.accent, size: 18),
      filled: true,
      fillColor: palette.panel.withAlpha(90),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.accent, width: 1.3),
      ),
    );
  }
}

class _RegisterBusyCard extends StatelessWidget {
  const _RegisterBusyCard({
    required this.draft,
    required this.palette,
    required this.onChanged,
    this.onRemove,
  });

  static const _days = [
    MapEntry(1, 'Pzt'),
    MapEntry(2, 'Sal'),
    MapEntry(3, 'Çar'),
    MapEntry(4, 'Per'),
    MapEntry(5, 'Cum'),
    MapEntry(6, 'Cmt'),
    MapEntry(7, 'Paz'),
  ];
  static const _times = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
  ];

  final _RegisterBusySlotDraft draft;
  final _AuthPalette palette;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: draft.dayOfWeek,
                  items: _days
                      .map(
                        (day) => DropdownMenuItem(
                          value: day.key,
                          child: Text(day.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    draft.dayOfWeek = value;
                    onChanged();
                  },
                  decoration: _selectDecoration('Gün'),
                  dropdownColor: palette.panel,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.startTime,
                  items: _times
                      .map(
                        (time) =>
                            DropdownMenuItem(value: time, child: Text(time)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    draft.startTime = value;
                    onChanged();
                  },
                  decoration: _selectDecoration('Başlangıç'),
                  dropdownColor: palette.panel,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.endTime,
                  items: _times
                      .map(
                        (time) =>
                            DropdownMenuItem(value: time, child: Text(time)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    draft.endTime = value;
                    onChanged();
                  },
                  decoration: _selectDecoration('Bitiş'),
                  dropdownColor: palette.panel,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onRemove != null) ...[
                SizedBox(width: 4),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.remove_circle_outline, color: palette.muted),
                  tooltip: 'Busy time kaldır',
                ),
              ],
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Yorgunluk',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: Slider(
                  value: draft.fatigueLevel.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: palette.accent,
                  inactiveColor: palette.pagerInactive,
                  label: draft.fatigueLevel.toString(),
                  onChanged: (value) {
                    draft.fatigueLevel = value.round();
                    onChanged();
                  },
                ),
              ),
              Text(
                '${draft.fatigueLevel}/5',
                style: TextStyle(
                  color: palette.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _selectDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.muted, fontSize: 11),
      filled: true,
      fillColor: palette.panel.withAlpha(90),
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.accent, width: 1.3),
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
      pagerActive: Color(0xFF8A6CFF),
      pagerInactive: Color(0x669B8DCC),
    );
  }

  factory _AuthPalette.light() {
    return _AuthPalette(
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
      pagerActive: Color(0xFFA78BFA),
      pagerInactive: Color(0x668F9D93),
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
