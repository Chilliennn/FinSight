import 'package:flutter/material.dart';

import 'presentation/shared/app_layout.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinSight AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      // Dashboard is the root route — built with nav callbacks via buildDashboardWithNav
      home: Builder(
        builder: (context) => AppLayout(
          // title: 'Dashboard',
          // child: buildDashboardWithNav(context),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const AppLayout(),
    );
  }
}