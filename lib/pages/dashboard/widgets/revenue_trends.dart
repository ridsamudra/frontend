// lib/pages/dashboard/widgets/revenue_trends.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/browser_client.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/auth_service.dart';

class RevenueTrends extends StatefulWidget {
  const RevenueTrends({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RevenueTrendsState createState() => _RevenueTrendsState();
}

class _RevenueTrendsState extends State<RevenueTrends> {
  final AuthService authService = AuthService();
  String selectedTimeFilter = '7 Hari';
  String selectedLocationFilter = 'Semua';
  List<BarChartGroupData> barGroups = [];
  List<String> dateLabels = [];
  bool isLoading = true;
  double maxY = 0;
  String? highlightedBar;
  List<String> locations = ['Semua'];
  Map<String, bool> visibleBars = {
    'cash': true,
    'prepaid': true,
    'member': true,
    'manual': true,
    'masalah': true,
    'total': true,
  };

  final Map<String, Color> barColors = {
    'cash': Colors.blue.shade300,
    'prepaid': Colors.green.shade300,
    'member': Colors.orange.shade300,
    'manual': Colors.purple.shade300,
    'masalah': Colors.red.shade300,
    'total': Colors.grey.shade300,
  };

  @override
  void initState() {
    super.initState();
    fetchLocations();
    fetchRevenueData();
  }

  Future<void> fetchLocations() async {
    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;

      final uri = Uri.parse(
              'http://127.0.0.1:8000/api/revenue/filterbydays/bylocations')
          .replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
      });

      final response = await client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          locations = ['Semua', ...data.keys.toList()];
        });
      } else {
        throw Exception('Failed to load locations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching locations: $e');
      setState(() {
        locations = ['Semua'];
      });
    }
  }

  Future<void> fetchRevenueData() async {
    setState(() {
      isLoading = true;
    });

    final sessionData = await authService.getSessionData();
    if (sessionData == null) {
      throw Exception('No session data available');
    }

    final client = BrowserClient()..withCredentials = true;
    String baseUrl = 'http://127.0.0.1:8000/api/revenue/';
    String endpoint;

    if (selectedTimeFilter == '7 Hari') {
      endpoint = 'filterbydays';
    } else if (selectedTimeFilter == '6 Bulan') {
      endpoint = 'filterbymonths';
    } else {
      endpoint = 'filterbyyears';
    }

    endpoint += selectedLocationFilter == 'Semua' ? '/all' : '/bylocations';

    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
        if (selectedLocationFilter != 'Semua')
          'location': selectedLocationFilter,
      });

      final response = await client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);
        processData(jsonData);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching data: $error');
      }
      setState(() {
        barGroups = [];
        dateLabels = [];
        isLoading = false;
      });
    } finally {
      client.close();
    }
  }

  void processData(dynamic jsonData) {
    List<BarChartGroupData> tempBarGroups = [];
    List<String> tempDateLabels = [];
    maxY = 0;

    if (selectedLocationFilter == 'Semua') {
      processAllLocationsData(jsonData, tempBarGroups, tempDateLabels);
    } else {
      processSingleLocationData(
          jsonData[selectedLocationFilter], tempBarGroups, tempDateLabels);
    }

    setState(() {
      barGroups = tempBarGroups;
      dateLabels = tempDateLabels;
      isLoading = false;
      adjustMaxY();
    });
  }

  void processAllLocationsData(List<dynamic> data,
      List<BarChartGroupData> tempBarGroups, List<String> tempDateLabels) {
    for (int i = 0; i < data.length; i++) {
      tempDateLabels.add(formatDate(data[i]['tanggal']));
      addBarGroup(data[i], i, tempBarGroups);
    }
  }

  void processSingleLocationData(List<dynamic> data,
      List<BarChartGroupData> tempBarGroups, List<String> tempDateLabels) {
    for (int i = 0; i < data.length; i++) {
      tempDateLabels.add(formatDate(data[i]['tanggal']));
      addBarGroup(data[i], i, tempBarGroups);
    }
  }

  String formatDate(dynamic dateValue) {
    if (dateValue is int) {
      return dateValue.toString();
    } else if (dateValue is String) {
      if (selectedTimeFilter == '7 Hari') {
        try {
          final date = DateTime.parse(dateValue);
          return DateFormat('dd MMM').format(date);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing date: $e');
          }
          return dateValue;
        }
      } else if (selectedTimeFilter == '6 Bulan') {
        return _formatMonthYear(dateValue);
      } else {
        return dateValue;
      }
    }
    return dateValue.toString();
  }

  String _formatMonthYear(String dateString) {
    try {
      final date = DateTime.parse('$dateString-01');
      return DateFormat('MMM yyyy').format(date);
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting month/year: $e');
      }
      return dateString;
    }
  }

  void addBarGroup(Map<String, dynamic> data, int index,
      List<BarChartGroupData> tempBarGroups) {
    List<BarChartRodData> rods = [];
    visibleBars.forEach((key, isVisible) {
      if (isVisible) {
        double value = _parseAndFormatNumber(data[key]);
        rods.add(_createBarRod(value, barColors[key]!));
        maxY = [maxY, value].reduce((a, b) => a > b ? a : b);
      }
    });

    tempBarGroups.add(BarChartGroupData(
      x: index,
      barRods: rods,
    ));
  }

  void adjustMaxY() {
    if (selectedTimeFilter == '6 Tahun') {
      maxY = (maxY / 1000000000).ceil() * 1000000000;
    } else if (selectedTimeFilter == '6 Bulan') {
      maxY = (maxY / 100000000).ceil() * 100000000;
    } else {
      maxY = (maxY / 10000000).ceil() * 10000000;
    }
    maxY = maxY == 0 ? 1 : maxY;
  }

  double _parseAndFormatNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }

  BarChartRodData _createBarRod(double value, Color color) {
    return BarChartRodData(
      toY: value,
      color: color,
      width: 16,
      borderRadius: BorderRadius.circular(4),
    );
  }

  String formatNumber(double number) {
    return NumberFormat('#,##0', 'en_US').format(number);
  }

  Widget getTitles(double value, TitleMeta meta) {
    int index = value.toInt();
    if (index < dateLabels.length) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(dateLabels[index],
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
      );
    }
    return const Text('');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return _buildWideLayout();
                } else {
                  return _buildNarrowLayout();
                }
              },
            ),
            const SizedBox(height: 24.0),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : barGroups.isEmpty
                    ? const Center(child: Text('No data available'))
                    : SizedBox(
                        height: 300,
                        child: BarChart(
                          BarChartData(
                            maxY: maxY,
                            barGroups: barGroups,
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: getTitles,
                                  reservedSize: 40,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 125,
                                  interval: maxY > 0 ? maxY / 5 : 1,
                                  getTitlesWidget: (value, meta) {
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        formatNumber(value),
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  String barType = getLabelForRodIndex(rodIndex)
                                      .capitalize();
                                  String date = dateLabels[groupIndex];
                                  return BarTooltipItem(
                                    '$barType\n',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '$date\n',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Rp ${formatNumber(rod.toY)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              touchCallback: (FlTouchEvent event,
                                  BarTouchResponse? response) {
                                setState(() {
                                  if (response == null ||
                                      response.spot == null) {
                                    highlightedBar = null;
                                  } else {
                                    highlightedBar = getLabelForRodIndex(
                                        response.spot!.touchedRodDataIndex);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ),
            const SizedBox(height: 24.0),
            Container(
              alignment: Alignment.center,
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: visibleBars.entries
                    .where((entry) => entry.value)
                    .map((entry) => _legendItem(
                          barColors[entry.key]!,
                          entry.key.capitalize(),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Trend Pendapatan',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Color(0xFF424242),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            _buildFilterButton(
              icon: Icons.location_on,
              label: selectedLocationFilter,
              onPressed: _showLocationFilterDialog,
            ),
            const SizedBox(width: 12),
            _buildFilterButton(
              icon: Icons.calendar_today,
              label: selectedTimeFilter,
              onPressed: _showTimeFilterDialog,
            ),
            const SizedBox(width: 12),
            _buildFilterButton(
              icon: Icons.visibility,
              label: 'Visibilitas',
              onPressed: _showVisibilityDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trend Pendapatan',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Color(0xFF424242),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFilterButton(
              icon: Icons.location_on,
              label: selectedLocationFilter,
              onPressed: _showLocationFilterDialog,
            ),
            _buildFilterButton(
              icon: Icons.calendar_today,
              label: selectedTimeFilter,
              onPressed: _showTimeFilterDialog,
            ),
            _buildFilterButton(
              icon: Icons.visibility,
              label: 'Visibilitas',
              onPressed: _showVisibilityDialog,
            ),
          ],
        ),
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
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }

  void _showLocationFilterDialog() {
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
                      selectedLocationFilter = location;
                    });
                    Navigator.of(context).pop();
                    fetchRevenueData();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showTimeFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Rentang Waktu'),
          content: SingleChildScrollView(
            child: ListBody(
              children: ['7 Hari', '6 Bulan', '6 Tahun'].map((String filter) {
                return ListTile(
                  title: Text(filter),
                  onTap: () {
                    setState(() {
                      selectedTimeFilter = filter;
                    });
                    Navigator.of(context).pop();
                    fetchRevenueData();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showVisibilityDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tombol Visibilitas'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: ListBody(
                  children: visibleBars.keys.map((String key) {
                    return CheckboxListTile(
                      title: Text(key.capitalize()),
                      value: visibleBars[key],
                      onChanged: (bool? value) {
                        setState(() {
                          visibleBars[key] = value!;
                        });
                        this.setState(() {});
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
                fetchRevenueData();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _legendItem(Color color, String label) {
    bool isHighlighted = label.toLowerCase() == highlightedBar;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: isHighlighted ? 16 : 14,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted ? Colors.black : Colors.black54,
          ),
          child: Text(label),
        ),
      ],
    );
  }

  String getLabelForRodIndex(int index) {
    List<String> visibleKeys = visibleBars.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    return index < visibleKeys.length ? visibleKeys[index] : '';
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
