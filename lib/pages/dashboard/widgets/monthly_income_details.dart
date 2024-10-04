// lib/pages/dashboard/widgets/monthly_income_details.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/browser_client.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' as excel;

class MonthlyIncomeDetails extends StatefulWidget {
  final String location;

  const MonthlyIncomeDetails({
    super.key,
    required this.location,
  });

  @override
  _MonthlyIncomeDetailsState createState() => _MonthlyIncomeDetailsState();
}

class _MonthlyIncomeDetailsState extends State<MonthlyIncomeDetails> {
  List<dynamic> monthlyIncomeData = [];
  int selectedYear = DateTime.now().year;
  String? errorMessage;
  bool isLoading = false;
  final AuthService authService = AuthService();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      fetchMonthlyIncomeData();
    });
  }

  Future<void> fetchMonthlyIncomeData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;

      final uri = Uri.parse(
        'http://127.0.0.1:8000/api/revenuedetails/filterbymonths/',
      ).replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
        'year': selectedYear.toString(),
        'location': widget.location,
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data[widget.location] != null) {
          setState(() {
            monthlyIncomeData = List.from(data[widget.location]);
          });
        } else {
          throw NoDataException(
              'No data available for the selected location and period');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } on NoDataException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred while fetching data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16.0),
          _buildDataCard(),
        ],
      ),
    );
  }

  Widget _buildDataCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pendapatan Bulanan Detail',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF2C3E50),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildFilterAndExportButtons(),
              ],
            ),
            const SizedBox(height: 16.0),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              _buildErrorWidget()
            else
              _buildDataTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndExportButtons() {
    return Row(
      children: [
        _buildFilterButton(
          icon: Icons.calendar_today,
          label: selectedYear.toString(),
          onPressed: () => _selectYear(context),
        ),
        const SizedBox(width: 8),
        _buildExportButton(),
      ],
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: const Color(0xFF2C3E50),
        backgroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.file_download, size: 18, color: Colors.black87),
      label: const Text('Export', style: TextStyle(color: Colors.black87)),
      onPressed: () => _showExportDialog(),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Data'),
          content: const Text('Pilih format export:'),
          actions: [
            TextButton(
              child: const Text('PDF'),
              onPressed: () {
                Navigator.of(context).pop();
                _exportToPDF();
              },
            ),
            TextButton(
              child: const Text('Excel'),
              onPressed: () {
                Navigator.of(context).pop();
                _exportToExcel();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    // Load a Unicode-compatible font
    final font =
        await rootBundle.load("assets/fonts/Roboto/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Table(
            border: pw.TableBorder.all(),
            children: [
              // Header
              pw.TableRow(
                children: _getColumns().map((column) {
                  return pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(column,
                        style: pw.TextStyle(
                            font: ttf, fontWeight: pw.FontWeight.bold)),
                  );
                }).toList(),
              ),
              // Data rows
              ..._getDataRows().map((row) {
                return pw.TableRow(
                  children: row.map((cell) {
                    return pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(cell, style: pw.TextStyle(font: ttf)),
                    );
                  }).toList(),
                );
              }),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _exportToExcel() async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Sheet1'];

    // Add header
    final headers = _getColumns();
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = excel.TextCellValue(headers[i]);
    }

    // Add data
    final data = _getDataRows();
    for (var i = 0; i < data.length; i++) {
      for (var j = 0; j < data[i].length; j++) {
        final cellValue = data[i][j];
        sheet
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: j, rowIndex: i + 1))
            .value = excel.TextCellValue(cellValue);
      }
    }

    final bytes = excelFile.save();
    final blob = html.Blob([bytes!],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'monthly_income_details.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  List<String> _getColumns() {
    return [
      'Bulan',
      'Tarif Tunai',
      'Tarif Non Tunai',
      'Member',
      'Manual',
      'Tiket Masalah',
      'Total Pendapatan',
      'Qty Casual',
      'Qty Pass',
      'Total Qty',
    ];
  }

  List<List<String>> _getDataRows() {
    final rows = <List<String>>[];
    final filteredData = monthlyIncomeData.where((item) {
      return item is Map<String, dynamic> &&
          item.values.every((value) => value != null) &&
          item.values.any((value) => value is num && value != 0);
    }).toList();

    for (var item in filteredData) {
      rows.add([
        _formatMonth(item['bulan']),
        NumberFormat('#,###.##').format(item['tarif_tunai']),
        NumberFormat('#,###.##').format(item['tarif_non_tunai']),
        NumberFormat('#,###.##').format(item['member']),
        NumberFormat('#,###.##').format(item['manual']),
        NumberFormat('#,###.##').format(item['tiket_masalah']),
        NumberFormat('#,###.##').format(item['total_pendapatan']),
        NumberFormat('#,###.##').format(item['qty_casual']),
        NumberFormat('#,###.##').format(item['qty_pass']),
        NumberFormat('#,###.##').format(item['total_qty']),
      ]);
    }

    // Add summary rows
    final summaryData = _calculateSummaryData(filteredData);
    for (var key in ['Total', 'Minimal', 'Maksimal', 'Rata-rata']) {
      final data = summaryData[key]!;
      rows.add([
        key,
        NumberFormat('#,###.##').format(data['tarif_tunai']),
        NumberFormat('#,###.##').format(data['tarif_non_tunai']),
        NumberFormat('#,###.##').format(data['member']),
        NumberFormat('#,###.##').format(data['manual']),
        NumberFormat('#,###.##').format(data['tiket_masalah']),
        NumberFormat('#,###.##').format(data['total_pendapatan']),
        NumberFormat('#,###.##').format(data['qty_casual']),
        NumberFormat('#,###.##').format(data['qty_pass']),
        NumberFormat('#,###.##').format(data['total_qty']),
      ]);
    }

    return rows;
  }

  Future<void> _selectYear(BuildContext context) async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Tahun'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: 5,
              itemBuilder: (BuildContext context, int index) {
                final year = DateTime.now().year - 2 + index;
                return ListTile(
                  title: Text(year.toString()),
                  onTap: () => Navigator.of(context).pop(year),
                );
              },
            ),
          ),
        );
      },
    );

    if (picked != null && picked != selectedYear) {
      setState(() {
        selectedYear = picked;
      });
      fetchMonthlyIncomeData();
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.red.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  errorMessage!,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 64,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.grey[300],
          ),
          child: DataTable(
            columnSpacing: 20,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFECF0F1)),
            dataRowColor: WidgetStateProperty.all(Colors.white),
            border: TableBorder.all(
              color: Colors.grey[300]!,
              width: 1,
              style: BorderStyle.solid,
            ),
            dataRowHeight: 56,
            headingRowHeight: 60,
            horizontalMargin: 12,
            columns: _buildColumns(),
            rows: _buildDataRows(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    final columns = [
      'Bulan',
      'Tarif Tunai',
      'Tarif Non Tunai',
      'Member',
      'Manual',
      'Tiket Masalah',
      'Total Pendapatan',
      'Qty Casual',
      'Qty Pass',
      'Total Qty',
    ];

    return columns
        .map((column) => DataColumn(
              label: Expanded(
                child: Text(
                  column,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF34495E),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ))
        .toList();
  }

  List<DataRow> _buildDataRows() {
    final List<DataRow> rows = [];
    final filteredData = monthlyIncomeData.where((item) {
      return item is Map<String, dynamic> &&
          item.values.every((value) => value != null) &&
          item.values.any((value) => value is num && value != 0);
    }).toList();

    // Add monthly data
    rows.addAll(filteredData.map((item) => _buildRow(item)));

    // Calculate and add summary data
    final summaryData = _calculateSummaryData(filteredData);
    rows.addAll([
      _buildRow(summaryData['Total']!,
          rowName: 'Total', color: const Color(0xFFE8F0FE), isSummary: true),
      _buildRow(summaryData['Minimal']!,
          rowName: 'Minimal', color: const Color(0xFFE8F8F5), isSummary: true),
      _buildRow(summaryData['Maksimal']!,
          rowName: 'Maksimal', color: const Color(0xFFFDF2E9), isSummary: true),
      _buildRow(summaryData['Rata-rata']!,
          rowName: 'Rata-rata',
          color: const Color(0xFFF4ECF7),
          isSummary: true),
    ]);

    return rows;
  }

  Map<String, Map<String, dynamic>> _calculateSummaryData(
      List<dynamic> filteredData) {
    final keys = [
      'tarif_tunai',
      'tarif_non_tunai',
      'member',
      'manual',
      'tiket_masalah',
      'total_pendapatan',
      'qty_casual',
      'qty_pass',
      'total_qty'
    ];

    return {
      'Total': Map.fromIterable(keys,
          value: (key) => filteredData.fold<num>(0,
              (sum, item) => sum + (item[key] is num ? item[key] as num : 0))),
      'Minimal': Map.fromIterable(keys, value: (key) {
        final validValues = filteredData
            .where((item) => item[key] is num)
            .map((item) => item[key] as num)
            .toList();
        return validValues.isNotEmpty ? validValues.reduce(min) : 0;
      }),
      'Maksimal': Map.fromIterable(keys, value: (key) {
        final validValues = filteredData
            .where((item) => item[key] is num)
            .map((item) => item[key] as num)
            .toList();
        return validValues.isNotEmpty ? validValues.reduce(max) : 0;
      }),
      'Rata-rata': Map.fromIterable(keys, value: (key) {
        final validValues = filteredData
            .where((item) => item[key] is num && item[key] != 0)
            .map((item) => item[key] as num)
            .toList();
        return validValues.isNotEmpty
            ? validValues.reduce((a, b) => a + b) / validValues.length
            : 0;
      }),
    };
  }

  num min(num a, num b) => a < b ? a : b;
  num max(num a, num b) => a > b ? a : b;

  DataRow _buildRow(Map<String, dynamic> data,
      {String? rowName, Color? color, bool isSummary = false}) {
    final cells = [
      DataCell(
        Center(
          child: Text(
            rowName ?? _formatMonth(data['bulan']),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: rowName != null ? FontWeight.w600 : FontWeight.w600,
              color: const Color(0xFF2C3E50),
            ),
            textAlign: isSummary ? TextAlign.left : TextAlign.center,
          ),
        ),
      ),
      // ... (rest of the method remains the same)
      ...[
        'tarif_tunai',
        'tarif_non_tunai',
        'member',
        'manual',
        'tiket_masalah',
        'total_pendapatan',
        'qty_casual',
        'qty_pass',
        'total_qty'
      ].map((key) {
        final value = data[key];
        return DataCell(
          Container(
            alignment: Alignment.centerRight,
            child: Text(
              value is num ? NumberFormat('#,###.##').format(value) : '-',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: rowName != null ? FontWeight.w600 : FontWeight.w600,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ),
        );
      }),
    ];

    return DataRow(
      cells: cells,
      color: color != null ? WidgetStateProperty.all(color) : null,
    );
  }

  String _formatMonth(dynamic month) {
    final monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];

    if (month is int && month >= 1 && month <= 12) {
      return '${monthNames[month - 1]} $selectedYear';
    } else if (month is String) {
      try {
        final monthNumber = int.parse(month);
        if (monthNumber >= 1 && monthNumber <= 12) {
          return '${monthNames[monthNumber - 1]} $selectedYear';
        }
      } catch (e) {
        // If parsing fails, return the original value
      }
    }
    return '$month $selectedYear';
  }
}

class NoDataException implements Exception {
  final String message;
  NoDataException(this.message);
}
