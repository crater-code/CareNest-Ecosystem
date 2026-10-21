import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:star_sitters_core/star_sitters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_background.dart';

/// Screen for sitters to create a dispute tied to a job.
class CreateDisputeScreen extends StatefulWidget {
  final String? jobId;
  const CreateDisputeScreen({super.key, this.jobId});

  @override
  State<CreateDisputeScreen> createState() => _CreateDisputeScreenState();
}

class _CreateDisputeScreenState extends State<CreateDisputeScreen> {
  String? _selectedJobId;
  List<Map<String, dynamic>> _jobs = [];
  Map<String, dynamic>? _hire;
  String _issueType = 'payment_issue';
  String _priority = 'medium';
  final _desc = TextEditingController();
  bool _busy = false;
  bool _loadingJobs = false;
  List<PlatformFile> _pickedFiles = [];

  @override
  void initState() {
    super.initState();
    _selectedJobId = widget.jobId;
    _loadJobsIfNeeded();
    if (_selectedJobId != null) _loadHire(_selectedJobId!);
  }

  Future<void> _loadJobsIfNeeded() async {
    if (_selectedJobId != null) return;
    setState(() => _loadingJobs = true);
    try {
      final hires = await JobsRepository(
        Supabase.instance.client,
      ).sitterHireHistoryWithJobs();
      if (!mounted) return;
      setState(() {
        _jobs = hires
            .map((row) {
              final job = row['jobs'] as Map?;
              final jobId = job?['id']?.toString() ?? row['job_id']?.toString();
              String displayTitle = job?['title']?.toString() ?? 'Job';
              if (jobId != null && jobId.length >= 4) {
                displayTitle = '$displayTitle #${jobId.substring(0, 4)}';
              }
              return <String, dynamic>{
                'id': jobId,
                'title': displayTitle,
              };
            })
            .where((job) => job['id'] != null)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading jobs: $e');
    } finally {
      if (mounted) setState(() => _loadingJobs = false);
    }
  }

  Future<void> _loadHire(String jobId) async {
    final hire = await JobsRepository(
      Supabase.instance.client,
    ).hireForJob(jobId);
    if (!mounted) return;
    setState(() => _hire = hire);
  }

  Future<void> _pickFiles() async {
    final pick = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return;
    setState(() => _pickedFiles = pick.files);
  }

  Future<void> _submit() async {
    if (_selectedJobId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a job.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Sign in required');

      final repo = ProfileRepository(client);
      final uploaded = <Map<String, dynamic>>[];
      for (final f in _pickedFiles) {
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final path = await repo.uploadDocument(bytes, f.name);
        await client.from('uploaded_documents').insert({
          'user_id': uid,
          'doc_kind': 'other',
          'document_name': f.name,
          'storage_path': path,
        });
        uploaded.add({'name': f.name, 'storage_path': path});
      }

      var finalDesc = _desc.text.trim();
      if (_hire != null) {
        String? familyName;
        String? familyId;
        final job = _hire!['jobs'] as Map?;
        if (job != null) {
          familyName = job['family_name']?.toString();
          familyId = job['family_id']?.toString();
          final fp = job['family_profiles'] as Map?;
          if (fp != null && fp['users'] is Map) {
            familyName ??= (fp['users'] as Map)['full_name']?.toString();
          }
        }
        if (familyName != null || familyId != null) {
          finalDesc =
              'Reported against: ${familyName ?? familyId}\n\n$finalDesc';
        }
      }

      if (uploaded.isNotEmpty) {
        finalDesc =
            '$finalDesc\n\nAttachments:\n${uploaded.map((u) => '- ${u['name']}: ${u['storage_path']}').join('\n')}';
      }

      await client.from('disputes').insert({
        'job_id': _selectedJobId,
        'reported_by_user_id': uid,
        'reported_by_role': 'sitter',
        'issue_type': _issueType,
        'description': finalDesc,
        'priority': _priority,
        'status': 'open',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispute created. Admins will review it.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: const Text('Create Dispute'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              20,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                if (widget.jobId == null) ...[
                  const Text(
                    'Select job',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingJobs)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Loading hired jobs...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  else if (_jobs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No hired jobs found.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedJobId,
                      items: _jobs
                          .map(
                            (j) => DropdownMenuItem(
                              value: j['id']?.toString(),
                              child: Text(
                                j['title']?.toString() ?? 'Job',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        setState(() => _selectedJobId = v);
                        if (v != null) await _loadHire(v);
                      },
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: const Color(0xFF1E293B),
                      iconEnabledColor: Colors.white,
                      decoration: InputDecoration(
                        fillColor: const Color(0xFF1E293B),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (_hire != null) ...[
                  const Text(
                    'Reported against',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      () {
                        final job = _hire!['jobs'] as Map?;
                        String? name = job?['family_name']?.toString();
                        if (name == null && job?['family_profiles'] is Map) {
                          final fp = job!['family_profiles'] as Map;
                          if (fp['users'] is Map) {
                            name = (fp['users'] as Map)['full_name']?.toString();
                          }
                        }
                        return name ?? 'Family';
                      }(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Issue type',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _issueType,
                  items: const [
                    DropdownMenuItem(
                      value: 'payment_issue',
                      child: Text(
                        'Payment',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'time_discrepancy',
                      child: Text(
                        'Time discrepancy',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'no_show',
                      child: Text(
                        'No show',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'safety_concern',
                      child: Text(
                        'Safety concern',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(
                        'Other',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _issueType = v ?? 'other'),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF1E293B),
                  iconEnabledColor: Colors.white,
                  decoration: InputDecoration(
                    fillColor: const Color(0xFF1E293B),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Priority', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Low', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text(
                        'Medium',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text(
                        'High',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF1E293B),
                  iconEnabledColor: Colors.white,
                  decoration: InputDecoration(
                    fillColor: const Color(0xFF1E293B),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _desc,
                  maxLines: 6,
                  decoration: InputDecoration(
                    fillColor: const Color(0xFF1E293B),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Describe the issue…',
                    hintStyle: const TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Attachments',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose files'),
                    ),
                    for (final f in _pickedFiles) Chip(label: Text(f.name)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      elevation: 6,
                      shadowColor: const Color(
                        0xFFDC2626,
                      ).withAlpha((0.35 * 255).round()),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Dispute',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
