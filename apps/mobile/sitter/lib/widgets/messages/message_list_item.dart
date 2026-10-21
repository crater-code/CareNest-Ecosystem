import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MessageListItem extends StatelessWidget {
  final String name;
  final String preview;
  final String time;
  final bool isUnread;
  final int unreadCount;
  final String? avatarAsset;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const MessageListItem({
    super.key,
    required this.name,
    required this.preview,
    required this.time,
    this.isUnread = false,
    this.unreadCount = 0,
    this.avatarAsset,
    this.avatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x991E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1AA8D8EA), width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF2A2D3E),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : (avatarAsset != null ? AssetImage(avatarAsset!) : null)
                        as ImageProvider?,
              child: (avatarUrl == null && avatarAsset == null)
                  ? SvgPicture.asset(
                      'assets/profile-icon.svg',
                      width: 26,
                      height: 26,
                      colorFilter: const ColorFilter.mode(
                        Colors.white38,
                        BlendMode.srcIn,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0x99A8D8EA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Time + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA8D8EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
