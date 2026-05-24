import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDark;
  const LoginScreen({required this.toggleTheme, required this.isDark, Key? key})
      : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // ─── Theme ───────────────────────────────────────────────────────
  Color get _bg       => widget.isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8);
  Color get _cardBg   => widget.isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get _border   => widget.isDark ? const Color(0xFF1E2D3D) : const Color(0xFFDDE3EA);
  Color get _textMain => widget.isDark ? Colors.white            : const Color(0xFF0D1B2A);
  Color get _textSub  => widget.isDark ? const Color(0xFF6B7A8D) : const Color(0xFF7A8A9A);
  Color get _accent   => widget.isDark ? const Color(0xFF00E5FF) : const Color(0xFF0077B6);

  // ─── State ───────────────────────────────────────────────────────
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin       = true;
  bool _isLoading     = false;
  bool _obscure       = true;
  String _error       = "";

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Auth ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = "Please fill in all fields");
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = "Please enter a valid email");
      return;
    }
    if (password.length < 6) {
      setState(() => _error = "Password must be at least 6 characters");
      return;
    }

    setState(() { _isLoading = true; _error = ""; });

    try {
      if (_isLogin) {
        await SupabaseService.signIn(email, password);
      } else {
        await SupabaseService.signUp(email, password);
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => HomeScreen(
            toggleTheme: widget.toggleTheme,
            isDark: widget.isDark,
          ),
        ));
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = "Something went wrong. Try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        _buildBackground(),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Logo
                Row(children: [
                  Container(width: 42, height: 42,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                              colors: [_accent, _accent.withOpacity(0.7)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      child: Icon(Icons.shield_rounded,
                          color: widget.isDark ? const Color(0xFF0A0E1A) : Colors.white, size: 22)),
                  const SizedBox(width: 10),
                  Text("ScamShield", style: TextStyle(color: _textMain,
                      fontSize: 20, fontWeight: FontWeight.w800)),
                ]),

                const SizedBox(height: 48),

                // Title
                Text(_isLogin ? "Welcome Back" : "Create Account",
                    style: TextStyle(color: _textMain, fontSize: 28,
                        fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(_isLogin
                    ? "Sign in to access your scan history"
                    : "Sign up to save your scan history",
                    style: TextStyle(color: _textSub, fontSize: 14)),

                const SizedBox(height: 36),

                // Email field
                _buildField(
                  controller: _emailCtrl,
                  hint: "Email address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                // Password field
                _buildField(
                  controller: _passwordCtrl,
                  hint: "Password",
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: _textSub, size: 18),
                  ),
                ),

                const SizedBox(height: 8),

                // Error
                if (_error.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF3B5C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF3B5C).withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3B5C), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error,
                          style: const TextStyle(color: Color(0xFFFF3B5C), fontSize: 13))),
                    ]),
                  ),

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: widget.isDark ? const Color(0xFF0A0E1A) : Colors.white,
                      disabledBackgroundColor: _accent.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: widget.isDark ? const Color(0xFF0A0E1A) : Colors.white))
                        : Text(_isLogin ? "Sign In" : "Create Account",
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 20),

                // Toggle login/signup
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() { _isLogin = !_isLogin; _error = ""; }),
                    child: RichText(
                      text: TextSpan(
                        text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: TextStyle(color: _textSub, fontSize: 14),
                        children: [
                          TextSpan(
                            text: _isLogin ? "Sign Up" : "Sign In",
                            style: TextStyle(color: _accent, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Skip login (guest mode)
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (_) => HomeScreen(
                        toggleTheme: widget.toggleTheme,
                        isDark: widget.isDark,
                      ),
                    )),
                    child: Text("Continue as Guest",
                        style: TextStyle(color: _textSub, fontSize: 13,
                            decoration: TextDecoration.underline)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(color: _textMain, fontSize: 15),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _textSub),
          prefixIcon: Icon(icon, color: _textSub, size: 20),
          suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(children: [
      Container(color: _bg),
      Positioned(top: -80, right: -60,
          child: Container(width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_accent.withOpacity(0.08), Colors.transparent])))),
      Positioned(bottom: 0, left: -80,
          child: Container(width: 220, height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [const Color(0xFF7C3AED).withOpacity(0.06), Colors.transparent])))),
    ]);
  }
}