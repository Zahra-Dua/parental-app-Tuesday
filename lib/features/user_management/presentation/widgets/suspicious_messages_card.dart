import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/media_query_helpers.dart';

class SuspiciousMessagesCard extends StatelessWidget {
  final int suspiciousCount;
  final VoidCallback? onTap;

  const SuspiciousMessagesCard({
    super.key,
    required this.suspiciousCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);

    return Card(
      margin: EdgeInsets.all(mq.w(0.04)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(mq.w(0.04)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(mq.w(0.03)),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: mq.w(0.03)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suspicious Messages',
                          style: TextStyle(
                            fontSize: mq.sp(0.05),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Potential threats detected',
                          style: TextStyle(
                            fontSize: mq.sp(0.04),
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: mq.w(0.03),
                      vertical: mq.h(0.005),
                    ),
                    decoration: BoxDecoration(
                      color: suspiciousCount > 0 ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      suspiciousCount > 0 ? '$suspiciousCount Alert${suspiciousCount > 1 ? 's' : ''}' : 'Safe',
                      style: TextStyle(
                        fontSize: mq.sp(0.035),
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: mq.h(0.02)),
              
              if (suspiciousCount > 0) ...[
                Container(
                  padding: EdgeInsets.all(mq.w(0.03)),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      SizedBox(width: mq.w(0.02)),
                      Expanded(
                        child: Text(
                          'Review messages for potential threats and inappropriate content',
                          style: TextStyle(
                            fontSize: mq.sp(0.04),
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: mq.h(0.02)),
              ],
              
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.darkCyan,
                    size: 16,
                  ),
                  SizedBox(width: mq.w(0.01)),
                  Text(
                    'Tap to view messages',
                    style: TextStyle(
                      fontSize: mq.sp(0.04),
                      color: AppColors.darkCyan,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
