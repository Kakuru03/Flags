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
  String _filterStatus = 'pending';
  final Set<String> _processingReports = {}; // Track reports being processed

  // Show error message with optional retry callback
  void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(label: 'Retry', onPressed: onRetry)
            : null,
      ),
    );
  }

  // Show success message
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Core action handler with robust error handling
  Future<void> _handleReportAction(ReportModel report, String action,
      {String? response}) async {
    // Prevent duplicate processing
    if (_processingReports.contains(report.reportId)) {
      _showErrorSnackBar('Already processing this report, please wait...');
      return;
    }

    setState(() {
      _processingReports.add(report.reportId);
    });

    try {
      final reportRef = FirebaseFirestore.instance
          .collection('reports')
          .doc(report.reportId);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in as admin to perform actions.');
      }

      switch (action) {
        case 'warning':
          await reportRef.update({
            'status': 'action_taken',
            'actionTaken': 'warning',
            'adminResponse': response ??
                'Warning issued for inappropriate behavior',
            'actionDate': FieldValue.serverTimestamp(),
          });

          // Add warning to user's warnings subcollection
          await FirebaseFirestore.instance
              .collection('users')
              .doc(report.reportedUserId)
              .collection('warnings')
              .add({
            'reason': report.reason,
            'description': report.description,
            'issuedBy': currentUser.uid,
            'issuedAt': FieldValue.serverTimestamp(),
            'reportId': report.reportId,
          });

          _showSuccessSnackBar('Warning issued to user');
          break;

        case 'temporary_ban':
          await reportRef.update({
            'status': 'action_taken',
            'actionTaken': 'temporary_ban',
            'adminResponse':
                response ?? 'Temporary ban for violating community guidelines',
            'actionDate': FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(report.reportedUserId)
              .update({
            'isBanned': true,
            'banReason': report.reason,
            'banExpiry': Timestamp.fromDate(
                DateTime.now().add(const Duration(days: 30))),
            'banDate': FieldValue.serverTimestamp(),
          });

          _showSuccessSnackBar('User has been temporarily banned for 30 days');
          break;

        case 'permanent_ban':
          await reportRef.update({
            'status': 'action_taken',
            'actionTaken': 'permanent_ban',
            'adminResponse':
                response ?? 'Permanent ban for serious violation',
            'actionDate': FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(report.reportedUserId)
              .update({
            'isBanned': true,
            'banReason': report.reason,
            'banExpiry': null,
            'banDate': FieldValue.serverTimestamp(),
          });

          _showSuccessSnackBar('User has been permanently banned');
          break;

        case 'dismiss':
          await reportRef.update({
            'status': 'reviewed',
            'adminResponse':
                response ?? 'No action taken - insufficient evidence',
            'actionDate': FieldValue.serverTimestamp(),
          });

          _showSuccessSnackBar('Report dismissed');
          break;
      }

      // Refresh the list after successful action
      setState(() {});
    } catch (e, stackTrace) {
      debugPrint('Error handling report: $e\n$stackTrace');
      _showErrorSnackBar('Failed to ${_actionVerb(action)}: ${e.toString()}',
          onRetry: () => _handleReportAction(report, action, response: response));
    } finally {
      setState(() {
        _processingReports.remove(report.reportId);
      });
    }
  }

  String _actionVerb(String action) {
    switch (action) {
      case 'warning':
        return 'issue warning';
      case 'temporary_ban':
        return 'apply temporary ban';
      case 'permanent_ban':
        return 'apply permanent ban';
      case 'dismiss':
        return 'dismiss report';
      default:
        return 'perform action';
    }
  }

  void _showActionDialog(ReportModel report) {
    String? adminResponse;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reported User ID: ${report.reportedUserId}'),
              Text('Reason: ${report.reason}'),
              const SizedBox(height: 8),
              if (report.description != null)
                Text('Description: ${report.description!}'),
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
                _handleReportAction(report, 'temporary_ban',
                    response: adminResponse);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Permanent'),
              onTap: () {
                Navigator.pop(context);
                _handleReportAction(report, 'permanent_ban',
                    response: adminResponse);
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
              _FilterChip('Action Taken', 'action_taken', _filterStatus,
                  (value) {
                setState(() => _filterStatus = value);
              }),
            ],
          ),
        ),
        // Reports list with advanced error handling
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .orderBy('reportedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // Global error (network, permissions)
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading reports:\n${snapshot.error}',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Force refresh by resetting the stream
                          setState(() {});
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter reports locally
              final reports = snapshot.data!.docs.where((doc) {
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

                  return _ReportCard(
                    report: report,
                    isProcessing: _processingReports.contains(report.reportId),
                    onAction: _showActionDialog,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Separate widget to handle individual user data fetching with error handling
class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final bool isProcessing;
  final Function(ReportModel) onAction;

  const _ReportCard({
    required this.report,
    required this.isProcessing,
    required this.onAction,
  });

  Future<Map<String, UserModel?>> _fetchUsers() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(report.reportedUserId).get(),
        FirebaseFirestore.instance.collection('users').doc(report.reportedByUserId).get(),
      ]);
      final reportedUserDoc = results[0];
      final reportedByUserDoc = results[1];

      final reportedUser = reportedUserDoc.exists
          ? UserModel.fromMap(report.reportedUserId,
              reportedUserDoc.data() as Map<String, dynamic>)
          : null;
      final reportedByUser = reportedByUserDoc.exists
          ? UserModel.fromMap(report.reportedByUserId,
              reportedByUserDoc.data() as Map<String, dynamic>)
          : null;

      return {'reported': reportedUser, 'reporter': reportedByUser};
    } catch (e) {
      debugPrint('Error fetching users for report ${report.reportId}: $e');
      return {'reported': null, 'reporter': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, UserModel?>>(
      future: _fetchUsers(),
      builder: (context, snapshot) {
        UserModel? reportedUser;
        UserModel? reporterUser;

        if (snapshot.hasData) {
          reportedUser = snapshot.data!['reported'];
          reporterUser = snapshot.data!['reporter'];
        }

        // Show loading indicator only on first load, otherwise show card even if error
        if (snapshot.connectionState == ConnectionState.waiting &&
            reportedUser == null &&
            reporterUser == null) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: const Text('Loading user data...'),
              subtitle: Text('Report ID: ${report.reportId}'),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(report.status),
              child: const Icon(Icons.report, color: Colors.white, size: 20),
            ),
            title: Text(
              'Report from ${reporterUser?.displayName ?? 'Unknown user'}',
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
                    _InfoRow('Reported User:',
                        reportedUser?.displayName ?? 'Unknown (ID: ${report.reportedUserId})'),
                    _InfoRow('Reporter:',
                        reporterUser?.displayName ?? 'Unknown (ID: ${report.reportedByUserId})'),
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
                            onPressed: isProcessing ? null : () => onAction(report),
                            icon: isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.gavel),
                            label: isProcessing ? const Text('Processing...') : const Text('Review Report'),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
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