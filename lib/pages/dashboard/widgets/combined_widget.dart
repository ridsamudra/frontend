// lib/pages/dashboard/widgets/combined_widget.dart

import 'package:flutter/material.dart';
import 'revenue_trends.dart';
import 'revenue_trends_by_locations.dart';
import 'trouble_transactions.dart';

class CombinedRevenueWidget extends StatefulWidget {
  const CombinedRevenueWidget({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CombinedRevenueWidgetState createState() => _CombinedRevenueWidgetState();
}

class _CombinedRevenueWidgetState extends State<CombinedRevenueWidget> {
  String? selectedWidget;

  final List<String> widgetOptions = [
    'Trend Pendapatan',
    'Trend Pendapatan Tiap Lokasi',
    'Trend Tiket Bermasalah',
  ];

  Widget _getSelectedWidget() {
    switch (selectedWidget) {
      case 'Trend Pendapatan':
        return const RevenueTrends();
      case 'Trend Pendapatan Tiap Lokasi':
        return const RevenueTrendsByLocations();
      case 'Trend Tiket Bermasalah':
        return const TroubleTransactions();
      default:
        return const RevenueTrends();
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
            if (selectedWidget == null)
              const Text(
                'Silakan pilih widget',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Color(0xFF757575),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 16.0),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedWidget,
                  hint: const Text(
                    'Pilih widget:',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: Color(0xFF757575),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  iconSize: 24,
                  elevation: 16,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF757575),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedWidget = newValue;
                    });
                  },
                  items: widgetOptions
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            if (selectedWidget != null) _getSelectedWidget(),
          ],
        ),
      ),
    );
  }
}
