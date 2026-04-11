import 'package:hive/hive.dart';
import '../domain/airtel_money_txn.dart';

class TxnStore {
  static const boxName = 'txns';
  static Box? _box;

  static Future<void> init() async {
    print("[SMSDBG][STORE] STEP 1: init() called");

    if (_box != null) {
      print("[SMSDBG][STORE] STEP 2: box already initialized");
      return;
    }

    _box = await Hive.openBox(boxName);
    print("[SMSDBG][STORE] STEP 3: Hive box '$boxName' opened");
  }

  static Future<void> upsert(AirtelMoneyTxn tx) async {
    print("[SMSDBG][STORE] STEP 4: upsert() called");

    await init();

    final key = tx.tid ??
        "${tx.network.name}_${tx.txnDateTime?.millisecondsSinceEpoch}_${tx.amount}_${tx.partyName}";

    print("[SMSDBG][STORE] STEP 5: computed key=$key");
    print("[SMSDBG][STORE] STEP 6: tx json=${tx.toJson()}");

    await _box!.put(key, tx.toJson());

    print("[SMSDBG][STORE] STEP 7: saved into Hive");

    final count = _box!.length;
    print("[SMSDBG][STORE] STEP 8: box count=$count");
  }

  static Box box() {
    print("[SMSDBG][STORE] STEP 9: box() requested");

    if (_box == null) {
      print("[SMSDBG][STORE][ERROR] box() called before init");
      throw StateError("TxnStore not initialized");
    }

    return _box!;
  }
}