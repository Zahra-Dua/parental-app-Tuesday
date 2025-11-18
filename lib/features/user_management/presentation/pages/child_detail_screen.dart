import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/media_query_helpers.dart';
import '../../../location_tracking/presentation/widgets/location_map_widget.dart';
import '../../../location_tracking/data/services/location_tracking_service.dart';
import '../../../location_tracking/data/datasources/location_remote_datasource.dart';
import '../widgets/suspicious_messages_card.dart';
import '../../../location_tracking/presentation/widgets/geofence_settings_card.dart';
import '../../../location_tracking/presentation/pages/geofence_configuration_screen.dart';
import '../../../messaging/presentation/pages/flagged_messages_screen.dart';
import '../../../call_logging/presentation/pages/call_history_screen.dart';
import '../../../parent_dashboard/presentation/pages/url_history_screen.dart';
import '../../../parent_dashboard/presentation/pages/app_usage_history_screen.dart';
import '../../../reports/presentation/widgets/report_card_widget.dart';
import '../../../watch_list/presentation/pages/watch_list_screen.dart';

class ChildDetailScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String parentId;

  const ChildDetailScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.parentId,
  });

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  Map<String, dynamic>? _childData;
  bool _isLoading = true;
  late LocationTrackingService _locationService;

  @override
  void initState() {
    super.initState();
    _locationService = LocationTrackingService(
      locationDataSource: LocationRemoteDataSourceImpl(
        firestore: FirebaseFirestore.instance,
      ),
    );
    _loadChildData();
  }

  Future<void> _loadChildData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('parents')
          .doc(widget.parentId)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _childData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading child data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.lightCyan,
        appBar: AppBar(
          title: Text(widget.childName),
          backgroundColor: AppColors.lightCyan,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightCyan,
      appBar: AppBar(
        title: Text('${widget.childName}\'s Phone'),
        backgroundColor: AppColors.lightCyan,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(mq.w(0.04)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Child Overview Card
            _buildChildOverviewCard(mq),
            
            SizedBox(height: mq.h(0.02)),
            
            // Live Location Card
            _buildLocationCard(mq),
            
            SizedBox(height: mq.h(0.02)),
            
        // Suspicious Messages Card
        _buildSuspiciousMessagesCard(mq),
        
        // Call History Card
        _buildCallHistoryCard(mq),
        
        SizedBox(height: mq.h(0.02)),
        
        // Watch List Card
        _buildWatchListCard(mq),
        
        SizedBox(height: mq.h(0.02)),
        
        // URL Tracking Card
        _buildUrlTrackingCard(mq),
        
        // App Usage Card
        _buildAppUsageCard(mq),
            
            SizedBox(height: mq.h(0.02)),
            
            // Activity Reports Card
            ReportCardWidget(
              childId: widget.childId,
              childName: widget.childName,
              parentId: widget.parentId,
            ),
            
            SizedBox(height: mq.h(0.02)),
            
            // Geofence Settings Card
            GeofenceSettingsCard(
              childId: widget.childId,
              childName: widget.childName,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GeofenceConfigurationScreen(
                      childId: widget.childId,
                      childName: widget.childName,
                    ),
                  ),
                );
              },
            ),
            
            SizedBox(height: mq.h(0.02)),
            
            // Child Info Card
            _buildChildInfoCard(mq),
          ],
        ),
      ),
    );
  }

  Widget _buildChildOverviewCard(MQ mq) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(mq.w(0.04)),
        child: Row(
          children: [
            // Child Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.darkCyan,
              child: Text(
                widget.childName[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: mq.sp(0.06),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            SizedBox(width: mq.w(0.03)),
            
            // Child Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.childName}\'s Phone',
                    style: TextStyle(
                      fontSize: mq.sp(0.05),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: mq.h(0.005)),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: mq.w(0.02)),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: mq.sp(0.04),
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: mq.w(0.02)),
                      Text(
                        '🔋 80%',
                        style: TextStyle(
                          fontSize: mq.sp(0.04),
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Dropdown Arrow
            Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(MQ mq) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(mq.w(0.04)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppColors.darkCyan,
                  size: 24,
                ),
                SizedBox(width: mq.w(0.02)),
                Text(
                  'Live Location',
                  style: TextStyle(
                    fontSize: mq.sp(0.05),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Navigate to full location screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationMapWidget(
                          childId: widget.childId,
                          childName: widget.childName,
                          parentId: widget.parentId,
                          locationService: _locationService,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'View Full Location',
                    style: TextStyle(
                      color: AppColors.darkCyan,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: mq.h(0.02)),
            
            // Location Map Widget
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LocationMapWidget(
                  childId: widget.childId,
                  childName: widget.childName,
                  parentId: widget.parentId,
                  locationService: _locationService,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspiciousMessagesCard(MQ mq) {
    return SuspiciousMessagesCard(
      suspiciousCount: 0, // TODO: Get actual count from Firebase
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlaggedMessagesScreen(
              childId: widget.childId,
              childName: widget.childName,
              parentId: widget.parentId,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWatchListCard(MQ mq) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: mq.w(0.04), vertical: mq.h(0.01)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WatchListScreen(
                  childId: widget.childId,
                  parentId: widget.parentId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(mq.w(0.04)),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.visibility,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                SizedBox(width: mq.w(0.04)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watch List',
                        style: TextStyle(
                          fontSize: mq.sp(0.05),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: mq.h(0.005)),
                      Text(
                        'Monitor specific contacts',
                        style: TextStyle(
                          fontSize: mq.sp(0.04),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallHistoryCard(MQ mq) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: mq.w(0.04), vertical: mq.h(0.01)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CallHistoryScreen(
                  childId: widget.childId,
                  childName: widget.childName,
                  parentId: widget.parentId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(mq.w(0.04)),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.call,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                SizedBox(width: mq.w(0.03)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Call History',
                        style: TextStyle(
                          fontSize: mq.sp(0.05),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: mq.h(0.005)),
                      Text(
                        'View ${widget.childName}\'s call logs',
                        style: TextStyle(
                          fontSize: mq.sp(0.04),
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlTrackingCard(MQ mq) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: mq.w(0.04), vertical: mq.h(0.01)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UrlHistoryScreen(
                  urls: [], // Will be fetched from Firebase
                  childId: widget.childId,
                  parentId: widget.parentId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(mq.w(0.04)),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.language,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                SizedBox(width: mq.w(0.03)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'URL Tracking',
                        style: TextStyle(
                          fontSize: mq.sp(0.05),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: mq.h(0.005)),
                      Text(
                        'Monitor ${widget.childName}\'s browsing activity',
                        style: TextStyle(
                          fontSize: mq.sp(0.04),
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppUsageCard(MQ mq) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: mq.w(0.04), vertical: mq.h(0.01)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppUsageHistoryScreen(
                  apps: [], // Will be fetched from Firebase
                  childId: widget.childId,
                  parentId: widget.parentId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(mq.w(0.04)),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.phone_android,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                SizedBox(width: mq.w(0.03)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Usage',
                        style: TextStyle(
                          fontSize: mq.sp(0.05),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: mq.h(0.005)),
                      Text(
                        'Monitor ${widget.childName}\'s app activity',
                        style: TextStyle(
                          fontSize: mq.sp(0.04),
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildInfoCard(MQ mq) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(mq.w(0.04)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Child Information',
              style: TextStyle(
                fontSize: mq.sp(0.05),
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            
            SizedBox(height: mq.h(0.02)),
            
            if (_childData != null) ...[
              _buildInfoRow(mq, 'Name', _childData!['name'] ?? 'Unknown'),
              _buildInfoRow(mq, 'Age', _childData!['age']?.toString() ?? 'Unknown'),
              _buildInfoRow(mq, 'Gender', _childData!['gender'] ?? 'Unknown'),
              
              if (_childData!['hobbies'] != null && (_childData!['hobbies'] as List).isNotEmpty) ...[
                SizedBox(height: mq.h(0.01)),
                Text(
                  'Hobbies:',
                  style: TextStyle(
                    fontSize: mq.sp(0.04),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: mq.h(0.01)),
                Wrap(
                  spacing: mq.w(0.02),
                  runSpacing: mq.h(0.01),
                  children: (_childData!['hobbies'] as List).map<Widget>((hobby) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: mq.w(0.03),
                        vertical: mq.h(0.005),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.darkCyan.withOpacity(0.3)),
                      ),
                      child: Text(
                        hobby.toString(),
                        style: TextStyle(
                          fontSize: mq.sp(0.035),
                          color: AppColors.darkCyan,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ] else ...[
              Text(
                'Child information not available',
                style: TextStyle(
                  fontSize: mq.sp(0.04),
                  color: AppColors.textLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(MQ mq, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: mq.h(0.005)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: mq.sp(0.04),
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: mq.sp(0.04),
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
