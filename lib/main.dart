import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:parental_control_app/core/di/service_locator.dart';
import 'package:parental_control_app/features/user_management/presentation/blocs/auth_bloc/auth_bloc.dart';
import 'package:parental_control_app/features/notifications/data/services/fcm_service.dart';
import 'package:parental_control_app/features/notifications/data/services/notification_handler.dart';
import 'core/constants/app_colors.dart';
import 'core/di/service_locator.dart' as di;
import 'features/user_management/presentation/pages/splash_screen.dart';
import 'firebase_options.dart';

// ✅ Import WorkManager service
// import 'package:parental_control_app/features/messaging/data/services/workmanager_message_service.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Handle background message
  print('🔔 Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with proper options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize local notifications
  await initializeLocalNotifications();
  
  // Initialize FCM service
  await FCMService().initialize();
  
  // Set up foreground message handler
  FirebaseMessaging.onMessage.listen(handleForegroundMessage);
  
  // Handle notification taps when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🔔 Notification opened app: ${message.messageId}');
    // Handle navigation based on notification data
  });
  
  // Check if app was opened from a notification
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('🔔 App opened from notification: ${initialMessage.messageId}');
    // Handle navigation
  }

  await di.initServiceLocator(); // Initialize GetIt service locator

  // ✅ Initialize WorkManager for background message monitoring
  // WorkManager temporarily disabled due to compatibility issues
  // try {
  //   print('🚀 INITIALIZING WORKMANAGER MESSAGE MONITORING...');
  //   await WorkManagerMessageService.initialize();
  //   print('✅ WORKMANAGER MESSAGE MONITORING INITIALIZED SUCCESSFULLY');
  // } catch (e) {
  //   print('❌ FAILED TO INITIALIZE WORKMANAGER: $e');
  // }

  runApp(const SafeNestApp());
}

class SafeNestApp extends StatelessWidget {
  const SafeNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<AuthBloc>()),
        // Add other BlocProviders here if you have them
      ],
      child: MaterialApp(
        title: 'SafeNest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.offWhite,
          primaryColor: AppColors.darkCyan,
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.lightCyan,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.black),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.black),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
