import 'package:hive_flutter/hive_flutter.dart';

import '../domain/airtel_money_txn.dart';

class SmsQueue {
  static const boxName = "sms_queue";
  static Box? _box;

  static Future<Box> _ensureBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    await Hive.initFlutter();
    _box = await Hive.openBox(boxName);
    return _box!;
  }

  static Future<void> init() async {
    await _ensureBox();
  }
static Future<void> storeRaw(Map<String, dynamic> sms) async {
  final box = await _ensureBox(); // ✅ use this
  final key = DateTime.now().microsecondsSinceEpoch.toString();

  await box.put(key, {
    ...sms,
    "sent": false,
    "tries": 0,
  });
}
  static Future<void> store(AirtelMoneyTxn tx) async {
    final box = await _ensureBox();
    await box.add({
      "tid": tx.tid,
      "amount": tx.amount,
      "partyName": tx.partyName,
      "partyNumber": tx.partyNumber,
      "balance": tx.balance,
      "type": tx.type.toString(),
      "network": tx.network.toString(),
      "txnDateTime": tx.txnDateTime?.toIso8601String(),
      "createdUtc": DateTime.now().toUtc().toIso8601String(),
      "sent": false,
      "tries": 0,
    });
  }

  static Future<List<Map<String, dynamic>>> pending({int limit = 50}) async {
    final box = await _ensureBox();

    final out = <Map<String, dynamic>>[];
    for (final k in box.keys) {
      final raw = box.get(k);
      if (raw is! Map) continue;

      final m = Map<String, dynamic>.from(raw);
      if (m["sent"] == true) continue;

      m["_key"] = k;
      out.add(m);

      if (out.length >= limit) break;
    }
    return out;
  }

  static Future<void> markSent(dynamic key) async {
    final box = await _ensureBox();
    final raw = box.get(key);
    if (raw is! Map) return;

    final m = Map<String, dynamic>.from(raw);
    m["sent"] = true;
    await box.put(key, m);
  }

  static Future<void> markTry(dynamic key) async {
    final box = await _ensureBox();
    final raw = box.get(key);
    if (raw is! Map) return;

    final m = Map<String, dynamic>.from(raw);
    m["tries"] = (m["tries"] ?? 0) + 1;
    await box.put(key, m);
  }
}