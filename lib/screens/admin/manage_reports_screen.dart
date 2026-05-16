import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';

class ManageReportsScreen extends StatefulWidget {
  const ManageReportsScreen({super.key});

  @override
  _ManageReportsScreenState createState() => _ManageReportsScreenState();
}

class _ManageReportsScreenState extends State<ManageReportsScreen> {
  String _filterStatus = 'pending'; // pending, reviewed, action_taken
  
  Future<void> _handleReportAction(ReportModel report, String action, {String? response}) async {
    final reportRef = FirebaseFirestore.instance.collection('reports').doc(report.reportId);
    
    switch (action) {
      case 'warning':
        await reportRef.update({
          'status': 'action_taken',
          'actionTaken': 'warning',
          'adminResponse': response ?? 'Warning issued for inappropriate behavior',
          'actionDate': Timestamp.now(),
        });
        
        // Add warning to user's record
        await FirebaseFirestore.instance
            .collection('users')
            .doc(report.reportedUserId)
            .collection('warnings')
            .add({
          'reason': report.reason,
          'description': report.description,
          'issuedBy': FirebaseAuth.instance.currentUser!.uid,
          'issuedAt': Timestamp.now(),
          'reportId': report.reportId,
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning issued to user')),
        );
        break;
        
      case 'temporary_ban':
        await reportRef.update({
          'status': 'action_taken',
          'actionTaken': 'temporary_ban',
          'adminResponse': response ?? 'Temporary ban for violating community guidelines',
          'actionDate': Timestamp.now(),
        });
        
        await FirebaseFirestore.instance.collection('users').doc(report.reportedUserId).update({
          'isBanned': true,
          'banReason': report.reason,
          'banExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
          'banDate': Timestamp.now(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User has been temporarily banned for 30 days')),
        );
        break;
        
      case 'permanent_ban':
        await reportRef.update({
          'status': 'action_taken',
          'actionTaken': 'permanent_ban',
          'adminResponse': response ?? 'Permanent ban for serious violation',
          'actionDate': Timestamp.now(),
        });
        
        await FirebaseFirestore.instance.collection('users').doc(report.reportedUserId).update({
          'isBanned': true,
          'banReason': report.reason,
          'banExpiry': null, // Permanent ban
          'banDate': Timestamp.now(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User has been permanently banned')),
        );
        break;
        
      case 'dismiss':
        await reportRef.update({
          'status': 'reviewed',
          'adminResponse': response ?? 'No action taken - insufficient evidence',
          'actionDate': Timestamp.now(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report dismissed')),
        );
        break;
    }
    
    setState(() {}); // Refresh the list
  }
  
  void _showActionDialog(ReportModel report) {
    String? adminResponse;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reported User ID: ${report.reportedUserId}'),
            Text('Reason: ${report.reason}'),
            const SizedBox(height: 8),
            if (report.description != null)
              Text('Description: ${report.description}'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Admin Response (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => adminResponse = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              _handleReportAction(report, 'warning', response: adminResponse);
            },
            child: const Text('Issue Warning'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _showBanDurationDialog(report, adminResponse);
            },
            child: const Text('Ban User'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleReportAction(report, 'dismiss', response: adminResponse);
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
  
  void _showBanDurationDialog(ReportModel report, String? adminResponse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Ban Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('30 Days (Temporary)'),
              onTap: () {
                Navigator.pop(context);
                _handleReportAction(report, 'temporary_ban', response: adminResponse);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Permanent'),
              onTap: () {
                Navigator.pop(context);
                _handleReportAction(report, 'permanent_ban', response: adminResponse);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter tabs
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _FilterChip('Pending', 'pending', _filterStatus, (value) {
                setState(() => _filterStatus = value);
              }),
              const SizedBox(width: 8),
              _FilterChip('Reviewed', 'reviewed', _filterStatus, (value) {
                setState(() => _filterStatus = value);
              }),
              const SizedBox(width: 8),
              _FilterChip('Action Taken', 'action_taken', _filterStatus, (value) {
                setState(() => _filterStatus = value);
              }),
            ],
          ),
        ),
        
        // Reports list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .orderBy('reportedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              var reports = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == _filterStatus;
              }).toList();
              
              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.report_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No $_filterStatus reports',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final doc = reports[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final report = ReportModel.fromMap(doc.id, data);
                  
                  return FutureBuilder(
                    future: Future.wait([
                      FirebaseFirestore.instance.collection('users').doc(report.reportedUserId).get(),
                      FirebaseFirestore.instance.collection('users').doc(report.reportedByUserId).get(),
                    ]),
                    builder: (context, userSnapshots) {
                      if (!userSnapshots.hasData) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: const Text('Loading user data...'),
                            subtitle: Text('Report ID: ${report.reportId}'),
                          ),
                        );
                      }
                      
                      final reportedUser = userSnapshots.data![0];
                      final reportedByUser = userSnapshots.data![1];
                      
                      final reportedUserData = reportedUser.exists
                          ? UserModel.fromMap(report.reportedUserId, reportedUser.data() as Map<String, dynamic>)
                          : null;
                      final reportedByUserData = reportedByUser.exists
                          ? UserModel.fromMap(report.reportedByUserId, reportedByUser.data() as Map<String, dynamic>)
                          : null;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(report.status),
                            child: const Icon(Icons.report, color: Colors.white, size: 20),
                          ),
                          title: Text(
                            'Report from ${reportedByUserData?.displayName ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Reason: ${report.reason}'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow('Report ID:', report.reportId),
                                  _InfoRow('Status:', report.status.toUpperCase()),
                                  _InfoRow('Reported User:', reportedUserData?.displayName ?? 'Unknown'),
                                  _InfoRow('Reported User ID:', report.reportedUserId),
                                  _InfoRow('Reporter:', reportedByUserData?.displayName ?? 'Unknown'),
                                  _InfoRow('Reported At:', _formatDate(report.reportedAt)),
                                  _InfoRow('Reason:', report.reason),
                                  if (report.description != null)
                                    _InfoRow('Description:', report.description!),
                                  if (report.adminResponse != null)
                                    _InfoRow('Admin Response:', report.adminResponse!),
                                  if (report.actionTaken != null)
                                    _InfoRow('Action Taken:', report.actionTaken!),
                                  
                                  const SizedBox(height: 16),
                                  if (report.status == 'pending')
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => _showActionDialog(report),
                                          icon: const Icon(Icons.gavel),
                                          label: const Text('Review Report'),
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
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'action_taken':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final Function(String) onSelected;
  
  const _FilterChip(this.label, this.value, this.selectedValue, this.onSelected);
  
  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selectedValue == value,
      onSelected: (_) => onSelected(value),
    );
  }
}