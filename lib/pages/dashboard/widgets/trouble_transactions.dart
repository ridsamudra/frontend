// lib/pages/dashboard/widgets/trouble_transactions.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/browser_client.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/auth_service.dart';

/// A widget that displays a bar chart of trouble transactions over time.
/// It allows filtering by different time periods and toggling visibility of locations.
class TroubleTransactions extends StatefulWidget {
  const TroubleTransactions({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TroubleTransactionsState createState() => _TroubleTransactionsState();
}

class _TroubleTransactionsState extends State<TroubleTransactions> {
  final AuthService authService = AuthService();
  String selectedTimeFilter = '7 Hari';
  List<BarChartGroupData> barGroups = [];
  List<String> dateLabels = [];
  bool isLoading = true;
  double maxY = 0;
  List<String> locationNames = [];
  Map<String, Color> locationColorMap = {};
  Map<String, bool> visibleLocations = {};
  String? highlightedLocation;

  // Predefined colors for locations
  final List<Color> locationColors = [
    Colors.blue.shade300,
    Colors.green.shade300,
    Colors.orange.shade300,
    Colors.purple.shade300,
    Colors.red.shade300,
    Colors.teal.shade300,
    Colors.pink.shade300,
    Colors.indigo.shade300,
    Colors.yellow.shade700,
    Colors.cyan.shade300,
    Colors.lime.shade300,
    Colors.amber.shade300,
    Colors.brown.shade300,
  ];

  @override
  void initState() {
    super.initState();
    fetchTroubleData();
  }

  /// Fetches trouble transaction data from the API based on the selected time filter
  Future<void> fetchTroubleData() async {
    setState(() {
      isLoading = true;
    });

    final sessionData = await authService.getSessionData();
    if (sessionData == null) {
      throw Exception('No session data available');
    }

    final client = BrowserClient()..withCredentials = true;
    String baseUrl = 'http://127.0.0.1:8000/api/trouble/';
    String endpoint;

    // Determine the endpoint based on the selected time filter
    if (selectedTimeFilter == '7 Hari') {
      endpoint = 'filterbydays';
    } else if (selectedTimeFilter == '6 Bulan') {
      endpoint = 'filterbymonths';
    } else {
      endpoint = 'filterbyyears';
    }

    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
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

  /// Processes the fetched data and updates the state for chart rendering
  void processData(Map<String, dynamic> jsonData) {
    List<BarChartGroupData> tempBarGroups = [];
    List<String> tempDateLabels = [];
    Set<String> tempLocationNames = {};
    Map<String, Color> tempLocationColorMap = {};
    maxY = 0;

    jsonData.forEach((date, locations) {
      tempDateLabels.add(formatDate(date));
      List<BarChartRodData> rods = [];

      for (var location in locations) {
        double totalMasalah =
            double.parse(location['total_masalah'].toString());
        String locationName = location['nama_lokasi'];
        tempLocationNames.add(locationName);

        // Assign a color to each location
        if (!tempLocationColorMap.containsKey(locationName)) {
          tempLocationColorMap[locationName] = locationColors[
              tempLocationColorMap.length % locationColors.length];
        }

        if (visibleLocations[locationName] ?? true) {
          rods.add(BarChartRodData(
            toY: totalMasalah,
            color: tempLocationColorMap[locationName],
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ));
          maxY = [maxY, totalMasalah].reduce((a, b) => a > b ? a : b);
        }
      }

      tempBarGroups.add(BarChartGroupData(
        x: tempDateLabels.length - 1,
        barRods: rods,
      ));
    });

    setState(() {
      barGroups = tempBarGroups;
      dateLabels = tempDateLabels;
      locationNames = tempLocationNames.toList();
      locationColorMap = tempLocationColorMap;
      isLoading = false;
      adjustMaxY();

      if (visibleLocations.isEmpty) {
        for (var location in locationNames) {
          visibleLocations[location] = true;
        }
      }
    });
  }

  /// Adjusts the maximum Y value for better chart scaling
  void adjustMaxY() {
    if (selectedTimeFilter == '6 Tahun') {
      maxY = (maxY / 10000000).ceil() * 10000000;
    } else if (selectedTimeFilter == '6 Bulan') {
      maxY = (maxY / 1000000).ceil() * 1000000;
    } else {
      maxY = (maxY / 100000).ceil() * 100000;
    }
    maxY = maxY == 0 ? 1 : maxY;
  }

  /// Formats the date string based on the selected time filter
  String formatDate(String dateString) {
    if (selectedTimeFilter == '7 Hari') {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM').format(date);
    } else if (selectedTimeFilter == '6 Bulan') {
      return _formatMonthYear(dateString);
    } else {
      return dateString;
    }
  }

  /// Formats the month and year for the '6 Bulan' filter
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

  /// Formats large numbers with commas for better readability
  String formatNumber(double number) {
    return NumberFormat('#,##0', 'en_US').format(number);
  }

  /// Generates the bottom titles for the bar chart
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
            // Responsive layout for the title and filter buttons
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
            // Chart or loading indicator
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : barGroups.isEmpty
                    ? const Center(child: Text('No data available'))
                    : SizedBox(
                        height: 300,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Adjust chart size for different screen sizes
                            double chartHeight = constraints.maxHeight;
                            double chartWidth = constraints.maxWidth;
                            return SizedBox(
                              height: chartHeight,
                              width: chartWidth,
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
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: const FlGridData(show: false),
                                  barTouchData: BarTouchData(
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem:
                                          (group, groupIndex, rod, rodIndex) {
                                        String locationName =
                                            locationNames[rodIndex];
                                        return BarTooltipItem(
                                          '$locationName\n',
                                          const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          children: [
                                            TextSpan(
                                              text:
                                                  '${dateLabels[groupIndex]}\n',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  'Rp ${formatNumber(rod.toY)}',
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
                                          highlightedLocation = null;
                                        } else {
                                          int touchedRodIndex = response
                                              .spot!.touchedRodDataIndex;
                                          highlightedLocation =
                                              locationNames[touchedRodIndex];
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            const SizedBox(height: 24.0),
            // Legend
            Container(
              alignment: Alignment.center,
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: locationNames
                    .where((location) => visibleLocations[location] ?? false)
                    .map((location) => _legendItem(
                          locationColorMap[location]!,
                          location,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the layout for wide screens (e.g., desktop)
  Widget _buildWideLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Trend Tiket Bermasalah',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Color(0xFF424242),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            _buildFilterButton(),
            const SizedBox(width: 12),
            _buildVisibilityButton(),
          ],
        ),
      ],
    );
  }

  /// Builds the layout for narrow screens (e.g., mobile)
  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trend Tiket Bermasalah',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Color(0xFF424242),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _buildFilterButton()),
            const SizedBox(width: 12),
            Expanded(child: _buildVisibilityButton()),
          ],
        ),
      ],
    );
  }

  /// Builds the time filter button
  Widget _buildFilterButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 18),
      label: Text(selectedTimeFilter),
      onPressed: _showTimeFilterDialog,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Builds the visibility toggle button
  Widget _buildVisibilityButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.visibility, size: 18),
      label: const Text('Visibilitas'),
      onPressed: _showVisibilityDialog,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Builds a legend item for a specific location
  Widget _legendItem(Color color, String text) {
    bool isHighlighted = text == highlightedLocation;
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
          child: Text(text),
        ),
      ],
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
                    fetchTroubleData();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// Shows a dialog to toggle visibility of locations
  void _showVisibilityDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tombol Visibilitas'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: locationNames.map((location) {
                    return CheckboxListTile(
                      title: Text(location),
                      value: visibleLocations[location] ?? true,
                      onChanged: (bool? value) {
                        setState(() {
                          visibleLocations[location] = value!;
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
                fetchTroubleData();
              },
            ),
          ],
        );
      },
    );
  }
}
