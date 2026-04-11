import 'package:flutter/services.dart';
import '../../features/sms_import/data/txn_parsers.dart';
import '../../features/sms_import/data/txn_store.dart';
import '../../features/sms_import/domain/airtel_money_txn.dart';
class SmsNativeBridge {
  static const _channel = MethodChannel('mobilecashbook/sms_events');

  static void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onSmsReceived') return;

      final args = Map<String, dynamic>.from(call.arguments as Map);
      final from = args['from']?.toString() ?? '';
      final body = args['body']?.toString() ?? '';
      final smsDateRaw = args['smsDate']?.toString();

      final smsDate = smsDateRaw == null ? null : DateTime.tryParse(smsDateRaw);

      print('[SMSDBG][BRIDGE] received from Android');
      print('[SMSDBG][BRIDGE] from=$from');
      print('[SMSDBG][BRIDGE] body=$body');

      final net = detectNetwork(from, body);
      print('[SMSDBG][BRIDGE] detected network=$net');

      if (net == null) return;

      final tx = (net == Network.airtel)
          ? parseAirtelMessage(body, smsDate: smsDate)
          : parseMtnMessage(body, smsDate: smsDate);

      print('[SMSDBG][BRIDGE] parsed tx=$tx');

      if (tx == null) return;

      await TxnStore.upsert(tx);
      print('[SMSDBG][BRIDGE] saved tx tid=${tx.tid}');
    });
  }
}