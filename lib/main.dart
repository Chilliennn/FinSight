import 'package:flutter/material.dart';
import 'presentation/shared/app_layout.dart';
import 'presentation/dashboard/dashboard_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinSight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AppLayout(
        title: 'Maju Bakery & Cafe',
        child: DashboardContent(),
      ),
    );
  }
}
