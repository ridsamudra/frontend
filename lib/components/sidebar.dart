// lib/components/sidebar.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/browser_client.dart';
import '../services/auth_service.dart';
import '../pages/dashboard/widgets/combined_widget_details.dart';
// import 'package:frontend/config/api_config.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final AuthService _authService = AuthService();
  List<String> locations = [];
  String? errorMessage;
  bool isLocationDropdownOpen = false;
  String?
      selectedLocation; // Tambahin variable untuk menyimpan lokasi yang dipilih

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      final sessionData = await _authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;

      final uri =
          Uri.parse('http://127.0.0.1:8000/api/revenuedetails/locations/')
              .replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        if (data is Map<String, dynamic> && data['status'] == 'success') {
          setState(() {
            locations = List<String>.from(data['locations']);
          });
        } else {
          throw Exception('Invalid data format');
        }
      } else {
        throw Exception('Failed to load locations: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch locations: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset(
                  '../assets/best_parking_logo.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              _buildMenuItem(
                icon: Icons.dashboard,
                title: 'Dashboard',
                onTap: () =>
                    Navigator.of(context).pushReplacementNamed('/dashboard'),
              ),
              const SizedBox(height: 10),
              _buildLocationDropdownButton(),
              if (isLocationDropdownOpen) _buildLocationDropdownList(),
              const Spacer(),
              _buildMenuItem(
                icon: Icons.logout,
                title: 'Logout',
                onTap: () async {
                  await _authService.logout();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(color: Colors.black)),
      onTap: onTap,
    );
  }

  Widget _buildLocationDropdownButton() {
    return ListTile(
      leading: const Icon(Icons.location_on, color: Colors.black),
      title: const Text('Pilih Lokasi', style: TextStyle(color: Colors.black)),
      trailing: Icon(
        isLocationDropdownOpen
            ? Icons.keyboard_arrow_up
            : Icons.keyboard_arrow_down,
        color: Colors.black,
      ),
      onTap: () {
        setState(() {
          isLocationDropdownOpen = !isLocationDropdownOpen;
        });
      },
    );
  }

  Widget _buildLocationDropdownList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: locations.map((location) {
          return ListTile(
            contentPadding: const EdgeInsets.only(left: 16.0, right: 16.0),
            leading: Radio<String>(
              value: location,
              groupValue: selectedLocation, // Ini lokasi yang dipilih
              onChanged: (String? value) {
                setState(() {
                  selectedLocation = value; // Set state buat lokasi terpilih
                });
              },
              activeColor: Colors.blueAccent, // Warna radio button ketika aktif
            ),
            title: Text(
              location,
              style: const TextStyle(color: Colors.black87, fontSize: 15),
            ),
            onTap: () {
              setState(() {
                selectedLocation = location; // Pilih lokasi saat user tap
                isLocationDropdownOpen = false;
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CombinedWidgetDetails(location: location),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
