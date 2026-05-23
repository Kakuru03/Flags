import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'edit_profile_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
onPressed: () async {
              await authService.logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: user.photos.isNotEmpty
                        ? NetworkImage(user.photos.first)
                        : null,
                    child: user.photos.isEmpty ? const Icon(Icons.person, size: 60) : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user.displayName ?? 'No Name',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (user.bio != null)
                    Text(
                      user.bio!,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 20),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: const Text('Email'),
                          subtitle: Text(user.email),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.cake),
                          title: const Text('Birthday'),
                          subtitle: Text(user.dateOfBirth != null
                              ? '${user.dateOfBirth!.year}-${user.dateOfBirth!.month}-${user.dateOfBirth!.day}'
                              : 'Not set'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.favorite),
                          title: const Text('Interests'),
                          subtitle: Text(user.interests.isEmpty
                              ? 'No interests added'
                              : user.interests.join(', ')),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.lock),
                          title: const Text('Account Status'),
                          subtitle: Text(user.isFrozen ? 'Frozen' : 'Active'),
                          trailing: Switch(
                            value: user.isFrozen,
                            onChanged: (value) async {
                              if (value) {
                                await authService.freezeAccount(user.uid);
                              } else {
                                await authService.unfreezeAccount(user.uid);
                              }
                            },
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.visibility),
                          title: const Text('Private Account'),
                          subtitle: Text(user.isPrivate
                              ? 'Only matches can see you'
                              : 'Everyone can see you'),
                          trailing: Switch(
                            value: user.isPrivate,
                            onChanged: (value) async {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({'isPrivate': value});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (user.matchedWithUid != null)
                    Card(
                      color: Colors.green.shade50,
                      child: const ListTile(
                        leading: Icon(Icons.favorite, color: Colors.green),
                        title: Text('In a Relationship'),
                        subtitle: Text('You have found your match!'),
                        trailing: Icon(Icons.verified, color: Colors.green),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}