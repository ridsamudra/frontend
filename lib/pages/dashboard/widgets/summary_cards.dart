// lib/pages/dashboard/widgets/summary_cards.dart

import 'package:flutter/material.dart';
import 'package:http/browser_client.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:frontend/services/auth_service.dart';

import '../../../components/responsive.dart';

class SummaryCards extends StatefulWidget {
  final String title;
  final String apiUrl;
  final Color color;

  const SummaryCards({
    super.key,
    required this.title,
    required this.apiUrl,
    this.color = Colors.black,
  });

  @override
  _SummaryCardsState createState() => _SummaryCardsState();
}

class _SummaryCardsState extends State<SummaryCards> {
  late Future<Map<String, String>> _futureData;
  DateTime? _lastUpdated;
  final AuthService authService = AuthService();

  @override
  void initState() {
    super.initState();
    _futureData = _fetchData();
  }

  Future<Map<String, String>> _fetchData() async {
    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient();
      final uri = Uri.parse(widget.apiUrl)
          .replace(queryParameters: {'session_data': jsonEncode(sessionData)});
      final response = await client.get(uri, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final apiUpdateTime = DateTime.parse(data['waktu']);

        if (_lastUpdated == null || apiUpdateTime.isAfter(_lastUpdated!)) {
          _lastUpdated = apiUpdateTime;
        }

        String value;
        switch (widget.title) {
          case 'Pendapatan 7 Hari Terakhir':
          case 'Pendapatan Hari Ini':
            value = NumberFormat.currency(
                    locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                .format((data[widget.title == 'Pendapatan 7 Hari Terakhir'
                        ? 'total_pendapatan'
                        : 'pendapatan_hari_ini'] as num)
                    .toDouble());
            break;
          case 'Transaksi 7 Hari Terakhir':
          case 'Transaksi Hari Ini':
            value = NumberFormat().format(data[
                widget.title == 'Transaksi 7 Hari Terakhir'
                    ? 'total_transaksi'
                    : 'transaksi_hari_ini'] as int);
            break;
          default:
            value = 'N/A';
        }

        return {
          'value': value,
          'lastUpdated': _lastUpdated != null
              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_lastUpdated!)
              : 'N/A'
        };
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching summary data: $e');
      return {'value': 'Error', 'lastUpdated': 'N/A'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Menentukan ukuran font berdasarkan lebar layar
        double titleFontSize = 14; // Default value
        double valueFontSize = 18; // Default value
        double lastUpdatedFontSize = 10; // Default value

        if (Responsive.isMobile(context)) {
          // Smartphone (mobile)
          titleFontSize = 12;
          valueFontSize = 16;
          lastUpdatedFontSize = 10;
        } else if (Responsive.isTablet(context)) {
          // Tablet
          titleFontSize = 16;
          valueFontSize = 22;
          lastUpdatedFontSize = 12;
        } else if (Responsive.isDesktop(context)) {
          // Laptop dan desktop
          titleFontSize = 18;
          valueFontSize = 24;
          lastUpdatedFontSize = 14;
        }

        return FutureBuilder<Map<String, String>>(
          future: _futureData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              final data = snapshot.data!;
              return Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding:
                      EdgeInsets.all(constraints.maxWidth < 600 ? 8.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.grey[700],
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: constraints.maxWidth < 600 ? 4 : 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          data['value']!,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.black,
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: constraints.maxWidth < 600 ? 2 : 4),
                      Text(
                        'Last updated: ${data['lastUpdated']}',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.normal,
                          fontStyle: FontStyle.italic,
                          fontSize: lastUpdatedFontSize,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return const Center(child: Text('No Data'));
            }
          },
        );
      },
    );
  }
}
