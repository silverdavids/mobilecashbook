import 'package:flutter/material.dart';
import '../../app/router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MobileCashBook"),
      ),
     body: Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ElevatedButton(
  onPressed: () => Navigator.pushNamed(context, AppRoutes.dashboard),
  child: const Text("Go Dashboard"),
),
      ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.transactions),
        child: const Text("Go Transactions"),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.smsImport),
        child: const Text("Go SMS Import"),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.reports),
        child: const Text("Go Reports"),
      ),
    ],
  ),
),

    );
  }
}
