import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDark;

  const SplashScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  Color get _bg       => widget.isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8);
  Color get _accent   => widget.isDark ? const Color(0xFF00E5FF) : const Color(0xFF0077B6);
  Color get _accentDim=> widget.isDark ? const Color(0xFF00B8CC) : const Color(0xFF005F99);
  Color get _textMain => widget.isDark ? Colors.white            : const Color(0xFF0D1B2A);
  Color get _textSub  => widget.isDark ? const Color(0xFF6B7A8D) : const Color(0xFF7A8A9A);

  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;
  late Animation<double>   _logoScale, _logoFade, _textFade, _pulse;
  late Animation<Offset>   _textSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);
    _logoFade  = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);

    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textFade  = CurvedAnimation(parent: _textController, curve: Curves.easeIn);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textController.forward();
    });

    // Navigate after splash
    Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      // Check if already logged in
      if (SupabaseService.isLoggedIn) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => HomeScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
        ));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => LoginScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
        ));
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        _buildBackground(),
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            _accent.withOpacity(0.2 * _pulse.value), Colors.transparent])),
                      child: child),
                  child: Center(child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [_accent, _accentDim],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(color: _accent.withOpacity(0.35),
                              blurRadius: 24, spreadRadius: 4)]),
                      child: Icon(Icons.shield_rounded,
                          color: widget.isDark ? const Color(0xFF0A0E1A) : Colors.white, size: 40))),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Column(children: [
                  Text("ScamShield", style: TextStyle(color: _textMain,
                      fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text("Verify  ·  Trust  ·  Stay Safe",
                      style: TextStyle(color: _accent.withOpacity(0.7),
                          fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(height: 60),
            FadeTransition(opacity: _textFade, child: _LoadingDots(color: _accent)),
          ]),
        ),
        Positioned(bottom: 40, left: 0, right: 0,
            child: FadeTransition(opacity: _textFade,
                child: Text("AI-Powered Protection", textAlign: TextAlign.center,
                    style: TextStyle(color: _textSub.withOpacity(0.5),
                        fontSize: 12, letterSpacing: 1.0)))),
      ]),
    );
  }

  Widget _buildBackground() {
    return Stack(children: [
      Container(color: _bg),
      Positioned(top: -100, right: -80,
          child: Container(width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_accent.withOpacity(0.08), Colors.transparent])))),
      Positioned(bottom: -80, left: -80,
          child: Container(width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF4A00E0).withOpacity(0.08), Colors.transparent])))),
    ]);
  }
}

class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500)));
    _anims = _controllers.map((c) =>
        Tween<double>(begin: 0.3, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6, height: 6,
              decoration: BoxDecoration(
                  color: widget.color.withOpacity(_anims[i].value),
                  shape: BoxShape.circle)),
        )));
  }
}