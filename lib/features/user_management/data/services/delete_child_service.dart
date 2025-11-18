import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeleteChildService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Delete child and all associated data from Firebase
  Future<bool> deleteChild({
    required String parentId,
    required String childId,
  }) async {
    try {
      print('🗑️ [DeleteChild] Starting deletion for child: $childId');

      // 1. Delete child's location data
      await _deleteLocationData(parentId, childId);
      
      // 2. Delete child's flagged messages
      await _deleteFlaggedMessages(parentId, childId);
      
      // 3. Delete child's geofence data
      await _deleteGeofenceData(parentId, childId);
      
      // 4. Delete child's general messages
      await _deleteMessages(parentId, childId);
      
      // 5. Delete child document from parent's children collection
      await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .delete();

      // 6. Clear child's local data
      await _clearChildLocalData(childId);

      print('✅ [DeleteChild] Child $childId deleted successfully');
      return true;
    } catch (e) {
      print('❌ [DeleteChild] Error deleting child: $e');
      return false;
    }
  }

  /// Delete child's location data
  Future<void> _deleteLocationData(String parentId, String childId) async {
    try {
      final locationRef = _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('location');

      // Delete current location
      await locationRef.doc('current').delete();

      // Delete location history (batch delete)
      final locationHistory = await locationRef.get();
      final batch = _firestore.batch();
      
      for (final doc in locationHistory.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [DeleteChild] Location data deleted');
    } catch (e) {
      print('⚠️ [DeleteChild] Error deleting location data: $e');
    }
  }

  /// Delete child's flagged messages
  Future<void> _deleteFlaggedMessages(String parentId, String childId) async {
    try {
      final flaggedMessagesRef = _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('flagged_messages');

      // Batch delete all flagged messages
      final flaggedMessages = await flaggedMessagesRef.get();
      final batch = _firestore.batch();
      
      for (final doc in flaggedMessages.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [DeleteChild] Flagged messages deleted');
    } catch (e) {
      print('⚠️ [DeleteChild] Error deleting flagged messages: $e');
    }
  }

  /// Delete child's geofence data
  Future<void> _deleteGeofenceData(String parentId, String childId) async {
    try {
      final geofenceRef = _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('geofences');

      // Batch delete all geofences
      final geofences = await geofenceRef.get();
      final batch = _firestore.batch();
      
      for (final doc in geofences.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [DeleteChild] Geofence data deleted');
    } catch (e) {
      print('⚠️ [DeleteChild] Error deleting geofence data: $e');
    }
  }

  /// Delete child's general messages
  Future<void> _deleteMessages(String parentId, String childId) async {
    try {
      final messagesRef = _firestore.collection('messages');
      
      // Delete messages where childId matches
      final messages = await messagesRef
          .where('childId', isEqualTo: childId)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [DeleteChild] General messages deleted');
    } catch (e) {
      print('⚠️ [DeleteChild] Error deleting general messages: $e');
    }
  }

  /// Clear child's local data from SharedPreferences
  Future<void> _clearChildLocalData(String childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove child-specific data
      await prefs.remove('child_uid');
      await prefs.remove('last_message_timestamp_$childId');
      
      print('✅ [DeleteChild] Local data cleared');
    } catch (e) {
      print('⚠️ [DeleteChild] Error clearing local data: $e');
    }
  }
}
