import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/media_query_helpers.dart';
import '../../../../core/utils/error_message_helper.dart';
import '../../../location_tracking/data/models/location_model.dart';
import '../pages/child_detail_screen.dart';
import '../pages/edit_child_profile_screen.dart';
import '../../data/services/delete_child_service.dart';

class ChildDataCard extends StatefulWidget {
  final String childId;
  final String childName;
  final String parentId;
  final VoidCallback? onChildDeleted;
  final VoidCallback? onChildUpdated;

  const ChildDataCard({
    super.key,
    required this.childId,
    required this.childName,
    required this.parentId,
    this.onChildDeleted,
    this.onChildUpdated,
  });

  @override
  State<ChildDataCard> createState() => _ChildDataCardState();
}

class _ChildDataCardState extends State<ChildDataCard> {
  LocationModel? _currentLocation;
  bool _isLoading = true;
  final DeleteChildService _deleteChildService = DeleteChildService();

  @override
  void initState() {
    super.initState();
    _loadChildLocation();
  }

  Future<void> _loadChildLocation() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('parents')
          .doc(widget.parentId)
          .collection('children')
          .doc(widget.childId)
          .collection('location')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _currentLocation = LocationModel.fromMap(doc.data()!);
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
    }
  }

  Future<void> _editChild() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditChildProfileScreen(
          childId: widget.childId,
          parentId: widget.parentId,
        ),
      ),
    );

    // If update was successful, refresh the parent widget
    if (result == true && widget.onChildUpdated != null) {
      widget.onChildUpdated!();
    }
  }

  Future<void> _deleteChild() async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Child'),
          content: Text(
            'Are you sure you want to delete ${widget.childName}? This action cannot be undone and will remove all data associated with this child.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Deleting child...'),
              ],
            ),
          );
        },
      );

      try {
        final success = await _deleteChildService.deleteChild(
          parentId: widget.parentId,
          childId: widget.childId,
        );

        // Close loading dialog
        Navigator.of(context).pop();

        if (success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.childName} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Notify parent widget to refresh
          if (widget.onChildDeleted != null) {
            widget.onChildDeleted!();
          }
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete child. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        String errorMessage;
        if (ErrorMessageHelper.isNetworkError(e)) {
          errorMessage = ErrorMessageHelper.networkErrorProfileDeletion;
        } else {
          errorMessage = 'Error deleting child: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);

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
            // Navigate to child detail screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChildDetailScreen(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Child Header
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.childName,
                        style: TextStyle(
                          fontSize: mq.sp(0.05),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Child',
                        style: TextStyle(
                          fontSize: mq.sp(0.04),
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Location Status
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: mq.w(0.03),
                    vertical: mq.h(0.008),
                  ),
                  decoration: BoxDecoration(
                    color: _currentLocation != null ? Colors.green.shade400 : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (_currentLocation != null ? Colors.green : Colors.grey).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: mq.w(0.02)),
                      Text(
                        _currentLocation != null ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: mq.sp(0.035),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: mq.w(0.02)),
                // 3 Dots Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                  onSelected: (String value) {
                    if (value == 'edit') {
                      _editChild();
                    } else if (value == 'delete') {
                      _deleteChild();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppColors.darkCyan, size: 20),
                          SizedBox(width: 8),
                          Text('Edit Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Child'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: mq.h(0.02)),
            
            // Location Info
            if (_isLoading)
              Container(
                padding: EdgeInsets.symmetric(vertical: mq.h(0.02)),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkCyan),
                  ),
                ),
              )
            else if (_currentLocation != null) ...[
              Container(
                padding: EdgeInsets.all(mq.w(0.03)),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(mq.w(0.02)),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: Colors.red.shade600,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: mq.w(0.03)),
                        Expanded(
                          child: Text(
                            _currentLocation!.address,
                            style: TextStyle(
                              fontSize: mq.sp(0.04),
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mq.h(0.01)),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(mq.w(0.015)),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.access_time,
                            color: Colors.blue.shade600,
                            size: 16,
                          ),
                        ),
                        SizedBox(width: mq.w(0.03)),
                        Text(
                          'Last seen: ${_formatTime(_currentLocation!.timestamp)}',
                          style: TextStyle(
                            fontSize: mq.sp(0.035),
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(mq.w(0.03)),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(mq.w(0.02)),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_off,
                        color: Colors.grey.shade600,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: mq.w(0.03)),
                    Text(
                      'Location not available',
                      style: TextStyle(
                        fontSize: mq.sp(0.04),
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
          ],
        ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
