import 'package:hive/hive.dart';
import '../domain/airtel_money_txn.dart';

class TxnStore {
  static const boxName = 'txns';
  static Box? _box;

  static Future<void> init() async {
    _box ??= await Hive.openBox(boxName);
  }

  static Future<void> upsert(AirtelMoneyTxn tx) async {
    await init();

    final key = tx.tid ??
        "${tx.network.name}_${tx.txnDateTime?.millisecondsSinceEpoch}_${tx.amount}_${tx.partyName}";

    await _box!.put(key, tx.toJson()); // store Map
  }

  static Box box() {
    if (_box == null) throw StateError("TxnStore not initialized");
    return _box!;
  }
}