// reports_models.dart
// Data models + pure aggregators for reports (works directly from List<AirtelMoneyTxn>)


enum TxnFlow { incoming, outgoing, all }
enum GroupKind { person, category, day, network }

/// Your existing enums (keep using yours)
enum AirtelTxnType { credit, debit }
enum Network { airtel, mtn }

/// Your existing txn (must have network)
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

// ---------------------------
// 1) Period + Filters
// ---------------------------

class ReportPeriod {
  final DateTime from; // inclusive
  final DateTime to;   // inclusive (endOfDay recommended)
  const ReportPeriod({required this.from, required this.to});

  bool contains(DateTime? d) {
    if (d == null) return false;
    return !d.isBefore(from) && !d.isAfter(to);
  }
}

class ReportFilter {
  final ReportPeriod period;
  final TxnFlow flow;
  final Network? network; // null => both
  final String search;    // optional; you can reuse your search logic
  const ReportFilter({
    required this.period,
    this.flow = TxnFlow.all,
    this.network,
    this.search = "",
  });

  bool match(AirtelMoneyTxn t, {bool Function(AirtelMoneyTxn)? searchFn}) {
    if (!period.contains(t.txnDateTime)) return false;
    if (network != null && t.network != network) return false;

    if (flow == TxnFlow.incoming && t.type != AirtelTxnType.credit) return false;
    if (flow == TxnFlow.outgoing && t.type != AirtelTxnType.debit) return false;

    if (searchFn != null && !searchFn(t)) return false;
    return true;
  }
}

// ---------------------------
// 2) Derived classification (Category)
// ---------------------------

enum TxnCategory {
  received,
  sent,
  withdraw,
  deposit,
  paid,
  airtime,
  other,
}

TxnCategory classifyTxn(AirtelMoneyTxn t) {
  final name = t.partyName.toLowerCase();

  // Airtel messages you parse
  if (t.type == AirtelTxnType.credit && name.contains("cash deposit")) return TxnCategory.deposit;
  if (t.type == AirtelTxnType.credit && name.contains("received")) return TxnCategory.received;

  if (t.type == AirtelTxnType.debit && name.contains("withdraw")) return TxnCategory.withdraw;
  if (t.type == AirtelTxnType.debit && name.contains("paid")) return TxnCategory.paid;
  if (t.type == AirtelTxnType.debit && name.contains("airtime")) return TxnCategory.airtime;

  // MTN parser uses names like "Withdraw", "Withdraw (Pending) - ..."
  if (t.type == AirtelTxnType.debit && name.startsWith("withdraw")) return TxnCategory.withdraw;

  // Sent vs Received fallback by type
  if (t.type == AirtelTxnType.credit) return TxnCategory.received;
  if (t.type == AirtelTxnType.debit) return TxnCategory.sent;

  return TxnCategory.other;
}

// ---------------------------
// 3) Summary Models (for headers/cards)
// ---------------------------

class MoneySplit {
  final int amount;
  final int count;
  const MoneySplit({required this.amount, required this.count});

  MoneySplit operator +(MoneySplit o) =>
      MoneySplit(amount: amount + o.amount, count: count + o.count);

  static const zero = MoneySplit(amount: 0, count: 0);
}

class ReportTotals {
  final MoneySplit incoming;
  final MoneySplit outgoing;

  const ReportTotals({
    required this.incoming,
    required this.outgoing,
  });

  int get net => incoming.amount - outgoing.amount;
  int get totalCount => incoming.count + outgoing.count;

  ReportTotals operator +(ReportTotals o) => ReportTotals(
        incoming: incoming + o.incoming,
        outgoing: outgoing + o.outgoing,
      );

  static const zero = ReportTotals(incoming: MoneySplit.zero, outgoing: MoneySplit.zero);
}

class ReportSummary {
  final ReportPeriod period;
  final Network? network; // null => both
  final ReportTotals totals;

  final int? openingBalance; // optional (if you can compute)
  final int? closingBalance; // optional

  /// Useful “quality” fields
  final int missingBalanceCount;
  final int duplicateTidCount;

  const ReportSummary({
    required this.period,
    required this.network,
    required this.totals,
    required this.openingBalance,
    required this.closingBalance,
    required this.missingBalanceCount,
    required this.duplicateTidCount,
  });
}

// ---------------------------
// 4) Grouping Models (for tables / drill-down)
// ---------------------------

class GroupKey {
  final GroupKind kind;
  final String id;      // stable id (e.g. normalized phone, category enum name)
  final String title;   // display title (e.g. "John - 2567...", "Withdraw")
  final String? subtitle; // optional (e.g. phone, network)

  const GroupKey({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
  });
}

class GroupRow {
  final GroupKey key;
  final ReportTotals totals;
  final DateTime? lastTxnAt;

  /// extra breakdowns
  final ReportTotals airtel;
  final ReportTotals mtn;

  const GroupRow({
    required this.key,
    required this.totals,
    required this.lastTxnAt,
    required this.airtel,
    required this.mtn,
  });
}

class DrilldownStatement {
  final GroupKey key;
  final ReportPeriod period;
  final ReportTotals totals;
  final List<AirtelMoneyTxn> items; // already sorted newest-first

  const DrilldownStatement({
    required this.key,
    required this.period,
    required this.totals,
    required this.items,
  });
}

// ---------------------------
// 5) Timeline Models (daily totals)
// ---------------------------

class DayBucket {
  final DateTime day; // start-of-day
  final ReportTotals totals;
  const DayBucket({required this.day, required this.totals});
}

// ---------------------------
// 6) Aggregators (pure functions)
// ---------------------------

ReportTotals _totalsForOne(AirtelMoneyTxn t) {
  if (t.type == AirtelTxnType.credit) {
    return ReportTotals(
      incoming: MoneySplit(amount: t.amount, count: 1),
      outgoing: MoneySplit.zero,
    );
  } else {
    return ReportTotals(
      incoming: MoneySplit.zero,
      outgoing: MoneySplit(amount: t.amount, count: 1),
    );
  }
}

ReportTotals _totalsForList(Iterable<AirtelMoneyTxn> items) {
  var acc = ReportTotals.zero;
  for (final t in items) {
    acc = acc + _totalsForOne(t);
  }
  return acc;
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

ReportSummary buildSummary(
  List<AirtelMoneyTxn> all,
  ReportFilter filter, {
  bool Function(AirtelMoneyTxn)? searchFn,
}) {
  final items = all.where((t) => filter.match(t, searchFn: searchFn)).toList();

  // totals
  final totals = _totalsForList(items);

  // duplicate TIDs within filtered list
  final seen = <String>{};
  var dup = 0;
  for (final t in items) {
    final k = t.tid.trim();
    if (k.isEmpty) continue;
    if (seen.contains(k)) dup++;
    seen.add(k);
  }

  final missingBal = items.where((t) => t.balance == null).length;

  // opening/closing balance heuristics:
  // take earliest txn with non-null balance as opening-ish; latest as closing-ish
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

  return ReportSummary(
    period: filter.period,
    network: filter.network,
    totals: totals,
    openingBalance: opening,
    closingBalance: closing,
    missingBalanceCount: missingBal,
    duplicateTidCount: dup,
  );
}

List<GroupRow> groupByPerson(
  List<AirtelMoneyTxn> all,
  ReportFilter filter, {
  required String Function(AirtelMoneyTxn) displayName, // your _displayNameForTxn(tx)
  required String Function(String) normPhone,            // your _normPhone
  bool Function(AirtelMoneyTxn)? searchFn,
}) {
  final items = all.where((t) => filter.match(t, searchFn: searchFn)).toList();

  String personId(AirtelMoneyTxn t) {
    final n = normPhone(t.partyNumber);
    if (n.isNotEmpty) return n;
    final fallback = t.partyName.trim().toLowerCase();
    return fallback.isEmpty ? "unknown" : "name:$fallback";
  }

  final map = <String, List<AirtelMoneyTxn>>{};
  for (final t in items) {
    final id = personId(t);
    map.putIfAbsent(id, () => []).add(t);
  }

  final out = <GroupRow>[];
  map.forEach((id, list) {
    list.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    final totals = _totalsForList(list);

    final airtelTotals = _totalsForList(list.where((t) => t.network == Network.airtel));
    final mtnTotals = _totalsForList(list.where((t) => t.network == Network.mtn));

    final title = displayName(list.first); // newest txn “best name”
    final subtitle = id.startsWith("name:") ? null : id;

    out.add(
      GroupRow(
        key: GroupKey(kind: GroupKind.person, id: id, title: title, subtitle: subtitle),
        totals: totals,
        lastTxnAt: list.first.txnDateTime,
        airtel: airtelTotals,
        mtn: mtnTotals,
      ),
    );
  });

  // sort biggest first (by total volume)
  out.sort((a, b) => (b.totals.incoming.amount + b.totals.outgoing.amount)
      .compareTo(a.totals.incoming.amount + a.totals.outgoing.amount));

  return out;
}

List<GroupRow> groupByCategory(
  List<AirtelMoneyTxn> all,
  ReportFilter filter, {
  bool Function(AirtelMoneyTxn)? searchFn,
}) {
  final items = all.where((t) => filter.match(t, searchFn: searchFn)).toList();

  final map = <TxnCategory, List<AirtelMoneyTxn>>{};
  for (final t in items) {
    final c = classifyTxn(t);
    map.putIfAbsent(c, () => []).add(t);
  }

  final out = <GroupRow>[];
  map.forEach((cat, list) {
    list.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    final totals = _totalsForList(list);
    out.add(
      GroupRow(
        key: GroupKey(kind: GroupKind.category, id: cat.name, title: cat.name.toUpperCase()),
        totals: totals,
        lastTxnAt: list.first.txnDateTime,
        airtel: _totalsForList(list.where((t) => t.network == Network.airtel)),
        mtn: _totalsForList(list.where((t) => t.network == Network.mtn)),
      ),
    );
  });

  out.sort((a, b) => (b.totals.incoming.amount + b.totals.outgoing.amount)
      .compareTo(a.totals.incoming.amount + a.totals.outgoing.amount));
  return out;
}

List<DayBucket> buildDailyTimeline(
  List<AirtelMoneyTxn> all,
  ReportFilter filter, {
  bool Function(AirtelMoneyTxn)? searchFn,
}) {
  final items = all.where((t) => filter.match(t, searchFn: searchFn)).toList();

  final map = <DateTime, List<AirtelMoneyTxn>>{};
  for (final t in items) {
    final dt = t.txnDateTime;
    if (dt == null) continue;
    final day = _startOfDay(dt);
    map.putIfAbsent(day, () => []).add(t);
  }

  final days = map.keys.toList()..sort((a, b) => a.compareTo(b)); // oldest->newest

  return [
    for (final d in days)
      DayBucket(day: d, totals: _totalsForList(map[d]!)),
  ];
}

DrilldownStatement buildDrilldown(
  List<AirtelMoneyTxn> all,
  ReportFilter filter,
  GroupKey key, {
  required bool Function(AirtelMoneyTxn) belongsToGroup,
  bool Function(AirtelMoneyTxn)? searchFn,
}) {
  final items = all
      .where((t) => filter.match(t, searchFn: searchFn))
      .where(belongsToGroup)
      .toList();

  items.sort((a, b) {
    final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bd.compareTo(ad);
  });

  return DrilldownStatement(
    key: key,
    period: filter.period,
    totals: _totalsForList(items),
    items: items,
  );
}
