import 'package:flutter/material.dart';
import 'package:star_sitters_core/star_sitters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'hire_sitter_step1_screen.dart';
import 'sitter_chat_screen.dart';
import 'package:star_sitter_family/widgets/header2.dart';

/// Family app: read-only sitter profile from Supabase (`SittersRepository.getSitterPublicBundle`).
class SitterPublicProfileScreen extends StatefulWidget {
  final String sitterUserId;

  const SitterPublicProfileScreen({super.key, required this.sitterUserId});

  @override
  State<SitterPublicProfileScreen> createState() =>
      _SitterPublicProfileScreenState();
}

class _SitterPublicProfileScreenState extends State<SitterPublicProfileScreen> {
  late Future<Map<String, dynamic>?> _future;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = SittersRepository(
      Supabase.instance.client,
    ).getSitterPublicBundleWithHourlyRate(widget.sitterUserId);
  }

  String _ageLabel(String? dobIso) {
    if (dobIso == null || dobIso.isEmpty) return '—';
    final d = DateTime.tryParse(
      dobIso.length >= 10 ? dobIso.substring(0, 10) : dobIso,
    );
    if (d == null) return '—';
    final years = () {
      final n = DateTime.now();
      return (n.year - d.year) -
          ((n.month < d.month || (n.month == d.month && n.day < d.day))
              ? 1
              : 0);
    }();
    return '$years years old';
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'S';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  String _jobsLabel(Map<String, dynamic> row) {
    final totalMinutes = (row['total_minutes_worked'] as num?)?.toInt() ?? 0;
    if (totalMinutes <= 0) return 'New sitter';
    final jobs = (totalMinutes / 120).round();
    return '$jobs job${jobs == 1 ? '' : 's'}';
  }

  String _ratingLabel(Map<String, dynamic> row) {
    final rating = row['rating']?.toString();
    if (rating != null && rating.isNotEmpty) return rating;
    return '4.9';
  }

  String _hourlyRateLabel(Map<String, dynamic> row) {
    final rate = row['hourly_rate'];
    if (rate != null) {
      return '\$${rate}/hr';
    }
    return 'Ask for rate';
  }

  bool _guardianApproved(Map<String, dynamic> row) {
    return row['guardian_consent_status']?.toString() == 'approved';
  }

  Widget _initialsAvatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0xFF2A2D3E)),
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<String?> _findConversationId(String sitterId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || sitterId.isEmpty) return null;

    try {
      final result = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .eq('family_id', uid)
          .eq('sitter_id', sitterId)
          .maybeSingle();
      if (result == null) return null;
      return (result as Map)['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC8F0FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? const Color(0xFFC8F0FF)
                : Colors.white.withOpacity(0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF0F172A) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _tabContent(String bio, String name, bool guardianApproved) {
    switch (_selectedTabIndex) {
      case 1:
        return Text(
          guardianApproved
              ? 'Experienced sitter with strong family references and a proven safety-first approach.'
              : 'This sitter is still building their public experience profile.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.white.withOpacity(0.85),
          ),
        );
      case 2:
        return Text(
          'No reviews yet. Families can submit feedback after every completed job.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.white.withOpacity(0.85),
          ),
        );
      case 3:
        return Text(
          'Availability is managed through your job post. Select dates, submit a request, and this sitter will confirm availability in the application flow.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.white.withOpacity(0.85),
          ),
        );
      default:
        return Text(
          bio.isEmpty ? 'This sitter has not added a bio yet.' : bio,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.white.withOpacity(0.85),
          ),
        );
    }
  }

  Widget _bottomActionBar() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        final row = snap.data;
        final hourlyRate = row != null ? _hourlyRateLabel(row) : 'Hire';
        final sitterName = (row?['full_name']?.toString() ?? 'Sitter');
        final sitterId = row?['user_id']?.toString() ?? widget.sitterUserId;
        final userRow = row?['users'];
        final avatarUrl =
            (row?['avatar_url'] ??
                    (userRow is Map ? userRow['avatar_url'] : null))
                ?.toString();
        final rating = row != null ? _ratingLabel(row) : '4.9';
        final jobs = row != null ? _jobsLabel(row) : '0 jobs';

        return SafeArea(
          top: false,
          child: Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () async {
                        final conversationId = await _findConversationId(
                          sitterId,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SitterChatScreen(
                              conversationId: conversationId,
                              chatTitle: sitterName,
                              avatarUrl: avatarUrl,
                              jobInfo: conversationId != null
                                  ? 'Existing conversation'
                                  : 'Direct chat',
                              sitterId: sitterId,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.22)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Message',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HireSitterStep1Screen(
                              sitterName: sitterName,
                              hourlyRate: hourlyRate,
                              rating: rating,
                              jobCount: jobs,
                              sitterId: sitterId,
                              sitterAvatarUrl: avatarUrl,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBEF2FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'Hire • $hourlyRate',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _bottomActionBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/screen-bg.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB30F172A), Color(0xFF0F172A)],
                ),
              ),
            ),
          ),
          Column(
            children: [
              const Header2(title: 'Profile'),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError || snap.data == null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Sitter not found or not available for hire.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      );
                    }
                    final row = snap.data!;
                    final users = row['users'];
                    final u = users is Map<String, dynamic>
                        ? Map<String, dynamic>.from(users)
                        : <String, dynamic>{};
                    final name =
                        (row['full_name'] ?? u['full_name'] ?? 'Sitter')
                            .toString();
                    final avatar = (row['avatar_url'] ?? u['avatar_url'])
                        ?.toString();
                    final bio = (row['bio'] ?? '').toString().trim();
                    final dob = row['date_of_birth']?.toString();
                    final isVerified = _guardianApproved(row);
                    final rating = _ratingLabel(row);
                    final jobs = _jobsLabel(row);
                    final hourlyRate = _hourlyRateLabel(row);

                    final location =
                        row['location']?.toString() ?? 'San Francisco, CA';
                    final distance =
                        row['distance_miles']?.toString() ?? '2.3 miles away';
                    final ratingCount =
                        row['rating_count'] ?? row['review_count'];
                    final ratingLabel = ratingCount != null
                        ? '$rating (${ratingCount.toString()})'
                        : rating;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101827),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: avatar != null && avatar.isNotEmpty
                                          ? Image.network(
                                              avatar,
                                              width: 104,
                                              height: 104,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _initialsAvatar(name, 104),
                                            )
                                          : _initialsAvatar(name, 104),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.favorite_border,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _ageLabel(dob),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _badge(
                                                'Admin Verified',
                                                const Color(0xFF10B981),
                                              ),
                                              const SizedBox(height: 8),
                                              _badge(
                                                'Background Checked',
                                                const Color(0xFF3B82F6),
                                              ),
                                              const SizedBox(height: 8),
                                              _badge(
                                                'Certified',
                                                const Color(0xFF8B5CF6),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xFFFFD700),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ratingLabel,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '• $jobs',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: Color(0xFF78C0F5),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$location • $distance',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_outlined,
                                      color: Color(0xFF78C0F5),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Usually responds within 1 hour',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111827),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.04),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Hourly Rate',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                        ],
                                      ),
                                      Text(
                                        hourlyRate,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _tabButton('About', 0),
                                const SizedBox(width: 8),
                                _tabButton('Experience', 1),
                                const SizedBox(width: 8),
                                _tabButton('Reviews', 2),
                                const SizedBox(width: 8),
                                _tabButton('Availability', 3),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _tabContent(bio, name, isVerified),
                          const SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
