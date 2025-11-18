import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parental_control_app/features/user_management/presentation/pages/parent_qr_screen.dart';
import 'package:parental_control_app/core/constants/app_colors.dart';
import 'package:parental_control_app/core/utils/media_query_helpers.dart';
import 'package:parental_control_app/core/utils/error_message_helper.dart';
import 'package:parental_control_app/core/di/service_locator.dart';
import 'package:parental_control_app/features/user_management/domain/usecases/get_parent_children_usecase.dart';
import 'package:parental_control_app/features/location_tracking/presentation/pages/all_children_map_screen.dart';
import 'package:parental_control_app/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:parental_control_app/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/child_data_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'parent_settings_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  StreamSubscription<QuerySnapshot>? _childrenStream;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _childrenStream?.cancel();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final usecase = sl<GetParentChildrenUseCase>();
        final children = await usecase(parentUid: currentUser.uid);
        setState(() {
          _children = children;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      String errorMessage;
      if (ErrorMessageHelper.isNetworkError(e)) {
        errorMessage = ErrorMessageHelper.networkErrorRetrieval;
      } else {
        errorMessage = 'Error loading children: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setupRealtimeListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _childrenStream = FirebaseFirestore.instance
          .collection('parents')
          .doc(currentUser.uid)
          .collection('children')
          .snapshots()
          .listen((QuerySnapshot snapshot) {
        print('🔄 [ParentHome] Real-time update: ${snapshot.docs.length} children');
        
        final children = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'uid': doc.id,
            'name': data['name'] ?? 'Unknown',
            'age': data['age'],
            'gender': data['gender'],
            'hobbies': data['hobbies'],
          };
        }).toList();

        setState(() {
          _children = children;
          _isLoading = false;
        });

        // Show notification if new child was added
        if (children.isNotEmpty) {
          final newChild = children.last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.child_care, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('New child connected: ${newChild['name']}'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      });
    }
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      // Navigate to all children map screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AllChildrenMapScreen(),
        ),
      );
    } else if (index == 3) {
      // Navigate to notifications screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<NotificationBloc>(),
            child: const NotificationsScreen(),
          ),
        ),
      );
    } else if (index == 4) {
      // Navigate to settings screen
        Navigator.push(
          context,
          MaterialPageRoute(
          builder: (context) => const ParentSettingsScreen(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);
    
    return Scaffold(
      backgroundColor: AppColors.lightCyan,
      appBar: AppBar(
        backgroundColor: AppColors.lightCyan,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.black),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 30,
              width: 30,
            ),
            const SizedBox(width: 8),
            const Text(
              'SafeNest',
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ParentSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, Parent',
                        style: TextStyle(
                          fontSize: mq.sp(0.06),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Keep your children safe and connected',
                        style: TextStyle(
                          fontSize: mq.sp(0.04),
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Generate QR Code Card
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ParentQRScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.darkCyan,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.qr_code,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Generate QR Code",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Create a QR code for your child to scan and join",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ParentQRScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.darkCyan,
                        ),
                        child: const Text("Generate QR"),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Connected Children Section
              Text(
                "Connected Children",
                style: TextStyle(
                  fontSize: mq.sp(0.05),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_children.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.child_care, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        "No children connected yet",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Generate a QR code and have your child scan it",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    // Children Profiles
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _children.length + 1, // +1 for Add Child button
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          if (index == _children.length) {
                            // Add Child Button
                            return Container(
                              margin: const EdgeInsets.only(right: 16),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ParentQRScreen(),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.darkCyan,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Add Child',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final child = _children[index];
                          return Container(
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: AppColors.darkCyan,
                                  child: Text(
                                    child['name']?[0]?.toUpperCase() ?? 'C',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  child['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Children's Activity
                    Text(
                      "Children's Activity",
                      style: TextStyle(
                        fontSize: mq.sp(0.05),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Child Data Cards
                    ..._children.map((child) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ChildDataCard(
                        childId: child['id'] ?? child['uid'] ?? '',
                        childName: child['name'] ?? 'Unknown',
                        parentId: FirebaseAuth.instance.currentUser!.uid,
                        onChildDeleted: () {
                          // Refresh the children list when a child is deleted
                          _loadChildren();
                        },
                        onChildUpdated: () {
                          // Refresh the children list when a child is updated
                          _loadChildren();
                        },
                      ),
                    )),

                    const SizedBox(height: 24),

                    // Children's Location
                    Text(
                      "Children's Location",
                      style: TextStyle(
                        fontSize: mq.sp(0.05),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                            builder: (context) => const AllChildrenMapScreen(),
                            ),
                          );
                      },
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Map View',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Location tracking will be implemented',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recent Alerts
                    Text(
                      "Recent Alerts",
                      style: TextStyle(
                        fontSize: mq.sp(0.05),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildAlertItem('Emily visited a new website', Icons.language),
                          const Divider(),
                          _buildAlertItem('John left the designated safe zone', Icons.location_off),
                          const Divider(),
                          _buildAlertItem('Emily reached daily screen time limit', Icons.schedule),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20), // Extra space at bottom
            ],
          ),
        ),
      ),
     
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        selectedItemColor: AppColors.darkCyan,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notice'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
