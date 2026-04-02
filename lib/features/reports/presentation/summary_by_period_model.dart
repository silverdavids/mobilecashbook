// summary_by_period_model.dart

enum TxnFlow { incoming, outgoing, all }
enum Network { airtel, mtn }
enum AirtelTxnType { credit, debit }

class AirtelMoneyTxn {
  final AirtelTxnType type;
  final String tid;
  final int amount;
  final String partyNumber;
  final String partyName;
  final int? balance;
  final DateTime? txnDateTime;
  final Network network;

  const AirtelMoneyTxn({
    required this.type,
    required this.tid,
    required this.amount,
    required this.partyNumber,
    required this.partyName,
    required this.balance,
    required this.txnDateTime,
    required this.network,
  });
}

// -------------------------
// Period
// -------------------------
class ReportPeriod {
  final DateTime from; // inclusive
  final DateTime to;   // inclusive
  const ReportPeriod({required this.from, required this.to});

  bool contains(DateTime? d) {
    if (d == null) return false;
    return !d.isBefore(from) && !d.isAfter(to);
  }
}

// -------------------------
// Summary by period (exact fields you listed)
// -------------------------
class PeriodSummary {
  final ReportPeriod period;
  final Network? network; // null => both networks

  final int totalIn;   // sum credits
  final int totalOut;  // sum debits
  final int net;       // totalIn - totalOut

  final int? openingBalance; // optional (best-effort)
  final int? closingBalance; // optional (best-effort)

  final int txnCount;  // count of txns

  const PeriodSummary({
    required this.period,
    required this.network,
    required this.totalIn,
    required this.totalOut,
    required this.net,
    required this.openingBalance,
    required this.closingBalance,
    required this.txnCount,
  });
}

// -------------------------
// Builder (best-effort opening/closing from balance field)
// -------------------------
DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

PeriodSummary buildPeriodSummary(
  List<AirtelMoneyTxn> all,
  ReportPeriod period, {
  Network? network, // null => both
}) {
  // filter by period + network
  final items = all.where((t) {
    if (!period.contains(t.txnDateTime)) return false;
    if (network != null && t.network != network) return false;
    return true;
  }).toList();

  // compute totals
  int totalIn = 0;
  int totalOut = 0;

  for (final t in items) {
    if (t.type == AirtelTxnType.credit) totalIn += t.amount;
    if (t.type == AirtelTxnType.debit) totalOut += t.amount;
  }

  // opening / closing best-effort:
  // sort oldest->newest then take first/last non-null balance
  items.sort((a, b) {
    final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ad.compareTo(bd);
  });

  int? opening;
  int? closing;

  for (final t in items) {
    if (opening == null && t.balance != null) opening = t.balance;
  }
  for (final t in items.reversed) {
    if (closing == null && t.balance != null) closing = t.balance;
  }

  return PeriodSummary(
    period: period,
    network: network,
    totalIn: totalIn,
    totalOut: totalOut,
    net: totalIn - totalOut,
    openingBalance: opening,
    closingBalance: closing,
    txnCount: items.length,
  );
}

// -------------------------
// Common period helpers
// -------------------------
ReportPeriod todayPeriod() {
  final now = DateTime.now();
  return ReportPeriod(from: _startOfDay(now), to: _endOfDay(now));
}

ReportPeriod thisWeekPeriod() {
  final now = DateTime.now();
  final start = _startOfDay(now.subtract(Duration(days: now.weekday - 1))); // Mon
  return ReportPeriod(from: start, to: _endOfDay(now));
}

ReportPeriod thisMonthPeriod() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  return ReportPeriod(from: _startOfDay(start), to: _endOfDay(now));
}
