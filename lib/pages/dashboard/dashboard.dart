// lib/pages/dashboard/dashboard.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../components/sidebar.dart';
import 'widgets/summary_cards.dart';
import 'widgets/revenue_realtime_percentage.dart';
import 'widgets/post_status.dart';
import 'widgets/revenue_by_locations.dart';
import 'widgets/combined_widget.dart';
import 'widgets/traffic_hours.dart';

  
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Timer _timer;
  late DateTime _currentTime;
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('id_ID', null);
    setState(() {
      _localeInitialized = true;
      _currentTime = DateTime.now();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    final dayFormat = DateFormat('EEEE', 'id_ID');
    final dateFormat = DateFormat('d MMMM y', 'id_ID');
    final timeFormat = DateFormat('HH:mm:ss');

    return '${dayFormat.format(dateTime)}, ${dateFormat.format(dateTime)} - ${timeFormat.format(dateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: _localeInitialized
                  ? Text(_formatDateTime(_currentTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ))
                  : const CircularProgressIndicator(),
            ),
          ),
        ],
      ),
      drawer: const Sidebar(),
      body: _localeInitialized
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSummaryCardsGrid(constraints),
                        const SizedBox(height: 16),
                        _buildMainContent(constraints),
                      ],
                    ),
                  ),
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSummaryCardsGrid(BoxConstraints constraints) {
    int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      childAspectRatio: constraints.maxWidth < 600 ? 1.5 : 2.5,
      mainAxisSpacing: 16.0,
      crossAxisSpacing: 16.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _buildSummaryCards(),
    );
  }

  Widget _buildMainContent(BoxConstraints constraints) {
    if (constraints.maxWidth >= 1200) {
      // Desktop layout
      return const Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 300,
                  child: RevenueRealtimePercentage(),
                ),
              ),
              SizedBox(width: 16.0),
              Expanded(
                child: SizedBox(
                  height: 300,
                  child: PostStatus(),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          RevenueByLocations(),
          SizedBox(height: 16),
          TrafficHours(),
          SizedBox(height: 16),
          CombinedRevenueWidget(),
        ],
      );
    } else {
      // Tablet and Mobile layout
      return const Column(
        children: [
          RevenueRealtimePercentage(),
          SizedBox(height: 16),
          PostStatus(),
          SizedBox(height: 16),
          RevenueByLocations(),
          SizedBox(height: 16),
          TrafficHours(),
          SizedBox(height: 16),
          CombinedRevenueWidget(),
        ],
      );
    }
  }

  List<Widget> _buildSummaryCards() {
    return [
      const SummaryCards(
        title: 'Pendapatan 7 Hari Terakhir',
        apiUrl: 'http://127.0.0.1:8000/api/summarycards/',
      ),
      const SummaryCards(
        title: 'Pendapatan Hari Ini',
        apiUrl: 'http://127.0.0.1:8000/api/summarycards/',
      ),
      const SummaryCards(
        title: 'Transaksi 7 Hari Terakhir',
        apiUrl: 'http://127.0.0.1:8000/api/summarycards/',
      ),
      const SummaryCards(
        title: 'Transaksi Hari Ini',
        apiUrl: 'http://127.0.0.1:8000/api/summarycards/',
      ),
    ];
  }
}
