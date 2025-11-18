import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class AuthRemoteDataSource {
  Future<User> signIn({required String email, required String password});
  Future<User> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String userType,
  });
  Future<User> signInAnonymously();
  Future<void> sendPasswordResetEmail({required String email});
  Future<String> verifyPasswordResetCode({required String code});
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({required this.auth, required this.firestore});

  @override
  Future<User> signIn({required String email, required String password}) async {
    try {
      print('🔥 [AuthRemote] Starting signin for: $email');
      
      // Retry logic for network issues
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          final cred = await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          print('✅ [AuthRemote] Signin successful');
          return cred.user!;
        } on FirebaseAuthException catch (e) {
          print('❌ [AuthRemote] Firebase Auth Error: ${e.code} - ${e.message}');
          
          // Handle specific Firebase Auth errors
          if (e.code == 'network-request-failed' || 
              e.code == 'too-many-requests' ||
              e.message?.contains('interrupted') == true ||
              e.message?.contains('unreachable') == true) {
            
            retryCount++;
            if (retryCount < maxRetries) {
              print('🔄 [AuthRemote] Retrying signin (attempt $retryCount/$maxRetries)');
              await Future.delayed(Duration(seconds: retryCount * 2));
              continue;
            }
          }
          
          // Re-throw Firebase Auth specific errors
          throw _getUserFriendlyError(e);
        } catch (e) {
          print('❌ [AuthRemote] General Error: $e');
          
          // Handle network connectivity issues
          if (e.toString().contains('SocketException') ||
              e.toString().contains('HandshakeException') ||
              e.toString().contains('interrupted') ||
              e.toString().contains('unreachable')) {
            
            retryCount++;
            if (retryCount < maxRetries) {
              print('🔄 [AuthRemote] Retrying due to network issue (attempt $retryCount/$maxRetries)');
              await Future.delayed(Duration(seconds: retryCount * 2));
              continue;
            }
          }
          
          throw 'Network connection failed. Please check your internet connection and try again.';
        }
      }
      
      throw 'Unable to sign in. Please check your internet connection and try again.';
    } catch (e) {
      print('❌ [AuthRemote] Final signin error: $e');
      rethrow;
    }
  }

  @override
  Future<User> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String userType,
  }) async {
    try {
      print('🔥 [AuthRemote] Starting signup for: $email');
      
      // Retry logic for network issues
      int retryCount = 0;
      const maxRetries = 3;
      
      // Combine firstName and lastName for display name
      final fullName = '$firstName $lastName'.trim();
      
      while (retryCount < maxRetries) {
        try {
          final cred = await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          
          print('✅ [AuthRemote] Firebase Auth successful');
          final uid = cred.user!.uid;
          
          if (userType == 'parent') {
            print('📝 [AuthRemote] Creating parent document in Firestore');
            await firestore.collection('parents').doc(uid).set({
              'uid': uid,
              'firstName': firstName,
              'lastName': lastName,
              'name': fullName, // Keep 'name' for backward compatibility
              'email': email,
              'userType': userType,
              'childrenIds': [],
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            print('✅ [AuthRemote] Parent document created successfully');
          } else if (userType == 'child') {
            // Note: Child signup through this screen is not the normal flow
            // Children are typically created via QR code scanning
            // This is just for edge case handling
            print('⚠️ [AuthRemote] Child signup detected - this is not the normal flow');
            // Child accounts are created in parent's subcollection via QR scanning
            // We don't create a standalone child document here
          }
          
          // Update display name with full name
          await cred.user!.updateDisplayName(fullName);
          print('✅ [AuthRemote] Display name updated');
          
          return cred.user!;
        } on FirebaseAuthException catch (e) {
          print('❌ [AuthRemote] Firebase Auth Error: ${e.code} - ${e.message}');
          
          // Handle specific Firebase Auth errors
          if (e.code == 'network-request-failed' || 
              e.code == 'too-many-requests' ||
              e.message?.contains('interrupted') == true ||
              e.message?.contains('unreachable') == true) {
            
            retryCount++;
            if (retryCount < maxRetries) {
              print('🔄 [AuthRemote] Retrying signup (attempt $retryCount/$maxRetries)');
              await Future.delayed(Duration(seconds: retryCount * 2));
              continue;
            }
          }
          
          // Re-throw Firebase Auth specific errors
          throw _getUserFriendlyError(e);
        } catch (e) {
          print('❌ [AuthRemote] General Error: $e');
          
          // Handle network connectivity issues
          if (e.toString().contains('SocketException') ||
              e.toString().contains('HandshakeException') ||
              e.toString().contains('interrupted') ||
              e.toString().contains('unreachable')) {
            
            retryCount++;
            if (retryCount < maxRetries) {
              print('🔄 [AuthRemote] Retrying due to network issue (attempt $retryCount/$maxRetries)');
              await Future.delayed(Duration(seconds: retryCount * 2));
              continue;
            }
          }
          
          throw 'Network connection failed. Please check your internet connection and try again.';
        }
      }
      
      throw 'Unable to create account. Please check your internet connection and try again.';
    } catch (e) {
      print('❌ [AuthRemote] Final signup error: $e');
      rethrow;
    }
  }

  @override
  Future<User> signInAnonymously() async {
    final cred = await auth.signInAnonymously();
    return cred.user!;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<String> verifyPasswordResetCode({required String code}) async {
    // returns the user's email for that code if valid
    final email = await auth.verifyPasswordResetCode(code);
    return email;
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    await auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  /// Convert Firebase Auth errors to user-friendly messages
  String _getUserFriendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes before trying again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email or try logging in.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address. Please enter a valid email.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please check your email or sign up.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'requires-recent-login':
        return 'Please log in again to complete this action.';
      default:
        if (e.message?.contains('interrupted') == true || 
            e.message?.contains('unreachable') == true) {
          return 'Network connection interrupted. Please check your internet connection and try again.';
        }
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
