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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile image
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                image: user.photos.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(user.photos.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: user.photos.isEmpty
                  ? const Icon(Icons.person, size: 40, color: Colors.grey)
                  : null,
            ),
            
            const SizedBox(width: 12),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (user.bio != null)
                    Text(
                      user.bio!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            // Unread indicator
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 16),
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            
            // Online indicator
            Container(
              margin: const EdgeInsets.only(right: 16),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _isOnline() ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  bool _isOnline() {
    if (user.lastActive == null) return false;
    final difference = DateTime.now().difference(user.lastActive!);
    return difference.inMinutes < 5;
  }
}