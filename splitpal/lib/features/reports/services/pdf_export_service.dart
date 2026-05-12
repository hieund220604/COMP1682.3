import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../report_models.dart';

class PdfExportService {
  static Future<void> generateAndShareFinancialReport(MonthlyReport report) async {
    final pdf = pw.Document();

    // Load fonts to support Vietnamese
    final fontData = await rootBundle.load('assets/fonts/be_vietnam_pro/BeVietnamPro-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/be_vietnam_pro/BeVietnamPro-Bold.ttf');
    
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(fontBoldData);

    final theme = pw.ThemeData.withFont(
      base: ttf,
      bold: ttfBold,
    );

    // Format helpers
    final formatCurrency = (double amount) => CurrencyFormatter.formatVND(amount);
    final isPositive = report.overview.netCashflow >= 0;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              color: PdfColors.grey50,
            ),
          ),
        ),
        header: (context) => _buildHeader(report, ttfBold),
        footer: (context) => _buildFooter(context, ttf),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildOverview(report.overview, formatCurrency, ttfBold),
          pw.SizedBox(height: 20),
          _buildCashflowChart(report.dailySpending, ttf),
          pw.SizedBox(height: 20),
          _buildBreakdownSection(report, formatCurrency, ttfBold),
          pw.SizedBox(height: 20),
          if (report.budgetPerformance.isNotEmpty)
            _buildBudgetTable(report.budgetPerformance, formatCurrency, ttfBold),
        ],
      ),
    );

    // Share or print the PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'SplitPal_Financial_Report_${report.month}.pdf',
    );
  }

  static pw.Widget _buildHeader(MonthlyReport report, pw.Font ttfBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SPLITPAL', style: pw.TextStyle(font: ttfBold, fontSize: 24, color: PdfColor.fromHex('#E8472A'))),
              pw.SizedBox(height: 4),
              pw.Text('Financial Intelligence Report', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Report Month', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              pw.Text(report.month, style: pw.TextStyle(font: ttfBold, fontSize: 18)),
              pw.SizedBox(height: 4),
              pw.Text('Generated: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font ttf) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey500),
      ),
    );
  }

  static pw.Widget _buildOverview(ReportOverview overview, String Function(double) formatCurrency, pw.Font ttfBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Total Inflow', formatCurrency(overview.totalInflow), PdfColors.green700, ttfBold),
              _buildSummaryItem('Total Outflow', formatCurrency(overview.totalOutflow), PdfColors.red700, ttfBold),
              _buildSummaryItem(
                'Net Cashflow', 
                formatCurrency(overview.netCashflow), 
                overview.netCashflow >= 0 ? PdfColors.green700 : PdfColors.red700, 
                ttfBold
              ),
            ],
          ),
          pw.Divider(color: PdfColors.grey200, height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSmallSummaryItem('Opening Balance', formatCurrency(overview.openingBalance)),
              _buildSmallSummaryItem('Closing Balance', formatCurrency(overview.closingBalance)),
              _buildSmallSummaryItem('Transactions', '${overview.transactionCount} items'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value, PdfColor color, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(font: ttfBold, fontSize: 16, color: color)),
      ],
    );
  }

  static pw.Widget _buildSmallSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 12, color: PdfColors.black)),
      ],
    );
  }

  static pw.Widget _buildCashflowChart(List<DailySpending> daily, pw.Font ttf) {
    if (daily.isEmpty) return pw.SizedBox();

    final maxVal = daily.fold<double>(1, (m, d) => m > (d.outflow + d.inflow) ? m : (d.outflow + d.inflow));
    const chartHeight = 100.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Daily Cashflow', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey800)),
          pw.SizedBox(height: 12),
          pw.SizedBox(
            height: chartHeight + 15,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: daily.map((d) {
                final total = d.outflow + d.inflow;
                final ratio = maxVal > 0 ? (total / maxVal) : 0.0;
                final barH = ratio * chartHeight;
                final inFraction = total > 0 ? d.inflow / total : 0.0;
                final inH = barH * inFraction;
                final outH = barH - inH;
                final dayStr = d.date.split('-').last;

                return pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        if (inH > 0)
                          pw.Container(
                            height: inH,
                            width: 10,
                            color: PdfColors.green300,
                          ),
                        if (outH > 0)
                          pw.Container(
                            height: outH,
                            width: 10,
                            color: PdfColors.red300,
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          dayStr,
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBreakdownSection(MonthlyReport report, String Function(double) formatCurrency, pw.Font ttfBold) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildSourceList('Outflow Breakdown', report.outflowBySource.entries, formatCurrency, ttfBold),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _buildSourceList('Inflow Breakdown', report.inflowBySource.entries, formatCurrency, ttfBold),
        ),
      ],
    );
  }

  static pw.Widget _buildSourceList(String title, List<dynamic> entries, String Function(double) formatCurrency, pw.Font ttfBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: ttfBold, fontSize: 14, color: PdfColors.grey800)),
          pw.SizedBox(height: 12),
          if (entries.isEmpty)
            pw.Text('No data available', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey500))
          else
            ...entries.map((e) {
              final label = e.label as String;
              final amount = e.amount as double;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    pw.Text(formatCurrency(amount), style: pw.TextStyle(font: ttfBold, fontSize: 12, color: PdfColors.grey900)),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  static pw.Widget _buildBudgetTable(List<BudgetPerformance> budgets, String Function(double) formatCurrency, pw.Font ttfBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Budget Performance', style: pw.TextStyle(font: ttfBold, fontSize: 14, color: PdfColors.grey800)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(font: ttfBold, fontSize: 10, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8472A')),
            cellStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
            cellAlignment: pw.Alignment.centerRight,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
            },
            data: [
              ['Category', 'Budget', 'Spent', 'Remaining', 'Usage'],
              ...budgets.map((b) {
                final budget = b.budgetLimit ?? 0;
                final remaining = budget - b.spent;
                return [
                  b.tagName,
                  budget > 0 ? formatCurrency(budget) : 'N/A',
                  formatCurrency(b.spent),
                  budget > 0 ? formatCurrency(remaining) : 'N/A',
                  '${b.percentUsed}%',
                ];
              }),
            ],
          ),
        ],
      ),
    );
  }
}
