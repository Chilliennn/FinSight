import 'package:flutter/material.dart';

class LogoutPage extends StatelessWidget {
  final VoidCallback onConfirmLogout;

  const LogoutPage({super.key, required this.onConfirmLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, size: 40, color: Color(0xFF2563EB)),
            const SizedBox(height: 12),
            const Text(
              'Logout',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be redirected to the login page.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onConfirmLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Confirm Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
