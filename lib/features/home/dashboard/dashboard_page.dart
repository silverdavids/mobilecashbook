import 'package:flutter/material.dart';
import '../../sms_import/domain/airtel_money_txn.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../sms_import/data/txn_store.dart';

enum PeriodPreset { today, week, month, all }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  PeriodPreset _preset = PeriodPreset.week;
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
String _presetTitle() {
  switch (_preset) {
    case PeriodPreset.today:
      return "Today";
    case PeriodPreset.week:
      return "This week";
    case PeriodPreset.month:
      return "This month";
    case PeriodPreset.all:
      return "All time";
  }
}
List<AirtelMoneyTxn> _applyPeriod(List<AirtelMoneyTxn> all) {
  final now = DateTime.now();
  DateTime start;
  final end = _endOfDay(now);

  switch (_preset) {
    case PeriodPreset.today:
      start = _startOfDay(now);
      break;

    case PeriodPreset.week:
      // ✅ "This week" = Monday -> today (local time)
      final monday = now.subtract(Duration(days: now.weekday - DateTime.monday));
      start = _startOfDay(monday);
      break;

    case PeriodPreset.month:
      // ✅ "This month" = 1st -> today
      start = DateTime(now.year, now.month, 1);
      break;

    case PeriodPreset.all:
      return all;
  }

  return all.where((t) {
    final dt = t.txnDateTime;
    if (dt == null) return false;
    return !dt.isBefore(start) && !dt.isAfter(end);
  }).toList();
}
String _periodLabel() {
  final now = DateTime.now();
  late DateTime start;
  final end = _endOfDay(now);

  switch (_preset) {
    case PeriodPreset.today:
      start = _startOfDay(now);
      break;
    case PeriodPreset.week:
      final monday = now.subtract(Duration(days: now.weekday - DateTime.monday));
      start = _startOfDay(monday);
      break;
    case PeriodPreset.month:
      start = DateTime(now.year, now.month, 1);
      break;
    case PeriodPreset.all:
      return "All time";
  }

  final f = DateFormat("yyyy-MM-dd");
  return "${f.format(start)} → ${f.format(end)}";
}
String _ugx(int v) {
  final f = NumberFormat.decimalPattern(); // 1,234,567
  return "UGX ${f.format(v)}";
}

  int _sumIncome(List<AirtelMoneyTxn> list) =>
      list.where((t) => t.type == AirtelTxnType.credit).fold(0, (a, b) => a + b.amount);

  int _sumExpense(List<AirtelMoneyTxn> list) =>
      list.where((t) => t.type == AirtelTxnType.debit).fold(0, (a, b) => a + b.amount);

 AirtelMoneyTxn? _latestWithBalanceByNet(List<AirtelMoneyTxn> all, Network net) {
  final list = all
      .where((t) => t.txnDateTime != null && t.balance != null && t.network == net)
      .toList()
    ..sort((a, b) => b.txnDateTime!.compareTo(a.txnDateTime!));

  return list.isEmpty ? null : list.first;
}

int? _currentBalanceFor(List<AirtelMoneyTxn> txns, Network net) =>
    _latestWithBalanceByNet(txns, net)?.balance;

String _balText(int? v) => v == null ? "—" : _ugx(v);
@override
Widget build(BuildContext context) {
  final box = Hive.box(TxnStore.boxName);

  print("[SMSDBG][DASH] build() called");

  return ValueListenableBuilder(
    valueListenable: box.listenable(),
    builder: (context, _, __) {
      print("[SMSDBG][DASH] Hive listenable triggered");
      print("[SMSDBG][DASH] raw box count=${box.length}");

      final txns = box.values
          .map((e) => AirtelMoneyTxn.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      print("[SMSDBG][DASH] parsed txns count=${txns.length}");

      final filtered = _applyPeriod(txns);
      final income = _sumIncome(filtered);
      final expense = _sumExpense(filtered);
      final net = income - expense;

      final mtnBal = _latestWithBalanceByNet(txns, Network.mtn)?.balance;
      final airtelBal = _latestWithBalanceByNet(txns, Network.airtel)?.balance;

      final hasAnyBal = (mtnBal != null) || (airtelBal != null);
      final totalBal = (mtnBal ?? 0) + (airtelBal ?? 0);
      final displayBalance = hasAnyBal ? totalBal : net;

      print("[SMSDBG][DASH] filtered count=${filtered.length}");
      print("[SMSDBG][DASH] income=$income expense=$expense net=$net");

      return Scaffold(
        appBar: AppBar(
          title: const Text("Dashboard"),
          actions: [
            PopupMenuButton<PeriodPreset>(
              initialValue: _preset,
              onSelected: (v) => setState(() => _preset = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: PeriodPreset.today, child: Text("Today")),
                PopupMenuItem(value: PeriodPreset.week, child: Text("This week")),
                PopupMenuItem(value: PeriodPreset.month, child: Text("This month")),
                PopupMenuItem(value: PeriodPreset.all, child: Text("All time")),
              ],
              icon: const Icon(Icons.calendar_month),
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _balanceCard(displayBalance, net),
            if (_preset != PeriodPreset.all) ...[
              const SizedBox(height: 6),
              Text(_periodLabel(),
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _miniCard("MTN Balance", _balText(mtnBal), Icons.sim_card, Colors.purple),
                const SizedBox(width: 8),
                _miniCard("Airtel Balance", _balText(airtelBal), Icons.sim_card, Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniCard("Income", _ugx(income), Icons.arrow_downward, Colors.green),
                const SizedBox(width: 8),
                _miniCard("Expenses", _ugx(expense), Icons.arrow_upward, Colors.red),
                const SizedBox(width: 8),
                _miniCard("Net", _ugx(net), Icons.ssid_chart, Colors.blue),
              ],
            ),
            const SizedBox(height: 18),
            const Text("Recent transactions",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._recentTxns(txns),
          ],
        ),
      );
    },
  );
}
  @override
 Widget _balanceCard(int balance, int net) {
    final sign = net >= 0 ? "+" : "-";
    final netAbs = net.abs();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Current Balance", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            _ugx(balance),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
        Text(
  "$sign${_ugx(netAbs)} in ${_presetTitle().toLowerCase()}",
  style: const TextStyle(color: Colors.white70),
),
        ],
      ),
    );
  }

  Widget _miniCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  List<Widget> _recentTxns(List<AirtelMoneyTxn> all) {
    final list = all.where((t) => t.txnDateTime != null).toList()
      ..sort((a, b) => b.txnDateTime!.compareTo(a.txnDateTime!));

    final top = list.take(6).toList();

    if (top.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.withOpacity(0.1),
          ),
          child: const Text("No transactions yet. Import SMS to begin."),
        )
      ];
    }

    return top.map((t) {
      final isCredit = t.type == AirtelTxnType.credit;
      final amt = _ugx(t.amount);
      final dt = t.txnDateTime!;
      final dateTxt = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: (isCredit ? Colors.green : Colors.red).withOpacity(0.15),
          child: Icon(isCredit ? Icons.call_received : Icons.call_made, color: isCredit ? Colors.green : Colors.red),
        ),
        title: Text(t.partyName.isEmpty ? (isCredit ? "Received" : "Sent") : t.partyName),
        subtitle: Text("${t.network.name.toUpperCase()} • $dateTxt"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(isCredit ? "+$amt" : "-$amt",
                style: TextStyle(fontWeight: FontWeight.bold, color: isCredit ? Colors.green : Colors.red)),
            if (t.balance != null) Text(_ugx(t.balance!), style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      );
    }).toList();
  }
}