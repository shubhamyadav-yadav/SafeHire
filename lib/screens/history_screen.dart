import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class HistoryScreen extends StatefulWidget {
  final bool isDark;
  const HistoryScreen({required this.isDark, Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // ─── Theme ───────────────────────────────────────────────────────
  Color get _bg       => widget.isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8);
  Color get _cardBg   => widget.isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get _border   => widget.isDark ? const Color(0xFF1E2D3D) : const Color(0xFFDDE3EA);
  Color get _textMain => widget.isDark ? Colors.white            : const Color(0xFF0D1B2A);
  Color get _textSub  => widget.isDark ? const Color(0xFF6B7A8D) : const Color(0xFF7A8A9A);
  Color get _accent   => widget.isDark ? const Color(0xFF00E5FF) : const Color(0xFF0077B6);

  static const _red    = Color(0xFFFF3B5C);
  static const _orange = Color(0xFFFF9800);
  static const _green  = Color(0xFF00C853);

  // ─── State ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _selectedFilter = "All";

  final List<String> _filters = ["All", "URL Checker", "Email Analyzer", "Job Analyzer", "APK Analyzer", "Screenshot"];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await SupabaseService.getHistory();
    if (mounted) {
      setState(() {
        _history  = data;
        _filtered = data;
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == "All") {
        _filtered = _history;
      } else {
        _filtered = _history.where((e) => e['scan_type'] == filter).toList();
      }
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Clear History", style: TextStyle(color: _textMain, fontWeight: FontWeight.w700)),
        content: Text("Are you sure? This will delete all your scan history.",
            style: TextStyle(color: _textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: _textSub))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete All", style: TextStyle(color: Color(0xFFFF3B5C),
                  fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteHistory();
      _loadHistory();
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case "danger":  return _red;
      case "warning": return _orange;
      case "safe":    return _green;
      default:        return _accent;
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case "danger":  return Icons.dangerous_rounded;
      case "warning": return Icons.warning_amber_rounded;
      case "safe":    return Icons.verified_rounded;
      default:        return Icons.info_outline_rounded;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case "URL Checker":    return Icons.link_rounded;
      case "Email Analyzer": return Icons.mark_email_unread_rounded;
      case "APK Analyzer":   return Icons.android_rounded;
      case "Job Analyzer":   return Icons.work_outline_rounded;
      case "Screenshot":     return Icons.auto_awesome_rounded;
      default:               return Icons.search_rounded;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    } catch (_) { return ""; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        Container(color: _bg),
        SafeArea(
          child: Column(children: [
            // ── AppBar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: _cardBg,
                          borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: _textMain, size: 14)),
                ),
                const SizedBox(width: 4),
                Text("Scan History", style: TextStyle(color: _textMain,
                    fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_history.isNotEmpty)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _red.withOpacity(0.3))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B5C), size: 14),
                        SizedBox(width: 4),
                        Text("Clear All", style: TextStyle(color: Color(0xFFFF3B5C),
                            fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Filter chips ──
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = _filters[i];
                  final selected = f == _selectedFilter;
                  return GestureDetector(
                    onTap: () => _applyFilter(f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: selected ? _accent : _cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? _accent : _border)),
                      child: Text(f, style: TextStyle(
                          color: selected
                              ? (widget.isDark ? const Color(0xFF0A0E1A) : Colors.white)
                              : _textSub,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ── Content ──
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
                  : _filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                color: _accent,
                backgroundColor: _cardBg,
                onRefresh: _loadHistory,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildCard(_filtered[i]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history_rounded, color: _textSub, size: 52),
        const SizedBox(height: 16),
        Text("No scan history yet", style: TextStyle(color: _textMain,
            fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text("Your scans will appear here", style: TextStyle(color: _textSub, fontSize: 13)),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final level   = item['level']       as String? ?? "info";
    final type    = item['scan_type']   as String? ?? "Unknown";
    final score   = item['score']       as int?    ?? 0;
    final reason  = item['reason']      as String? ?? "";
    final input   = item['input_content'] as String? ?? "";
    final date    = _formatDate(item['created_at'] as String?);
    final color   = _levelColor(level);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card header ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17))),
          child: Row(children: [
            Container(width: 34, height: 34,
                decoration: BoxDecoration(color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(_typeIcon(type), color: color, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type, style: TextStyle(color: _textMain,
                  fontWeight: FontWeight.w700, fontSize: 13)),
              Text(date, style: TextStyle(color: _textSub, fontSize: 11)),
            ])),
            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_levelIcon(level), color: color, size: 12),
                const SizedBox(width: 4),
                Text("$score/100", style: TextStyle(color: color,
                    fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),

        // ── Card body ──
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Input preview
            if (input.isNotEmpty) ...[
              Text("Input", style: TextStyle(color: _textSub,
                  fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                input.length > 100 ? "${input.substring(0, 100)}..." : input,
                style: TextStyle(color: _textMain, fontSize: 12, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
            ],

            // Risk bar
            Row(children: [
              Text("Risk", style: TextStyle(color: _textSub, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100, minHeight: 5,
                  backgroundColor: _border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )),
              const SizedBox(width: 8),
              Text("$score%", style: TextStyle(color: color,
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ]),

            // Reason
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border)),
                child: Text(
                  reason.length > 150 ? "${reason.substring(0, 150)}..." : reason,
                  style: TextStyle(color: _textSub, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}