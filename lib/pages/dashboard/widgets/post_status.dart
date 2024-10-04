// lib/pages/dashboard/widgets/post_status.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/browser_client.dart';

class PostStatus extends StatefulWidget {
  const PostStatus({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PostStatusState createState() => _PostStatusState();
}

class _PostStatusState extends State<PostStatus> {
  // ... (kode lainnya tetap sama)
  Map<String, dynamic> _postStatusData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  int _touchedIndex = -1;
  String? selectedLocation;
  List<String> locations = ['Semua'];
  AuthService authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    fetchPostStatus();
  }

  Future<void> _fetchLocations() async {
    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;
      final uri = Uri.parse('http://127.0.0.1:8000/api/poststatus/bylocations')
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

  Future<void> fetchPostStatus([String? location]) async {
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
            ? 'http://127.0.0.1:8000/api/poststatus/all'
            : 'http://127.0.0.1:8000/api/poststatus/bylocations',
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
          if (location == null || location == 'Semua') {
            data = decodedData;
          } else {
            data = (decodedData[location] as List<dynamic>).first;
          }
        } else {
          throw Exception('Unexpected data format');
        }

        setState(() {
          _postStatusData = data;
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

  void _openFilterDialog() async {
    final selected = await showDialog<String>(
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
                    Navigator.of(context).pop(location);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selected != null && selected != selectedLocation) {
      setState(() {
        selectedLocation = selected;
        fetchPostStatus(selected);
      });
    }
  }

  Widget _buildStatusCard(BuildContext context, String title, Color color,
      String count, String transactionSum) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count Pos',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // const SizedBox(height: 4),
            Text(
              'Transaksi\n$transactionSum',
              // textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, dynamic> data) {
    var activeCount = data['jumlah_pos_online'] as int;
    var inactiveCount = data['jumlah_pos_offline'] as int;

    Map<String, double> postData = {
      'POS ONLINE': activeCount.toDouble(),
      'POS OFFLINE': inactiveCount.toDouble(),
    };

    final total = activeCount + inactiveCount;

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 40,
            // startDegreeOffset: -90,
            sections: postData.entries.map((entry) {
              final vehicleType = entry.key;
              final percentage = (entry.value / total * 100).toDouble();
              final isTouch =
                  _touchedIndex == postData.keys.toList().indexOf(vehicleType);

              return PieChartSectionData(
                color: vehicleType == 'POS ONLINE'
                    ? const Color(0xCC28C76F)
                    : const Color(0xCCC72828),
                value: entry.value,
                title: '',
                radius: isTouch ? 50 : 40,
                badgeWidget: isTouch
                    ? Padding(
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
                              '${entry.value.toInt()} pos',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                badgePositionPercentageOffset: 0.9,
              );
            }).toList(),
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
                  'Status Pos',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF757575),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton.icon(
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
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _buildStatusCard(
                                      context,
                                      'POS ONLINE',
                                      const Color(0xCC28C76F),
                                      _postStatusData['jumlah_pos_online']
                                          .toString(),
                                      _postStatusData[
                                              'total_transaksi_pos_online']
                                          .toString(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _buildStatusCard(
                                      context,
                                      'POS OFFLINE',
                                      const Color(0xCCC72828),
                                      _postStatusData['jumlah_pos_offline']
                                          .toString(),
                                      _postStatusData[
                                              'total_transaksi_pos_offline']
                                          .toString(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildPieChart(_postStatusData),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
