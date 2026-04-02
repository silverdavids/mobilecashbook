import '../domain/airtel_money_txn.dart';

//enum Network { airtel, mtn }

/// ------------------------------------------------------------
/// NETWORK DETECTION
/// ------------------------------------------------------------
Network? detectNetwork(String? sender, String? body) {
  final s = (sender ?? "").toLowerCase();
  final b = (body ?? "").toLowerCase();

  // Airtel
  if (s.contains("airtel") &&
      (b.contains("ugx") && b.contains("tid"))) {
    return Network.airtel;
  }

  // MTN
  if (b.contains("ugx") &&
      (b.contains("transaction id") ||
       b.contains("new momo balance") ||
       b.contains("new balance") ||
       b.contains("y'ello"))) {
    return Network.mtn;
  }

  return null;
}

/// ------------------------------------------------------------
/// COMMON HELPERS
/// ------------------------------------------------------------
int? _extractAmount(String body) {
  final r = RegExp(r'UGX\s?([\d,]+)', caseSensitive: false);
  final m = r.firstMatch(body);
  if (m == null) return null;
  return int.tryParse(m.group(1)!.replaceAll(',', ''));
}

int? _extractBalance(String body) {
  final r = RegExp(
    r'(?:balance.*?UGX\s?)([\d,]+)',
    caseSensitive: false,
  );

  final m = r.firstMatch(body);
  if (m == null) return null;
  return int.tryParse(m.group(1)!.replaceAll(',', ''));
}

String _extractTid(String body) {
  final r = RegExp(
    r'(?:TID|Transaction Id|Transaction ID|ID)\s*[:\-]?\s*([A-Z0-9\-]+)',
    caseSensitive: false,
  );

  final m = r.firstMatch(body);
  return m?.group(1)?.trim() ??
      "UNKNOWN-${DateTime.now().millisecondsSinceEpoch}";
}

String _extractPhone(String body) {
  final r = RegExp(r'(07\d{8}|2567\d{8})');
  return r.firstMatch(body)?.group(0) ?? "";
}

String _clean(String v) => v.trim();


/// ------------------------------------------------------------
/// AIRTEL PARSER
/// ------------------------------------------------------------
AirtelMoneyTxn? parseAirtelMessage(
  String body, {
  DateTime? smsDate,
}) {
  final lower = body.toLowerCase();

  final amount = _extractAmount(body);
  if (amount == null) return null;

  final tid = _extractTid(body);
  final balance = _extractBalance(body);
  final phone = _extractPhone(body);

  AirtelTxnType type;
  String name = "";

  if (lower.startsWith("received")) {
    type = AirtelTxnType.credit;
    name = "Received";
  } else if (lower.startsWith("sent") ||
             lower.startsWith("paid") ||
             lower.contains("withdraw")) {
    type = AirtelTxnType.debit;
    name = "Payment";
  } else {
    return null;
  }

  return AirtelMoneyTxn(
    type: type,
    tid: tid,
    amount: amount,
    partyName: _clean(name),
    partyNumber: phone,
    balance: balance,
    txnDateTime: smsDate,
    network: Network.airtel,
  );
}

/// ------------------------------------------------------------
/// MTN PARSER
/// ------------------------------------------------------------
AirtelMoneyTxn? parseMtnMessage(
  String body, {
  DateTime? smsDate,
}) {
  final lower = body.toLowerCase();

  final amount = _extractAmount(body);
  if (amount == null) return null;

  final tid = _extractTid(body);
  final balance = _extractBalance(body);
  final phone = _extractPhone(body);

  AirtelTxnType type;
  String name = "";

  if (lower.contains("you have received")) {
    type = AirtelTxnType.credit;
    name = "Received";
  } else if (lower.contains("you have sent") ||
             lower.contains("withdrawn") ||
             lower.contains("paid")) {
    type = AirtelTxnType.debit;
    name = "Withdraw";
  } else {
    return null;
  }

  return AirtelMoneyTxn(
    type: type,
    tid: tid,
    amount: amount,
    partyName: _clean(name),
    partyNumber: phone,
    balance: balance,
    txnDateTime: smsDate,
    network: Network.mtn,
  );
}