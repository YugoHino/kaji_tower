
import 'package:flutter/material.dart';

class ApartmentScreen extends StatefulWidget {
  const ApartmentScreen({super.key});

  @override
  State<ApartmentScreen> createState() => _ApartmentScreenState();
}

class _ApartmentScreenState extends State<ApartmentScreen> {
  // TODO: This should be managed by a central state management solution
  int _totalPoints = 120;
  int _currentFloor = 3;
  int _totalFloors = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total Points Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      '総獲得ポイント',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_totalPoints P',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Apartment Display
            Expanded(
              child: Column(
                children: [
                  Text(
                    '地方都市ステージ',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_currentFloor / $_totalFloors 階',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildApartment(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApartment() {
    return ListView.builder(
      reverse: true, // Start from the bottom floor
      itemCount: _totalFloors,
      itemBuilder: (context, index) {
        final floor = index + 1;
        final isCurrentFloor = floor == _currentFloor;
        final isClearedFloor = floor < _currentFloor;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
          height: 50,
          decoration: BoxDecoration(
            color: isCurrentFloor
                ? Colors.amber[700]
                : isClearedFloor
                    ? Colors.blueGrey[300]
                    : Colors.blueGrey[800],
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              '$floor階',
              style: TextStyle(
                color: isCurrentFloor ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
