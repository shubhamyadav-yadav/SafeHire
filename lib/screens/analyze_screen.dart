import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../analyzers/apk_analyzer.dart';
import '../analyzers/email_analyzer.dart';
import '../analyzers/job_analyzer.dart';
import '../analyzers/url_checker.dart';
import '../services/stats_service.dart';
import '../services/supabase_service.dart';

class AnalyzeScreen extends StatefulWidget {
  final String type;
  const AnalyzeScreen({required this.type, Key? key}) : super(key: key);

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> with TickerProviderStateMixin {

  // ─── Theme ────────────────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg       => _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8);
  Color get _cardBg   => _isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get _border   => _isDark ? const Color(0xFF1E2D3D) : const Color(0xFFDDE3EA);
  Color get _textMain => _isDark ? Colors.white            : const Color(0xFF0D1B2A);
  Color get _textSub  => _isDark ? const Color(0xFF6B7A8D) : const Color(0xFF7A8A9A);

  static const Color _red    = Color(0xFFFF3B5C);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _green  = Color(0xFF00C853);

  Color get _accentColor {
    switch (widget.type) {
      case "URL Checker":    return _isDark ? const Color(0xFF00E5FF) : const Color(0xFF0077B6);
      case "Email Analyzer": return const Color(0xFFFF6B35);
      case "APK Analyzer":   return _green;
      case "Job Analyzer":   return const Color(0xFFB388FF);
      default:               return _isDark ? const Color(0xFF00E5FF) : const Color(0xFF0077B6);
    }
  }

  IconData get _screenIcon {
    switch (widget.type) {
      case "URL Checker":    return Icons.link_rounded;
      case "Email Analyzer": return Icons.mark_email_unread_rounded;
      case "APK Analyzer":   return Icons.android_rounded;
      case "Job Analyzer":   return Icons.work_outline_rounded;
      default:               return Icons.search_rounded;
    }
  }

  String get _hintText {
    switch (widget.type) {
      case "URL Checker":    return "Paste a URL (e.g. https://example.com)";
      case "Email Analyzer": return "Paste the full email content here...";
      case "Job Analyzer":   return "Paste the job description here...";
      default:               return "Paste content here...";
    }
  }

  // ─── State ────────────────────────────────────────────────────────
  final TextEditingController _controller = TextEditingController();
  String _output   = "";
  String _level    = "none";
  int    _score    = 0;
  bool   _isLoading = false;
  bool   _isAI     = false;

  late AnimationController _resultAnim;
  late Animation<double>   _resultScale;
  late Animation<double>   _resultFade;

  @override
  void initState() {
    super.initState();
    _resultAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _resultScale = CurvedAnimation(parent: _resultAnim, curve: Curves.elasticOut);
    _resultFade  = CurvedAnimation(parent: _resultAnim, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _resultAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ─── Analyze ──────────────────────────────────────────────────────
  Future<void> _analyze() async {
    final input = _controller.text.trim();
    if (input.isEmpty) { _showSnack("Please enter content first"); return; }

    setState(() { _isLoading = true; _output = ""; _level = "none"; _score = 0; });
    _resultAnim.reset();

    Map<String, dynamic> result = {};

    if (widget.type == "URL Checker") {
      result = await URLChecker.checkDetailed(input);
      _isAI  = false;
    } else if (widget.type == "Email Analyzer") {
      result = await EmailAnalyzer.checkDetailed(input);
      _isAI  = true;
    } else if (widget.type == "Job Analyzer") {
      result = await JobAnalyzer.checkDetailed(input);
      _isAI  = true;
    } else {
      result = {"message": "Use APK picker below", "level": "info", "score": 0};
    }

    final level   = result["level"]   as String? ?? "info";
    final message = result["message"] as String? ?? "";
    final score   = result["score"]   as int?    ?? 0;

    // ── Save to Supabase ──
    await SupabaseService.saveScan(
      scanType:     widget.type,
      inputContent: input,
      result:       level,
      level:        level,
      score:        score,
      reason:       message,
    );

    await StatsService.incrementScan(level == "danger" || level == "warning");

    if (mounted) {
      setState(() {
        _isLoading = false;
        _output    = message;
        _level     = level;
        _score     = score;
      });
      _resultAnim.forward();
    }
  }

  Future<void> _pickAPK() async {
    setState(() { _isLoading = true; _output = ""; _level = "none"; _score = 0; });
    _resultAnim.reset();

    final picked = await FilePicker.platform.pickFiles();
    if (picked != null) {
      final file   = File(picked.files.single.path!);
      final result = await APKAnalyzer.analyzeDetailed(file);
      final level  = result["level"]   as String? ?? "info";
      final message= result["message"] as String? ?? "";
      final score  = result["score"]   as int?    ?? 0;

      // ── Save to Supabase ──
      await SupabaseService.saveScan(
        scanType:     "APK Analyzer",
        inputContent: picked.files.single.name,
        result:       level,
        level:        level,
        score:        score,
        reason:       message,
      );

      await StatsService.incrementScan(level == "danger" || level == "warning");

      if (mounted) {
        setState(() {
          _isLoading = false;
          _output    = message;
          _level     = level;
          _score     = score;
          _isAI      = false;
        });
        _resultAnim.forward();
      }
    } else {
      setState(() { _isLoading = false; });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF111827),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Level helpers ────────────────────────────────────────────────
  Color get _levelColor {
    switch (_level) {
      case "danger":  return _red;
      case "warning": return _orange;
      case "safe":    return _green;
      default:        return _accentColor;
    }
  }

  IconData get _levelIcon {
    switch (_level) {
      case "danger":  return Icons.dangerous_rounded;
      case "warning": return Icons.warning_amber_rounded;
      case "safe":    return Icons.verified_rounded;
      default:        return Icons.info_outline_rounded;
    }
  }

  String get _levelLabel {
    switch (_level) {
      case "danger":  return "HIGH RISK";
      case "warning": return "SUSPICIOUS";
      case "safe":    return "SAFE";
      default:        return "RESULT";
    }
  }

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        _buildBackground(),
        SafeArea(child: Column(children: [
          _buildAppBar(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              _buildTitle(),
              const SizedBox(height: 24),
              widget.type == "APK Analyzer" ? _buildAPKZone() : _buildInputCard(),
              const SizedBox(height: 16),
              if (widget.type != "APK Analyzer") _buildAnalyzeBtn(),
              const SizedBox(height: 28),
              if (_isLoading) _buildLoadingCard(),
              if (_output.isNotEmpty && !_isLoading) _buildResultCard(),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _buildBackground() {
    return Stack(children: [
      Container(color: _bg),
      Positioned(top: -60, right: -40,
          child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accentColor.withOpacity(_isDark ? 0.1 : 0.06), Colors.transparent])))),
    ]);
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _cardBg,
                  borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: _textMain, size: 14)),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withOpacity(0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_screenIcon, color: _accentColor, size: 14),
            const SizedBox(width: 6),
            Text(widget.type, style: TextStyle(color: _accentColor, fontSize: 12,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTitle() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.type, style: TextStyle(color: _textMain, fontSize: 26,
          fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Row(children: [
        Icon(Icons.auto_awesome_rounded, color: _accentColor, size: 13),
        const SizedBox(width: 4),
        Text("AI-powered + rule-based analysis",
            style: TextStyle(color: _textSub, fontSize: 13)),
      ]),
    ]);
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Icon(_screenIcon, color: _accentColor, size: 16),
            const SizedBox(width: 8),
            Text("Input", style: TextStyle(color: _accentColor, fontSize: 12,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ]),
        ),
        TextField(
          controller: _controller,
          maxLines: widget.type == "URL Checker" ? 2 : 7,
          style: TextStyle(color: _textMain, fontSize: 14, height: 1.5),
          cursorColor: _accentColor,
          decoration: InputDecoration(
            hintText: _hintText,
            hintStyle: TextStyle(color: _textSub, fontSize: 14),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            border: InputBorder.none,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: _border))),
          child: Row(children: [
            Icon(Icons.lock_outline_rounded, color: _textSub, size: 13),
            const SizedBox(width: 5),
            Text("Not stored or shared", style: TextStyle(color: _textSub, fontSize: 11)),
            const Spacer(),
            GestureDetector(
              onTap: () => _controller.clear(),
              child: Text("Clear", style: TextStyle(color: _accentColor, fontSize: 12,
                  fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAPKZone() {
    return GestureDetector(
      onTap: _pickAPK,
      child: Container(height: 180,
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _green.withOpacity(0.4), width: 1.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 60, height: 60,
              decoration: BoxDecoration(color: _green.withOpacity(0.1), shape: BoxShape.circle,
                  border: Border.all(color: _green.withOpacity(0.3))),
              child: const Icon(Icons.upload_file_rounded, color: _green, size: 28)),
          const SizedBox(height: 14),
          Text("Tap to select APK file",
              style: TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text("Analyzes permissions & security risks",
              style: TextStyle(color: _textSub, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildAnalyzeBtn() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _analyze,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: _isDark ? const Color(0xFF0A0E1A) : Colors.white,
          disabledBackgroundColor: _accentColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_screenIcon, size: 18),
          const SizedBox(width: 8),
          const Text("Run Analysis", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border)),
      child: Column(children: [
        SizedBox(width: 40, height: 40,
            child: CircularProgressIndicator(color: _accentColor, strokeWidth: 2.5)),
        const SizedBox(height: 16),
        Text("Analyzing...", style: TextStyle(color: _textMain,
            fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        Text(_isAI ? "AI is scanning for threats..." : "Checking against threat database...",
            style: TextStyle(color: _textSub, fontSize: 12)),
      ]),
    );
  }

  Widget _buildResultCard() {
    return ScaleTransition(
      scale: _resultScale,
      child: FadeTransition(
        opacity: _resultFade,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _levelColor.withOpacity(0.4), width: 1.5)),
          child: Column(children: [
            // Header
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: _levelColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_levelIcon, color: _levelColor, size: 20),
                const SizedBox(width: 8),
                Text(_levelLabel, style: TextStyle(color: _levelColor,
                    fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)),
                if (_isAI) ...[
                  const SizedBox(width: 10),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text("AI", style: TextStyle(color: _accentColor,
                          fontSize: 10, fontWeight: FontWeight.w700))),
                ],
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Score ring
                Stack(alignment: Alignment.center, children: [
                  SizedBox(width: 90, height: 90,
                      child: CircularProgressIndicator(
                          value: _score / 100, strokeWidth: 6,
                          backgroundColor: _border,
                          valueColor: AlwaysStoppedAnimation<Color>(_levelColor))),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text("$_score", style: TextStyle(color: _levelColor,
                        fontSize: 22, fontWeight: FontWeight.w800)),
                    Text("/100", style: TextStyle(color: _textSub, fontSize: 10)),
                  ]),
                ]),
                const SizedBox(height: 20),

                // Result text
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                  child: Text(
                      _output.replaceAll("🚨","").replaceAll("✅","")
                          .replaceAll("⚠️","").replaceAll("❌","").trim(),
                      style: TextStyle(color: _textMain, fontSize: 13, height: 1.6)),
                ),

                const SizedBox(height: 20),

                // Risk bar
                if (_level != "info") ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("Risk Score", style: TextStyle(color: _textSub, fontSize: 12)),
                    Text("$_score / 100", style: TextStyle(color: _levelColor,
                        fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: _score / 100, minHeight: 6,
                          backgroundColor: _border,
                          valueColor: AlwaysStoppedAnimation<Color>(_levelColor))),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text("Safe", style: TextStyle(color: _green, fontSize: 10)),
                    const Spacer(),
                    Text("Danger", style: TextStyle(color: _red, fontSize: 10)),
                  ]),
                  const SizedBox(height: 16),
                ],

                // Saved indicator
                if (SupabaseService.isLoggedIn)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.cloud_done_rounded, color: _textSub, size: 13),
                    const SizedBox(width: 4),
                    Text("Saved to your history",
                        style: TextStyle(color: _textSub, fontSize: 11)),
                  ]),

                const SizedBox(height: 16),

                // Buttons
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => setState(() {
                      _output = ""; _level = "none"; _score = 0; _controller.clear();
                    }),
                    style: OutlinedButton.styleFrom(foregroundColor: _textSub,
                        side: BorderSide(color: _border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text("Clear"),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: widget.type == "APK Analyzer" ? _pickAPK : _analyze,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: _isDark ? const Color(0xFF0A0E1A) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0),
                    child: const Text("Re-scan",
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}