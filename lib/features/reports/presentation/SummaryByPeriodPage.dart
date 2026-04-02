import 'package:flutter/material.dart';
import '../../sms_import/domain/airtel_money_txn.dart';
// Use your existing model:
// enum AirtelTxnType { credit, debit }
// enum Network { airtel, mtn }
// class AirtelMoneyTxn { ... amount, balance, txnDateTime, type, network, ... }

class SummaryByPeriodPage extends StatefulWidget {
  final List<AirtelMoneyTxn> txns;
  const SummaryByPeriodPage({super.key, required this.txns});

  @override
  State<SummaryByPeriodPage> createState() => _SummaryByPeriodPageState();
}

enum PeriodPreset { today, week, month, custom }

class _SummaryByPeriodPageState extends State<SummaryByPeriodPage> {
  PeriodPreset _preset = PeriodPreset.today;

  DateTime _from = _startOfDay(DateTime.now());
  DateTime _to = _endOfDay(DateTime.now());

  @override
  void initState() {
    super.initState();
    _applyPreset(_preset);
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _fmtInt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final left = s.length - i;
      b.write(s[i]);
      if (left > 1 && left % 3 == 1) b.write(',');
    }
    return b.toString();
  }

  void _applyPreset(PeriodPreset p) {
    final now = DateTime.now();
    if (p == PeriodPreset.today) {
      _from = _startOfDay(now);
      _to = _endOfDay(now);
    } else if (p == PeriodPreset.week) {
      // Monday -> today
      final start = _startOfDay(now.subtract(Duration(days: now.weekday - 1)));
      _from = start;
      _to = _endOfDay(now);
    } else if (p == PeriodPreset.month) {
      final start = DateTime(now.year, now.month, 1);
      _from = _startOfDay(start);
      _to = _endOfDay(now);
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _preset = PeriodPreset.custom;
      _from = _startOfDay(picked);
      if (_to.isBefore(_from)) _to = _endOfDay(picked);
    });
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _preset = PeriodPreset.custom;
      _to = _endOfDay(picked);
      if (_from.isAfter(_to)) _from = _startOfDay(picked);
    });
  }

  // Core calculation
  _Summary _compute() {
    final txns = widget.txns.where((t) {
      final d = t.txnDateTime;
      if (d == null) return false;
      return !d.isBefore(_from) && !d.isAfter(_to);
    }).toList();

    txns.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd); // oldest -> newest
    });

    int totalIn = 0;
    int totalOut = 0;

    for (final t in txns) {
      if (t.type == AirtelTxnType.credit) totalIn += t.amount;
      if (t.type == AirtelTxnType.debit) totalOut += t.amount;
    }

    final openingBalance = txns.isEmpty ? null : txns.first.balance;
    final closingBalance = txns.isEmpty ? null : txns.last.balance;

    return _Summary(
      count: txns.length,
      totalIn: totalIn,
      totalOut: totalOut,
      net: totalIn - totalOut,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _compute();

    Widget pill(String text, bool selected, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Colors.deepPurple : Colors.black12),
            color: selected ? Colors.deepPurple.withOpacity(.10) : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.deepPurple : Colors.black87,
            ),
          ),
        ),
      );
    }

    Widget metric({
      required String label,
      required String value,
      IconData? icon,
      Color? valueColor,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final rangeText = "${_fmtDate(_from)} → ${_fmtDate(_to)}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Summary by Period"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Presets
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              pill("Today", _preset == PeriodPreset.today, () {
                setState(() {
                  _preset = PeriodPreset.today;
                  _applyPreset(_preset);
                });
              }),
              pill("Week", _preset == PeriodPreset.week, () {
                setState(() {
                  _preset = PeriodPreset.week;
                  _applyPreset(_preset);
                });
              }),
              pill("Month", _preset == PeriodPreset.month, () {
                setState(() {
                  _preset = PeriodPreset.month;
                  _applyPreset(_preset);
                });
              }),
              pill("Custom", _preset == PeriodPreset.custom, () {
                setState(() {
                  _preset = PeriodPreset.custom;
                });
              }),
            ],
          ),

          const SizedBox(height: 12),

          // Custom range pickers (always visible, but mainly used for Custom)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFrom,
                  icon: const Icon(Icons.date_range),
                  label: Text("From: ${_fmtDate(_from)}"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTo,
                  icon: const Icon(Icons.date_range),
                  label: Text("To: ${_fmtDate(_to)}"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Range summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.black54),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rangeText,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  "${s.count} txns",
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          metric(
            label: "Total In (Credits)",
            value: "UGX ${_fmtInt(s.totalIn)}",
            icon: Icons.arrow_downward,
            valueColor: Colors.green,
          ),
          const SizedBox(height: 10),
          metric(
            label: "Total Out (Debits)",
            value: "UGX ${_fmtInt(s.totalOut)}",
            icon: Icons.arrow_upward,
            valueColor: Colors.red,
          ),
          const SizedBox(height: 10),
          metric(
            label: "Net (In − Out)",
            value: "UGX ${_fmtInt(s.net)}",
            icon: Icons.swap_vert,
            valueColor: s.net >= 0 ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 10),
          metric(
            label: "Opening Balance (optional)",
            value: s.openingBalance == null ? "—" : "UGX ${_fmtInt(s.openingBalance!)}",
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 10),
          metric(
            label: "Closing Balance (optional)",
            value: s.closingBalance == null ? "—" : "UGX ${_fmtInt(s.closingBalance!)}",
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }
}

class _Summary {
  final int count;
  final int totalIn;
  final int totalOut;
  final int net;
  final int? openingBalance;
  final int? closingBalance;

  const _Summary({
    required this.count,
    required this.totalIn,
    required this.totalOut,
    required this.net,
    required this.openingBalance,
    required this.closingBalance,
  });
}
