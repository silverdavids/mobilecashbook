import 'package:flutter/material.dart';
import '../transactions/presentation/transactions_page.dart';
import '../sms_import/presentation/sms_import_page.dart';
import '../reports/presentation/reports_page.dart';
import './dashboard/dashboard_page.dart';
import '../sms_import/data/txn_store.dart';
import '../sms_import/domain/airtel_money_txn.dart';
import 'package:hive_flutter/hive_flutter.dart';
class HomeShell extends StatefulWidget {
  final int initialIndex;
  const HomeShell({super.key, this.initialIndex = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialIndex;
  }

  List<AirtelMoneyTxn> _readTxnsFromHive(Box box) {
    return box.values
        .map((e) => AirtelMoneyTxn.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.txnDateTime != null) // optional
        .toList()
      ..sort((a, b) => b.txnDateTime!.compareTo(a.txnDateTime!));
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(TxnStore.boxName);

    return ValueListenableBuilder(
      valueListenable: box.listenable(), // ✅ auto-refresh all pages
      builder: (context, _, __) {
        final txns = _readTxnsFromHive(box);

        final pages = [
          const DashboardPage(), // ✅ dashboard reads Hive internally (your new version)
          SmsImportPage(
            onTxnsChanged: (list) async {
              // ✅ optional: if your import page already calls TxnStore.upsert per item,
              // you can delete this callback or leave it empty.
              for (final tx in list) {
                await TxnStore.upsert(tx);
              }
            },
          ),
          TransactionsPage(txns: txns),
          ReportsPage(txns: txns),
        ];

        final safeTab = _tab.clamp(0, pages.length - 1);

        return Scaffold(
          body: pages[safeTab],
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: Offset(0, -2),
                  color: Colors.black12,
                )
              ],
            ),
            child: SafeArea(
              child: BottomNavigationBar(
                backgroundColor: Colors.white,
                type: BottomNavigationBarType.fixed,
                currentIndex: safeTab,
                selectedItemColor: Colors.blue,
                unselectedItemColor: Colors.black54,
                showUnselectedLabels: true,
                onTap: (i) => setState(() => _tab = i),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
                  BottomNavigationBarItem(icon: Icon(Icons.sms), label: "Import"),
                  BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Txns"),
                  BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Reports"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}