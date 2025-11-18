import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:call_log/call_log.dart';
import 'package:parental_control_app/core/constants/app_colors.dart';
import 'package:parental_control_app/core/utils/media_query_helpers.dart';
import '../../data/datasources/call_log_remote_datasource.dart';
import '../../data/models/call_log_model.dart';
import '../widgets/call_history_card.dart';

class CallHistoryScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String parentId;

  const CallHistoryScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.parentId,
  });

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final CallLogRemoteDataSourceImpl _dataSource = CallLogRemoteDataSourceImpl(
    firestore: FirebaseFirestore.instance,
  );
  
  List<CallLogModel> _callLogs = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
  }

  Future<void> _loadCallLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('📞 [CallHistory] Loading call logs for parent: ${widget.parentId}, child: ${widget.childId}');
      
      final callLogs = await _dataSource.getCallLogs(
        parentId: widget.parentId,
        childId: widget.childId,
      );
      
      print('📞 [CallHistory] Loaded ${callLogs.length} call logs from Firebase');
      if (callLogs.isNotEmpty) {
        print('📞 [CallHistory] First call log: ${callLogs.first.number} - ${callLogs.first.callTypeString}');
        print('📞 [CallHistory] Last call log: ${callLogs.last.number} - ${callLogs.last.callTypeString}');
      } else {
        print('⚠️ [CallHistory] No call logs found in Firebase');
      }
      
      setState(() {
        _callLogs = callLogs;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ [CallHistory] Error loading call logs: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading call logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<CallLogModel> get _filteredCallLogs {
    if (_selectedFilter == 'All') {
      return _callLogs;
    }
    
    CallType? filterType;
    switch (_selectedFilter) {
      case 'Incoming':
        filterType = CallType.incoming;
        break;
      case 'Outgoing':
        filterType = CallType.outgoing;
        break;
      case 'Missed':
        filterType = CallType.missed;
        break;
    }
    
    return _callLogs.where((call) => call.type == filterType).toList();
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
        title: Text(
          '${widget.childName}\'s Call History',
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCallLogs,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips
            Container(
              padding: EdgeInsets.symmetric(horizontal: mq.w(0.04), vertical: mq.h(0.01)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    'Incoming',
                    'Outgoing',
                    'Missed',
                  ].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: EdgeInsets.only(right: mq.w(0.02)),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        selectedColor: AppColors.darkCyan.withOpacity(0.2),
                        checkmarkColor: AppColors.darkCyan,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.darkCyan : AppColors.textDark,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            // Call Logs List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkCyan),
                      ),
                    )
                  : _filteredCallLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.call_end,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: mq.h(0.02)),
                              Text(
                                'No call logs found',
                                style: TextStyle(
                                  fontSize: mq.sp(0.05),
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: mq.h(0.01)),
                              Text(
                                'Call logs will appear here once calls are made',
                                style: TextStyle(
                                  fontSize: mq.sp(0.04),
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: mq.h(0.01)),
                          itemCount: _filteredCallLogs.length,
                          itemBuilder: (context, index) {
                            final callLog = _filteredCallLogs[index];
                            return CallHistoryCard(
                              callLog: callLog,
                              onTap: () {
                                // TODO: Show call details dialog
                                _showCallDetails(callLog);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCallDetails(CallLogModel callLog) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(callLog.name ?? callLog.number),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (callLog.name != null) ...[
              Text('Number: ${callLog.number}'),
              const SizedBox(height: 8),
            ],
            Text('Type: ${callLog.callTypeString}'),
            const SizedBox(height: 8),
            Text('Duration: ${callLog.durationString}'),
            const SizedBox(height: 8),
            Text('Date: ${_formatFullDate(callLog.dateTime)}'),
            const SizedBox(height: 8),
            Text('Time: ${_formatFullTime(callLog.dateTime)}'),
            if (callLog.simDisplayName != null) ...[
              const SizedBox(height: 8),
              Text('SIM: ${callLog.simDisplayName}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatFullTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
