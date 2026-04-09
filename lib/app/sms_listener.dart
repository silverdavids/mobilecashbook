import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telephony/telephony.dart';

import '../features/sms_import/background/sms_background_handler.dart';
import '../features/sms_import/data/txn_parsers.dart';
import '../features/sms_import/data/txn_store.dart';
import '../features/sms_import/domain/airtel_money_txn.dart';

final Telephony _telephony = Telephony.instance;

enum SmsListenState { off, listening, denied, error }

class SmsListenStateNotifier extends Notifier<SmsListenState> {
  @override
  SmsListenState build() => SmsListenState.off;
   Future<void> _handleForegroundMessage(SmsMessage msg) async {
    await TxnStore.init();

    final body = msg.body ?? "";
    final sender = msg.address ?? "";
    final smsDate = msg.date == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(msg.date!);

    final net = detectNetwork(sender, body);
    if (net == null) return;

    final tx = (net == Network.airtel)
        ? parseAirtelMessage(body, smsDate: smsDate)
        : parseMtnMessage(body, smsDate: smsDate);

    if (tx != null) {
      await TxnStore.upsert(tx);
    }
  }


  Future<void> init() async {
    try {
      final ok = await _telephony.requestPhoneAndSmsPermissions ?? false;

      if (!ok) {
        state = SmsListenState.denied;
        return;
      }

      _telephony.listenIncomingSms(
        listenInBackground: false,
        onNewMessage: _handleForegroundMessage,
        onBackgroundMessage: onBackgroundMessage,
      );


      state = SmsListenState.listening;
    } catch (_) {
      state = SmsListenState.error;
    }
  }
}

final smsListenStateProvider =
    NotifierProvider<SmsListenStateNotifier, SmsListenState>(
        SmsListenStateNotifier.new);