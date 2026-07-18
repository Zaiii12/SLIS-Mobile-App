import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/calendar_event.dart';

/// Builds a simple printable list-style PDF of [events] for the given
/// [periodLabel] (e.g. "March 2026" or "SY 2025-2026"), grouped by month —
/// mirrors the ASIA web admin-portal's "YearListPrint" table (a plain
/// month-by-month list), not the visual month-grid, since that's the part
/// that actually prints/reads well on paper.
Future<void> printCalendarEvents({
  required String periodLabel,
  required List<CalendarEvent> events,
}) async {
  final doc = pw.Document();
  final sorted = [...events]..sort((a, b) => a.startDate.compareTo(b.startDate));

  final grouped = <String, List<CalendarEvent>>{};
  for (final event in sorted) {
    final key = DateFormat('MMMM yyyy').format(event.startDate);
    grouped.putIfAbsent(key, () => []).add(event);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'South Lakes Integrated School',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'School Calendar — $periodLabel',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
      build: (context) {
        if (grouped.isEmpty) {
          return [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text('No events in this period.'),
            ),
          ];
        }
        return [
          for (final entry in grouped.entries) ...[
            pw.Text(
              entry.key,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.2),
                1: pw.FlexColumnWidth(3.5),
                2: pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Date', bold: true),
                    _cell('Title', bold: true),
                    _cell('Type', bold: true),
                  ],
                ),
                for (final event in entry.value)
                  pw.TableRow(
                    children: [
                      _cell(_dateRangeLabel(event)),
                      _cell(event.title),
                      _cell(calendarEventTypeLabels[event.eventType] ?? event.eventType),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
          ],
        ];
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

String _dateRangeLabel(CalendarEvent event) {
  if (event.isMultiDay) {
    return '${DateFormat('MMM d').format(event.startDate)} – ${DateFormat('MMM d').format(event.endDate)}';
  }
  return DateFormat('MMM d (EEE)').format(event.startDate);
}

pw.Widget _cell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
    ),
  );
}
