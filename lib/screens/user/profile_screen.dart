import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../utils/error_handler.dart'; // optional but recommended
import 'edit_profile_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isTogglingFreeze = false;
  bool _isTogglingPrivate = false;
  bool _isLoggingOut = false;

  /// Shows a snackbar message
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Handles freezing/unfreezing account with error handling
  Future<void> _toggleFreezeAccount(AuthService authService, String uid, bool currentValue) async {
    if (_isTogglingFreeze) return;
    setState(() => _isTogglingFreeze = true);

    try {
      if (currentValue) {
        await authService.unfreezeAccount(uid);
        _showMessage('Account unfrozen successfully.');
      } else {
        // Optional: ask for confirmation before freezing
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Freeze account?'),
            content: const Text(
              'When your account is frozen, you will not be shown to other users '
                  'and will not receive any matches. You can unfreeze anytime.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Freeze', style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await authService.freezeAccount(uid);
        _showMessage('Account frozen.');
      }
      // Refresh the user model so UI updates
      await authService.refreshCurrentUserModel();
      if (mounted) setState(() {}); // rebuild with new data
    } catch (e, st) {
      debugPrint('Error toggling freeze: $e\n$st');
      _showMessage('Failed to update account status: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isTogglingFreeze = false);
    }
  }

  /// Handles toggling private account status
  Future<void> _togglePrivateAccount(AuthService authService, String uid, bool currentValue) async {
    if (_isTogglingPrivate) return;
    setState(() => _isTogglingPrivate = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'isPrivate': !currentValue});
      // Refresh local user model
      await authService.refreshCurrentUserModel();
      _showMessage('Account privacy updated.');
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('Error toggling private: $e\n$st');
      _showMessage('Failed to update privacy: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isTogglingPrivate = false);
    }
  }

  /// Handles logout with confirmation and error handling
  Future<void> _logout(AuthService authService) async {
    if (_isLoggingOut) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoggingOut = true);
    try {
      await authService.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e, st) {
      debugPrint('Logout error: $e\n$st');
      _showMessage('Logout failed: ${e.toString()}', isError: true);
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

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
              ).then((_) {
                // Refresh after returning from edit screen
                authService.refreshCurrentUserModel();
                if (mounted) setState(() {});
              });
            },
          ),
          IconButton(
            icon: _isLoggingOut
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.logout),
            onPressed: _isLoggingOut ? null : () => _logout(authService),
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
            if (user.bio != null && user.bio!.isNotEmpty)
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
                    leading: const Icon(Icons.ac_unit), // Freeze icon
                    title: const Text('Account Status'),
                    subtitle: Text(user.isFrozen ? 'Frozen' : 'Active'),
                    trailing: _isTogglingFreeze
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Switch(
                      value: user.isFrozen,
                      onChanged: (value) =>
                          _toggleFreezeAccount(authService, user.uid, user.isFrozen),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text('Private Account'),
                    subtitle: Text(user.isPrivate
                        ? 'Only matches can see you'
                        : 'Everyone can see you'),
                    trailing: _isTogglingPrivate
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Switch(
                      value: user.isPrivate,
                      onChanged: (_) =>
                          _togglePrivateAccount(authService, user.uid, user.isPrivate),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Optional: Show "In a relationship" if matchedWithUid exists
            if (user.matchedWithUid != null && user.matchedWithUid!.isNotEmpty)
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