import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/error_report.dart';

class ErrorReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = 'errorReports';

  /// Submit a new error report
  Future<bool> submitReport(ErrorReport report) async {
    try {
      await _firestore.collection(_collectionName).add(report.toMap());
      debugPrint('✅ Error report submitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting error report: $e');
      return false;
    }
  }

  /// Get all error reports (Admin only)
  Stream<List<ErrorReport>> getAllReports() {
    return _firestore
        .collection(_collectionName)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ErrorReport.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Mark a report as resolved
  Future<bool> resolveReport(String reportId, bool isResolved) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(reportId)
          .update({'isResolved': isResolved});
      return true;
    } catch (e) {
      debugPrint('❌ Error updating report status: $e');
      return false;
    }
  }

  /// Delete a report
  Future<bool> deleteReport(String reportId) async {
    try {
      await _firestore.collection(_collectionName).doc(reportId).delete();
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting report: $e');
      return false;
    }
  }
}
