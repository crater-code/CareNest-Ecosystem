import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:star_sitter_family/widgets/app_background.dart';

import 'create_dispute_screen.dart';

class FamilyDisputesScreen extends StatefulWidget {
  const FamilyDisputesScreen({super.key});

  @override
  State<FamilyDisputesScreen> createState() => _FamilyDisputesScreenState();
}

class _FamilyDisputesScreenState extends State<FamilyDisputesScreen> {
  late final SupabaseClient _client;
  Future<List<Map<String, dynamic>>>? _disputesFuture;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _refresh();
  }

  void _refresh() {
    setState(() {
      _disputesFuture = _fetchMyDisputes();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchMyDisputes() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    // We rely on RLS to filter disputes where the user is either the reporter 
    // or a party to the job (family_id = auth.uid()).
    final res = await _client
        .from('disputes')
        .select(
          'id, job_id, issue_type, description, priority, status, created_at',
        )
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  Widget _statusBadge(String? status) {
    final s = status ?? 'open';
    Color bg;
    switch (s) {
      case 'resolved':
        bg = const Color(0xFF10B981);
        break;
      case 'investigating':
        bg = const Color(0xFFF59E0B);
        break;
      default:
        bg = const Color(0xFFEF4444);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        s[0].toUpperCase() + s.substring(1),
        style: TextStyle(color: bg, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _previewDescription(String? description) {
    if (description == null || description.trim().isEmpty) {
      return 'No description available.';
    }
    final trimmed = description.trim().replaceAll('\n', ' ');
    return trimmed.length <= 120
        ? trimmed
        : '${trimmed.substring(0, 120).trim()}...';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Disputes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Create'),
              Tab(text: 'My disputes'),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: SafeArea(
            top: false,
            child: TabBarView(
              children: [
                // Create tab
                SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topInset + 54, 20, 20),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(30, 41, 59, 0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Need help with a job?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Submit a dispute for any issue you want our team to review.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.report_problem,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Create dispute',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    elevation: 5,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final navigator = Navigator.of(context);
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final ok = await navigator.push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateDisputeScreen(),
                                      ),
                                    );
                                    if (!mounted) return;
                                    if (ok == true) {
                                      _refresh();
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Dispute submitted.'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // My disputes tab
                RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _disputesFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: topInset + 100),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Error: ${snap.error}',
                                  textAlign: TextAlign.center,
                                  style:
                                      const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      final rows = snap.data ?? [];
                      if (rows.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: topInset + 100),
                            const Center(
                              child: Text(
                                'No disputes found.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(12, topInset + 50, 12, 12),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final r = rows[idx];
                          final issue = r['issue_type']?.toString() ?? 'Issue';
                          final status = r['status']?.toString() ?? 'open';
                          final created = r['created_at']?.toString();
                          String time = '';
                          if (created != null) {
                            final dt = DateTime.tryParse(created);
                            if (dt != null) {
                              time = DateFormat.yMMMd().add_jm().format(
                                dt.toLocal(),
                              );
                            }
                          }
                          return Material(
                            color: const Color(0x991E293B),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF0F172A),
                                  title: Text(issue),
                                  content: SingleChildScrollView(
                                    child: Text(
                                      r['description']?.toString() ?? '—',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            issue,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        _statusBadge(status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _previewDescription(
                                        r['description']?.toString(),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
