import 'package:supabase_flutter/supabase_flutter.dart';

/// Public sitter discovery for the family app (BACKEND.md §17 Hire screen).
class SittersRepository {
  SittersRepository(this._client);
  final SupabaseClient _client;

  /// Active, admin-approved sitters (`is_active = true`).
  Future<List<Map<String, dynamic>>> listActiveSitters({int limit = 50}) async {
    final res = await _client
        .from('sitter_profiles')
        .select(
          'user_id, full_name, avatar_url, bio, date_of_birth, guardian_consent_status, '
          'users(full_name, email, avatar_url)',
        )
        .eq('is_active', true)
        .order('updated_at', ascending: false)
        .limit(limit);
    final list = res as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// One sitter for profile preview (family → sitter card).
  Future<Map<String, dynamic>?> getSitterPublicBundle(
    String sitterUserId,
  ) async {
    final sp = await _client
        .from('sitter_profiles')
        .select(
          'user_id, full_name, avatar_url, bio, date_of_birth, guardian_consent_status, total_minutes_worked, '
          'users(full_name, email, avatar_url)',
        )
        .eq('user_id', sitterUserId)
        .eq('is_active', true)
        .maybeSingle();
    if (sp == null) return null;
    return Map<String, dynamic>.from(sp as Map);
  }

  Future<double?> hourlyRateForAge(int age) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final res = await _client
        .from('age_wage_tiers')
        .select('hourly_rate')
        .lte('min_age', age)
        .gte('max_age', age)
        .lte('effective_from', today)
        .order('effective_from', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(res as List);
    if (list.isEmpty) return null;
    return double.tryParse(list.first['hourly_rate'].toString());
  }

  Future<Map<String, dynamic>?> getSitterPublicBundleWithHourlyRate(
    String sitterUserId,
  ) async {
    final bundle = await getSitterPublicBundle(sitterUserId);
    if (bundle == null) return null;
    final dob = bundle['date_of_birth']?.toString();
    if (dob != null && dob.isNotEmpty) {
      final parsed = DateTime.tryParse(
        dob.length >= 10 ? dob.substring(0, 10) : dob,
      );
      if (parsed != null) {
        final now = DateTime.now();
        final age =
            (now.year - parsed.year) -
            ((now.month < parsed.month ||
                    (now.month == parsed.month && now.day < parsed.day))
                ? 1
                : 0);
        final rate = await hourlyRateForAge(age);
        if (rate != null) {
          bundle['hourly_rate'] = rate;
        }
      }
    }
    return bundle;
  }
}
