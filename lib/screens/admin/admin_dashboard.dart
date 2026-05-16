import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_users_screen.dart';
import 'manage_reports_screen.dart';
import 'monitor_chats_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const DashboardStatsScreen(),
    const ManageUsersScreen(),
    const ManageReportsScreen(),
    const MonitorChatsScreen(),
  ];
  
  final List<String> _titles = [
    'Dashboard',
    'Manage Users',
    'Reports',
    'Monitor Chats',
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flags Admin - ${_titles[_selectedIndex]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Flags Admin Panel',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Administrator Privileges',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () => _setIndex(0),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              selected: _selectedIndex == 1,
              onTap: () => _setIndex(1),
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Reports'),
              selected: _selectedIndex == 2,
              onTap: () => _setIndex(2),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Monitor Chats'),
              selected: _selectedIndex == 3,
              onTap: () => _setIndex(3),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin Settings'),
              onTap: () {
                // Add other admin settings
              },
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
  
  void _setIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);
  }
}

class DashboardStatsScreen extends StatelessWidget {
  const DashboardStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder(
          stream: FirebaseFirestore.instance.collection('reports').snapshots(),
          builder: (context, reportSnapshot) {
            int totalUsers = userSnapshot.hasData ? userSnapshot.data!.docs.length : 0;
            int totalReports = reportSnapshot.hasData ? reportSnapshot.data!.docs.length : 0;
            int bannedUsers = 0; // Implement this count
            
            return Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    title: 'Total Users',
                    value: totalUsers.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  _StatCard(
                    title: 'Active Reports',
                    value: totalReports.toString(),
                    icon: Icons.report_problem,
                    color: Colors.red,
                  ),
                  _StatCard(
                    title: 'Banned Users',
                    value: bannedUsers.toString(),
                    icon: Icons.block,
                    color: Colors.orange,
                  ),
                  const _StatCard(
                    title: 'Active Matches',
                    value: '0', // Implement count
                    icon: Icons.favorite,
                    color: Colors.green,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}