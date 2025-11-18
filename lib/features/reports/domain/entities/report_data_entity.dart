import 'package:equatable/equatable.dart';

class ReportDataEntity extends Equatable {
  final int totalScreenTime; // in minutes
  final Map<String, int> appUsageByApp; // appName -> minutes
  final Map<String, int> urlVisitsByDomain; // domain -> count
  final int totalUrlsVisited;
  final int totalAppsUsed;
  final List<Map<String, dynamic>> topApps; // [{appName, minutes, percentage}]
  final List<Map<String, dynamic>> topDomains; // [{domain, count, percentage}]

  const ReportDataEntity({
    required this.totalScreenTime,
    required this.appUsageByApp,
    required this.urlVisitsByDomain,
    required this.totalUrlsVisited,
    required this.totalAppsUsed,
    required this.topApps,
    required this.topDomains,
  });

  @override
  List<Object?> get props => [
        totalScreenTime,
        appUsageByApp,
        urlVisitsByDomain,
        totalUrlsVisited,
        totalAppsUsed,
        topApps,
        topDomains,
      ];
}

