import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import '../domain/airtel_money_txn.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class SmsImportPage extends StatefulWidget {
  final void Function(List<AirtelMoneyTxn>)? onTxnsChanged;
  const SmsImportPage({super.key, this.onTxnsChanged});

  @override
  State<SmsImportPage> createState() => _SmsImportPageState();
}

enum FilterMode { singleDay, range }        // date selection mode only
enum ViewScope { last10, all, dateFilter }  // what to show





class _SmsImportPageState extends State<SmsImportPage> {
  final SmsQuery _query = SmsQuery();
@override
void initState() {
  super.initState();
  _listCtrl.addListener(_onScroll);

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await ensureContactsPermission();
    await _loadContactsOnce();
    await _readSms();
  });
}

@override
void dispose() {
  _listCtrl.dispose();
  _searchCtrl.dispose();
  super.dispose();
}



ViewScope _scope = ViewScope.last10; // ✅ default
FilterMode _mode = FilterMode.singleDay;
final ScrollController _listCtrl = ScrollController();

static const int _pageSize = 10;
int _visibleCount = _pageSize;

bool _loadingMore = false;
bool _hasMore = true;
double _lastTriggerOffset = -1;
          // prevents double-load

final Map<String, String> _contactCache = {}; // normalizedNumber -> displayName
String _normPhone(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');

  if (s.startsWith('0') && s.length == 10) return '256${s.substring(1)}';
  if (s.length == 9 && s.startsWith('7')) return '256$s';
  if (s.startsWith('256') && s.length == 12) return s;

  return s;
}

String _dayHeader(DateTime d) {
  final today = _startOfDay(DateTime.now());
  final dd = _startOfDay(d);

  if (dd == today) return "Today";
  if (dd == today.subtract(const Duration(days: 1))) return "Yesterday";
  return _fmtDate(dd);
}

Map<String, List<AirtelMoneyTxn>> _groupTxnsByDay(List<AirtelMoneyTxn> list) {
  final map = <String, List<AirtelMoneyTxn>>{};
  for (final tx in list) {
    final dt = tx.txnDateTime ?? DateTime.now();
    final key = _fmtDate(_startOfDay(dt));
    map.putIfAbsent(key, () => []).add(tx);
  }

  // sort each group newest-first
  for (final k in map.keys) {
    map[k]!.sort((a, b) {
      final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
  }
  return map;
}


Future<void> ensureContactsPermission() async {
  final status = await Permission.contacts.status;

  if (status.isGranted) return;

  final res = await Permission.contacts.request();

  if (!res.isGranted) {
    // user denied again or "Don't ask again"
    await openAppSettings();
  }
}

void _onScroll() {
  if (_scope != ViewScope.last10) return;
  if (_loading || _loadingMore || !_hasMore) return;
  if (!_listCtrl.hasClients) return;

  final pos = _listCtrl.position;

  // near bottom
  if (pos.extentAfter < 320) {
    // prevent spam triggers
    if ((_lastTriggerOffset - pos.pixels).abs() < 6) return;
    _lastTriggerOffset = pos.pixels;

    _loadMore();
  }
}

Future<void> _loadMore() async {
  final total = _sortedAll().where(_matchesSearch).length; // search-safe total
  if (_visibleCount >= total) {
    setState(() => _hasMore = false);
    return;
  }

  setState(() => _loadingMore = true);

  await Future.delayed(const Duration(milliseconds: 140)); // feels nicer

  setState(() {
    _visibleCount = (_visibleCount + _pageSize).clamp(0, total);
    _loadingMore = false;
    _hasMore = _visibleCount < total;
    _applyFilters();
  });
}



Future<void> _loadMoreSmooth() async {
  final total = _sortedAll().length;
  if (_visibleCount >= total) {
    setState(() => _hasMore = false);
    return;
  }

  setState(() => _loadingMore = true);

  // capture current scroll offset (stable anchor)
  final beforeOffset = _listCtrl.hasClients ? _listCtrl.offset : 0.0;

  // tiny delay so loader shows (feels responsive)
  await Future.delayed(const Duration(milliseconds: 120));

  setState(() {
    _visibleCount = (_visibleCount + _pageSize).clamp(0, total);
    _loadingMore = false;
    _hasMore = _visibleCount < total;
    _applyFilters(); // updates _filteredTxns
  });

  // restore offset so it doesn't "jump"
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_listCtrl.hasClients) return;
    final max = _listCtrl.position.maxScrollExtent;
    final target = beforeOffset.clamp(0.0, max);
    _listCtrl.jumpTo(target);
  });
}


bool _contactsLoaded = false;

Future<void> _loadContactsOnce() async {
  if (_contactsLoaded) return;

  final ok = await FlutterContacts.requestPermission();
  if (!ok) return;

  final contacts = await FlutterContacts.getContacts(withProperties: true);

  for (final c in contacts) {
    final name = c.displayName.trim();
    if (name.isEmpty) continue;

    for (final p in c.phones) {
      final n = _normPhone(p.number);
      if (n.isNotEmpty) _contactCache[n] = name;
    }
  }

  _contactsLoaded = true;
}
Widget pageHeader(String summaryText) {
  return Row(
    children: [
      Expanded(
        child: Text(
          summaryText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      IconButton(
        onPressed: _loading ? null : _openFiltersSheet,
        icon: const Icon(Icons.tune),
        tooltip: "Filters",
      ),
    ],
  );
}

void _openFiltersSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent, // ✅ lets us do rounded “card” sheet
    builder: (ctx) {
      final theme = Theme.of(ctx);

      Widget sectionTitle(String t, {IconData? icon}) => Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
              ],
              Text(
                t,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ],
          );

      Widget softCard({required Widget child}) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: child,
          );

      Widget pillChip({
        required String text,
        required bool selected,
        required VoidCallback onTap,
        IconData? icon,
      }) {
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _loading ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? Colors.deepPurple : Colors.black12,
              ),
              color: selected ? Colors.deepPurple.withOpacity(.10) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 16, color: selected ? Colors.deepPurple : Colors.black54),
                  const SizedBox(width: 6),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.deepPurple : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      Widget viewChips(StateSetter setSheet) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              pillChip(
                text: "Last 10",
                icon: Icons.bolt,
                selected: _scope == ViewScope.last10,
                onTap: () {
                  setState(() {
                    _scope = ViewScope.last10;
                    _applyFilters();
                  });
                  setSheet(() {});
                },
              ),
              pillChip(
                text: "All",
                icon: Icons.all_inbox,
                selected: _scope == ViewScope.all,
                onTap: () {
                  setState(() {
                    _scope = ViewScope.all;
                    _applyFilters();
                  });
                  setSheet(() {});
                },
              ),
              pillChip(
                text: "By Date",
                icon: Icons.date_range,
                selected: _scope == ViewScope.dateFilter,
                onTap: () {
                  setState(() {
                    _scope = ViewScope.dateFilter;

                    final today = DateTime.now();
                    _fromDate ??= _startOfDay(today);
                    _toDate ??= _endOfDay(today);

                    _applyFilters();
                  });
                  setSheet(() {});
                },
              ),
            ],
          );

      Widget modeChips(StateSetter setSheet) => Row(
            children: [
              Expanded(
                child: pillChip(
                  text: "Single Day",
                  icon: Icons.today,
                  selected: _mode == FilterMode.singleDay,
                  onTap: () {
                    setState(() {
                      _mode = FilterMode.singleDay;
                      _applyFilters();
                    });
                    setSheet(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: pillChip(
                  text: "Range",
                  icon: Icons.view_week,
                  selected: _mode == FilterMode.range,
                  onTap: () {
                    setState(() {
                      _mode = FilterMode.range;
                      final today = DateTime.now();
                      _fromDate ??= _startOfDay(today);
                      _toDate ??= _endOfDay(today);
                      _applyFilters();
                    });
                    setSheet(() {});
                  },
                ),
              ),
            ],
          );

      Widget singleDayRow(StateSetter setSheet) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
              color: Colors.black.withOpacity(.02),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Day: ${_fmtDate(_selectedDay)}",
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          await _pickSingleDay();
                          setSheet(() {});
                        },
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text("Pick"),
                ),
              ],
            ),
          );

      Widget rangeRow(StateSetter setSheet) => Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          await _pickFrom();
                          setSheet(() {});
                        },
                  icon: const Icon(Icons.date_range),
                  label: Text(_fromDate == null
                      ? "From"
                      : "From: ${_fmtDate(_fromDate!)}"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          await _pickTo();
                          setSheet(() {});
                        },
                  icon: const Icon(Icons.date_range),
                  label: Text(_toDate == null ? "To" : "To: ${_fmtDate(_toDate!)}"),
                ),
              ),
            ],
          );

      Widget quickFiltersBar() => SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const SizedBox(width: 2),
                _qBtn("Today", _setToday),
                _qBtn("Yest", _setYesterday),
                _qBtn("This Week", _setThisWeek),
                _qBtn("This Month", _setThisMonth),
                _qBtn("Last Month", _setLastMonth),
              ],
            ),
          );

      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: softCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text(
                          "Filters",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        if (_loading)
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // View section
                    sectionTitle("View", icon: Icons.visibility),
                    const SizedBox(height: 10),
                    viewChips(setSheet),

                    const SizedBox(height: 16),

                    // Date section (only if By Date)
                    if (_scope == ViewScope.dateFilter) ...[
                      sectionTitle("Date Filter", icon: Icons.calendar_month),
                      const SizedBox(height: 10),
                      modeChips(setSheet),
                      const SizedBox(height: 12),
                      if (_mode == FilterMode.singleDay) singleDayRow(setSheet),
                      if (_mode == FilterMode.range) rangeRow(setSheet),
                      const SizedBox(height: 12),
                      sectionTitle("Quick Picks", icon: Icons.flash_on),
                      const SizedBox(height: 10),
                      quickFiltersBar(),
                      const SizedBox(height: 10),
                    ],

                    const SizedBox(height: 12),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(_applyFilters);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text("Apply",
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _searchCtrl.clear();
                              _search = "";

                              _scope = ViewScope.last10;
                              _mode = FilterMode.singleDay;
                              _selectedDay = DateTime.now();
                              _fromDate = null;
                              _toDate = null;

                              _applyFilters();
                            });
                            setSheet(() {});
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Reset",
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ✅ helper quick button used inside the sheet (keeps it pretty)
Widget _qBtn(String text, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: _loading ? null : onTap,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}



String _nameForNumber(String number) {
  final rawDigits = number.replaceAll(RegExp(r'[^0-9]'), '');
  final norm = _normPhone(number);

  return _contactCache[norm] ??
      _contactCache[rawDigits] ??
      (rawDigits.length == 9 ? _contactCache['0$rawDigits'] : null) ??
      (rawDigits.length == 9 ? _contactCache['256$rawDigits'] : null) ??
      "";
}
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

String _displayNameForTxn(AirtelMoneyTxn tx) {
  final smsName = (tx.partyName).trim();                 // from SMS parser
  final contactName = _nameForNumber(tx.partyNumber).trim(); // from phonebook

  if (smsName.isEmpty && contactName.isEmpty) return tx.partyNumber;

  if (smsName.isEmpty) return contactName;
  if (contactName.isEmpty) return smsName;

  // avoid duplicates (case-insensitive)
  if (smsName.toLowerCase() == contactName.toLowerCase()) return smsName;

  return "$smsName - $contactName";
}



  bool _loading = false;
  String _status = "Tap 'Read SMS' to import messages.";

  List<AirtelMoneyTxn> _allTxns = [];
  List<AirtelMoneyTxn> _filteredTxns = [];

 // FilterMode _mode = FilterMode.singleDay;

  // Single day
  DateTime _selectedDay = DateTime.now();

  // Range
  DateTime? _fromDate;
  DateTime? _toDate;

  // ---- Helpers
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _fmtDateTime(DateTime? d) {
    if (d == null) return "";
    return "${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  Future<bool> _ensurePermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    final result = await Permission.sms.request();
    return result.isGranted;
  }



Network _network = Network.airtel;

Widget networkToggle() {
  Widget b(String text, Network n) {
    final selected = _network == n;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: BorderSide(color: selected ? Colors.deepPurple : Colors.black12),
          backgroundColor: selected ? Colors.deepPurple.withOpacity(.08) : null,
        ),
        onPressed: _loading
            ? null
            : () {
  setState(() {
    _network = n;
    _applyFilters(); // ✅ just filter what we already loaded
  });
},
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.deepPurple : null,
          ),
        ),
      ),
    );
  }

  return Row(
    children: [
      b("Airtel", Network.airtel),
      const SizedBox(width: 8),
      b("MTN", Network.mtn),
    ],
  );
}
Network? _detectNetwork(String? sender, String? body) {
  final s = (sender ?? "").toLowerCase().trim();
  final b = (body ?? "").toLowerCase().replaceAll('\n', ' ').trim();

  // Airtel
  final airtelSenderOk = s.contains("airtel");
  final airtelStartsOk =
      b.startsWith("received") ||
      b.startsWith("sent") ||
      b.startsWith("paid") ||
      b.startsWith("cash deposit") ||
      b.startsWith("withdrawn");
  final airtelOk = airtelSenderOk && airtelStartsOk && b.contains("tid") && b.contains("ugx");
  if (airtelOk) return Network.airtel;

  // MTN
  final mtnStartsOk =
      b.startsWith("y'ello") ||
      b.startsWith("you have sent") ||
      b.startsWith("you have received") ||
      b.startsWith("you have withdrawn") ||
      b.startsWith("you have bought") ||
      b.startsWith("you have paid") ||
      b.startsWith("you've purchased");
  final mtnOk = mtnStartsOk && b.contains("ugx") && (b.contains(" id") || b.contains("transaction id") ||
      b.contains("new momo balance") || b.contains("new balance") || b.contains("balance is now"));
  if (mtnOk) return Network.mtn;

  return null;
}


List<AirtelMoneyTxn> _sortedAll() {
  final list = List<AirtelMoneyTxn>.from(_allTxns);
  list.sort((a, b) {
    final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bd.compareTo(ad); // newest first
  });
  return list;
}




  // ---- Filtering

void _applyFilters() {
  if (_allTxns.isEmpty) {
    _filteredTxns = [];
    _status = "No transactions loaded. Tap Read.";
    return;
  }

  var base = _sortedAll(); // newest first
  base = base.where((t) => t.network == _network).toList();

  // DATE FILTER only if scope = dateFilter
  if (_scope == ViewScope.dateFilter) {
    if (_mode == FilterMode.singleDay) {
      final from = _startOfDay(_selectedDay);
      final to = _endOfDay(_selectedDay);
      base = base.where((tx) {
        final d = tx.txnDateTime;
        return d != null && !d.isBefore(from) && !d.isAfter(to);
      }).toList();
    } else {
      final from = _fromDate;
      final to = _toDate;
      if (from != null && to != null) {
        base = base.where((tx) {
          final d = tx.txnDateTime;
          return d != null && !d.isBefore(from) && !d.isAfter(to);
        }).toList();
      }
    }
  }

  // Search always applies
  base = base.where(_matchesSearch).toList();

  // Pagination only in Last10 scope
  if (_scope == ViewScope.last10) {
    _hasMore = _visibleCount < base.length;
    base = base.take(_visibleCount).toList();
  }

  _filteredTxns = base;

  final scopeText = _scope == ViewScope.last10
      ? "Latest $_visibleCount"
      : _scope == ViewScope.all
          ? "All"
          : "Filtered";

  _status = "Showing ${_filteredTxns.length} txns ($scopeText)";
}



  void _setToday() {
    final now = DateTime.now();
    setState(() {
      _mode = FilterMode.singleDay;
      _selectedDay = now;
      _applyFilters();
    });
  }

  void _setYesterday() {
    final d = DateTime.now().subtract(const Duration(days: 1));
    setState(() {
      _mode = FilterMode.singleDay;
      _selectedDay = d;
      _applyFilters();
    });
  }

  void _setThisWeek() {
    final now = DateTime.now();
    final start = _startOfDay(now.subtract(Duration(days: now.weekday - 1))); // Mon
    setState(() {
      _mode = FilterMode.range;
      _fromDate = start;
      _toDate = _endOfDay(now);
      _applyFilters();
    });
  }

  void _setThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    setState(() {
      _mode = FilterMode.range;
      _fromDate = _startOfDay(start);
      _toDate = _endOfDay(now);
      _applyFilters();
    });
  }

  void _setLastMonth() {
    final now = DateTime.now();
    final firstThisMonth = DateTime(now.year, now.month, 1);
    final lastMonthEnd = firstThisMonth.subtract(const Duration(days: 1));
    final lastMonthStart = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);

    setState(() {
      _mode = FilterMode.range;
      _fromDate = _startOfDay(lastMonthStart);
      _toDate = _endOfDay(lastMonthEnd);
      _applyFilters();
    });
  }

  Future<void> _pickSingleDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;

    setState(() {
      _mode = FilterMode.singleDay;
      _selectedDay = picked;
      _applyFilters();
    });
  }

Future<void> _pickFrom() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: _fromDate ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (picked == null) return;

  setState(() {
    _mode = FilterMode.range;

    final newFrom = _startOfDay(picked);

    // ✅ if To is null, set it to same day end
    final currentTo = _toDate ?? _endOfDay(picked);

    // ✅ if To is before From, move To to same day end
    final newTo = currentTo.isBefore(newFrom) ? _endOfDay(picked) : currentTo;

    _fromDate = newFrom;
    _toDate = newTo;

    _applyFilters();
  });
}
Widget _txnCard(AirtelMoneyTxn tx) {
  final isCredit = tx.type == AirtelTxnType.credit;
  final amountColor = isCredit ? Colors.green : Colors.red;

  final who = _displayNameForTxn(tx);
  final dt = tx.txnDateTime;
final balText = tx.balance == null ? "—" : fmtInt(tx.balance!);

  final timeOnly = dt == null
      ? ""
      : "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

final netLabel = tx.network == Network.airtel ? "Airtel" : "MTN";

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: amountColor.withOpacity(.12),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: amountColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "UGX ${fmtInt(tx.amount)}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: amountColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Text(
                        netLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "${isCredit ? "From" : "To"}: $who",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "TID: ${tx.tid}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (timeOnly.isNotEmpty)
                      Text(
                        timeOnly,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                if (tx.partyNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tx.partyNumber, style: const TextStyle(color: Colors.black54)),
                ],
                const SizedBox(height: 6),
             Text(
  "Bal: $balText",
  style: const TextStyle(
    fontWeight: FontWeight.w800,
    color: Colors.black54,
  ),
),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget quickFilters() {
  Widget btn(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: _loading ? null : onTap,
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  return SizedBox(
    height: 34,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        btn("Today", _setToday),
        btn("Yest", _setYesterday),
        btn("ThisWeek", _setThisWeek),
        btn("ThisMonth", _setThisMonth),
        btn("LastMonth", _setLastMonth),
      ],
    ),
  );
}
List<Widget> _buildTxnSlivers(List<AirtelMoneyTxn> txns) {
  final grouped = _groupTxnsByDay(txns);

  // keys are yyyy-mm-dd so lexicographic sort works
  final dayKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  final slivers = <Widget>[];

  for (final k in dayKeys) {
    final day = DateTime.parse(k);
    final header = _dayHeader(day);
    final items = grouped[k]!;

    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(
            header,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );

    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _txnCard(items[i]),
          childCount: items.length,
        ),
      ),
    );
  }

  return slivers;
}





Future<void> _pickTo() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: _toDate ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (picked == null) return;

  setState(() {
    _mode = FilterMode.range;

    final newTo = _endOfDay(picked);

    // ✅ if From is null, set it to same day start
    final currentFrom = _fromDate ?? _startOfDay(picked);

    // ✅ if From is after To, move From to same day start
    final newFrom = currentFrom.isAfter(newTo) ? _startOfDay(picked) : currentFrom;

    _fromDate = newFrom;
    _toDate = newTo;

    _applyFilters();
  });
}

final _searchCtrl = TextEditingController();
String _search = "";

String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

bool _matchesSearch(AirtelMoneyTxn tx) {
  final raw = _search.trim();
  if (raw.isEmpty) return true;

  final qDigits = _digitsOnly(raw);

  // 1) Match by phone digits (partial)
  final numDigits = _digitsOnly(tx.partyNumber);
  final phoneHit = qDigits.isNotEmpty && numDigits.contains(qDigits);

  // 2) Match by TID digits (partial)
  final tidDigits = _digitsOnly(tx.tid);
  final tidHit = qDigits.isNotEmpty && tidDigits.contains(qDigits);

  // 3) Optional: match by name text
  final nameHit = _displayNameForTxn(tx).toLowerCase().contains(raw.toLowerCase());

  return phoneHit || tidHit || nameHit;
}

bool _isSyntheticMtnConfirmTid(String tid) => tid.startsWith("MTNCONF-");



  // ---- SMS load
  Future<void> _readSms() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _status = "Requesting permission...";
      _allTxns = [];
      _filteredTxns = [];
    });

    final ok = await _ensurePermission();
    if (!ok) {
      setState(() {
        _loading = false;
        _status = "SMS permission denied. Enable it in Settings.";
      });
      return;
    }

    
      setState(() => _status = "Reading inbox...");

  //final msgs = await _query.querySms(kinds: [SmsQueryKind.inbox], count: 500);

final msgs = await _query.querySms(
  kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
  count: 1500,
);

final target = msgs.where((m) => _detectNetwork(m.sender, m.body) != null).toList();


// ✅ process oldest -> newest (pending usually comes before confirm)
target.sort((a, b) {
  final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  return ad.compareTo(bd);
});

final map = <String, AirtelMoneyTxn>{};
final waitingConfirms = <AirtelMoneyTxn>[]; // confirms that arrived before pending

bool isSyntheticConfirmTid(String tid) => tid.startsWith("MTNCONF-");

bool isPendingWithdraw(AirtelMoneyTxn t) =>
    t.type == AirtelTxnType.debit &&
    t.partyName.toLowerCase().contains("withdraw (pending)");

bool isConfirmWithdraw(AirtelMoneyTxn t) =>
    t.type == AirtelTxnType.debit &&
    t.partyName.toLowerCase() == "withdraw" &&
    t.balance != null;

String? findBestPendingKey(AirtelMoneyTxn confirm) {
  String? bestKey;
  int bestDiff = 1 << 30;

  for (final e in map.entries) {
    final p = e.value;
    if (!isPendingWithdraw(p)) continue;
    if (p.amount != confirm.amount) continue;

    final a = p.txnDateTime;
    final b = confirm.txnDateTime;
    if (a == null || b == null) continue;

    final diff = a.difference(b).inMinutes.abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      bestKey = e.key;
    }
  }

  return (bestKey != null && bestDiff <= 60) ? bestKey : null;
}
for (final m in target) {
  final body = m.body ?? "";

  final net = _detectNetwork(m.sender, m.body);
  if (net == null) continue;

  final tx = (net == Network.airtel)
      ? parseAirtelMoneyTxn(body, smsDate: m.date)
      : parseMtnMoMoTxn(body, smsDate: m.date);

  if (tx == null) continue;

  // ✅ IMPORTANT: use tx everywhere below
  debugPrint("TX: ${tx.partyName} | net=${tx.network} | tid=${tx.tid}");

  // ✅ MTN confirm merge should check tx.network, not _network
  if (tx.network == Network.mtn && isSyntheticConfirmTid(tx.tid) && isConfirmWithdraw(tx)) {
    final bestKey = findBestPendingKey(tx);

    if (bestKey != null) {
      final pending = map[bestKey]!;
      map[bestKey] = AirtelMoneyTxn(
        type: pending.type,
        tid: pending.tid,
        amount: pending.amount,
        partyName: "Withdraw",
        partyNumber: pending.partyNumber,
        balance: tx.balance,
        txnDateTime: tx.txnDateTime ?? pending.txnDateTime,
        network: Network.mtn, // ✅ keep network
      );
    } else {
      waitingConfirms.add(tx);
    }
    continue;
  }

  // normal add (tid key)
  final key = tx.tid;
  final prev = map[key];

  if (prev == null) {
    map[key] = tx;
  } else {
    final prevScore = (prev.balance != null ? 10 : 0) + (prev.txnDateTime != null ? 1 : 0);
    final newScore  = (tx.balance  != null ? 10 : 0) + (tx.txnDateTime  != null ? 1 : 0);
    map[key] = (newScore >= prevScore) ? tx : prev;
  }

  // ✅ retry waiting confirms when pending arrives
  if (tx.network == Network.mtn && isPendingWithdraw(tx) && waitingConfirms.isNotEmpty) {
    final toRemove = <AirtelMoneyTxn>[];
    for (final c in waitingConfirms) {
      final bestKey = findBestPendingKey(c);
      if (bestKey != null) {
        final pending = map[bestKey]!;
        map[bestKey] = AirtelMoneyTxn(
          type: pending.type,
          tid: pending.tid,
          amount: pending.amount,
          partyName: "Withdraw",
          partyNumber: pending.partyNumber,
          balance: c.balance,
          txnDateTime: c.txnDateTime ?? pending.txnDateTime,
          network: Network.mtn,
        );
        toRemove.add(c);
      }
    }
    waitingConfirms.removeWhere(toRemove.contains);
  }
}



final parsed = map.values.toList()
  ..sort((a, b) {
    final ad = a.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.txnDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bd.compareTo(ad);
  });

setState(() {
  _allTxns = parsed;
  _loading = false;

  _scope = ViewScope.last10;
  _visibleCount = _pageSize;
  _hasMore = true;
  _lastTriggerOffset = -1;

  _mode = FilterMode.singleDay;
  _selectedDay = DateTime.now();
  _applyFilters();
});
final a = parsed.where((x) => x.network == Network.airtel).length;
final m = parsed.where((x) => x.network == Network.mtn).length;
debugPrint("PARSED: Airtel=$a, MTN=$m, Total=${parsed.length}");

widget.onTxnsChanged?.call(parsed); // ✅ publish to HomeShell
  // If no pending found, skip adding MTNCONF (optional)
  // continue;

  // Or: if you prefer to still show it, fall through (remove this continue)
}


  
@override
Widget build(BuildContext context) {
 String scopeText() {
  switch (_scope) {
    case ViewScope.last10:
      return "Last 10";
    case ViewScope.all:
      return "All";
    case ViewScope.dateFilter:
      if (_mode == FilterMode.singleDay) return _fmtDate(_selectedDay);
      if (_fromDate != null && _toDate != null) {
        return "${_fmtDate(_fromDate!)} → ${_fmtDate(_toDate!)}";
      }
      return "Pick range";
  }
}

final summaryText = _allTxns.isEmpty
    ? (_loading ? "Reading messages..." : "No transactions loaded yet.")
    : "Showing ${_filteredTxns.length} txns (${scopeText()})";


  // ---- build grouped list rows (headers + items)
  final grouped = _groupTxnsByDay(_filteredTxns);

  // order days newest-first
  final dayKeys = grouped.keys.toList()
    ..sort((a, b) => b.compareTo(a)); // yyyy-mm-dd sorts correctly

  final rows = <_Row>[];
  for (final k in dayKeys) {
    final day = DateTime.parse(k);
    rows.add(_Row.header(_dayHeader(day)));
    for (final tx in grouped[k]!) {
      rows.add(_Row.item(tx));
    }
  }

  return Scaffold(
    appBar:null,

    // ✅ FAB Read (list is hero)
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading ? null : _readSms,
      icon: const Icon(Icons.sms),
      label: const Text("Read"),
    ),

    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- Summary card
     Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  decoration: BoxDecoration(
    border: Border.all(color: Colors.black12),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Row(
    children: [
      Expanded(child: pageHeader(summaryText)),
      if (_loading)
        const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
    ],
  ),
),

            const SizedBox(height: 12),

            // --- Network toggle (compact)
            Row(
              children: [
                Expanded(child: networkToggle()),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loading ? null : _readSms,
                  icon: const Icon(Icons.refresh),
                  tooltip: "Refresh",
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- Search (always visible)
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search phone / name / TID",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _search = "";
                            _applyFilters();
                          });
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {
                  _search = v;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(height: 12),

            // --- Grouped list (money-first + headers)
          Expanded(
  child: _filteredTxns.isEmpty
      ? Center(
          child: Text(
            _allTxns.isEmpty
                ? "No transactions found yet.\nTap Read to import."
                : "No results for your filter/search.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        )
      : CustomScrollView(
          key: const PageStorageKey("sms_sliver_list"),
          controller: _listCtrl,
          slivers: [
            ..._buildTxnSlivers(_filteredTxns),

            SliverToBoxAdapter(
              child: _scope != ViewScope.last10
                  ? const SizedBox(height: 16)
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: !_hasMore
                            ? const Text(
                                "No more messages",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : (_loadingMore
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    "Scroll to load more…",
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )),
                      ),
                    ),
            ),
          ],
        ),
),

          ],
        ),
      ),
    ),
  );
}




}
class _Row {
  final bool isHeader;
  final String? headerText;
  final AirtelMoneyTxn? tx;

  _Row.header(this.headerText)
      : isHeader = true,
        tx = null;

  _Row.item(this.tx)
      : isHeader = false,
        headerText = null;
}

