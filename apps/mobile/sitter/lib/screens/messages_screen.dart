import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:star_sitters_core/star_sitters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/bottom_nav_bar.dart';
import '../widgets/messages/message_search_bar.dart';
import '../widgets/messages/message_list_item.dart';
import '../utils/custom_page_route.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _currentNavIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/screen-bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          IgnorePointer(
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
          SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Secure conversations with families',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        const MessageSearchBar(),
                        const SizedBox(height: 12),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: ConversationsRepository(
                            Supabase.instance.client,
                          ).sitterConversations(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                '${snapshot.error}',
                                style: const TextStyle(color: Colors.white70),
                              );
                            }
                            final rows =
                                snapshot.data ?? const <Map<String, dynamic>>[];
                            if (rows.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  'No conversations yet. Apply and get hired to chat.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: rows.map((c) {
                                final id = c['id']?.toString() ?? '';
                                final created = c['created_at'] != null
                                    ? DateTime.tryParse(
                                        c['created_at'].toString(),
                                      )
                                    : null;
                                final time = created != null
                                    ? DateFormat.yMMMd().add_jm().format(
                                        created.toLocal(),
                                      )
                                    : '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _FamilyConversationTile(
                                    conversationId: id,
                                    time: time,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                BottomNavBar(
                  currentIndex: _currentNavIndex,
                  onTap: (index) {
                    if (index == 0) {
                      Navigator.pop(context);
                    } else {
                      setState(() => _currentNavIndex = index);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyConversationTile extends StatefulWidget {
  final String conversationId;
  final String time;

  const _FamilyConversationTile({
    required this.conversationId,
    required this.time,
  });

  @override
  State<_FamilyConversationTile> createState() =>
      _FamilyConversationTileState();
}

class _FamilyConversationTileState extends State<_FamilyConversationTile> {
  String _partnerName = 'Family';
  String? _avatarUrl;
  bool _loading = true;
  int? _unreadCountOverride;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.conversationId.isEmpty) return;
    final repo = ConversationsRepository(Supabase.instance.client);
    final profile = await repo.fetchPartnerProfile(widget.conversationId);

    if (mounted) {
      setState(() {
        if (profile != null) {
          _partnerName = profile['full_name']?.toString() ?? 'Family';
          _avatarUrl = profile['avatar_url']?.toString();
        }
        _loading = false;
      });
    }
  }

  Future<bool> _markConversationRead() async {
    if (widget.conversationId.isEmpty) return false;
    try {
      await MessagesRepository(
        Supabase.instance.client,
      ).markConversationRead(widget.conversationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _openChat() {
    _markConversationRead().then((success) {
      if (!mounted) return;
      if (success) {
        setState(() => _unreadCountOverride = 0);
      }
      Navigator.push(
        context,
        CustomPageRoute(
          builder: (_) => ChatScreen(
            familyName: _partnerName,
            conversationId: widget.conversationId,
            avatarUrl: _avatarUrl,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.conversationId.isNotEmpty
          ? MessagesRepository(
              Supabase.instance.client,
            ).stream(widget.conversationId)
          : const Stream<List<Map<String, dynamic>>>.empty(),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const <Map<String, dynamic>>[];
        final uid = Supabase.instance.client.auth.currentUser?.id;
        final streamUnreadCount = messages
            .where(
              (message) =>
                  message['sender_id']?.toString() != uid &&
                  message['read_at'] == null,
            )
            .length;
        final unreadCount = _unreadCountOverride ?? streamUnreadCount;
        final latestMessage = _latestReceivedMessageBody(messages, uid);

        return MessageListItem(
          name: _partnerName,
          preview: latestMessage.isNotEmpty
              ? latestMessage
              : 'Tap to view conversation',
          time: widget.time,
          unreadCount: unreadCount,
          isUnread: unreadCount > 0,
          avatarUrl: _avatarUrl,
          onTap: _openChat,
        );
      },
    );
  }

  String _latestReceivedMessageBody(
    List<Map<String, dynamic>> messages,
    String? uid,
  ) {
    if (messages.isEmpty) return '';
    final received = messages
        .where((message) => message['sender_id']?.toString() != uid)
        .toList();
    if (received.isEmpty) {
      return _latestMessageBody(messages);
    }

    final sorted = List<Map<String, dynamic>>.from(received);
    sorted.sort((a, b) {
      final ta =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return sorted.last['body']?.toString() ?? '';
  }

  String _latestMessageBody(List<Map<String, dynamic>> messages) {
    final sorted = List<Map<String, dynamic>>.from(messages);
    sorted.sort((a, b) {
      final ta =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return sorted.isNotEmpty ? sorted.last['body']?.toString() ?? '' : '';
  }
}
