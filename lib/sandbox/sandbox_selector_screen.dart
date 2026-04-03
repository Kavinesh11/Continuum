// SandboxSelectorScreen — shown after login in sandbox mode.
// Lets you pick a driver persona before entering the app.

import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import 'driver_provider.dart';
import 'sandbox_drivers.dart';

class SandboxSelectorScreen extends StatelessWidget {
  const SandboxSelectorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Text(
                  '🧪  SANDBOX MODE',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select a driver\npersona',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Each persona has pre-loaded location history, order history, and risk profile.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: allSandboxDrivers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final driver = allSandboxDrivers[i];
                    return _DriverCard(driver: driver);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final SandboxDriver driver;

  const _DriverCard({required this.driver});

  static const _tierColors = {
    'Platinum': Color(0xFF7C3AED),
    'Gold': Color(0xFFD97706),
    'Silver': Color(0xFF6B7280),
  };

  static const _tierIcons = {
    'Platinum': Icons.workspace_premium,
    'Gold': Icons.star,
    'Silver': Icons.shield_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColors[driver.tier] ?? Colors.grey;
    final tierIcon = _tierIcons[driver.tier] ?? Icons.shield_outlined;

    return GestureDetector(
      onTap: () {
        DriverProvider.of(context).switchDriver(driver);
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: tierColor.withOpacity(0.2),
                  child: Text(
                    driver.initials,
                    style: TextStyle(
                      color: tierColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        driver.city,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tierIcon, color: tierColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        driver.tier,
                        style: TextStyle(
                          color: tierColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  label: 'Orders this week',
                  value: '${driver.weeklyOrderCount}',
                ),
                _Stat(
                  label: 'Weekly earnings',
                  value: '₹${driver.weeklyEarnings.toStringAsFixed(0)}',
                ),
                _Stat(
                  label: 'Completion',
                  value: '${(driver.completionRate * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    driver.currentLocation.address,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${driver.locationHistory.length} pings',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
