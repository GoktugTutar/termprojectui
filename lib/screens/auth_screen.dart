import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'main_scaffold.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();
  final _regPassConfirm = TextEditingController();

  bool _loading = false;
  bool _loginObscure = true;
  bool _regObscure = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    _regPassConfirm.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final token = await ApiClient.login(
          _loginEmail.text.trim(), _loginPass.text.trim());
      await ApiClient.saveToken(token);
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainScaffold()));
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_registerKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final token = await ApiClient.register(
          _regEmail.text.trim(), _regPass.text.trim());
      await ApiClient.saveToken(token);
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainScaffold()));
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Logo / Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.school_rounded,
                          size: 56, color: cs.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('Ders Takip',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: cs.primary)),
                    const SizedBox(height: 4),
                    Text('Akilli Ders Planlayici',
                        style: TextStyle(fontSize: 14, color: cs.outline)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: cs.onPrimary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Giris Yap'),
                    Tab(text: 'Kayit Ol'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tab,
                  children: [_buildLogin(), _buildRegister()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    final cs = Theme.of(context).colorScheme;
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
          ),
          const SizedBox(height: 16),
          _field(
            controller: _loginPass,
            label: 'Sifre',
            icon: Icons.lock_outline,
            obscure: _loginObscure,
            suffixIcon: IconButton(
              icon: Icon(
                  _loginObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'En az 6 karakter' : null,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _loading ? null : _login,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary))
                : const Text('Giris Yap', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegister() {
    final cs = Theme.of(context).colorScheme;
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
          ),
          const SizedBox(height: 12),
          _field(
            controller: _regPass,
            label: 'Sifre',
            icon: Icons.lock_outline,
            obscure: _regObscure,
            suffixIcon: IconButton(
              icon:
                  Icon(_regObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _regObscure = !_regObscure),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'En az 6 karakter' : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _regPassConfirm,
            label: 'Sifre Tekrar',
            icon: Icons.lock_outline,
            obscure: _regObscure,
            validator: (v) =>
                v != _regPass.text ? 'Sifreler eslesmiyor' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _register,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary))
                : const Text('Kayit Ol', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }
}
