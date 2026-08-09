/// A friend (accepted friend_requests row) with the profile/stats fields
/// needed to display them in a friends list.
class Friend {
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final int xp;
  final int streakDays;

  const Friend({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.xp,
    required this.streakDays,
  });

  /// Same formula as lib/repositories/stats_repository.dart's local
  /// StatsSnapshot.level — kept as a single literal here rather than a
  /// shared constant, since this is the one place cloud data crosses back
  /// into that local concept.
  int get level => (xp ~/ 100) + 1;
}

/// A pending friend request, either sent by or addressed to the current
/// user.
class FriendRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String? fromDisplayName;
  final String? toDisplayName;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.fromDisplayName,
    required this.toDisplayName,
    required this.createdAt,
  });
}
