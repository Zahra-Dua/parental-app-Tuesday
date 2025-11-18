import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/qr_code_service.dart';

abstract class PairingRemoteDataSource {
  Future<String> generateParentQRCode({required String parentUid});
  Future<void> linkChildToParent({
    required String parentUid,
    required String firstName,
    required String lastName,
    required String childName,
    required int age,
    required String gender,
    required List<String> hobbies,
  });
  Future<bool> isChildAlreadyLinked({required String childUid});
  Future<String?> getChildParentId({required String childUid});
  Future<List<Map<String, dynamic>>> getParentChildren({required String parentUid});
}

class PairingRemoteDataSourceImpl implements PairingRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  
  PairingRemoteDataSourceImpl({required this.firestore, required this.auth});

  @override
  Future<String> generateParentQRCode({required String parentUid}) async {
    // Verify parent exists and get parent data
    final parentDoc = await firestore.collection('parents').doc(parentUid).get();
    if (!parentDoc.exists || parentDoc.data()?['userType'] != 'parent') {
      throw Exception('Parent not found or invalid user type');
    }

    final parentData = parentDoc.data()!;
    
    // Generate proper JSON QR data for parent profile
    final qrData = QRCodeService.generateUserProfileQRData(
      uid: parentUid,
      name: parentData['name'] ?? '',
      email: parentData['email'] ?? '',
      userType: 'parent',
    );
    
    // Convert to JSON string
    return QRCodeService.dataToJson(qrData);
  }

     @override
   Future<void> linkChildToParent({
     required String parentUid,
     required String firstName,
     required String lastName,
     required String childName,
     required int age,
     required String gender,
     required List<String> hobbies,
   }) async {
     final userCredential = await auth.signInAnonymously();
     final childUid = userCredential.user!.uid;

     // Create child in parent's subcollection (not in users collection)
     await firestore.collection('parents').doc(parentUid)
       .collection('children').doc(childUid).set({
         'uid': childUid,
         'firstName': firstName,
         'lastName': lastName,
         'name': childName, // Keep for backward compatibility
         'email': '',
         'userType': 'child',
         'age': age,
         'gender': gender,
         'hobbies': hobbies,
         'createdAt': FieldValue.serverTimestamp(),
         'updatedAt': FieldValue.serverTimestamp(),
       });

     // Update parent's childrenIds array
     await firestore.collection('parents').doc(parentUid).update({
       'childrenIds': FieldValue.arrayUnion([childUid]),
       'updatedAt': FieldValue.serverTimestamp(),
     });

     // Create messages subcollection for this child
     await firestore.collection('parents').doc(parentUid)
       .collection('children').doc(childUid)
       .collection('messages').doc('initial').set({
         'message': 'Child account created',
         'timestamp': FieldValue.serverTimestamp(),
         'type': 'system',
       });

     // Create location subcollection for this child
     await firestore.collection('parents').doc(parentUid)
       .collection('children').doc(childUid)
       .collection('location').doc('current').set({
         'latitude': 0.0,
         'longitude': 0.0,
         'address': 'Location not available',
         'accuracy': 0.0,
         'timestamp': FieldValue.serverTimestamp(),
         'isTrackingEnabled': false,
       });
   }

  @override
  Future<bool> isChildAlreadyLinked({required String childUid}) async {
    // Check if child exists in any parent's children subcollection
    final parentsQuery = await firestore.collection('parents').get();
    
    for (final parentDoc in parentsQuery.docs) {
      final childDoc = await firestore
          .collection('parents')
          .doc(parentDoc.id)
          .collection('children')
          .doc(childUid)
          .get();
      
      if (childDoc.exists) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<String?> getChildParentId({required String childUid}) async {
    // Find which parent has this child in their subcollection
    final parentsQuery = await firestore.collection('parents').get();
    
    for (final parentDoc in parentsQuery.docs) {
      final childDoc = await firestore
          .collection('parents')
          .doc(parentDoc.id)
          .collection('children')
          .doc(childUid)
          .get();
      
      if (childDoc.exists) {
        return parentDoc.id;
      }
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getParentChildren({required String parentUid}) async {
    final childrenSnap = await firestore.collection('parents').doc(parentUid)
        .collection('children').get();
    if (childrenSnap.docs.isEmpty) return [];
    return childrenSnap.docs.map((d) => d.data()).toList();
  }
}