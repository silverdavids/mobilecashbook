import 'package:flutter/material.dart';
import '../../sms_import/domain/airtel_money_txn.dart';

class TxnsByRecipientPage extends StatefulWidget {
  final List<AirtelMoneyTxn> txns;
  const TxnsByRecipientPage({super.key, required this.txns});

  @override
  State<TxnsByRecipientPage> createState() => _TxnsByRecipientPageState();
}

enum PeriodPreset { today, week, month, custom }
enum NetworkFilter { all, airtel, mtn }

class _TxnsByRecipientPageState extends State<TxnsByRecipientPage> {
  PeriodPreset _preset = PeriodPreset.today;
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

  String _recipientLabel(AirtelMoneyTxn t) {
    final name = (t.partyName).trim();
    final num = (t.partyNumber).trim();
    if (name.isEmpty && num.isEmpty) return "Unknown";
    if (name.isEmpty) return num;
    if (num.isEmpty) return name;
    return "$name • $num";
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
  List<AirtelMoneyTxn> _filteredDebits() {
    final range = _activeRange();
    final start = range.start;
    final end = range.end;

    final list = widget.txns.where((t) {
      if (t.type != AirtelTxnType.debit) return false; // ✅ debits only
      if (!_matchesNetwork(t)) return false;

      final d = t.txnDateTime;
      if (d == null) return false;

      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    // newest first
    list.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    return list;
  }

  List<_RecipientGroup> _groupByRecipient(List<AirtelMoneyTxn> debits) {
    final map = <String, _RecipientGroup>{};

    for (final t in debits) {
      // group key: partyNumber if present else name
      final key = (t.partyNumber.trim().isNotEmpty)
          ? t.partyNumber.trim()
          : t.partyName.trim().toLowerCase();

      final label = _recipientLabel(t);

      final existing = map[key];
      if (existing == null) {
        map[key] = _RecipientGroup(
          key: key,
          label: label,
          total: t.amount,
          count: 1,
          items: [t],
        );
      } else {
        existing.total += t.amount;
        existing.count += 1;
        existing.items.add(t);
      }
    }

    final groups = map.values.toList();
    groups.sort((a, b) => b.total.compareTo(a.total)); // total out desc
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final debits = _filteredDebits();
    final groups = _groupByRecipient(debits);

    final range = _activeRange();
    final rangeText = "${_fmtDate(range.start)} → ${_fmtDate(range.end)}";

    final totalOut = debits.fold<int>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Debits by Recipient"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // --- filters card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Period: $rangeText",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
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
                      const Text("Network:", style: TextStyle(fontWeight: FontWeight.w800)),
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
                      const Spacer(),
                      Text(
                        "Total Out: UGX ${fmtInt(totalOut)}",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- list
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        widget.txns.isEmpty
                            ? "No transactions loaded.\nGo to Import and tap Read."
                            : "No debits found for this filter.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _RecipientDetailsPage(
                                  title: g.label,
                                  txns: g.items,
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(.10),
                                  ),
                                  child: Icon(
                                    Icons.person_search_outlined,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Count: ${g.count}",
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "UGX ${fmtInt(g.total)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
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
}

class _RecipientGroup {
  final String key;
  final String label;
  int total;
  int count;
  final List<AirtelMoneyTxn> items;

  _RecipientGroup({
    required this.key,
    required this.label,
    required this.total,
    required this.count,
    required this.items,
  });
}

class _RecipientDetailsPage extends StatelessWidget {
  final String title;
  final List<AirtelMoneyTxn> txns;

  const _RecipientDetailsPage({required this.title, required this.txns});

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
          final dt = t.txnDateTime;
          final when = dt == null
              ? ""
              : "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
                "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

          final net = t.network == Network.airtel ? "Airtel" : "MTN";

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "UGX ${fmtInt(t.amount)}",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text("TID: ${t.tid}", style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text("When: $when", style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text("Network: $net", style: const TextStyle(color: Colors.black54)),
              ],
            ),
          );
        },
      ),
    );
  }
}
