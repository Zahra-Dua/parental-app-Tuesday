import 'package:flutter/material.dart';
import 'package:parental_control_app/core/constants/app_assets.dart';
import 'package:parental_control_app/core/constants/app_colors.dart';
import 'package:parental_control_app/core/utils/media_query_helpers.dart';

class ResponsiveLogo extends StatelessWidget {
  final double sizeFactor; // fraction of screen width, e.g. 0.2

  const ResponsiveLogo({super.key, this.sizeFactor = 0.22});

  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);
    final logoSize = mq.w(sizeFactor);
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: EdgeInsets.all(mq.w(0.03)),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(AppAssets.logo, fit: BoxFit.contain),
        ),
      ],
    );
  }
}
