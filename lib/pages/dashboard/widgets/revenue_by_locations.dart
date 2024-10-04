// lib/pages/dashboard/widgets/revenue_by_locations.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/browser_client.dart';
import 'package:intl/intl.dart';

class RevenueByLocations extends StatefulWidget {
  const RevenueByLocations({super.key});

  @override
  _RevenueByLocationsState createState() => _RevenueByLocationsState();
}

class _RevenueByLocationsState extends State<RevenueByLocations> {
  late Future<dynamic> _dataFuture;
  final AuthService authService = AuthService();
  String? selectedLocation;
  String? errorMessage;
  List<String> locations = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchRevenueByLocations();
    _fetchLocations();
  }

  Future<dynamic> fetchRevenueByLocations([String? location]) async {
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
        location == null
            ? 'http://127.0.0.1:8000/api/revenuebylocations/all'
            : 'http://127.0.0.1:8000/api/revenuebylocations/bylocations',
      ).replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
        if (location != null) 'location': location,
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.isEmpty) {
          throw NoDataException('No data available for the selected location');
        }
        return data;
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } on NoDataException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
      return null;
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred while fetching data: $e';
      });
      return null;
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;

      final uri =
          Uri.parse('http://127.0.0.1:8000/api/revenuebylocations/bylocations')
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
        throw Exception(
            'Failed to load locations: ${response.statusCode}\nBody: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch locations: $e';
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
        selectedLocation = selected == 'Semua' ? null : selected;
        errorMessage = null;
        _dataFuture = fetchRevenueByLocations(selectedLocation);
      });
    }
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
                  'Pendapatan Tiap Lokasi',
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
            const SizedBox(height: 16.0),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              _buildErrorWidget()
            else
              _buildDataWidget(),
          ],
        ),
      ),
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
                    fontSize: 16,
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

  Widget _buildDataWidget() {
    return FutureBuilder<dynamic>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }

        final data = snapshot.data;
        if (data is List) {
          return _buildTable(data);
        } else if (data is Map<String, dynamic>) {
          if (selectedLocation != null) {
            return _buildTable(data[selectedLocation] ?? []);
          } else {
            return Column(
              children: data.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        color: Color(0xFF757575),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTable(entry.value),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            );
          }
        }

        return const Center(child: Text('Invalid data format'));
      },
    );
  }

  Widget _buildTable(List<dynamic> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth:
              MediaQuery.of(context).size.width - 32, // Subtracting padding
        ),
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
            return Colors.grey[200];
          }),
          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
            return Colors.white;
          }),
          columns: const [
            DataColumn(
                label: Text('Waktu',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w600))),
            DataColumn(
                label: Text('Titik Lokasi',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w600))),
            DataColumn(
                label: Text('Total Transaksi',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w600))),
            DataColumn(
                label: Text('Total Pendapatan',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w600))),
          ],
          rows: _buildDataRows(data),
        ),
      ),
    );
  }

  List<DataRow> _buildDataRows(List<dynamic> data) {
    final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return data.map((row) {
      return DataRow(
        cells: [
          DataCell(Text(
            DateFormat('dd-MM-yyyy HH:mm:ss')
                .format(DateTime.parse(row['waktu'])),
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w500),
          )),
          DataCell(Text(row['id_lokasi'],
              style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500))),
          DataCell(Text(
            NumberFormat.decimalPattern('id_ID').format(row['total_transaksi']),
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w500),
          )),
          DataCell(Text(
            currencyFormat.format(row['total_pendapatan']),
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w500),
          )),
        ],
      );
    }).toList();
  }
}

class NoDataException implements Exception {
  final String message;
  NoDataException(this.message);
}
