import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String reportId;
  final String reportedUserId;
  final String reportedByUserId;
  final String reason;
  final String? description;
  final DateTime reportedAt;
  final String status; // 'pending', 'reviewed', 'action_taken'
  final String? adminResponse;
  final String? actionTaken; // 'warning', 'temporary_ban', 'permanent_ban'
  final DateTime? actionDate;

  ReportModel({
    required this.reportId,
    required this.reportedUserId,
    required this.reportedByUserId,
    required this.reason,
    this.description,
    required this.reportedAt,
    this.status = 'pending',
    this.adminResponse,
    this.actionTaken,
    this.actionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'reportedUserId': reportedUserId,
      'reportedByUserId': reportedByUserId,
      'reason': reason,
      'description': description,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'status': status,
      'adminResponse': adminResponse,
      'actionTaken': actionTaken,
      'actionDate': actionDate != null ? Timestamp.fromDate(actionDate!) : null,
    };
  }

  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    return ReportModel(
      reportId: id,
      reportedUserId: map['reportedUserId'] ?? '',
      reportedByUserId: map['reportedByUserId'] ?? '',
      reason: map['reason'] ?? '',
      description: map['description'],
      reportedAt: (map['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      adminResponse: map['adminResponse'],
      actionTaken: map['actionTaken'],
      actionDate: (map['actionDate'] as Timestamp?)?.toDate(),
    );
  }
}