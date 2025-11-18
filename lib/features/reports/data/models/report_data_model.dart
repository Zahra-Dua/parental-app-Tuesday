import '../../../app_limits/data/models/app_usage_firebase.dart';
import '../../../url_tracking/data/models/visited_url_firebase.dart';

class ReportDataModel {
  final List<AppUsageFirebase> appUsage;
  final List<VisitedUrlFirebase> visitedUrls;
  final int totalScreenTime; // in minutes
  final Map<String, int> appUsageByApp; // appName -> minutes
  final Map<String, int> urlVisitsByDomain; // domain -> count
  final int totalUrlsVisited;
  final int totalAppsUsed;
  final List<Map<String, dynamic>> topApps; // [{appName, minutes, percentage}]
  final List<Map<String, dynamic>> topDomains; // [{domain, count, percentage}]

  ReportDataModel({
    required this.appUsage,
    required this.visitedUrls,
    required this.totalScreenTime,
    required this.appUsageByApp,
    required this.urlVisitsByDomain,
    required this.totalUrlsVisited,
    required this.totalAppsUsed,
    required this.topApps,
    required this.topDomains,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalScreenTime': totalScreenTime,
      'totalUrlsVisited': totalUrlsVisited,
      'totalAppsUsed': totalAppsUsed,
      'appUsageByApp': appUsageByApp,
      'urlVisitsByDomain': urlVisitsByDomain,
      'topApps': topApps,
      'topDomains': topDomains,
    };
  }
}

