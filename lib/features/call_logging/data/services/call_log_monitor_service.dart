import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../datasources/call_log_remote_datasource.dart';

/// Simple call log monitoring service
class CallLogMonitorService {
  final CallLogRemoteDataSourceImpl dataSource;
  Timer? _timer;

  CallLogMonitorService({required this.dataSource});

  Future<void> initialize({int frequencyMinutes = 5}) async {
    print('🚀 [CallLogMonitor] Starting call log monitoring (every $frequencyMinutes minutes)');
    await _monitorCallLogs();
    _timer = Timer.periodic(Duration(minutes: frequencyMinutes), (timer) {
      _monitorCallLogs();
    });
    print('✅ [CallLogMonitor] Call log monitoring started');
  }

  Future<void> _monitorCallLogs() async {
    try {
      print('🔔 [CallLogMonitor] Starting call log monitoring cycle');
      final prefs = await SharedPreferences.getInstance();
      String? parentId = prefs.getString('parent_uid');
      String? childId = prefs.getString('child_uid');

      print('🔍 [CallLogMonitor] parent_uid: $parentId, child_uid: $childId');

      if (parentId == null || childId == null) {
        print('❌ [CallLogMonitor] parent_uid or child_uid missing - skipping call log monitoring');
        return;
      }

      final isLinked = await dataSource.firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .get()
          .then((doc) => doc.exists);

      print('🔗 [CallLogMonitor] Child linked to parent: $isLinked');

      if (!isLinked) {
        print('⚠️ [CallLogMonitor] Child not linked to parent yet - skipping call log monitoring');
        return;
      }

      await Future.delayed(Duration(milliseconds: 500)); // Delay to prevent permission conflicts
      print('🚀 [CallLogMonitor] Calling monitorChildCallLogs...');
      await dataSource.monitorChildCallLogs(parentId: parentId, childId: childId);
      print('✅ [CallLogMonitor] Call log monitoring cycle completed');
    } catch (e, st) {
      print('❌ [CallLogMonitor] Call log monitoring error: $e\n$st');
      if (e.toString().contains('Reply already submitted')) {
        print('⚠️ [CallLogMonitor] Permission handling conflict - will retry next cycle');
      }
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    print('🛑 [CallLogMonitor] Call log monitoring stopped');
  }
}
