import 'package:flutter/material.dart';

import '../features/home/home_shell.dart';

// ✅ add this

class AppRoutes {
  static const home = '/';
  static const transactions = '/transactions';
  static const smsImport = '/sms-import';
  static const reports = '/reports';
  static const dashboard = "/dashboard";

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
    case home:
  return MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)); // Dashboard

case dashboard:
  return MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0));

case smsImport:
  return MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 1));

case transactions:
  return MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 2));

case reports:
  return MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 3));

      default:
        return MaterialPageRoute(builder: (_) => const HomeShell());
    }
  }
}