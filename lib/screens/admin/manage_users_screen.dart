import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _searchQuery = '';
  String _filterStatus = 'All'; // All, Active, Frozen, Banned
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _banUser(String userId, String userName) async {
    showDialog(
      context: context,
      builder: (context) {
        String? banReason;
        int? banDays;
        
        return AlertDialog(
          title: const Text('Ban User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to ban $userName?'),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Ban Reason',
                  hintText: 'Enter reason for banning',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => banReason = value,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Ban Duration',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                  DropdownMenuItem(value: 90, child: Text('90 days')),
                  DropdownMenuItem(value: 0, child: Text('Permanent')),
                ],
                onChanged: (value) => banDays = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'isBanned': true,
                  'banReason': banReason ?? 'Violation of terms',
                  'banExpiry': banDays != null && banDays! > 0
                      ? Timestamp.fromDate(DateTime.now().add(Duration(days: banDays!)))
                      : null,
                  'banDate': Timestamp.now(),
                });
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$userName has been banned')),
                );
              },
              child: const Text('Ban User'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _unbanUser(String userId, String userName) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isBanned': false,
      'banReason': null,
      'banExpiry': null,
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$userName has been unbanned')),
    );
  }

  Future<void> _warnUser(String userId, String userName) async {
    showDialog(
      context: context,
      builder: (context) {
        String warningMessage = '';
        
        return AlertDialog(
          title: const Text('Send Warning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Send a warning to $userName:'),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Warning Message',
                  hintText: 'Enter the warning message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => warningMessage = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Store warning in user's warnings subcollection
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('warnings')
                    .add({
                  'message': warningMessage,
                  'issuedBy': FirebaseAuth.instance.currentUser!.uid,
                  'issuedAt': Timestamp.now(),
                  'type': 'warning',
                });
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Warning sent to $userName')),
                );
              },
              child: const Text('Send Warning'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users by name or email',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _filterStatus,
                items: ['All', 'Active', 'Frozen', 'Banned'].map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _filterStatus = value!;
                  });
                },
              ),
            ],
          ),
        ),
        
        // Users list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              var users = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final userName = (data['displayName'] ?? '').toLowerCase();
                final userEmail = (data['email'] ?? '').toLowerCase();
                
                // Apply search filter
                bool matchesSearch = _searchQuery.isEmpty ||
                    userName.contains(_searchQuery) ||
                    userEmail.contains(_searchQuery);
                
                // Apply status filter
                bool matchesStatus = true;
                if (_filterStatus == 'Active') {
                  matchesStatus = data['isBanned'] != true && data['isFrozen'] != true;
                } else if (_filterStatus == 'Frozen') {
                  matchesStatus = data['isFrozen'] == true;
                } else if (_filterStatus == 'Banned') {
                  matchesStatus = data['isBanned'] == true;
                }
                
                return matchesSearch && matchesStatus;
              }).toList();
              
              if (users.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final doc = users[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final user = UserModel.fromMap(doc.id, data);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photos.isNotEmpty
                            ? NetworkImage(user.photos.first)
                            : null,
                        child: user.photos.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        user.displayName ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.email),
                          if (user.isBanned)
                            const Chip(
                              label: Text('BANNED', style: TextStyle(fontSize: 10)),
                              backgroundColor: Colors.red,
                              labelStyle: TextStyle(color: Colors.white),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          if (user.isFrozen)
                            const Chip(
                              label: Text('FROZEN', style: TextStyle(fontSize: 10)),
                              backgroundColor: Colors.orange,
                              labelStyle: TextStyle(color: Colors.white),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow('Bio:', user.bio ?? 'No bio'),
                              _InfoRow('Gender:', user.gender ?? 'Not specified'),
                              _InfoRow('Seeking:', user.seeking ?? 'Not specified'),
                              _InfoRow('Age:', user.dateOfBirth != null
                                  ? '${DateTime.now().difference(user.dateOfBirth!).inDays ~/ 365} years'
                                  : 'Not specified'),
                              _InfoRow('Interests:', user.interests.join(', ')),
                              _InfoRow('Report Count:', '${user.reportCount}'),
                              _InfoRow('Joined:', _formatDate(user.createdAt)),
                              _InfoRow('Last Active:', _formatDate(user.lastActive)),
                              
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!user.isBanned)
                                    ElevatedButton.icon(
                                      onPressed: () => _warnUser(user.uid, user.displayName ?? 'User'),
                                      icon: const Icon(Icons.warning_amber),
                                      label: const Text('Warn'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                    ),
                                  const SizedBox(width: 8),
                                  if (!user.isBanned)
                                    ElevatedButton.icon(
                                      onPressed: () => _banUser(user.uid, user.displayName ?? 'User'),
                                      icon: const Icon(Icons.block),
                                      label: const Text('Ban'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    ),
                                  if (user.isBanned)
                                    ElevatedButton.icon(
                                      onPressed: () => _unbanUser(user.uid, user.displayName ?? 'User'),
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text('Unban'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      // View full profile
                                      _showUserProfile(context, user);
                                    },
                                    icon: const Icon(Icons.visibility),
                                    label: const Text('View'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _InfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  void _showUserProfile(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: user.photos.isNotEmpty
                    ? NetworkImage(user.photos.first)
                    : null,
                child: user.photos.isEmpty ? const Icon(Icons.person, size: 50) : null,
              ),
              const SizedBox(height: 16),
              Text(user.displayName ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(user.email, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              if (user.photos.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: user.photos.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(user.photos[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Text(user.bio ?? 'No bio', style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}