import 'dart:typed_data';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/report_data_entity.dart';

class PdfGeneratorService {
  Future<Uint8List> generateReportPdf({
    required String childName,
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
    required ReportDataEntity reportData,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(childName, reportType, startDate, endDate),
            pw.SizedBox(height: 30),

            // Summary Section
            _buildSummarySection(reportData),
            pw.SizedBox(height: 30),

            // App Usage Chart
            if (reportData.topApps.isNotEmpty) ...[
              _buildAppUsageChart(reportData),
              pw.SizedBox(height: 30),
            ],

            // Top Apps Section
            _buildTopAppsSection(reportData),
            pw.SizedBox(height: 30),

            // Web Usage Chart
            if (reportData.topDomains.isNotEmpty) ...[
              _buildWebUsageChart(reportData),
              pw.SizedBox(height: 30),
            ],

            // Top Domains Section
            _buildTopDomainsSection(reportData),
            pw.SizedBox(height: 30),

            // Footer
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String childName, String reportType, DateTime startDate, DateTime endDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Digital Activity Report',
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Child: $childName',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Report Type: ${reportType.toUpperCase()}',
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Period: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildSummarySection(ReportDataEntity reportData) {
    final hours = reportData.totalScreenTime ~/ 60;
    final minutes = reportData.totalScreenTime % 60;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Screen Time', '${hours}h ${minutes}m'),
              _buildSummaryItem('Apps Used', '${reportData.totalAppsUsed}'),
              _buildSummaryItem('URLs Visited', '${reportData.totalUrlsVisited}'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _buildAppUsageChart(ReportDataEntity reportData) {
    if (reportData.topApps.isEmpty) {
      return pw.SizedBox.shrink();
    }

    final maxMinutes = reportData.topApps.isNotEmpty
        ? reportData.topApps.map((app) => app['minutes'] as int).reduce(math.max)
        : 1;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'App Usage Chart',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Container(
          height: 200,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: reportData.topApps.take(5).map((app) {
              final minutes = app['minutes'] as int;
              final height = (minutes / maxMinutes) * 180;
              
              return pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      height: height,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue700,
                        borderRadius: const pw.BorderRadius.vertical(
                          top: pw.Radius.circular(5),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '${minutes}m',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _truncateAppName(app['appName'] as String),
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildWebUsageChart(ReportDataEntity reportData) {
    if (reportData.topDomains.isEmpty) {
      return pw.SizedBox.shrink();
    }

    final maxCount = reportData.topDomains.isNotEmpty
        ? reportData.topDomains.map((domain) => domain['count'] as int).reduce(math.max)
        : 1;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Web Usage Chart',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Container(
          height: 200,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: reportData.topDomains.take(5).map((domain) {
              final count = domain['count'] as int;
              final height = (count / maxCount) * 180;
              
              return pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      height: height,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green700,
                        borderRadius: const pw.BorderRadius.vertical(
                          top: pw.Radius.circular(5),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '$count',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _truncateDomain(domain['domain'] as String),
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _truncateAppName(String name) {
    if (name.length <= 10) return name;
    return '${name.substring(0, 8)}...';
  }

  String _truncateDomain(String domain) {
    if (domain.length <= 12) return domain;
    return '${domain.substring(0, 10)}...';
  }

  pw.Widget _buildTopAppsSection(ReportDataEntity reportData) {
    if (reportData.topApps.isEmpty) {
      return pw.Text(
        'No app usage data available',
        style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top Apps by Usage',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('App Name', isHeader: true),
                _buildTableCell('Usage (min)', isHeader: true),
                _buildTableCell('Percentage', isHeader: true),
              ],
            ),
            ...reportData.topApps.map((app) {
              final minutes = app['minutes'] as int;
              final percentage = app['percentage'] as String;
              return pw.TableRow(
                children: [
                  _buildTableCell(app['appName'] as String),
                  _buildTableCell('$minutes'),
                  _buildTableCell('$percentage%'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTopDomainsSection(ReportDataEntity reportData) {
    if (reportData.topDomains.isEmpty) {
      return pw.Text(
        'No browsing data available',
        style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top Visited Domains',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Domain', isHeader: true),
                _buildTableCell('Visits', isHeader: true),
                _buildTableCell('Percentage', isHeader: true),
              ],
            ),
            ...reportData.topDomains.map((domain) {
              final count = domain['count'] as int;
              final percentage = domain['percentage'] as String;
              return pw.TableRow(
                children: [
                  _buildTableCell(domain['domain'] as String),
                  _buildTableCell('$count'),
                  _buildTableCell('$percentage%'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        'Generated on ${_formatDate(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
