import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:parental_control_app/core/constants/app_colors.dart';
import 'package:parental_control_app/core/utils/media_query_helpers.dart';
import 'package:parental_control_app/core/utils/error_message_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parental_control_app/core/di/service_locator.dart';
import 'package:parental_control_app/features/user_management/domain/usecases/link_child_to_parent_usecase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parental_control_app/features/user_management/presentation/pages/child_permissions_screen.dart';
import 'package:parental_control_app/core/services/qr_code_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parental_control_app/features/location_tracking/data/services/child_location_service.dart';
import 'package:parental_control_app/features/location_tracking/data/datasources/location_remote_datasource.dart';
// import 'package:parental_control_app/features/messaging/data/services/workmanager_message_service.dart';
import 'package:parental_control_app/features/messaging/data/datasources/message_remote_datasource.dart';
import 'package:parental_control_app/features/call_logging/data/datasources/call_log_remote_datasource.dart';
import 'package:parental_control_app/features/notifications/presentation/pages/sos_emergency_screen.dart';
import 'package:parental_control_app/features/child_tracking/data/services/real_data_collection_service.dart';

class ChildScanQRScreen extends StatefulWidget {
  const ChildScanQRScreen({super.key});

  @override
  State<ChildScanQRScreen> createState() => _ChildScanQRScreenState();
}

class _ChildScanQRScreenState extends State<ChildScanQRScreen> {
  bool _scanning = true;
  bool _isCheckingLink = true;
  MobileScannerController cameraController = MobileScannerController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';
  final List<String> _selectedHobbies = [];
  
  final List<String> _availableHobbies = [
    'Reading', 'Sports', 'Music', 'Art', 'Gaming', 
    'Cooking', 'Dancing', 'Swimming', 'Cycling', 'Photography'
  ];

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyLinked();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlreadyLinked() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Check if this child is already linked by looking for their UID in any parent's childrenIds
        // This is a simplified check - in a real app, you'd want to store the parentId in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final parentUid = prefs.getString('parent_uid');
        
        if (parentUid != null) {
          // Child is already linked, check permissions first
          print('✅ CHILD ALREADY LINKED: Parent ID found: $parentUid');
          print('🔐 CHECKING PERMISSIONS: Verifying message permissions...');
          
          // Check if message permissions are granted
          final smsGranted = await Permission.sms.isGranted;
          final phoneGranted = await Permission.phone.isGranted;
          
          if (smsGranted && phoneGranted) {
            print('✅ PERMISSIONS GRANTED: Going to home screen');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ChildHomeScreen()),
            );
          } else {
            print('⚠️ PERMISSIONS MISSING: Going to permissions screen');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ChildPermissionsScreen()),
            );
          }
          return;
        }
      }
    } catch (e) {
      // If there's an error checking, continue with normal flow
    }
    
    setState(() {
      _isCheckingLink = false;
    });
    _handlePermissions();
  }

  Future<void> _handlePermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text('Please enable camera permission in app settings to scan QR codes.'),
          actions: [
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _linkChildToParent(String parentUid) async {
    final childData = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildChildProfileDialog(),
    );

    if (childData == null) {
      setState(() { _scanning = true; });
      return;
    }

    try {
      final usecase = sl<LinkChildToParentUseCase>();
      await usecase(
        parentUid: parentUid,
        firstName: childData['firstName'] ?? '',
        lastName: childData['lastName'] ?? '',
        childName: childData['name'],
        age: childData['age'],
        gender: childData['gender'],
        hobbies: childData['hobbies'],
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_type', 'child');
      await prefs.setString('child_name', childData['name']);
      await prefs.setString('parent_uid', parentUid);
      await prefs.setString('child_uid', FirebaseAuth.instance.currentUser!.uid);
      print('Stored parent_uid: $parentUid, child_uid: ${FirebaseAuth.instance.currentUser!.uid}');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully linked to parent! Welcome ${childData['name']}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Navigate to permissions screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChildPermissionsScreen()),
      );
    } catch (e) {
      print('Error linking to parent: $e');
      String errorMessage;
      if (ErrorMessageHelper.isNetworkError(e)) {
        errorMessage = ErrorMessageHelper.networkErrorLinking;
      } else {
        errorMessage = 'Error linking to parent: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      setState(() { _scanning = true; });
    }
  }

  Widget _buildChildProfileDialog() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Let\'s setup SafeNest for your Child'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Upload Photo Placeholder
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text('Upload Photo', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                
                // First Name Field
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                
                // Last Name Field
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                
                // Age Field
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Male', 'Female', 'Other'].map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // Hobbies Section
                const Text('Hobbies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableHobbies.map((hobby) {
                    final isSelected = _selectedHobbies.contains(hobby);
                    return FilterChip(
                      label: Text(hobby),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _selectedHobbies.add(hobby);
                          } else {
                            _selectedHobbies.remove(hobby);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final firstName = _firstNameController.text.trim();
                final lastName = _lastNameController.text.trim();
                
                if (firstName.isEmpty ||
                    lastName.isEmpty ||
                    _ageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                  return;
                }
                
                // Validate first name and last name
                if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(firstName)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('First name must contain only alphabetic characters')),
                  );
                  return;
                }
                
                if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(lastName)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Last name must contain only alphabetic characters')),
                  );
                  return;
                }
                
                if (firstName.length > 50 || lastName.length > 50) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name must not exceed 50 characters')),
                  );
                  return;
                }
                
                final age = int.tryParse(_ageController.text.trim());
                if (age == null || age < 3 || age > 18) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid age (3-18)')),
                  );
                  return;
                }
                
                final fullName = '$firstName $lastName'.trim();
                
                Navigator.pop(context, {
                  'firstName': firstName,
                  'lastName': lastName,
                  'name': fullName,
                  'age': age,
                  'gender': _selectedGender,
                  'hobbies': List<String>.from(_selectedHobbies),
                });
              },
              child: const Text('Connect to parent'),
            ),
          ],
        );
      },
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_scanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final raw = barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    setState(() { _scanning = false; });
    
    try {
      print('Scanned QR data: $raw'); // Debug log
      
      // Use QRCodeService to parse the data (handles both JSON and plain string)
      Map<String, dynamic>? qrData = QRCodeService.jsonToData(raw);
      print('QR parsing result: $qrData'); // Debug log
      
      String? parentUid;
      
      if (qrData != null) {
        // Handle different QR code types
        if (qrData['type'] == 'user_profile') {
          // Parent profile QR code
          if (qrData['userType'] == 'parent') {
            parentUid = qrData['uid'];
          }
        } else if (qrData['type'] == 'firebase_id') {
          // Simple Firebase ID
          parentUid = qrData['id'];
        } else if (qrData['type'] == 'family_invite') {
          // Family invite QR code
          parentUid = qrData['familyId'];
        }
      } else {
        // If JSON parsing failed, treat as plain parent ID
        print('JSON parsing failed, treating as plain parent ID: $raw');
        parentUid = raw.trim();
      }
      
      if (parentUid == null || parentUid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code format')),
        );
        setState(() { _scanning = true; });
        return;
      }
      
      print('Extracted parent UID: $parentUid'); // Debug log
      
      // Check if QR code has expired
      try {
        final parentDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(parentUid)
            .get();
        
        if (!parentDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parent account not found. Please check the QR code.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() { _scanning = true; });
          return;
        }
        
        final data = parentDoc.data();
        if (data != null) {
          final expiresAt = data['qrCodeExpiresAt'] as Timestamp?;
          
          if (expiresAt != null) {
            final expirationTime = expiresAt.toDate();
            final now = DateTime.now();
            
            if (now.isAfter(expirationTime)) {
              // QR code has expired
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(ErrorMessageHelper.expiredLinkingCode),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
              setState(() { _scanning = true; });
              return;
            }
          }
        }
      } catch (e) {
        print('Error checking QR expiration: $e');
        // If error checking expiration, continue with linking (graceful degradation)
        if (ErrorMessageHelper.isNetworkError(e)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(ErrorMessageHelper.networkErrorLinking),
              backgroundColor: Colors.red,
            ),
          );
          setState(() { _scanning = true; });
          return;
        }
      }
      
      await _linkChildToParent(parentUid);
    } catch (e) {
      print('Error scanning QR: $e'); // Debug log
      String errorMessage;
      if (ErrorMessageHelper.isNetworkError(e)) {
        errorMessage = ErrorMessageHelper.networkErrorLinking;
      } else {
        errorMessage = 'Error scanning QR: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      setState(() { _scanning = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);
    
    if (_isCheckingLink) {
      return Scaffold(
        backgroundColor: AppColors.lightCyan,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Parent QR Code'),
        backgroundColor: AppColors.lightCyan,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            ),
          ),
          Container(
            padding: EdgeInsets.all(mq.w(0.04)),
            color: AppColors.lightCyan,
            child: Column(
              children: [
                Text(
                  'Scan your parent\'s QR code to join the family',
                  style: TextStyle(
                    fontSize: mq.sp(0.04),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: mq.h(0.02)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => cameraController.toggleTorch(),
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Flash'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkCyan,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => cameraController.switchCamera(),
                      icon: const Icon(Icons.flip_camera_ios),
                      label: const Text('Switch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkCyan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  bool _isLocationTracking = false;
  late ChildLocationService _locationService;
  final RealDataCollectionService _dataCollectionService = RealDataCollectionService();
  String _childName = 'Loading...';
  String _parentName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _locationService = ChildLocationService(
      locationDataSource: LocationRemoteDataSourceImpl(firestore: FirebaseFirestore.instance),
    );
    _initializeServices();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childUid = prefs.getString('child_uid');
      final parentUid = prefs.getString('parent_uid');
      
      if (childUid != null && parentUid != null) {
        // Get child info
        final childDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(parentUid)
            .collection('children')
            .doc(childUid)
            .get();
        
        if (childDoc.exists) {
          setState(() {
            _childName = childDoc.data()?['name'] ?? 'Unknown Child';
          });
        }
        
        // Get parent info
        final parentDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(parentUid)
            .get();
        
        if (parentDoc.exists) {
          setState(() {
            _parentName = parentDoc.data()?['name'] ?? 'Unknown Parent';
          });
        }
      }
    } catch (e) {
      print('❌ Error loading user info: $e');
    }
  }

  Future<void> _initializeServices() async {
    try {
      print('🚀 INITIALIZING CHILD SERVICES: Starting location and message monitoring...');
      
      // Initialize location tracking
      await _locationService.initializeLocationTracking();
      await _locationService.startLocationTracking();
      setState(() {
        _isLocationTracking = true;
      });
      
      print('✅ LOCATION TRACKING: Started successfully');
      
      // Initialize message monitoring
      await _initializeMessageMonitoring();
      
      // Initialize URL and App Usage tracking for Firebase
      await _initializeDataCollection();
      
      print('✅ CHILD SERVICES: All services initialized');
    } catch (e) {
      print('❌ SERVICE INITIALIZATION ERROR: $e');
    }
  }

  Future<void> _initializeMessageMonitoring() async {
    try {
      print('🔍 INITIALIZING WORKMANAGER MESSAGE MONITORING: Starting background monitoring...');
      
      // Get parent ID from the linked parent
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No current user found');
        return;
      }
      
      // Get parent ID from child's document in the correct location
      // First, we need to find which parent this child belongs to
      // Since we don't have parentId, we'll search through all parents
      final parentsQuery = await FirebaseFirestore.instance
          .collection('parents')
          .get();
      
      String? parentId;
      for (final parentDoc in parentsQuery.docs) {
        final childDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(parentDoc.id)
            .collection('children')
            .doc(currentUser.uid)
            .get();
        
        if (childDoc.exists) {
          parentId = parentDoc.id;
          break;
        }
      }
      
      if (parentId == null) {
        print('❌ Child document not found in any parent\'s children collection');
        return;
      }
      
      print('✅ Found child in parent: $parentId');
      
      // Start message monitoring (without WorkManager for now)
      final messageDataSource = MessageRemoteDataSourceImpl(
        firestore: FirebaseFirestore.instance,
      );
      messageDataSource.startContinuousMonitoring(
        parentId: parentId,
        childId: currentUser.uid,
      );
      
      // Start call log monitoring
      final callLogDataSource = CallLogRemoteDataSourceImpl(
        firestore: FirebaseFirestore.instance,
      );
      callLogDataSource.startContinuousMonitoring(
        parentId: parentId,
        childId: currentUser.uid,
      );
      
      print('✅ MESSAGE MONITORING: Started successfully');
      print('✅ CALL LOG MONITORING: Started successfully');
    } catch (e) {
      print('❌ WORKMANAGER MESSAGE MONITORING ERROR: $e');
    }
  }

  Future<void> _initializeDataCollection() async {
    try {
      print('🚀 INITIALIZING DATA COLLECTION: Starting URL and App Usage tracking...');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No current user found for data collection');
        return;
      }
      
      // Get parent ID from SharedPreferences or find it
      final prefs = await SharedPreferences.getInstance();
      String? parentId = prefs.getString('parent_uid');
      
      // If parent ID not found in prefs, search for it
      if (parentId == null) {
        final parentsQuery = await FirebaseFirestore.instance
            .collection('parents')
            .get();
        
        for (final parentDoc in parentsQuery.docs) {
          final childDoc = await FirebaseFirestore.instance
              .collection('parents')
              .doc(parentDoc.id)
              .collection('children')
              .doc(currentUser.uid)
              .get();
          
          if (childDoc.exists) {
            parentId = parentDoc.id;
            break;
          }
        }
      }
      
      if (parentId == null) {
        print('❌ Parent ID not found for data collection');
        return;
      }
      
      print('✅ Found parent ID: $parentId');
      
      // Initialize real data collection (URL tracking + App Usage)
      await _dataCollectionService.initializeRealDataCollection(
        childId: currentUser.uid,
        parentId: parentId,
      );
      
      print('✅ DATA COLLECTION: URL and App Usage tracking initialized successfully');
      print('📊 Firebase Collections:');
      print('   - visitedUrls: parents/$parentId/children/${currentUser.uid}/visitedUrls');
      print('   - appUsage: parents/$parentId/children/${currentUser.uid}/appUsage');
    } catch (e) {
      print('❌ DATA COLLECTION ERROR: $e');
    }
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Dashboard'),
        backgroundColor: AppColors.lightCyan,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(mq.w(0.04)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child and Parent Info Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(mq.w(0.04)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: AppColors.primary, size: 24),
                          SizedBox(width: mq.w(0.02)),
                          Text(
                            'Child: $_childName',
                            style: TextStyle(
                              fontSize: mq.sp(0.05),
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: mq.h(0.01)),
                      Row(
                        children: [
                          Icon(Icons.family_restroom, color: AppColors.secondary, size: 24),
                          SizedBox(width: mq.w(0.02)),
                          Text(
                            'Parent: $_parentName',
                            style: TextStyle(
                              fontSize: mq.sp(0.04),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: mq.h(0.03)),
              
              Text(
                'Welcome!',
                style: TextStyle(
                  fontSize: mq.sp(0.06),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: mq.h(0.02)),
              Text(
                'You are now connected to your parent\'s account.',
                style: TextStyle(
                  fontSize: mq.sp(0.04),
                  color: AppColors.textLight,
                ),
              ),
              SizedBox(height: mq.h(0.04)),
              
              // Location Status Card
              Card(
                child: ListTile(
                  leading: Icon(
                    _isLocationTracking ? Icons.location_on : Icons.location_off,
                    color: _isLocationTracking ? Colors.green : Colors.red,
                  ),
                  title: Text(_isLocationTracking ? 'Location Sharing Active' : 'Location Sharing Inactive'),
                  subtitle: Text(_isLocationTracking 
                    ? 'Your location is being shared with your parent'
                    : 'Location sharing is not active'),
                  trailing: Switch(
                    value: _isLocationTracking,
                    onChanged: (value) async {
                      if (value) {
                        await _locationService.startLocationTracking();
                      } else {
                        await _locationService.stopLocationTracking();
                      }
                      setState(() {
                        _isLocationTracking = value;
                      });
                    },
                  ),
                ),
              ),
              
              SizedBox(height: mq.h(0.02)),
              
              // Feature Cards
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule, color: AppColors.darkCyan),
                  title: const Text('Screen Time'),
                  subtitle: const Text('View your daily usage'),
                  onTap: () {
                    // TODO: Implement screen time feature
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: AppColors.darkCyan),
                  title: const Text('Location'),
                  subtitle: const Text('Share location with parent'),
                  onTap: () {
                    // Navigate to permissions to enable background location first
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChildPermissionsScreen(),
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.emergency, color: AppColors.darkCyan),
                  title: const Text('SOS'),
                  subtitle: const Text('Emergency contact'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SOSEmergencyScreen(),
                      ),
                    );
                  },
                ),
              ),
              
              // Debug buttons for testing
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final messageDataSource = MessageRemoteDataSourceImpl(
                          firestore: FirebaseFirestore.instance,
                        );
                        await messageDataSource.resetMessageTimestamp(FirebaseAuth.instance.currentUser!.uid);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message timestamp reset!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error resetting timestamp: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reset Timestamp'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final messageDataSource = MessageRemoteDataSourceImpl(
                          firestore: FirebaseFirestore.instance,
                        );
                        await messageDataSource.monitorChildMessages(
                          parentId: 'test_parent',
                          childId: FirebaseAuth.instance.currentUser!.uid,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message monitoring triggered!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error monitoring messages: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Check Messages'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final callLogDataSource = CallLogRemoteDataSourceImpl(
                          firestore: FirebaseFirestore.instance,
                        );
                        await callLogDataSource.monitorChildCallLogs(
                          parentId: 'test_parent',
                          childId: FirebaseAuth.instance.currentUser!.uid,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Call log monitoring triggered!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error monitoring call logs: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Check Call Logs'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final callLogDataSource = CallLogRemoteDataSourceImpl(
                          firestore: FirebaseFirestore.instance,
                        );
                        await callLogDataSource.resetCallLogTimestamp(FirebaseAuth.instance.currentUser!.uid);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Call log timestamp reset!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error resetting call log timestamp: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reset Call Logs'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final callLogDataSource = CallLogRemoteDataSourceImpl(
                          firestore: FirebaseFirestore.instance,
                        );
                        await callLogDataSource.forceResetAndProcess(
                          'test_parent',
                          FirebaseAuth.instance.currentUser!.uid,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📞 Processing last 1 day call logs!'),
                            backgroundColor: Colors.indigo,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error processing call logs: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Process Call Logs'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final messageDataSource = MessageRemoteDataSourceImpl(
                          firestore: FirebaseFirestore.instance,
                        );
                        await messageDataSource.forceResetAndProcess(
                          'test_parent',
                          FirebaseAuth.instance.currentUser!.uid,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔄 Processing last 1 day messages!'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error processing messages: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Process Messages'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final messageDataSource = MessageRemoteDataSourceImpl(
                          firestore: FirebaseFirestore.instance,
                        );
                        await messageDataSource.resetMessageTimestamp(FirebaseAuth.instance.currentUser!.uid);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔄 Timestamp reset! Now processing...'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        // Auto-process after reset
                        await Future.delayed(const Duration(seconds: 1));
                        await messageDataSource.forceResetAndProcess(
                          'test_parent',
                          FirebaseAuth.instance.currentUser!.uid,
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error resetting: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Force Reset'),
                  ),
                ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

