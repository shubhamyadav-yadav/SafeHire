import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/stats_service.dart';
import '../services/supabase_service.dart';
import '../widgets/stats_chart.dart';
import '../analyzers/screenshot_analyzer.dart';
import 'analyze_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDark;
  const HomeScreen({required this.toggleTheme, required this.isDark, Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Color get _bg       => widget.isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8);
  Color get _cardBg   => widget.isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get _border   => widget.isDark ? const Color(0xFF1E2D3D) : const Color(0xFFDDE3EA);
  Color get _textMain => widget.isDark ? Colors.white            : const Color(0xFF0D1B2A);
  Color get _textSub  => widget.isDark ? const Color(0xFF6B7A8D) : const Color(0xFF7A8A9A);
  Color get _accent   => widget.isDark ? const Color(0xFF00E5FF) : const Color(0xFF0077B6);
  Color get _red      => const Color(0xFFFF3B5C);
  Color get _green    => const Color(0xFF00C853);

  List<Map<String, dynamic>> get features => [
    {"title": "URL Checker",    "subtitle": "Detect malicious links",  "icon": Icons.link_rounded,              "color": _accent,                     "bgColor": _accent.withOpacity(0.12)},
    {"title": "Email Analyzer", "subtitle": "Phishing detection",      "icon": Icons.mark_email_unread_rounded, "color": const Color(0xFFFF6B35),      "bgColor": const Color(0xFFFF6B35).withOpacity(0.12)},
    {"title": "APK Analyzer",   "subtitle": "Scan APK files",          "icon": Icons.android_rounded,           "color": _green,                      "bgColor": _green.withOpacity(0.12)},
    {"title": "Job Analyzer",   "subtitle": "Spot fake job offers",    "icon": Icons.work_outline_rounded,      "color": const Color(0xFFB388FF),      "bgColor": const Color(0xFFB388FF).withOpacity(0.12)},
  ];

  Map<String, int> stats = {"scans": 0, "threats": 0, "safe": 0};
  late List<AnimationController> _cardControllers;
  late AnimationController _headerController;
  late AnimationController _fabPulse;
  late Animation<double> _headerFade;
  late Animation<double> _fabAnim;

  @override
  void initState() {
    super.initState();
    _loadStats();

    _headerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerController.forward();

    _cardControllers = List.generate(4, (i) => AnimationController(
        vsync: this, duration: Duration(milliseconds: 400 + i * 80)));
    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: 300 + i * 100), () {
        if (mounted) _cardControllers[i].forward();
      });
    }

    _fabPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _fabAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _fabPulse, curve: Curves.easeInOut));
  }

  Future<void> _loadStats() async {
    Map<String, int> s;
    // Load from Supabase if logged in, else local
    if (SupabaseService.isLoggedIn) {
      s = await SupabaseService.getCloudStats();
    } else {
      s = await StatsService.getStats();
    }
    if (mounted) setState(() => stats = s);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Logout", style: TextStyle(color: _textMain, fontWeight: FontWeight.w700)),
        content: Text("Are you sure you want to logout?",
            style: TextStyle(color: _textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: _textSub))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text("Logout", style: TextStyle(color: Color(0xFFFF3B5C),
                  fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => LoginScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark)));
      }
    }
  }

  void _openAIScan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AIScanSheet(isDark: widget.isDark, onScanComplete: _loadStats),
    );
  }

  @override
  void dispose() {
    _headerController.dispose();
    _fabPulse.dispose();
    for (final c in _cardControllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnim,
        builder: (_, child) => Transform.scale(scale: _fabAnim.value, child: child),
        child: GestureDetector(
          onTap: _openAIScan,
          child: Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.5),
                    blurRadius: 20, spreadRadius: 2)]),
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              SizedBox(height: 2),
              Text("AI", style: TextStyle(color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),

      body: Stack(children: [
        _buildBackground(),
        SafeArea(child: Column(children: [
          _buildAppBar(),
          Expanded(child: RefreshIndicator(
            color: _accent,
            backgroundColor: _cardBg,
            onRefresh: _loadStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildHeroSection(),
                const SizedBox(height: 24),
                _buildStatsRow(),
                const SizedBox(height: 28),
                _buildSectionLabel("Detection Tools"),
                const SizedBox(height: 14),
                _buildFeatureGrid(),
                const SizedBox(height: 28),
                _buildSectionLabel("Threat Overview"),
                const SizedBox(height: 14),
                _buildChartCard(),
                const SizedBox(height: 20),
              ]),
            ),
          )),
        ])),
      ]),
    );
  }

  Widget _buildBackground() {
    return Stack(children: [
      Container(color: _bg),
      Positioned(top: -80, right: -60, child: Container(width: 260, height: 260,
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_accent.withOpacity(0.10), Colors.transparent])))),
      Positioned(bottom: 100, left: -80, child: Container(width: 220, height: 220,
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_red.withOpacity(0.06), Colors.transparent])))),
    ]);
  }

  Widget _buildAppBar() {
    final isLoggedIn = SupabaseService.isLoggedIn;
    final email      = SupabaseService.userEmail;
    final username   = email.isNotEmpty ? email.split('@')[0] : "Guest";

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(colors: [_accent, _accent.withOpacity(0.7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Icon(Icons.shield_rounded,
                color: widget.isDark ? const Color(0xFF0A0E1A) : Colors.white, size: 20)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("ScamShield", style: TextStyle(color: _textMain, fontSize: 16,
              fontWeight: FontWeight.w800)),
          if (isLoggedIn)
            Text("Hi, $username 👋", style: TextStyle(color: _textSub, fontSize: 11)),
        ]),
        const Spacer(),

        // AI Scan button
        GestureDetector(
          onTap: _openAIScan,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Text("AI Scan", style: TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(width: 6),

        // History button (only if logged in)
        if (isLoggedIn)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => HistoryScreen(isDark: widget.isDark)))
                .then((_) => _loadStats()),
            child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border)),
                child: Icon(Icons.history_rounded, color: _textSub, size: 18)),
          ),
        const SizedBox(width: 6),

        // Theme toggle
        GestureDetector(
          onTap: () => widget.toggleTheme(),
          child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border)),
              child: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: _textSub, size: 18)),
        ),
        const SizedBox(width: 6),

        // Logout / Login icon
        GestureDetector(
          onTap: isLoggedIn ? _logout : () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => LoginScreen(
                  toggleTheme: widget.toggleTheme, isDark: widget.isDark))),
          child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border)),
              child: Icon(isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                  color: isLoggedIn ? _red : _accent, size: 18)),
        ),
      ]),
    );
  }

  Widget _buildHeroSection() {
    return FadeTransition(
      opacity: _headerFade,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: _cardBg,
            border: Border.all(color: _accent.withOpacity(0.2))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _green.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: _green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text("AI Shield Active", style: TextStyle(color: _green, fontSize: 11,
                    fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 12),
            Text("Stay Protected\nFrom Scams", style: TextStyle(color: _textMain,
                fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 8),
            Text("AI detection for URLs, emails,\nAPKs, jobs & screenshots.",
                style: TextStyle(color: _textSub, fontSize: 13, height: 1.5)),
          ])),
          const SizedBox(width: 16),
          Container(width: 72, height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _accent.withOpacity(0.1),
                  border: Border.all(color: _accent.withOpacity(0.3), width: 1.5)),
              child: Icon(Icons.security_rounded, color: _accent, size: 36)),
        ]),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(children: [
      _statCard("Total Scans", stats["scans"].toString(), Icons.bar_chart_rounded, _accent),
      const SizedBox(width: 12),
      _statCard("Threats", stats["threats"].toString(), Icons.warning_amber_rounded, _red),
      const SizedBox(width: 12),
      _statCard("Safe", stats["safe"].toString(), Icons.verified_rounded, _green),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: _textSub, fontSize: 10, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildFeatureGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.05),
      itemCount: features.length,
      itemBuilder: (context, i) {
        final f = features[i];
        return AnimatedBuilder(
          animation: _cardControllers[i],
          builder: (context, child) {
            final v = _cardControllers[i].value;
            return Opacity(opacity: v,
                child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child));
          },
          child: _FeatureCard(
            title: f["title"], subtitle: f["subtitle"],
            icon: f["icon"], color: f["color"], bgColor: f["bgColor"],
            cardBg: _cardBg, border: _border, textMain: _textMain, textSub: _textSub,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AnalyzeScreen(type: f["title"])))
                .then((_) => _loadStats()),
          ),
        );
      },
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text("Safe vs Threats", style: TextStyle(color: _textMain,
              fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          _legendDot(_green, "Safe"),
          const SizedBox(width: 12),
          _legendDot(_red, "Threat"),
        ]),
        const SizedBox(height: 16),
        // Import StatsChart
        Builder(builder: (_) {
          final safe     = stats["safe"]    ?? 0;
          final threats  = stats["threats"] ?? 0;
          if (safe == 0 && threats == 0) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text("No scans yet", style: TextStyle(color: _textSub, fontSize: 13)),
            ));
          }
          return SizedBox(height: 140,
            child: Row(children: [
              Expanded(flex: 5, child: Center(child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 110, height: 110,
                    child: CircularProgressIndicator(
                      value: threats / (safe + threats),
                      strokeWidth: 12,
                      backgroundColor: _green.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF3B5C)),
                    )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("${safe + threats}", style: TextStyle(color: _textMain,
                      fontWeight: FontWeight.w800, fontSize: 20)),
                  Text("Total", style: TextStyle(color: _textSub, fontSize: 10)),
                ]),
              ]))),
              Expanded(flex: 4, child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                _legendRow(_green, "Safe", safe, safe + threats),
                const SizedBox(height: 14),
                _legendRow(_red, "Threats", threats, safe + threats),
              ])),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _legendRow(Color color, String label, int value, int total) {
    final pct = total > 0 ? (value / total * 100).round() : 0;
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(color: _textSub, fontSize: 12))),
      Text("$value", style: TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(width: 4),
      Text("($pct%)", style: TextStyle(color: _textSub, fontSize: 10)),
    ]);
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: _textSub, fontSize: 11)),
    ]);
  }
}

// ─── Feature Card ─────────────────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color, bgColor, cardBg, border, textMain, textSub;
  final VoidCallback onTap;
  const _FeatureCard({required this.title, required this.subtitle, required this.icon,
    required this.color, required this.bgColor, required this.cardBg,
    required this.border, required this.textMain, required this.textSub, required this.onTap});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: widget.cardBg, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _pressed ? widget.color.withOpacity(0.5) : widget.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: widget.bgColor, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.color.withOpacity(0.3))),
                    child: Icon(widget.icon, color: widget.color, size: 22)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: TextStyle(color: widget.textMain,
                      fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(widget.subtitle, style: TextStyle(color: widget.textSub, fontSize: 11)),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ─── AI Scan Bottom Sheet ──────────────────────────────────────────────────────
class _AIScanSheet extends StatefulWidget {
  final bool isDark;
  final VoidCallback onScanComplete;
  const _AIScanSheet({required this.isDark, required this.onScanComplete});
  @override
  State<_AIScanSheet> createState() => _AIScanSheetState();
}

class _AIScanSheetState extends State<_AIScanSheet> {
  Color get _bg       => widget.isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get _cardBg   => widget.isDark ? const Color(0xFF1A2332) : const Color(0xFFF8FAFC);
  Color get _border   => widget.isDark ? const Color(0xFF1E2D3D) : const Color(0xFFDDE3EA);
  Color get _textMain => widget.isDark ? Colors.white            : const Color(0xFF0D1B2A);
  Color get _textSub  => widget.isDark ? const Color(0xFF6B7A8D) : const Color(0xFF7A8A9A);

  static const _purple = Color(0xFF7C3AED);
  static const _pink   = Color(0xFFDB2777);
  static const _red    = Color(0xFFFF3B5C);
  static const _orange = Color(0xFFFF9800);
  static const _green  = Color(0xFF00C853);

  File? _imageFile;
  bool  _isLoading = false;
  Map<String, dynamic>? _result;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() { _imageFile = File(picked.path); _result = null; });
      await _analyze();
    }
  }

  Future<void> _analyze() async {
    if (_imageFile == null) return;
    setState(() => _isLoading = true);
    final result  = await ScreenshotAnalyzer.analyze(_imageFile!);
    final verdict = result["verdict"] as String? ?? "info";
    final score   = result["score"]   as int?    ?? 0;
    final reason  = result["reason"]  as String? ?? "";

    // Save to Supabase
    await SupabaseService.saveScan(
      scanType:     "Screenshot",
      inputContent: "Screenshot uploaded",
      result:       verdict,
      level:        verdict,
      score:        score,
      reason:       reason,
    );

    await StatsService.incrementScan(verdict == "danger" || verdict == "suspicious");
    widget.onScanComplete();
    if (mounted) setState(() { _isLoading = false; _result = result; });
  }

  Color   _vc(String v) { switch(v){ case "danger": return _red; case "suspicious": return _orange; case "safe": return _green; default: return _purple; } }
  IconData _vi(String v) { switch(v){ case "danger": return Icons.dangerous_rounded; case "suspicious": return Icons.warning_amber_rounded; case "safe": return Icons.verified_rounded; default: return Icons.info_outline_rounded; } }
  String  _vl(String v) { switch(v){ case "danger": return "HIGH RISK"; case "suspicious": return "SUSPICIOUS"; case "safe": return "SAFE"; default: return "RESULT"; } }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 42, height: 42,
                decoration: const BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_purple, _pink])),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("AI Screenshot Scanner", style: TextStyle(color: _textMain,
                  fontWeight: FontWeight.w800, fontSize: 17)),
              Text("Upload any screenshot to detect scam",
                  style: TextStyle(color: _textSub, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 24),

          if (_imageFile == null) ...[
            Row(children: [
              Expanded(child: _uploadBtn(icon: Icons.photo_library_rounded, label: "Gallery",
                  onTap: () => _pickImage(ImageSource.gallery))),
              const SizedBox(width: 12),
              Expanded(child: _uploadBtn(icon: Icons.camera_alt_rounded, label: "Camera",
                  onTap: () => _pickImage(ImageSource.camera))),
            ]),
            const SizedBox(height: 16),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _purple.withOpacity(0.2))),
              child: Column(children: [
                const Icon(Icons.tips_and_updates_rounded, color: _purple, size: 22),
                const SizedBox(height: 8),
                Text("Works with any screenshot", style: TextStyle(color: _textMain,
                    fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text("SMS • WhatsApp • Email • Job Offer • URL • Social Media",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSub, fontSize: 11, height: 1.5)),
              ]),
            ),
          ] else ...[
            ClipRRect(borderRadius: BorderRadius.circular(16),
                child: Image.file(_imageFile!, width: double.infinity, height: 200, fit: BoxFit.cover)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.refresh_rounded, color: _purple, size: 14),
                SizedBox(width: 4),
                Text("Change image", style: TextStyle(color: _purple, fontSize: 12,
                    fontWeight: FontWeight.w600)),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          if (_isLoading)
            Container(width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border)),
                child: Column(children: [
                  const SizedBox(width: 36, height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(_purple))),
                  const SizedBox(height: 12),
                  Text("AI is analyzing screenshot...",
                      style: TextStyle(color: _textMain, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("Gemini Vision scanning for threats",
                      style: TextStyle(color: _textSub, fontSize: 12)),
                ])),

          if (_result != null && !_isLoading)
            _buildResultCard(_result!),
        ]),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final verdict  = r["verdict"]    as String? ?? "info";
    final score    = r["score"]      as int?    ?? 0;
    final type     = r["type"]       as String? ?? "Unknown";
    final reason   = r["reason"]     as String? ?? "";
    final redFlags = (r["red_flags"] as List?)?.map((e) => e.toString()).toList() ?? [];
    final color    = _vc(verdict);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
      child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_vi(verdict), color: color, size: 18),
              const SizedBox(width: 8),
              Text(_vl(verdict), style: TextStyle(color: color, fontWeight: FontWeight.w800,
                  fontSize: 13, letterSpacing: 1.2)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text("AI", style: TextStyle(color: _purple, fontSize: 10,
                      fontWeight: FontWeight.w700))),
            ])),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 64, height: 64, child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: score / 100, strokeWidth: 5,
                    backgroundColor: _border, valueColor: AlwaysStoppedAnimation<Color>(color)),
                Text("$score", style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
              ])),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Content Type", style: TextStyle(color: _textSub, fontSize: 11)),
                const SizedBox(height: 4),
                Text(type, style: TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 15)),
                Text("Risk: $score/100", style: TextStyle(color: color, fontSize: 12,
                    fontWeight: FontWeight.w600)),
              ])),
            ]),
            const SizedBox(height: 14),
            Container(width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                child: Text(reason, style: TextStyle(color: _textMain, fontSize: 13, height: 1.5))),
            if (redFlags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("Red Flags:", style: TextStyle(color: _textSub, fontSize: 12,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...redFlags.map((f) => Padding(padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.circle, color: _red, size: 6),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: TextStyle(color: _textMain, fontSize: 12, height: 1.4))),
                  ]))),
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                  label: const Text("Scan Another", style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _purple, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                )),
          ]),
        ),
      ]),
    );
  }

  Widget _uploadBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _purple.withOpacity(0.3))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 44, height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_purple, _pink])),
                child: Icon(icon, color: Colors.white, size: 20)),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(color: _textMain, fontWeight: FontWeight.w600, fontSize: 13)),
          ])),
    );
  }
}