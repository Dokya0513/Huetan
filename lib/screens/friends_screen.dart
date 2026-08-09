import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/friend.dart';
import '../providers/providers.dart';
import '../services/oauth_loopback_service.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  late final Stream<AuthState> _authStateStream;

  String? _myFriendCode;
  List<FriendRequest> _incomingRequests = [];
  List<Friend> _friends = [];
  bool _loadingData = false;
  bool _signingIn = false;
  final _codeController = TextEditingController();
  bool _sendingRequest = false;

  @override
  void initState() {
    super.initState();
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
    if (Supabase.instance.client.auth.currentUser != null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    try {
      final service = ref.read(friendsServiceProvider);
      final results = await Future.wait([
        service.getMyProfile(),
        service.getIncomingRequests(),
        service.getFriends(),
      ]);
      if (!mounted) return;
      setState(() {
        _myFriendCode = (results[0] as Map<String, dynamic>)['friend_code'] as String?;
        _incomingRequests = results[1] as List<FriendRequest>;
        _friends = results[2] as List<Friend>;
      });
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      await OAuthLoopbackService().signInWithGoogle();
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    setState(() {
      _myFriendCode = null;
      _incomingRequests = [];
      _friends = [];
    });
  }

  Future<void> _copyMyCode() async {
    final code = _myFriendCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.friendsCodeCopiedSnackbar)));
  }

  Future<void> _sendRequest() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sendingRequest = true);
    try {
      await ref.read(friendsServiceProvider).sendFriendRequest(code);
      _codeController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.friendsRequestSentSnackbar)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.friendsRequestFailedSnackbar(e.toString())),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _respond(FriendRequest request, bool accept) async {
    await ref.read(friendsServiceProvider).respondToRequest(
      requestId: request.id,
      accept: accept,
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsScreenTitle)),
      body: StreamBuilder<AuthState>(
        stream: _authStateStream,
        builder: (context, snapshot) {
          final user =
              snapshot.data?.session?.user ??
              Supabase.instance.client.auth.currentUser;

          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.friendsSignInPrompt,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _signingIn ? null : _signIn,
                      icon: _signingIn
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(l10n.friendsSignInButton),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_loadingData && _myFriendCode == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.friendsSignedInAs(user.email ?? ''),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: _signOut,
                      child: Text(l10n.friendsSignOutButton),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.friendsMyCodeLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.friendsMyCodeHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _myFriendCode ?? '—',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: _myFriendCode == null
                                  ? null
                                  : _copyMyCode,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.friendsAddByCodeLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: l10n.friendsCodeInputHint,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sendingRequest ? null : _sendRequest,
                      child: Text(l10n.friendsSendRequestButton),
                    ),
                  ],
                ),
                if (_incomingRequests.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.friendsIncomingRequestsLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final request in _incomingRequests)
                    Card(
                      child: ListTile(
                        title: Text(request.fromDisplayName ?? request.fromUserId),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _respond(request, false),
                              child: Text(l10n.friendsDeclineButton),
                            ),
                            FilledButton(
                              onPressed: () => _respond(request, true),
                              child: Text(l10n.friendsAcceptButton),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                Text(
                  l10n.friendsListLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      l10n.friendsEmptyList,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  for (final friend in _friends)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: friend.avatarUrl != null
                              ? NetworkImage(friend.avatarUrl!)
                              : null,
                          child: friend.avatarUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(friend.displayName ?? friend.userId),
                        subtitle: Text(l10n.friendsLevelLabel(friend.level)),
                        trailing: Text(l10n.friendsStreakLabel(friend.streakDays)),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
