enum AirtelTxnType { credit, debit }


enum Network { airtel, mtn }

class AirtelMoneyTxn {
  final AirtelTxnType type;
  final String tid;
  final int amount;
  final String partyNumber;
  final String partyName;
  final int? balance;
  final DateTime? txnDateTime;

  final Network network; // ✅ ADD

  const AirtelMoneyTxn({
    required this.type,
    required this.tid,
    required this.amount,
    required this.partyNumber,
    required this.partyName,
    required this.balance,
    this.txnDateTime,
    required this.network, // ✅ ADD
  });
    Map<String, dynamic> toJson() => {
    "type": type.name,
    "tid": tid,
    "amount": amount,
    "partyNumber": partyNumber,
    "partyName": partyName,
    "balance": balance,
    "txnDateTime": txnDateTime?.toIso8601String(),
    "network": network.name,
  };

  static AirtelMoneyTxn fromJson(Map<String, dynamic> j) => AirtelMoneyTxn(
    type: AirtelTxnType.values.firstWhere((e) => e.name == j["type"]),
    tid: j["tid"],
    amount: j["amount"],
    partyNumber: j["partyNumber"] ?? "",
    partyName: j["partyName"] ?? "",
    balance: j["balance"],
    txnDateTime: j["txnDateTime"] == null ? null : DateTime.tryParse(j["txnDateTime"]),
    network: Network.values.firstWhere((e) => e.name == j["network"]),
  );
}




final _months = <String, int>{
  "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
  "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
};
DateTime? _parseAirtelDateTime(String? s) {
  if (s == null) return null;
  final text = s.trim();

  // Matches: 07-November-2025 23:29 OR 14-February-2026 08:37
  final m = RegExp(r'^(\d{1,2})-([A-Za-z]+)-(\d{4})\s+(\d{1,2}):(\d{2})$')
      .firstMatch(text);

  if (m == null) return null;

  final dd = int.parse(m.group(1)!);
  final mmName = m.group(2)!.toLowerCase();
  final yyyy = int.parse(m.group(3)!);
  final hh = int.parse(m.group(4)!);
  final min = int.parse(m.group(5)!);

  final mm = _months[mmName];
  if (mm == null) return null;

  return DateTime(yyyy, mm, dd, hh, min);
}
bool _isMtnWithdrawConfirm(String text) =>
    RegExp(r'You\s+have\s+withdrawn\s+UGX', caseSensitive: false).hasMatch(text) &&
    RegExp(r'New\s+balance\s*:?', caseSensitive: false).hasMatch(text);


DateTime? _parseMtnWithdrawConfirmDateTime(String text) {
  // "You have withdrawn UGX 500,000 on 2026-01-20 20:22:03."
  final m = RegExp(r'on\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})', caseSensitive: false)
      .firstMatch(text);
  if (m == null) return null;
  return DateTime.tryParse("${m.group(1)} ${m.group(2)}");
}


int _parseUgx(String s) => int.parse(s.replaceAll(",", "").trim());

AirtelMoneyTxn? parseAirtelMoneyReceived(String body) {
  final text = body.replaceAll('\n', ' ');
  final re = RegExp(
    r'RECEIVED\.\s*TID\s*(\d+)\.\s*UGX\s*([\d,]+)\s*from\s*(\d+)\s*,\s*(.+?)\.\s*Bal\s*UGX\s*([\d,]+)',
    caseSensitive: false,
  );

  final m = re.firstMatch(text);
  if (m == null) return null;

  return AirtelMoneyTxn(
    type: AirtelTxnType.credit,
    tid: m.group(1)!,
    amount: _parseUgx(m.group(2)!),
    partyNumber: m.group(3)!,
    partyName: m.group(4)!.trim(),
    balance: _parseUgx(m.group(5)!),
    network: Network.airtel
  );
}

AirtelMoneyTxn? parseAirtelMoneySent(String body) {
  final text = body.replaceAll('\n', ' ');

  final re = RegExp(
    r'SENT\.?\s*TID\s*(\d+)\.\s*UGX\s*([\d,]+)\s*to\s*(.+?)\s+(\d+)\.\s*Fee.*?Bal\s*UGX\s*([\d,]+)\.\s*Date\s*([^.]+)',
    caseSensitive: false,
  );

  final m = re.firstMatch(text);
  if (m == null) return null;

  return AirtelMoneyTxn(
    type: AirtelTxnType.debit,
    tid: m.group(1)!,
    amount: _parseUgx(m.group(2)!),
    partyName: m.group(3)!.trim(),
    partyNumber: m.group(4)!,
    balance: _parseUgx(m.group(5)!),
    txnDateTime: _parseAirtelDateTime(m.group(6)?.trim()),
    network: Network.airtel
  );
}
AirtelMoneyTxn? parseAirtelMoneyWithdrawn(String body) {
  final text = body.replaceAll('\n', ' ').trim();

  final re = RegExp(
    r'WITHDRAWN\.\s*TID\s*(\d+)\.\s*UGX\s*([\d,]+)\s*with\s*Agent\s*ID:\s*(\d+)\.\s*Fee\s*UGX\s*([\d,]+)\.\s*Tax\s*UGX\s*([\d,]+)\.\s*Bal\s*UGX\s*([\d,]+)\.\s*(\d{1,2}-[A-Za-z]+-\d{4}\s+\d{1,2}:\d{2})',
    caseSensitive: false,
  );

  final m = re.firstMatch(text);
  if (m == null) return null;

  final tid = m.group(1)!;
  final amount = _parseUgx(m.group(2)!);
  final agentId = m.group(3)!;
  // fee/tax available if you later add fields:
  // final fee = _parseUgx(m.group(4)!);
  // final tax = _parseUgx(m.group(5)!);

  final balance = _parseUgx(m.group(6)!);
  final dt = _parseAirtelDateTime(m.group(7)?.trim());

  return AirtelMoneyTxn(
    type: AirtelTxnType.debit,
    tid: tid,
    amount: amount,
    partyNumber: agentId, // ✅ keep agent id here (optional)
    partyName: "Withdraw - Agent $agentId",
    balance: balance,
    txnDateTime: dt,
    network: Network.airtel
  );
}



AirtelMoneyTxn? parseAirtelMoneyPaid(String body) {
  final text = body.replaceAll('\n', ' ');
  final re = RegExp(
    r'PAID\.\s*TID\s*(\d+)\.\s*UGX\s*([\d,]+)\s*to\s*(.+?)\.\s*Bal\s*UGX\s*([\d,]+)',
    caseSensitive: false,
  );

  final m = re.firstMatch(text);
  if (m == null) return null;

  return AirtelMoneyTxn(
    type: AirtelTxnType.debit,
    tid: m.group(1)!,
    amount: _parseUgx(m.group(2)!),
    partyNumber: "",
    partyName: m.group(3)!.trim(),
    balance: _parseUgx(m.group(4)!),
    network: Network.airtel
  );
}
AirtelMoneyTxn? parseAirtelMoneyCashDeposit(String body) {
  final text = body.replaceAll('\n', ' ');

  final re = RegExp(
    r'CASH\s+DEPOSIT\s+of\s+UGX\s*([\d,]+)\s+from\s+(.+?)\.\s*Bal\s*UGX\s*([\d,]+)\.\s*TID\s*(\d+)\.\s*(\d{1,2}-[A-Za-z]+-\d{4}\s+\d{1,2}:\d{2})',
    caseSensitive: false,
  );

  final m = re.firstMatch(text);
  if (m == null) return null;

  return AirtelMoneyTxn(
    type: AirtelTxnType.credit,
    tid: m.group(4)!,
    amount: _parseUgx(m.group(1)!),
    partyNumber: "",
    partyName: m.group(2)!.trim(),
    balance: _parseUgx(m.group(3)!),
    txnDateTime: _parseAirtelDateTime(m.group(5)?.trim()),
    network: Network.airtel
  );
}

DateTime? _parseMtnDateTime(String text) {
  // on 2026-01-20 11:42:36
  final m = RegExp(r'on\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})', caseSensitive: false)
      .firstMatch(text);
  if (m == null) return null;
  return DateTime.tryParse("${m.group(1)} ${m.group(2)}");
}

int? _parseMtnMoney(String? s) {
  if (s == null) return null;
  final cleaned = s.replaceAll(",", "").replaceAll("UGX", "").trim();
  // handles 504,634.88 -> 504634 (drops decimals)
  final asDouble = double.tryParse(cleaned);
  if (asDouble != null) return asDouble.floor();
  return int.tryParse(cleaned);
}


String _makeSyntheticTid(DateTime? smsDate, int amount) {
  final t = (smsDate ?? DateTime.now()).millisecondsSinceEpoch;
  return "MTNCONF-$amount-$t";
}



AirtelMoneyTxn? parseMtnMoMoTxn(String body, {DateTime? smsDate}) {
  final text = body.replaceAll('\n', ' ').trim();

  final isWithdrawalRequest =
      RegExp(r"requested\s+a\s+withdrawal", caseSensitive: false).hasMatch(text);

  final isWithdrawConfirm = _isMtnWithdrawConfirm(text);

  // sometimes only request has "Transaction ID 917..."
  final tidFound = RegExp(r'(?:Transaction ID|ID)\s*:?[\s]*([0-9]+)', caseSensitive: false)
      .firstMatch(text)
      ?.group(1);

  // If not request, not confirm, and no tid => ignore
final hasBalance = RegExp(
  r'(?:New\s+balance\s*:|New\s+balance\s+is|balance\s+is\s+now|New\s+MoMo\s+balance\s*:|Your\s+Mobile\s+Money\s+balance\s+is\s+now)',
  caseSensitive: false,
).hasMatch(text);

final hasAction =
    RegExp(r'You\s+have\s+sent\s+UGX', caseSensitive: false).hasMatch(text) ||
    RegExp(r'You\s+have\s+received\s+UGX', caseSensitive: false).hasMatch(text) ||
    RegExp(r'You\s+have\s+paid\s+UGX', caseSensitive: false).hasMatch(text) ||
    RegExp(r'You\s+have\s+bought\s+UGX', caseSensitive: false).hasMatch(text) ||
    RegExp(r"Y'ello\.", caseSensitive: false).hasMatch(text); // ✅ double quotes here

// ✅ only ignore if it’s clearly not a MoMo transaction
if (tidFound == null && !isWithdrawConfirm && !isWithdrawalRequest && !(hasBalance && hasAction)) {
  return null;
}


  // -------------------------
  // 1) REQUEST (PENDING)
  // -------------------------
  if (isWithdrawalRequest) {
    final amtStr = RegExp(r'withdrawal\s+of\s+UGX\s*([\d,]+(?:\.\d+)?)', caseSensitive: false)
        .firstMatch(text)
        ?.group(1);

    final who = RegExp(r'from\s+([^\.]+)\.', caseSensitive: false)
        .firstMatch(text)
        ?.group(1)
        ?.trim();

    final amount = _parseMtnMoney(amtStr);
    if (amount == null) return null;

    return AirtelMoneyTxn(
      type: AirtelTxnType.debit,
      tid: tidFound ?? "", // should exist for pending
      amount: amount,
      partyName: (who == null || who.isEmpty)
          ? "Withdraw (Pending)"
          : "Withdraw (Pending) - $who",
      partyNumber: "",
      balance: null,
      txnDateTime: smsDate,
      network: Network.mtn
    );
  }

  // -------------------------
  // 2) CONFIRM (WITHDRAWN) - often NO TID
  // -------------------------
  if (isWithdrawConfirm) {
    final amtStr = RegExp(r'withdrawn\s+UGX\s*([\d,]+(?:\.\d+)?)', caseSensitive: false)
        .firstMatch(text)
        ?.group(1);

    final amount = _parseMtnMoney(amtStr);
    if (amount == null) return null;

  final balStr = RegExp(
  r'(?:'
  r'New\s+balance\s*:'
  r'|New\s+balance\s+is\s*:?'          // ✅ handles "is:" and "is :"
  r'|balance\s+is\s+now\s*:?'
  r'|New\s+MoMo\s+balance\s*:?'
  r'|Your\s+Mobile\s+Money\s+balance\s+is\s+now\s*:?'
  r')\s*(?:UGX\s*)?([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
).firstMatch(text)?.group(1);



    final balance = _parseMtnMoney(balStr);

    // confirmation has "on 2026-01-20 20:22:03"
    final msgDt = _parseMtnWithdrawConfirmDateTime(text);
    final finalDt = msgDt ?? smsDate;

    // synthetic tid for merging only
    final syntheticTid = _makeSyntheticTid(finalDt, amount);

    return AirtelMoneyTxn(
      type: AirtelTxnType.debit,
      tid: syntheticTid,
      amount: amount,
      partyName: "Withdraw",
      partyNumber: "",
      balance: balance,
      txnDateTime: finalDt,
       network: Network.mtn
    );
  }

  // -------------------------
  // 3) OTHER MTN TXNS (SENT / RECEIVED / PAID / AIRTIME ...)
  // -------------------------

  // Amount: prefer context to avoid Fee/Tax UGX
  int? amount;
  if (RegExp(r'You\s+have\s+sent\s+UGX', caseSensitive: false).hasMatch(text)) {
    final m = RegExp(r'sent\s+UGX\s*([\d,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(text);
    amount = _parseMtnMoney(m?.group(1));
  } else if (RegExp(r'You\s+have\s+received\s+UGX', caseSensitive: false).hasMatch(text)) {
    final m = RegExp(r'received\s+UGX\s*([\d,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(text);
    amount = _parseMtnMoney(m?.group(1));
  } else if (RegExp(r'You\s+have\s+paid\s+UGX', caseSensitive: false).hasMatch(text)) {
    final m = RegExp(r'paid\s+UGX\s*([\d,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(text);
    amount = _parseMtnMoney(m?.group(1));
  } else if (RegExp(r'You\s+have\s+bought\s+UGX', caseSensitive: false).hasMatch(text)) {
    final m = RegExp(r'bought\s+UGX\s*([\d,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(text);
    amount = _parseMtnMoney(m?.group(1));
  } else {
    final m = RegExp(r'UGX\s*([\d,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(text);
    amount = _parseMtnMoney(m?.group(1));
  }
  if (amount == null) return null;

final balStr = RegExp(
  r'(?:'
  r'New\s+balance\s*:'
  r'|New\s+balance\s+is\s*:?'          // ✅ handles "is:" and "is :"
  r'|balance\s+is\s+now\s*:?'
  r'|New\s+MoMo\s+balance\s*:?'
  r'|Your\s+Mobile\s+Money\s+balance\s+is\s+now\s*:?'
  r')\s*(?:UGX\s*)?([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
).firstMatch(text)?.group(1);



  final balance = _parseMtnMoney(balStr);
  final msgDt = _parseMtnDateTime(text);
  final finalDt = msgDt ?? smsDate;

final tid = tidFound ?? _makeSyntheticTid(finalDt, amount);

  // SENT
  final sent1 = RegExp(
    r'You\s+have\s+sent\s+UGX\s*[\d,]+.*?to\s+(.+?)\s*,\s*(\d{9,15})\s+on',
    caseSensitive: false,
  ).firstMatch(text);

  final sent2 = RegExp(
    r'You\s+have\s+sent\s+UGX\s*[\d,]+.*?to\s+(\d{9,15})\s*,\s*([^\.]+)\.',
    caseSensitive: false,
  ).firstMatch(text);

  if (sent1 != null) {
    return AirtelMoneyTxn(
      type: AirtelTxnType.debit,
      tid: tid,
      amount: amount,
      partyName: sent1.group(1)!.trim(),
      partyNumber: sent1.group(2)!.trim(),
      balance: balance,
      txnDateTime: finalDt,
       network: Network.mtn
    );
  }

  if (sent2 != null) {
    return AirtelMoneyTxn(
      type: AirtelTxnType.debit,
      tid: tid,
      amount: amount,
      partyName: sent2.group(2)!.trim(),
      partyNumber: sent2.group(1)!.trim(),
      balance: balance,
      txnDateTime: finalDt,
       network: Network.mtn
    );
  }

  // RECEIVED (with number)
  final recv1 = RegExp(
    r'You\s+have\s+received\s+UGX\s*[\d,]+.*?from\s+(.+?)\s*,\s*(\d{9,15})',
    caseSensitive: false,
  ).firstMatch(text);

  if (recv1 != null) {
    return AirtelMoneyTxn(
      type: AirtelTxnType.credit,
      tid: tid,
      amount: amount,
      partyName: recv1.group(1)!.trim(),
      partyNumber: recv1.group(2)!.trim(),
      balance: balance,
      txnDateTime: finalDt,
       network: Network.mtn
    );
  }

  // RECEIVED (no number)
  final recv2 = RegExp(
    r'You\s+have\s+received\s+UGX\s*[\d,]+.*?from\s+(.+?)\s+on\s+\d{4}-\d{2}-\d{2}',
    caseSensitive: false,
  ).firstMatch(text);

  if (recv2 != null) {
    return AirtelMoneyTxn(
      type: AirtelTxnType.credit,
      tid: tid,
      amount: amount,
      partyName: recv2.group(1)!.trim(),
      partyNumber: "",
      balance: balance,
      txnDateTime: finalDt,
       network: Network.mtn
    );
  }

  // PAID
  final pay = RegExp(
    r'You\s+have\s+paid\s+UGX\s*[\d,]+\s+for\s+(.+?)\s+at',
    caseSensitive: false,
  ).firstMatch(text);

  if (pay != null) {
    return AirtelMoneyTxn(
      type: AirtelTxnType.debit,
      tid: tid,
      amount: amount,
      partyName: pay.group(1)!.trim(),
      partyNumber: "",
      balance: balance,
      txnDateTime: finalDt,
       network: Network.mtn
    );
  }

  // AIRTIME
  if (RegExp(r'You\s+have\s+bought\s+UGX.*airtime', caseSensitive: false).hasMatch(text)) {
    return AirtelMoneyTxn(
      type: AirtelTxnType.debit,
      tid: tid,
      amount: amount,
      partyName: "Airtime",
      partyNumber: "",
      balance: balance,
      txnDateTime: finalDt,
       network: Network.mtn
    );
  }

  // fallback
  return AirtelMoneyTxn(
    type: AirtelTxnType.debit,
    tid: tid,
    amount: amount,
    partyName: "MTN Transaction",
    partyNumber: "",
    balance: balance,
    txnDateTime: finalDt,
     network: Network.mtn
  );
}

AirtelMoneyTxn? parseAirtelMoneySentV2(String body) {
  final text = body.replaceAll('\n', ' ').trim();

  final re = RegExp(
    r'SENT\s+UGX\s*([\d,]+)\s*to\s*(.+?)\s*on\s*(\d{9,15})\.\s*Fee\s*UGX\s*[\d.,]+\s*Bal\s*UGX\s*([\d,]+)\.\s*TID\s*(\d+)',
    caseSensitive: false,
  );

  final m = re.firstMatch(text);
  if (m == null) return null;

  return AirtelMoneyTxn(
    type: AirtelTxnType.debit,
    tid: m.group(5)!,
    amount: _parseUgx(m.group(1)!),
    partyName: m.group(2)!.trim(),
    partyNumber: m.group(3)!,
    balance: _parseUgx(m.group(4)!),
    network: Network.airtel, // ✅ FIX
  );
}



AirtelMoneyTxn? parseAirtelMoneyTxn(String body, {DateTime? smsDate}) {
  final tx =
      parseAirtelMoneyReceived(body)
      ?? parseAirtelMoneySent(body)      // old format
      ?? parseAirtelMoneySentV2(body)    // ✅ NEW FORMAT
      ?? parseAirtelMoneyPaid(body)
      ?? parseAirtelMoneyCashDeposit(body)
      ?? parseAirtelMoneyWithdrawn(body);

  if (tx == null) return null;

  final finalDt = tx.txnDateTime ?? smsDate;

  return AirtelMoneyTxn(
    type: tx.type,
    tid: tx.tid,
    amount: tx.amount,
    partyNumber: tx.partyNumber,
    partyName: tx.partyName,
    balance: tx.balance,
    txnDateTime: finalDt,
     network: Network.airtel
  );
}




 // ✅ include this


