// lib/pages/dashboard/widgets/traffic_hours.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/browser_client.dart';

class TrafficHours extends StatefulWidget {
  const TrafficHours({super.key});

  @override
  _TrafficHoursState createState() => _TrafficHoursState();
}

class _TrafficHoursState extends State<TrafficHours> {
  List<BarChartGroupData> barGroups = [];
  bool isLoading = true;
  String errorMessage = '';
  double maxTransaction = 0;
  final NumberFormat numberFormat = NumberFormat('#,###');
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  AuthService authService = AuthService();
  String? selectedLocation;
  List<String> locations = ['Semua'];
  Map<int, double> revenueData = {};
  bool hasData = false;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    fetchTrafficData();
  }

  Future<void> _fetchLocations() async {
    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;
      final uri =
          Uri.parse('http://127.0.0.1:8000/api/traffichours/bylocations')
              .replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          setState(() {
            locations = ['Semua', ...data.keys];
          });
        }
      } else {
        throw Exception('Failed to load locations');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch locations: $e';
      });
    }
  }

  Future<void> fetchTrafficData([String? location]) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      hasData = false;
    });

    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;
      final uri = Uri.parse(
        location == null || location == 'Semua'
            ? 'http://127.0.0.1:8000/api/traffichours/all'
            : 'http://127.0.0.1:8000/api/traffichours/bylocations',
      ).replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
        if (location != null && location != 'Semua') 'location': location,
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        Map<String, dynamic> data;

        if (decodedData is Map<String, dynamic>) {
          data = location == null || location == 'Semua'
              ? decodedData
              : decodedData[location];
        } else {
          throw Exception('Unexpected data format');
        }

        _processTrafficData(data);
      } else {
        throw Exception('Failed to load data');
      }
    } catch (error) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${error.toString()}';
      });
    }
  }

  void _processTrafficData(Map<String, dynamic> data) {
    List<BarChartGroupData> tempBarGroups = [];
    maxTransaction = 0;
    revenueData.clear();
    hasData = false;

    for (int i = 0; i < 24; i++) {
      double transaksi = data['transaksi']['jam_$i'].toDouble();
      double pendapatan = data['pendapatan']['jam_$i'].toDouble();

      if (transaksi > 0 || pendapatan > 0) {
        hasData = true;
      }

      maxTransaction = maxTransaction > transaksi ? maxTransaction : transaksi;
      revenueData[i] = pendapatan;

      tempBarGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: transaksi,
            color: Colors.blue,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ));
    }

    if (maxTransaction == 0) {
      maxTransaction = 1;
    }

    setState(() {
      barGroups = tempBarGroups;
      isLoading = false;
    });
  }

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Lokasi'),
          content: SingleChildScrollView(
            child: ListBody(
              children: locations.map((String location) {
                return ListTile(
                  title: Text(location),
                  onTap: () {
                    setState(() {
                      selectedLocation = location;
                    });
                    Navigator.of(context).pop();
                    fetchTrafficData(location);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.location_on, size: 18),
      label: Text(selectedLocation ?? 'Semua'),
      onPressed: _openFilterDialog,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trafik Tiap Jam',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF757575),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildFilterButton(),
              ],
            ),
            const SizedBox(height: 16),
            _buildChartContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage));
    } else if (!hasData) {
      return _buildNoDataWidget();
    } else {
      return _buildResponsiveChart();
    }
  }

  Widget _buildNoDataWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey[500],
            size: 50,
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak ada data yang tersedia',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Silakan pilih filter dengan titik lokasi yang lain.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxHeight > 300 ? 300.0 : constraints.maxHeight;
        return SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              titlesData: _getTitlesData(),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              maxY: maxTransaction,
              minY: 0,
              barTouchData: _getBarTouchData(),
            ),
          ),
        );
      },
    );
  }

  FlTitlesData _getTitlesData() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(
                numberFormat.format(value.toInt()),
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
          interval: maxTransaction > 0 ? maxTransaction / 5 : 1,
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  BarTouchData _getBarTouchData() {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          int hour = group.x;
          double transactions = rod.toY;
          double revenue = revenueData[hour] ?? 0;
          return BarTooltipItem(
            'Jam $hour\n'
            'Transaksi: ${numberFormat.format(transactions.round())}\n'
            'Pendapatan: ${currencyFormat.format(revenue)}',
            const TextStyle(color: Colors.white),
          );
        },
      ),
    );
  }
}
