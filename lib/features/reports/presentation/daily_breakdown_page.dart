import 'package:flutter/material.dart';
import '../../sms_import/domain/airtel_money_txn.dart';

class DailyBreakdownPage extends StatefulWidget {
  final List<AirtelMoneyTxn> txns;
  const DailyBreakdownPage({super.key, required this.txns});

  @override
  State<DailyBreakdownPage> createState() => _DailyBreakdownPageState();
}

enum PeriodPreset { today, week, month, custom }
enum NetworkFilter { all, airtel, mtn }

class _DailyBreakdownPageState extends State<DailyBreakdownPage> {
  PeriodPreset _preset = PeriodPreset.week; // ✅ default
  NetworkFilter _net = NetworkFilter.all;

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

  bool _matchesNetwork(AirtelMoneyTxn t) {
    if (_net == NetworkFilter.all) return true;
    if (_net == NetworkFilter.airtel) return t.network == Network.airtel;
    return t.network == Network.mtn;
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

  // ---------- compute ----------
  List<AirtelMoneyTxn> _filteredTxns() {
    final range = _activeRange();
    final start = range.start;
    final end = range.end;

    final list = widget.txns.where((t) {
      if (!_matchesNetwork(t)) return false;
      final d = t.txnDateTime;
      if (d == null) return false;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    list.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad); // newest first
    });

    return list;
  }

  List<_DayRow> _buildDayRows(List<AirtelMoneyTxn> txns) {
    final map = <String, _DayRow>{};

    for (final t in txns) {
      final d = t.txnDateTime!;
      final day = _startOfDay(d);
      final key = _fmtDate(day);

      final row = map.putIfAbsent(
        key,
        () => _DayRow(day: day, credits: 0, debits: 0, count: 0, items: []),
      );

      row.count += 1;
      row.items.add(t);

      if (t.type == AirtelTxnType.credit) {
        row.credits += t.amount;
      } else {
        row.debits += t.amount;
      }
    }

    final rows = map.values.toList();
    rows.sort((a, b) => b.day.compareTo(a.day)); // newest day first
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final txns = _filteredTxns();
    final rows = _buildDayRows(txns);

    final range = _activeRange();
    final rangeText = "${_fmtDate(range.start)} → ${_fmtDate(range.end)}";

    final totalIn = txns
        .where((t) => t.type == AirtelTxnType.credit)
        .fold<int>(0, (s, t) => s + t.amount);
    final totalOut = txns
        .where((t) => t.type == AirtelTxnType.debit)
        .fold<int>(0, (s, t) => s + t.amount);
    final net = totalIn - totalOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Breakdown"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // --- filters & totals
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text("Network:",
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      DropdownButton<NetworkFilter>(
                        value: _net,
                        onChanged: (v) => setState(() => _net = v ?? NetworkFilter.all),
                        items: const [
                          DropdownMenuItem(value: NetworkFilter.all, child: Text("All")),
                          DropdownMenuItem(value: NetworkFilter.airtel, child: Text("Airtel")),
                          DropdownMenuItem(value: NetworkFilter.mtn, child: Text("MTN")),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
           LayoutBuilder(
  builder: (context, c) {
    final w = c.maxWidth;
    final spacing = 10.0;
    final itemW = (w - spacing * 2) / 3; // 3 items + 2 gaps

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        SizedBox(
          width: itemW,
          child: _miniStat("In", "UGX ${fmtInt(totalIn)}",
              icon: Icons.call_received_outlined),
        ),
        SizedBox(
          width: itemW,
          child: _miniStat("Out", "UGX ${fmtInt(totalOut)}",
              icon: Icons.call_made_outlined),
        ),
        SizedBox(
          width: itemW,
          child: _miniStat("Net", "UGX ${fmtInt(net)}",
              icon: Icons.analytics_outlined),
        ),
      ],
    );
  },
),

                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- list
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        widget.txns.isEmpty
                            ? "No transactions loaded.\nGo to Import and tap Read."
                            : "No results for this period.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                   itemBuilder: (context, i) {
  final r = rows[i];
  final netDay = r.credits - r.debits;

  final netColor = netDay > 0
      ? Colors.green
      : netDay < 0
          ? Colors.red
          : Colors.black54;

  final netBg = netDay > 0
      ? Colors.green.withOpacity(.08)
      : netDay < 0
          ? Colors.red.withOpacity(.08)
          : Colors.black.withOpacity(.04);

  final netBorder = netDay > 0
      ? Colors.green.withOpacity(.25)
      : netDay < 0
          ? Colors.red.withOpacity(.25)
          : Colors.black12;

  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _DayDetailsPage(
            title: _fmtDate(r.day),
            txns: r.items..sort((a, b) {
              final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            }),
          ),
        ),
      );
    },
    child: Container(
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
            child: Icon(Icons.calendar_month_outlined,
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDate(r.day),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  "In: ${fmtInt(r.credits)}   Out: ${fmtInt(r.debits)}   Count: ${r.count}",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ✅ NET pill: red for -ve, green for +ve
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: netBg,
              border: Border.all(color: netBorder),
            ),
            child: Text(
              "UGX ${fmtInt(netDay)}",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: netColor,
              ),
            ),
          ),

          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Colors.black45),
        ],
      ),
    ),
  );
},

                    ),
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

Widget _miniStat(String title, String value, {required IconData icon}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // ✅ this makes numbers always visible
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
    ),
  );
}

}

class _DayRow {
  final DateTime day;
  int credits;
  int debits;
  int count;
  final List<AirtelMoneyTxn> items;

  _DayRow({
    required this.day,
    required this.credits,
    required this.debits,
    required this.count,
    required this.items,
  });
}

class _DayDetailsPage extends StatelessWidget {
  final String title;
  final List<AirtelMoneyTxn> txns;
  const _DayDetailsPage({required this.title, required this.txns});

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
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: txns.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final t = txns[i];
          final isCredit = t.type == AirtelTxnType.credit;
          final net = t.network == Network.airtel ? "Airtel" : "MTN";

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
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text("TID: ${t.tid}", style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text("Net: $net • $when",
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text("${isCredit ? "From" : "To"}: ${t.partyName} ${t.partyNumber}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54)),
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
