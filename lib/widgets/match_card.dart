import 'package:flutter/material.dart';
import '../models/user_model.dart';

class MatchCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final int unreadCount;

  const MatchCard({
    super.key,
    required this.user,
    required this.onTap,
    this.unreadCount = 0,
  });

  bool get _isOnline {
    if (user.lastActive == null) return false;
    return DateTime.now().difference(user.lastActive!).inMinutes < 5;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: user.photos.isEmpty
                        ? LinearGradient(
                            colors: [
                              Colors.deepPurple.shade200,
                              Colors.purple.shade300
                            ],
                          )
                        : null,
                    image: user.photos.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(user.photos.first),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user.photos.isEmpty
                      ? Center(
                          child: Text(
                            (user.displayName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                ),
                if (_isOnline)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            // User info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.displayName ?? 'User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        if (user.dateOfBirth != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${DateTime.now().difference(user.dateOfBirth!).inDays ~/ 365}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (user.bio != null && user.bio!.isNotEmpty)
                      Text(
                        user.bio!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (user.interests.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: user.interests.take(3).map((interest) {
                            return Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                interest,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.deepPurple.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Right side: unread badge + chevron
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  Icon(Icons.chevron_right,
                      color: Colors.grey.shade400, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
