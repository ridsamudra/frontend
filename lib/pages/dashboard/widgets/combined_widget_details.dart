// lib/pages/dashboard/widgets/combined_widget_details.dart

import 'package:flutter/material.dart';
import 'daily_income_details.dart';
import 'monthly_income_details.dart';
import 'yearly_income_details.dart';
import '../../../components/sidebar.dart';
import '../../../components/navbar.dart';

class CombinedWidgetDetails extends StatefulWidget {
  final String location;

  const CombinedWidgetDetails({super.key, required this.location});

  @override
  // ignore: library_private_types_in_public_api
  _CombinedWidgetDetailsState createState() => _CombinedWidgetDetailsState();
}

class _CombinedWidgetDetailsState extends State<CombinedWidgetDetails> {
  String selectedWidget = 'Pendapatan Harian';

  final List<String> widgetOptions = [
    'Pendapatan Harian',
    'Pendapatan Bulanan',
    'Pendapatan Tahunan',
  ];

  Widget _getSelectedWidget() {
    switch (selectedWidget) {
      case 'Pendapatan Harian':
        return DailyIncomeDetails(location: widget.location);
      case 'Pendapatan Bulanan':
        return MonthlyIncomeDetails(location: widget.location);
      case 'Pendapatan Tahunan':
        return YearlyIncomeDetails(location: widget.location);
      default:
        return DailyIncomeDetails(location: widget.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(title: 'Income Details - ${widget.location}'),
      drawer: const Sidebar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    if (newValue != null) {
                      setState(() {
                        selectedWidget = newValue;
                      });
                    }
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
            Expanded(
              child: _getSelectedWidget(),
            ),
          ],
        ),
      ),
    );
  }
}
