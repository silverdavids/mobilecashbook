import 'package:flutter/material.dart';
import '../../sms_import/domain/airtel_money_txn.dart';

class TransactionsPage extends StatefulWidget {
  final List<AirtelMoneyTxn> txns; // ✅ pass imported txns here
  const TransactionsPage({super.key, required this.txns});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _searchCtrl = TextEditingController();
  String _q = "";
  static const double _dateW  = 64;
static const double _moneyW = 74;
static const double _balW   = 82;
static const double _gap    = 10;
Network? _netFilter; // null = All

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

String _fmtShortDate(DateTime? d) {
  if (d == null) return "";
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  // 2 lines: date then time
  return "$dd/$mm\n$hh:$mi";
}


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

  bool _matches(AirtelMoneyTxn tx) {
    final raw = _q.trim().toLowerCase();
    if (raw.isEmpty) return true;

    final text =
        "${tx.partyName} ${tx.partyNumber} ${tx.tid}".toLowerCase().replaceAll('\n', ' ');

    return text.contains(raw);
  }
  Widget networkSwitch() {
  Widget chip(String text, Network? n, IconData icon) {
    final selected = _netFilter == n;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _netFilter = n),
        icon: Icon(icon, size: 16),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor: selected ? Colors.deepPurple.withOpacity(.08) : null,
          side: BorderSide(color: selected ? Colors.deepPurple : Colors.black12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  return Row(
    children: [
      chip("All", null, Icons.all_inbox),
      const SizedBox(width: 10),
      chip("Airtel", Network.airtel, Icons.sim_card),
      const SizedBox(width: 10),
      chip("MTN", Network.mtn, Icons.sim_card_outlined),
    ],
  );
}


  List<AirtelMoneyTxn> _sortedNewest(List<AirtelMoneyTxn> list) {
    final out = List<AirtelMoneyTxn>.from(list);
    out.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  /// Best-effort: compute a running balance for rows where tx.balance is null.
  /// Strategy:
  /// - Work oldest -> newest
  /// - Keep lastKnownBalance
  /// - If tx.balance present => set lastKnownBalance = it
  /// - Else if lastKnownBalance exists => apply +/- amount
  /// - Else => remain null
  List<_LedgerRow> _buildLedgerRows(List<AirtelMoneyTxn> srcNewest) {
    // Convert to oldest -> newest for running calc
    final oldestFirst = List<AirtelMoneyTxn>.from(srcNewest.reversed);

    int? lastKnown;
    final rowsOldest = <_LedgerRow>[];

    for (final tx in oldestFirst) {
      final isCredit = tx.type == AirtelTxnType.credit;
      final credit = isCredit ? tx.amount : 0;
      final debit = isCredit ? 0 : tx.amount;

      int? displayBal;

      if (tx.balance != null) {
        displayBal = tx.balance;
        lastKnown = tx.balance;
      } else if (lastKnown != null) {
        displayBal = lastKnown + (isCredit ? tx.amount : -tx.amount);
        lastKnown = displayBal;
      } else {
        displayBal = null;
      }

      rowsOldest.add(_LedgerRow(
        tx: tx,
        credit: credit,
        debit: debit,
        displayBalance: displayBal,
      ));
    }

    // return newest-first rows (so UI matches your app)
    return rowsOldest.reversed.toList();
  }
  Widget tableHeaderRow() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(12),
      color: Colors.black.withOpacity(.02),
    ),
    child: Row(
      children: const [
        SizedBox(width: _dateW, child: Text("Date", style: TextStyle(fontWeight: FontWeight.w900))),
        SizedBox(width: _gap),
        Expanded(child: Text("Txn", style: TextStyle(fontWeight: FontWeight.w900))),
        SizedBox(width: _gap),
        SizedBox(width: _moneyW, child: Align(alignment: Alignment.centerRight, child: Text("Cr", style: TextStyle(fontWeight: FontWeight.w900)))),
        SizedBox(width: _gap),
        SizedBox(width: _moneyW, child: Align(alignment: Alignment.centerRight, child: Text("Dr", style: TextStyle(fontWeight: FontWeight.w900)))),
        SizedBox(width: _gap),
        SizedBox(width: _balW, child: Align(alignment: Alignment.centerRight, child: Text("Bal", style: TextStyle(fontWeight: FontWeight.w900)))),
      ],
    ),
  );
}

Widget ledgerRow(_LedgerRow r) {
  final tx = r.tx;

  final title = tx.partyName.trim().isEmpty ? "Transaction" : tx.partyName.trim();
  final creditText = r.credit == 0 ? "" : _fmtInt(r.credit);
  final debitText  = r.debit  == 0 ? "" : _fmtInt(r.debit);
  final balText    = r.displayBalance == null ? "—" : _fmtInt(r.displayBalance!);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _dateW,
          child: Text(
            _fmtShortDate(tx.txnDateTime),
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: _gap),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                "TID: ${tx.tid}${tx.partyNumber.isNotEmpty ? " • ${tx.partyNumber}" : ""}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),

        const SizedBox(width: _gap),
        SizedBox(
          width: _moneyW,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(creditText,
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green),
            ),
          ),
        ),

        const SizedBox(width: _gap),
        SizedBox(
          width: _moneyW,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(debitText,
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red),
            ),
          ),
        ),

        const SizedBox(width: _gap),
        SizedBox(
          width: _balW,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(balText, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    ),
  );
}


Widget pageHeader({required int rowCount}) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ledger",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              "$rowCount rows",
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: () {
          // optional: open filters / export / settings
        },
        icon: const Icon(Icons.tune),
        tooltip: "Filters",
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
   final filtered = widget.txns
    .where(_matches)
    .where((t) => _netFilter == null || t.network == _netFilter)
    .toList();

    final newest = _sortedNewest(filtered);
    final rows = _buildLedgerRows(newest);

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header row (title + count)
   pageHeader(rowCount: rows.length),
const SizedBox(height: 12),

networkSwitch(),
const SizedBox(height: 12),

              // Search
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Search name / phone / TID",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _q.isEmpty
    ? null
    : IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          _searchCtrl.clear();
          setState(() => _q = "");
        },
      ),
                    
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
              const SizedBox(height: 12),

              // Table header
            // --- Table + Rows
Expanded(
  child: rows.isEmpty
      ? const Center(child: Text("No transactions to display.", style: TextStyle(color: Colors.black54)))
      : LayoutBuilder(
          builder: (context, c) {
            // Minimum width needed for your columns without squashing "Txn"
            const minTableWidth = 520.0;

            final table = Column(
              children: [
                tableHeaderRow(),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => ledgerRow(rows[i]),
                  ),
                ),
              ],
            );

            // If screen is wide enough, no horizontal scroll.
            if (c.maxWidth >= minTableWidth) return table;

            // Otherwise, enable horizontal scroll so Txn doesn't collapse vertically.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: minTableWidth,
                child: table,
              ),
            );
          },
        ),
),

              const SizedBox(height: 8),

              // Rows
           ],
          ),
        ),
      ),
    );
  }
}

class _LedgerRow {
  final AirtelMoneyTxn tx;
  final int credit;
  final int debit;
  final int? displayBalance;

  _LedgerRow({
    required this.tx,
    required this.credit,
    required this.debit,
    required this.displayBalance,
  });
}
