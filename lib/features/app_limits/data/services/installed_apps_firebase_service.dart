import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/installed_app_firebase.dart';
import '../models/installed_app.dart';

class InstalledAppsFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sync installed apps from child device to parent
  Future<void> syncInstalledApps({
    required List<InstalledApp> apps,
    required String childId,
    required String parentId,
  }) async {
    try {
      print('🔄 Syncing ${apps.length} installed apps to Firebase...');
      
      // Get existing apps from Firebase
      final existingAppsSnapshot = await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('installedApps')
          .get();

      final existingPackageNames = existingAppsSnapshot.docs
          .map((doc) => doc.data()['packageName'] as String)
          .toSet();

      final now = DateTime.now();
      final batch = _firestore.batch();
      int newAppsCount = 0;

      for (final app in apps) {
        final appId = 'app_${app.packageName}';
        final docRef = _firestore
            .collection('parents')
            .doc(parentId)
            .collection('children')
            .doc(childId)
            .collection('installedApps')
            .doc(appId);

        final isNewInstallation = !existingPackageNames.contains(app.packageName);
        
        if (isNewInstallation) {
          newAppsCount++;
          print('🆕 New app detected: ${app.appName} (${app.packageName})');
        }

        final installedAppFirebase = InstalledAppFirebase(
          id: appId,
          packageName: app.packageName,
          appName: app.appName,
          iconPath: app.iconPath,
          versionName: app.versionName,
          versionCode: app.versionCode,
          isSystemApp: app.isSystemApp,
          installTime: app.installTime,
          lastUpdateTime: app.lastUpdateTime,
          detectedAt: now,
          isNewInstallation: isNewInstallation,
          createdAt: now,
          updatedAt: now,
        );

        batch.set(docRef, installedAppFirebase.toJson());
      }

      await batch.commit();
      print('✅ Synced ${apps.length} apps to Firebase (${newAppsCount} new installations)');

      // Notify parent about new installations
      if (newAppsCount > 0) {
        await _notifyParentAboutNewApps(
          childId: childId,
          parentId: parentId,
          newApps: apps.where((app) => !existingPackageNames.contains(app.packageName)).toList(),
        );
      }
    } catch (e) {
      print('❌ Error syncing installed apps to Firebase: $e');
      rethrow;
    }
  }

  // Get installed apps for a child
  Stream<List<InstalledAppFirebase>> getInstalledAppsStream({
    required String childId,
    required String parentId,
  }) {
    return _firestore
        .collection('parents')
        .doc(parentId)
        .collection('children')
        .doc(childId)
        .collection('installedApps')
        .orderBy('detectedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InstalledAppFirebase.fromJson(doc.data()))
          .toList();
    });
  }

  // Get newly installed apps
  Future<List<InstalledAppFirebase>> getNewlyInstalledApps({
    required String childId,
    required String parentId,
    Duration? timeWindow,
  }) async {
    try {
      final query = _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('installedApps')
          .where('isNewInstallation', isEqualTo: true);

      if (timeWindow != null) {
        final cutoffTime = DateTime.now().subtract(timeWindow);
        query.where('detectedAt', isGreaterThan: Timestamp.fromDate(cutoffTime));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => InstalledAppFirebase.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error getting newly installed apps: $e');
      return [];
    }
  }

  // Mark app as no longer new
  Future<void> markAppAsNotNew({
    required String childId,
    required String parentId,
    required String packageName,
  }) async {
    try {
      final appId = 'app_$packageName';
      await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('installedApps')
          .doc(appId)
          .update({
        'isNewInstallation': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking app as not new: $e');
    }
  }

  // Notify parent about new app installations
  Future<void> _notifyParentAboutNewApps({
    required String childId,
    required String parentId,
    required List<InstalledApp> newApps,
  }) async {
    try {
      // Store notification in Firestore
      for (final app in newApps) {
        await _firestore
            .collection('parents')
            .doc(parentId)
            .collection('notifications')
            .add({
          'type': 'new_app_installation',
          'childId': childId,
          'appName': app.appName,
          'packageName': app.packageName,
          'isSystemApp': app.isSystemApp,
          'installTime': Timestamp.fromDate(app.installTime),
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      print('✅ Notified parent about ${newApps.length} new app installations');
    } catch (e) {
      print('❌ Error notifying parent about new apps: $e');
    }
  }

  // Delete app from installed apps list (when uninstalled)
  Future<void> removeInstalledApp({
    required String childId,
    required String parentId,
    required String packageName,
  }) async {
    try {
      final appId = 'app_$packageName';
      await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('installedApps')
          .doc(appId)
          .delete();

      print('✅ Removed app from installed apps: $packageName');
    } catch (e) {
      print('❌ Error removing installed app: $e');
      rethrow;
    }
  }
}

