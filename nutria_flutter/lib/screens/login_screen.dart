import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _googleServerClientId =
      '204507980549-24oq36r2cetpdu7qpc0tqp8ovo69nt12.apps.googleusercontent.com';

  bool _isRegister = false;
  bool _obscure = true;
  bool _googleLoading = false;
  bool _googleInitialized = false;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final name = _nameCtrl.text.trim();

    bool ok;
    if (_isRegister) {
      ok = await auth.register(email, pass, name);
    } else {
      ok = await auth.login(email, pass);
    }

    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _googleSignIn() async {
    final auth = context.read<AuthProvider>();
    if (_googleLoading || auth.isLoading) return;
    setState(() => _googleLoading = true);
    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize(
          serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
        );
        _googleInitialized = true;
      }

      final account = await google.authenticate();
      if (!mounted) return;

      final name = (account.displayName ?? '').trim().isEmpty
          ? account.email.split('@').first
          : account.displayName!.trim();

      final ok = await auth.socialLogin(account.email.trim(), name, 'google');
      if (ok && mounted) {
        Navigator.pushReplacementNamed(context, '/');
      } else if (mounted && auth.error != null) {
        _showSnack('Não foi possível conectar com sua conta Google. Tente novamente.');
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled &&
          e.code != GoogleSignInExceptionCode.interrupted &&
          e.code != GoogleSignInExceptionCode.uiUnavailable &&
          mounted) {
        _showSnack('Não foi possível conectar ao Google. Verifique a configuração e tente novamente.');
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Não foi possível conectar ao Google. Verifique sua conexão e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _setMode(bool isRegister) {
    _formKey.currentState?.reset();
    _passCtrl.clear();
    _nameCtrl.clear();
    _confirmCtrl.clear();
    setState(() => _isRegister = isRegister);
    context.read<AuthProvider>().clearError();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loginGreen = isDark ? AppColors.greenDark : AppColors.green;
    final loginOrange = isDark ? const Color(0xFFFB923C) : AppColors.orange;
    final loginWhite = isDark ? AppColors.darkSurface : Colors.white;
    final loginSurface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final loginBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final loginText = isDark ? AppColors.darkText : AppColors.lightText;
    final loginMuted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppBackground(isDark: isDark, overlay: false),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: loginWhite,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 50,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo + Title
                        Image.asset('assets/images/logo-512.png', width: 118),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.02,
                              color: loginGreen,
                            ),
                            children: [
                              const TextSpan(text: 'Nutr'),
                              TextSpan(
                                text: 'IA',
                                style: TextStyle(color: loginOrange),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A escolha inteligente para o seu prato',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: loginMuted,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Segmented Tabs
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: loginSurface2,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _segmentedTab(
                                  'Entrar',
                                  !_isRegister,
                                  loginGreen,
                                  loginMuted,
                                  loginWhite,
                                  auth.isLoading || _googleLoading
                                      ? null
                                      : () => _setMode(false),
                                ),
                              ),
                              Expanded(
                                child: _segmentedTab(
                                  'Cadastrar',
                                  _isRegister,
                                  loginGreen,
                                  loginMuted,
                                  loginWhite,
                                  auth.isLoading || _googleLoading
                                      ? null
                                      : () => _setMode(true),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Flash error
                        if (auth.error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSoftLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 17),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    auth.error!,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.danger,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isRegister) ...[
                                _buildField(
                                  controller: _nameCtrl,
                                  hint: 'Seu nome',
                                  prefix: Icons.person_outline,
                                  loginBorder: loginBorder,
                                  loginText: loginText,
                                  loginMuted: loginMuted,
                                  loginGreen: loginGreen,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                                  autofill: const [AutofillHints.name],
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _buildField(
                                controller: _emailCtrl,
                                hint: 'Seu email',
                                prefix: Icons.mail_outline,
                                loginBorder: loginBorder,
                                loginText: loginText,
                                loginMuted: loginMuted,
                                loginGreen: loginGreen,
                                keyboard: TextInputType.emailAddress,
                                validator: _validateEmail,
                                autofocus: !_isRegister,
                                autofill: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                              ),
                              const SizedBox(height: 12),
                              _buildField(
                                controller: _passCtrl,
                                hint: 'Sua senha',
                                prefix: Icons.lock_outline,
                                loginBorder: loginBorder,
                                loginText: loginText,
                                loginMuted: loginMuted,
                                loginGreen: loginGreen,
                                obscure: _obscure,
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscure = !_obscure),
                                  child: Icon(
                                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: loginMuted,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 6)
                                    ? 'A senha deve ter pelo menos 6 caracteres'
                                    : null,
                                autofill: _isRegister
                                    ? const [AutofillHints.newPassword]
                                    : const [AutofillHints.password],
                                textInputAction: _isRegister ? TextInputAction.next : TextInputAction.done,
                                onSubmitted: (_) {
                                  if (_isRegister) {
                                    FocusScope.of(context).nextFocus();
                                  } else {
                                    _submit();
                                  }
                                },
                              ),
                              if (_isRegister) ...[
                                const SizedBox(height: 12),
                                _buildField(
                                  controller: _confirmCtrl,
                                  hint: 'Confirmar senha',
                                  prefix: Icons.lock_outline,
                                  loginBorder: loginBorder,
                                  loginText: loginText,
                                  loginMuted: loginMuted,
                                  loginGreen: loginGreen,
                                  obscure: true,
                                  validator: (v) =>
                                      (v != _passCtrl.text) ? 'As senhas não coincidem' : null,
                                  autofill: const [AutofillHints.newPassword],
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (auth.isLoading || _googleLoading) ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: loginGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Text(
                                    _isRegister ? 'Criar conta' : 'Entrar',
                                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),

                        // Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Row(
                            children: [
                              Expanded(child: Container(height: 1, color: loginBorder)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('ou', style: GoogleFonts.poppins(fontSize: 12, color: loginMuted)),
                              ),
                              Expanded(child: Container(height: 1, color: loginBorder)),
                            ],
                          ),
                        ),

                        // Google button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: (auth.isLoading || _googleLoading) ? null : _googleSignIn,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: loginWhite,
                              foregroundColor: loginText,
                              side: BorderSide(color: loginBorder, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: _googleLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 19,
                                        height: 19,
                                        child: CustomPaint(
                                          painter: _GoogleLogoPainter(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Continuar com Google',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentedTab(String label, bool active, Color green, Color muted, Color white, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? green : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active
              ? [BoxShadow(color: green.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? white : muted,
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Informe seu email';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
    return valid ? null : 'Informe um email válido';
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData prefix,
    required Color loginBorder,
    required Color loginText,
    required Color loginMuted,
    required Color loginGreen,
    String? Function(String?)? validator,
    bool obscure = false,
    TextInputType? keyboard,
    Widget? suffix,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    List<String>? autofill,
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofocus: autofocus,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: autofill,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 15, color: loginText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: loginMuted),
        prefixIcon: Icon(prefix, color: loginMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: loginBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: loginBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: loginGreen, width: 1.5),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w / 2;

    final red = Paint()..color = const Color(0xFFEA4335);
    final blue = Paint()..color = const Color(0xFF4285F4);
    final green = Paint()..color = const Color(0xFF34A853);
    final yellow = Paint()..color = const Color(0xFFFBBC05);

    // Simplified Google "G" shape
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r),
      -90 * 3.14159 / 180,
      90 * 3.14159 / 180,
      false,
      red,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r),
      0,
      90 * 3.14159 / 180,
      false,
      green,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r),
      90 * 3.14159 / 180,
      90 * 3.14159 / 180,
      false,
      yellow,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r),
      180 * 3.14159 / 180,
      90 * 3.14159 / 180,
      false,
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
