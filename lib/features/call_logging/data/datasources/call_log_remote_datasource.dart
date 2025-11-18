import 'dart:async';
import 'package:call_log/call_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_log_model.dart';
import '../../../notifications/data/services/notification_integration_service.dart';
import '../../../watch_list/data/services/watch_list_firebase_service.dart';

class CallLogRemoteDataSourceImpl {
  final FirebaseFirestore firestore;
  Timer? _monitorTimer;
  bool _isRunning = false;

  CallLogRemoteDataSourceImpl({required this.firestore});

  /// 🔁 Start background call log monitoring every 5 minutes
  void startContinuousMonitoring({
    required String parentId,
    required String childId,
  }) {
    if (_isRunning) {
      print('⚙️ [CallMonitor] Already running, skipping duplicate start');
      return;
    }

    print('🚀 [CallMonitor] Starting background call log monitoring (every 5 minutes)...');
    _isRunning = true;

    // Run immediately once, then every 5 minutes
    monitorChildCallLogs(parentId: parentId, childId: childId);
    _monitorTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      monitorChildCallLogs(parentId: parentId, childId: childId);
    });
  }

  /// 🛑 Stop background monitoring
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _isRunning = false;
    print('🛑 [CallMonitor] Call log monitoring stopped.');
  }

  /// 🧹 Force reset and process all recent call logs
  Future<void> forceResetAndProcess(String parentId, String childId) async {
    print('🔄 [CallLogRemote] Force resetting and processing all recent call logs...');
    
    // Reset timestamp to 0 to force reprocessing
    final prefs = await SharedPreferences.getInstance();
    final lastTsKey = 'last_call_log_timestamp_$childId';
    await prefs.setInt(lastTsKey, 0);
    
    // Process all call logs from last 1 day
    await monitorChildCallLogs(parentId: parentId, childId: childId);
    
    print('✅ [CallLogRemote] Force reset and process completed');
  }

  /// 🔄 Reset call log timestamp for testing
  Future<void> resetCallLogTimestamp(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTsKey = 'last_call_log_timestamp_$childId';
    await prefs.setInt(lastTsKey, 0); // Set to 0 instead of removing
    print('🔄 [CallLogRemote] Call log timestamp reset to 0 for child: $childId');
  }

  /// 📞 Main monitor called every 5 minutes
  Future<void> monitorChildCallLogs({
    required String parentId,
    required String childId,
  }) async {
    print('\n📞 [CallLogRemote] Checking new call logs for child: $childId');

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTsKey = 'last_call_log_timestamp_$childId';
      int lastTimestamp = prefs.getInt(lastTsKey) ?? 0;

      // ✅ Fetch call logs with error handling first
      List<CallLogEntry> callLogList = [];
      try {
        print('📞 [CallLogRemote] Attempting to fetch call logs...');
        final Iterable<CallLogEntry> callLogs = await CallLog.get();
        callLogList = callLogs.toList();
        print('📞 [CallLogRemote] Total call logs fetched: ${callLogList.length}');
        
        if (callLogList.isEmpty) {
          print('⚠️ [CallLogRemote] No call logs found. This could be due to:');
          print('   1. No call history on device');
          print('   2. Missing READ_CALL_LOG permission');
          print('   3. Device restrictions');
        }
      } catch (e) {
        print('❌ [CallLogRemote] Error fetching call logs: $e');
        print('🔍 [CallLogRemote] This might be due to missing permissions or no call logs');
        print('🔍 [CallLogRemote] Make sure READ_CALL_LOG permission is granted');
        return;
      }

      // Check if timestamp is corrupted
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      if (lastTimestamp > currentTime || lastTimestamp > 2000000000000 || lastTimestamp > 1000000000000) {
        print('⚠️ [CallLogRemote] Corrupted timestamp detected: $lastTimestamp > $currentTime');
        print('🔄 [CallLogRemote] Resetting timestamp...');
        lastTimestamp = 0;
        await prefs.setInt(lastTsKey, 0);
        print('ℹ️ [CallLogRemote] Timestamp reset to 0 - will initialize on next run');
        
        // Process recent call logs immediately
        await _processRecentCallLogs(parentId, childId);
        return;
      }

      // 🕐 First-time setup - Process last 1 day of call logs
      if (lastTimestamp == 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final oneDayAgo = DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
        
        print('🕐 [CallLogRemote] First run detected → Processing last 1 day of call logs');
        print('📅 [CallLogRemote] Processing calls from: ${DateTime.fromMillisecondsSinceEpoch(oneDayAgo)}');
        print('📅 [CallLogRemote] Processing calls until: ${DateTime.fromMillisecondsSinceEpoch(now)}');
        
        // Process all call logs from last 1 day
        int processedCount = 0;
        int uploadedCount = 0;
        
        for (final call in callLogList) {
          final ts = call.timestamp ?? 0;
          final number = call.number ?? '';
          
          // Process call logs from last 1 day
          if (ts >= oneDayAgo && ts <= now && number.trim().isNotEmpty) {
            print('🆕 [CallLogRemote] Processing call: ${call.name ?? 'Unknown'} ($number)');
            
            final callLogModel = CallLogModel.fromCallLogEntry(
              entry: call,
              childId: childId,
              parentId: parentId,
            );
            await _uploadCallLog(callLogModel);
            
            processedCount++;
            uploadedCount++;
          }
        }
        
        // Set timestamp to current time for future runs
        await prefs.setInt(lastTsKey, now);
        print('✅ [CallLogRemote] First run complete: Processed $processedCount calls, uploaded $uploadedCount');
        print('ℹ️ [CallLogRemote] Next run will process calls newer than: ${DateTime.fromMillisecondsSinceEpoch(now)}');
        return;
      }

      print('⏰ [CallLogRemote] Last processed timestamp: $lastTimestamp');
      print('🕐 [CallLogRemote] Current time: ${DateTime.now().millisecondsSinceEpoch}');
      
      // Show each call log for debugging
      for (int i = 0; i < callLogList.length && i < 10; i++) {
        final call = callLogList[i];
        final name = call.name ?? 'Unknown';
        final number = call.number ?? 'Unknown';
        final type = call.callType?.toString() ?? 'Unknown';
        final callTime = DateTime.fromMillisecondsSinceEpoch(call.timestamp ?? 0);
        final timeAgo = DateTime.now().difference(callTime).inMinutes;
        print('📞 [CallLogRemote] Call ${i+1}: $name ($number) - $type (${timeAgo}m ago)');
      }
      
      int newCallCount = 0;
      int uploadedCount = 0;
      int latestTimestamp = lastTimestamp;

      for (final call in callLogList) {
        final ts = call.timestamp ?? 0;
        final number = call.number ?? '';

        // Skip old call logs
        if (ts <= lastTimestamp) {
          final timeDiff = (lastTimestamp - ts) / 1000;
          print('⏭️ [CallLogRemote] Skipping old call: ts=$ts <= last=$lastTimestamp (${timeDiff.toStringAsFixed(1)}s ago)');
          continue;
        }
        
        // Process calls from last 1 day only
        final oneDayAgo = DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
        if (ts < oneDayAgo) {
          print('⏭️ [CallLogRemote] Skipping call older than 1 day: ts=$ts < $oneDayAgo');
          continue;
        }

        if (number.trim().isEmpty) continue;

        newCallCount++;
        print('🆕 [CallLogRemote] NEW call found: ${call.name ?? 'Unknown'} ($number)');
        print('📅 [CallLogRemote] Call timestamp: $ts (last: $lastTimestamp)');

        // 📤 Upload to Firebase
        final callLogModel = CallLogModel.fromCallLogEntry(
          entry: call,
          childId: childId,
          parentId: parentId,
        );

        await _uploadCallLog(callLogModel);
        uploadedCount++;
        print('✅ [CallLogRemote] Call log uploaded to Firebase');

        // 🔍 Check if call is suspicious and send notification
        await _checkAndNotifySuspiciousCall(
          parentId: parentId,
          childId: childId,
          call: call,
          callLogModel: callLogModel,
        );

        if (ts > latestTimestamp) latestTimestamp = ts;
      }

      // 🕓 Update timestamp only if new calls processed
      if (newCallCount > 0) {
        await prefs.setInt(lastTsKey, latestTimestamp);
        print('⏰ [CallLogRemote] Updated last processed timestamp → $latestTimestamp');
        print('📊 [CallLogRemote] New calls processed: $newCallCount, Uploaded: $uploadedCount');
        print('ℹ️ [CallLogRemote] Next run will process calls newer than: ${DateTime.fromMillisecondsSinceEpoch(latestTimestamp)}');
      } else {
        print('😴 [CallLogRemote] No new call logs found.');
        print('ℹ️ [CallLogRemote] All calls are older than: ${DateTime.fromMillisecondsSinceEpoch(lastTimestamp)}');
        print('ℹ️ [CallLogRemote] Current time: ${DateTime.now()}');
        print('ℹ️ [CallLogRemote] Time difference: ${(DateTime.now().millisecondsSinceEpoch - lastTimestamp) / 1000}s');
      }

      print('✅ [CallLogRemote] Cycle complete | Checked: ${callLogList.length}, New: $newCallCount, Uploaded: $uploadedCount');
    } catch (e) {
      print('❌ [CallLogRemote] Error during monitoring: $e');
    }
  }

  /// 🧪 Process recent call logs immediately (for testing)
  Future<void> _processRecentCallLogs(String parentId, String childId) async {
    print('🧪 [CallLogRemote] Processing recent call logs for immediate upload...');
    
    int processedCount = 0;
    int uploadedCount = 0;
    
    // Process calls from last 7 days
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    
    try {
      final Iterable<CallLogEntry> callLogs = await CallLog.get();
      
      for (final call in callLogs) {
        final ts = call.timestamp ?? 0;
        final number = call.number ?? '';
        
        if (ts < sevenDaysAgo || number.trim().isEmpty) continue;
        
        processedCount++;
        print('🆕 [CallLogRemote] Processing call: ${call.name ?? 'Unknown'} ($number)');
        
        // Upload to Firebase
        final callLogModel = CallLogModel.fromCallLogEntry(
          entry: call,
          childId: childId,
          parentId: parentId,
        );
        
        await _uploadCallLog(callLogModel);
        uploadedCount++;
      }
      
      // Update timestamp to current time
      final prefs = await SharedPreferences.getInstance();
      final lastTsKey = 'last_call_log_timestamp_$childId';
      await prefs.setInt(lastTsKey, DateTime.now().millisecondsSinceEpoch);
      
      print('✅ [CallLogRemote] Processed $processedCount calls, uploaded $uploadedCount');
    } catch (e) {
      print('❌ [CallLogRemote] Error processing recent calls: $e');
    }
  }

  /// 🔍 Check if call is suspicious and send notification
  Future<void> _checkAndNotifySuspiciousCall({
    required String parentId,
    required String childId,
    required CallLogEntry call,
    required CallLogModel callLogModel,
  }) async {
    try {
      final number = call.number ?? '';
      final name = call.name;
      final duration = call.duration ?? 0;
      final callType = call.callType;

      // Check if call is suspicious
      bool isSuspicious = false;
      String reason = '';

      // 1. Unknown number (no name)
      if (name == null || name.isEmpty || name == 'Unknown') {
        isSuspicious = true;
        reason = 'Unknown number';
      }

      // 2. Check if number is in watchlist
      try {
        final watchListService = WatchListFirebaseService();
        final isInWatchList = await watchListService.isNumberInWatchList(
          parentId: parentId,
          childId: childId,
          phoneNumber: number,
        );

        if (isInWatchList) {
          isSuspicious = true;
          final contact = await watchListService.getContactByPhoneNumber(
            parentId: parentId,
            childId: childId,
            phoneNumber: number,
          );
          reason = 'Watch List contact: ${contact?.contactName ?? number}';
        }
      } catch (e) {
        // Watchlist check error - continue
        print('ℹ️ [CallLogRemote] Watchlist check skipped: $e');
      }

      // 3. Long duration call from unknown number (> 5 minutes)
      if ((name == null || name.isEmpty) && duration > 300) {
        isSuspicious = true;
        reason = 'Long duration call from unknown number';
      }

      // 4. Multiple missed calls from same number (check recent calls)
      if (callType == CallType.missed) {
        try {
          final recentMissedCalls = await firestore
              .collection('parents')
              .doc(parentId)
              .collection('children')
              .doc(childId)
              .collection('call_logs')
              .where('number', isEqualTo: number)
              .where('type', isEqualTo: 'CallType.missed')
              .where('dateTime', isGreaterThan: DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch)
              .get();

          if (recentMissedCalls.docs.length >= 3) {
            isSuspicious = true;
            reason = 'Multiple missed calls from same number';
          }
        } catch (e) {
          print('ℹ️ [CallLogRemote] Missed calls check skipped: $e');
        }
      }

      // Send notification if suspicious
      if (isSuspicious) {
        print('🚨 [CallLogRemote] Suspicious call detected: $reason');
        final notificationService = NotificationIntegrationService();
        await notificationService.onSuspiciousCallDetected(
          parentId: parentId,
          childId: childId,
          callerNumber: number,
          callerName: name ?? 'Unknown',
          callType: callLogModel.callTypeString.toLowerCase(),
          duration: duration,
          transcription: null,
        );
        print('✅ [CallLogRemote] Suspicious call notification sent');
      }
    } catch (e) {
      print('⚠️ [CallLogRemote] Error checking suspicious call: $e');
    }
  }

  /// 📤 Upload call log to Firebase
  Future<void> _uploadCallLog(CallLogModel callLog) async {
    try {
      print('📤 [CallLogRemote] Uploading call log to Firebase...');
      print('📤 [CallLogRemote] Path: parents/${callLog.parentId}/children/${callLog.childId}/call_logs');
      print('📤 [CallLogRemote] Call: ${callLog.number} - ${callLog.callTypeString}');
      
      final docRef = await firestore
          .collection('parents')
          .doc(callLog.parentId)
          .collection('children')
          .doc(callLog.childId)
          .collection('call_logs')
          .add(callLog.toMap());
      
      print('✅ [CallLogRemote] Call log uploaded successfully with ID: ${docRef.id}');
    } catch (e) {
      print('❌ [CallLogRemote] Error uploading call log: $e');
    }
  }

  /// 🔍 Fetch call logs for parent view
  Future<List<CallLogModel>> getCallLogs({
    required String parentId,
    required String childId,
  }) async {
    try {
      print('📞 [CallLogRemote] Fetching call logs from Firebase...');
      print('📞 [CallLogRemote] Path: parents/$parentId/children/$childId/call_logs');
      
      final snapshot = await firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('call_logs')
          .orderBy('dateTime', descending: true)
          .get();

      print('📞 [CallLogRemote] Firebase query returned ${snapshot.docs.length} documents');
      
      final callLogs = snapshot.docs.map((doc) {
        print('📞 [CallLogRemote] Processing doc: ${doc.id}');
        return CallLogModel.fromMap(doc.data());
      }).toList();
      
      print('📞 [CallLogRemote] Successfully converted ${callLogs.length} call logs');
      return callLogs;
    } catch (e) {
      print('❌ [CallLogRemote] Error fetching call logs: $e');
      return [];
    }
  }
}
