import 'package:flutter/material.dart';
import '../../sms_import/domain/airtel_money_txn.dart';

class NetworkSplitPage extends StatefulWidget {
  final List<AirtelMoneyTxn> txns;
  const NetworkSplitPage({super.key, required this.txns});

  @override
  State<NetworkSplitPage> createState() => _NetworkSplitPageState();
}

enum PeriodPreset { today, week, month, custom }

class _NetworkSplitPageState extends State<NetworkSplitPage> {
  PeriodPreset _preset = PeriodPreset.week; // ✅ default
  DateTimeRange? _customRange;

  // ---------- helpers ----------
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String fmtInt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final left = s.length - i;
      b.write(s[i]);
      if (left > 1 && left % 3 == 1) b.write(',');
    }
    return b.toString();
  }

  DateTimeRange _activeRange() {
    final now = DateTime.now();
    switch (_preset) {
      case PeriodPreset.today:
        return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
      case PeriodPreset.week:
        final start = _startOfDay(now.subtract(Duration(days: now.weekday - 1))); // Mon
        return DateTimeRange(start: start, end: _endOfDay(now));
      case PeriodPreset.month:
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: _startOfDay(start), end: _endOfDay(now));
      case PeriodPreset.custom:
        return _customRange ??
            DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initial,
    );

    if (picked == null) return;

    setState(() {
      _preset = PeriodPreset.custom;
      _customRange = DateTimeRange(
        start: _startOfDay(picked.start),
        end: _endOfDay(picked.end),
      );
    });
  }

  List<AirtelMoneyTxn> _txnsInRange() {
    final r = _activeRange();
    return widget.txns.where((t) {
      final d = t.txnDateTime;
      if (d == null) return false;
      return !d.isBefore(r.start) && !d.isAfter(r.end);
    }).toList();
  }

  _Stats _calcStats(List<AirtelMoneyTxn> txns) {
    int credits = 0;
    int debits = 0;
    int count = txns.length;

    for (final t in txns) {
      if (t.type == AirtelTxnType.credit) {
        credits += t.amount;
      } else {
        debits += t.amount;
      }
    }

    return _Stats(credits: credits, debits: debits, count: count);
  }

  @override
  Widget build(BuildContext context) {
    final all = _txnsInRange();

    final airtelTxns = all.where((t) => t.network == Network.airtel).toList();
    final mtnTxns = all.where((t) => t.network == Network.mtn).toList();

    // sort newest first for details view
    airtelTxns.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    mtnTxns.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    final a = _calcStats(airtelTxns);
    final m = _calcStats(mtnTxns);
    final c = _calcStats(all);

    final range = _activeRange();
    final rangeText = "${_fmtDate(range.start)} → ${_fmtDate(range.end)}";

    return Scaffold(
      appBar: AppBar(title: const Text("Network Split")),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Period + chips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Period: $rangeText",
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip("Today", _preset == PeriodPreset.today,
                          () => setState(() => _preset = PeriodPreset.today)),
                      _chip("Week", _preset == PeriodPreset.week,
                          () => setState(() => _preset = PeriodPreset.week)),
                      _chip("Month", _preset == PeriodPreset.month,
                          () => setState(() => _preset = PeriodPreset.month)),
                      _chip("Custom", _preset == PeriodPreset.custom, _pickCustomRange),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Airtel + MTN cards
            Row(
              children: [
                Expanded(
                  child: _netCard(
                    context: context,
                    title: "Airtel",
                    icon: Icons.sim_card_outlined,
                    txns: airtelTxns,
                    stats: a,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _netCard(
                    context: context,
                    title: "MTN",
                    icon: Icons.network_cell_outlined,
                    txns: mtnTxns,
                    stats: m,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Combined summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                    ),
                    child: Icon(Icons.analytics_outlined,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Combined",
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          "In: ${fmtInt(c.credits)}   Out: ${fmtInt(c.debits)}   Net: ${fmtInt(c.net)}",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Count: ${c.count}",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // small note / empty state
            Expanded(
              child: widget.txns.isEmpty
                  ? const Center(
                      child: Text(
                        "No transactions loaded.\nGo to Import and tap Read.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
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
            fontWeight: FontWeight.w900,
            color: selected ? Colors.deepPurple : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _netCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<AirtelMoneyTxn> txns,
    required _Stats stats,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _TxnListPage(title: "$title (${txns.length})", txns: txns),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "In: ${fmtInt(stats.credits)}",
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              "Out: ${fmtInt(stats.debits)}",
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              "Net: ${fmtInt(stats.net)}",
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              "Count: ${stats.count}",
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats {
  final int credits;
  final int debits;
  final int count;
  int get net => credits - debits;

  const _Stats({required this.credits, required this.debits, required this.count});
}

class _TxnListPage extends StatelessWidget {
  final String title;
  final List<AirtelMoneyTxn> txns;

  const _TxnListPage({required this.title, required this.txns});

  String fmtInt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final left = s.length - i;
      b.write(s[i]);
      if (left > 1 && left % 3 == 1) b.write(',');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: txns.isEmpty
          ? const Center(child: Text("No transactions"))
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: txns.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = txns[i];
                final isCredit = t.type == AirtelTxnType.credit;

                final dt = t.txnDateTime;
                final when = dt == null
                    ? ""
                    : "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: (isCredit ? Colors.green : Colors.red).withOpacity(.12),
                        ),
                        child: Icon(
                          isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isCredit ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "UGX ${fmtInt(t.amount)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text("TID: ${t.tid}",
                                style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 2),
                            Text("Time: $when",
                                style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 2),
                            Text(
                              "${isCredit ? "From" : "To"}: ${t.partyName} ${t.partyNumber}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
