import 'package:telephony/telephony.dart';
//import 'package:telephony_fix/telephony_fix.dart';
import '../data/sms_queue.dart';
import '../data/txn_store.dart';
import 'package:mobilecashbook/core/api/ApiSender.dart';
import '../data/txn_parsers.dart';
import '../domain/airtel_money_txn.dart';
import 'package:device_info_plus/device_info_plus.dart';
//import 'package:mobilecashbook/core/api/sms_payload.dart';
import 'package:mobilecashbook/core/device_id.dart';
Future<String> getDeviceId() async {
  final info = DeviceInfoPlugin();
  final android = await info.androidInfo;
  return android.id; // stable device id
}
@pragma('vm:entry-point')
Future<void> onBackgroundMessage(SmsMessage message) async {
  print("✅ BACKGROUND CALLBACK FIRED"); // <-- keep this for testing

  await SmsQueue.init();
  await TxnStore.init();

  final body = message.body ?? "";
  final sender = message.address ?? "";
  final smsDate = message.date == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(message.date!);

  final net = detectNetwork(sender, body);
  if (net == null) return;

  final deviceId = await DeviceId.getOrCreate(); // ✅ background-safe

  await SmsQueue.storeRaw({
    "deviceId": deviceId,
    "from": sender,
    "body": body,
    "smsDate": smsDate?.toUtc().toIso8601String(),
    "providerHint": net.name,
  });

  final tx = (net == Network.airtel)
      ? parseAirtelMessage(body, smsDate: smsDate)
      : parseMtnMessage(body, smsDate: smsDate);

   if (tx != null) {
    await TxnStore.upsert(tx);
    print("✅ TX STORED locally tid=${tx.tid} net=${tx.network.name}");
  } else {
    print(
      "⚠️ SMS matched ${net.name} but parser returned null. sender=$sender bodyLen=${body.length}",
    );
  }

  await ApiSender.tryFlushQueue();

}
