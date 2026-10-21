import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:star_sitters_core/star_sitters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:star_sitter_family/widgets/app_background.dart';

/// Screen for families to create a dispute tied to a job.
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
    final jobs = await JobsRepository(Supabase.instance.client).myFamilyJobs();
    if (!mounted) return;
    setState(() => _jobs = jobs);
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

      // Upload picked files to private family bg-check bucket and record uploaded_documents rows.
      final repo = ProfileRepository(client);
      final uploaded = <Map<String, dynamic>>[];
      for (final f in _pickedFiles) {
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final path = await repo.uploadDocument(bytes, f.name);
        // insert uploaded_documents row so admins can review
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
        String? sitterName;
        String? sitterId;
        if (_hire!['sitter_profiles'] is Map) {
          final sp = _hire!['sitter_profiles'] as Map;
          sitterId = sp['user_id']?.toString();
          if (sp['users'] is Map) {
            sitterName = (sp['users'] as Map)['full_name']?.toString();
          }
        }
        if (sitterName != null || sitterId != null) {
          finalDesc =
              'Reported against: ${sitterName ?? sitterId}\n\n$finalDesc';
        }
      }

      // Append attachments list
      if (uploaded.isNotEmpty) {
        finalDesc =
            '$finalDesc\n\nAttachments:\n${uploaded.map((u) => '- ${u['name']}: ${u['storage_path']}').join('\n')}';
      }

      // Insert dispute row
      await client.from('disputes').insert({
        'job_id': _selectedJobId,
        'reported_by_user_id': uid,
        'reported_by_role': 'family',
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
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Dispute'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topInset, 20, 20),
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
                  DropdownButtonFormField<String>(
                    initialValue: _selectedJobId,
                    items: _jobs
                        .map(
                          (j) => DropdownMenuItem(
                            value: j['id']?.toString(),
                            child: Text(j['title']?.toString() ?? 'Job'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      setState(() => _selectedJobId = v);
                      if (v != null) await _loadHire(v);
                    },
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
                        String? name;
                        if (_hire!['sitter_profiles'] is Map) {
                          final sp = _hire!['sitter_profiles'] as Map;
                          if (sp['users'] is Map) {
                            name = (sp['users'] as Map)['full_name']?.toString();
                          }
                        }
                        return name ?? 'Sitter';
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
                      child: Text('Payment'),
                    ),
                    DropdownMenuItem(
                      value: 'time_discrepancy',
                      child: Text('Time discrepancy'),
                    ),
                    DropdownMenuItem(value: 'no_show', child: Text('No show')),
                    DropdownMenuItem(
                      value: 'safety_concern',
                      child: Text('Safety concern'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _issueType = v ?? 'other'),
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
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'medium'),
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
                    hintStyle: TextStyle(color: Colors.white70),
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
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Choose files'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                    for (final f in _pickedFiles)
                      Chip(
                        label: Text(
                          f.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFF111827),
                        side: const BorderSide(color: Colors.white12),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
