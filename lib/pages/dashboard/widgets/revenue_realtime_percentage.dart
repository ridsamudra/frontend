// lib/pages/dashboard/widgets/revenue_realtime_percentage.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/browser_client.dart';

class RevenueRealtimePercentage extends StatefulWidget {
  const RevenueRealtimePercentage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RevenueRealtimePercentageState createState() =>
      _RevenueRealtimePercentageState();
}

class _RevenueRealtimePercentageState extends State<RevenueRealtimePercentage> {
  Map<String, double> _dataMap = {};
  Map<String, int> _totalTransactions = {};
  Map<String, double> _totalPendapatan = {};
  bool _isLoading = true;
  String _errorMessage = '';
  int _touchedIndex = -1;
  final double _thresholdVisibility = 1.0;
  String? selectedLocation;
  List<String> locations = ['Semua'];
  AuthService authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    fetchRevenueRealtime();
  }

  Future<void> _fetchLocations() async {
    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;
      final uri =
          Uri.parse('http://127.0.0.1:8000/api/revenuerealtime/bylocations')
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
        _errorMessage = 'Failed to fetch locations: $e';
      });
    }
  }

  Future<void> fetchRevenueRealtime([String? location]) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;
      final uri = Uri.parse(
        location == null || location == 'Semua'
            ? 'http://127.0.0.1:8000/api/revenuerealtime/all'
            : 'http://127.0.0.1:8000/api/revenuerealtime/bylocations',
      ).replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
        if (location != null && location != 'Semua') 'location': location,
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        List<dynamic> data;

        if (decodedData is List) {
          data = decodedData;
        } else if (decodedData is Map<String, dynamic>) {
          // Jika data adalah map, ambil nilai dari kunci yang sesuai dengan lokasi
          data = decodedData[location] as List<dynamic>? ?? [];
        } else {
          throw Exception('Unexpected data format');
        }

        setState(() {
          _generateDataMap(data);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
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
                    fetchRevenueRealtime(location);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _generateDataMap(List<dynamic> data) {
    final double totalPendapatan = data
        .fold(0, (sum, item) => sum + (item['jumlah_pendapatan'] as int))
        .toDouble();

    _dataMap = {};
    _totalTransactions = {};
    _totalPendapatan = {};

    for (var item in data) {
      String vehicleType = item['jenis_kendaraan'];
      int transactions = item['jumlah_transaksi'] as int;
      double pendapatan = (item['jumlah_pendapatan'] as int).toDouble();

      _dataMap[vehicleType] = (pendapatan / totalPendapatan) * 100;
      _totalTransactions[vehicleType] = transactions;
      _totalPendapatan[vehicleType] = pendapatan;
    }
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Persentase Pendapatan',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF757575),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildFilterButton(
                  icon: Icons.location_on,
                  label: selectedLocation ?? 'Semua',
                  onPressed: _openFilterDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage))
                    : _dataMap.isEmpty
                        ? Center(
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
                          )
                        : Flexible(
                            child: _buildChartWithLegend(),
                          ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartWithLegend() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildChart()),
                  Expanded(flex: 2, child: _buildLegend()),
                ],
              )
            : Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: _buildChart(),
                  ),
                  const SizedBox(height: 16),
                  _buildLegend(),
                ],
              );
      },
    );
  }

  Widget _buildChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: _generatePieChartSections(),
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
      ),
    );
  }

  List<PieChartSectionData> _generatePieChartSections() {
    return _dataMap.entries.map((entry) {
      final vehicleType = entry.key;
      final percentage = entry.value;
      final isTouch =
          _touchedIndex == _dataMap.keys.toList().indexOf(vehicleType);

      final validPercentage = percentage.isFinite ? percentage : 0;

      return validPercentage >= _thresholdVisibility
          ? PieChartSectionData(
              color: _getColorForVehicleType(vehicleType),
              value: percentage.toDouble(),
              title: '',
              radius: isTouch ? 50 : 40,
              badgeWidget: isTouch ? _buildBadgeWidget(vehicleType) : null,
              badgePositionPercentageOffset: 0.9,
            )
          : PieChartSectionData(
              color: _getColorForVehicleType(vehicleType),
              value: percentage.toDouble(),
              title: '',
              radius: isTouch ? 50 : 40,
            );
    }).toList();
  }

  Widget _buildBadgeWidget(String vehicleType) {
    final percentage = _dataMap[vehicleType] ?? 0;
    final transactions = _totalTransactions[vehicleType] ?? 0;
    final pendapatan = _totalPendapatan[vehicleType] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicleType,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}% pendapatan',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            '$transactions transaksi',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'id_ID',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(pendapatan),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _dataMap.entries.map((entry) {
          final vehicleType = entry.key;
          final transactions = _totalTransactions[vehicleType] ?? 0;
          final pendapatan = _totalPendapatan[vehicleType] ?? 0.0;
          final formattedPendapatan = NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(pendapatan);

          final isTouch =
              _touchedIndex == _dataMap.keys.toList().indexOf(vehicleType);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getColorForVehicleType(vehicleType),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$vehicleType ($transactions - $formattedPendapatan)',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: isTouch ? Colors.black : const Color(0xFF757575),
                      fontWeight: isTouch ? FontWeight.bold : FontWeight.w500,
                      fontSize: isTouch ? 14 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getColorForVehicleType(String vehicleType) {
    final List<Color> colors = [
      const Color(0xD9322FC8),
      const Color(0xD9FF9F43),
      const Color(0xD9E73F76),
      const Color(0xD9B57C5A),
      const Color(0xD93FAF2A),
      const Color(0xD9E74C3C),
      const Color(0xD9F1C40F),
      const Color(0xD99398EC)
    ];
    return colors[_dataMap.keys.toList().indexOf(vehicleType) % colors.length];
  }
}
