import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend.dart';

/// Talks to the friend-feature tables set up by
/// supabase/friends_setup.sql: profiles, stats, friend_requests, and the
/// my_friends view. All methods require a signed-in user — callers are
/// expected to check that before calling.
class FriendsService {
  String get _uid {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('FriendsService requires a signed-in user.');
    }
    return uid;
  }

  /// The current user's own profile — mainly for showing their
  /// friend_code so they can share it.
  Future<Map<String, dynamic>> getMyProfile() async {
    return Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', _uid)
        .single();
  }

  /// Pushes the current local XP/streak up to the cloud so friends can
  /// see it — call this after review sessions, not on every screen build.
  Future<void> pushStats({required int xp, required int streakDays}) async {
    await Supabase.instance.client.from('stats').upsert({
      'user_id': _uid,
      'xp': xp,
      'streak_days': streakDays,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Friend>> getFriends() async {
    final rows = await Supabase.instance.client.from('my_friends').select();
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => Friend(
            userId: row['user_id'] as String,
            displayName: row['display_name'] as String?,
            avatarUrl: row['avatar_url'] as String?,
            xp: row['xp'] as int,
            streakDays: row['streak_days'] as int,
          ),
        )
        .toList();
  }

  /// Sends a friend request to whoever owns [friendCode]. Throws if the
  /// code doesn't match anyone, matches the caller themselves, or a
  /// request between these two users already exists.
  Future<void> sendFriendRequest(String friendCode) async {
    await Supabase.instance.client.rpc(
      'send_friend_request',
      params: {'code': friendCode},
    );
  }

  /// Pending requests addressed to the current user, with the sender's
  /// display name for showing in an "accept/decline" list.
  Future<List<FriendRequest>> getIncomingRequests() async {
    final rows = await Supabase.instance.client
        .from('friend_requests')
        .select('id, from_user_id, to_user_id, created_at, from:profiles!friend_requests_from_user_id_fkey(display_name)')
        .eq('to_user_id', _uid)
        .eq('status', 'pending');

    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final from = row['from'] as Map<String, dynamic>?;
      return FriendRequest(
        id: row['id'] as String,
        fromUserId: row['from_user_id'] as String,
        toUserId: row['to_user_id'] as String,
        fromDisplayName: from?['display_name'] as String?,
        toDisplayName: null,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    await Supabase.instance.client
        .from('friend_requests')
        .update({
          'status': accept ? 'accepted' : 'declined',
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }
}
