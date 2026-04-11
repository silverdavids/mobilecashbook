import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telephony/telephony.dart';

import '../features/sms_import/data/txn_parsers.dart';
import '../features/sms_import/data/txn_store.dart';
import '../features/sms_import/domain/airtel_money_txn.dart';

final Telephony _telephony = Telephony.instance;

enum SmsListenState { off, listening, denied, error }

@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage msg) async {
  try {
    print("[SMSDBG][BG] STEP 1: backgroundSmsHandler fired");

    await TxnStore.init();
    print("[SMSDBG][BG] STEP 2: TxnStore.init done");

    final body = msg.body ?? "";
    final sender = msg.address ?? "";
    final smsDate = msg.date == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(msg.date!);

    print("[SMSDBG][BG] STEP 3: sender=$sender");
    print("[SMSDBG][BG] STEP 4: body=$body");

    final net = detectNetwork(sender, body);
    print("[SMSDBG][BG] STEP 5: detected network=$net");

    if (net == null) {
      print("[SMSDBG][BG] STEP 6: network not matched, exiting");
      return;
    }

    final tx = (net == Network.airtel)
        ? parseAirtelMessage(body, smsDate: smsDate)
        : parseMtnMessage(body, smsDate: smsDate);

    print("[SMSDBG][BG] STEP 7: parsed tx=$tx");

    if (tx == null) {
      print("[SMSDBG][BG] STEP 8: parser returned null");
      return;
    }

    await TxnStore.upsert(tx);
    print("[SMSDBG][BG] STEP 9: saved tx tid=${tx.tid}");

    // Later add API sync here
    print("[SMSDBG][BG] STEP 10: background flow complete");
  } catch (e, st) {
    print("[SMSDBG][BG][ERROR] $e");
    print(st);
  }
}

class SmsListenStateNotifier extends Notifier<SmsListenState> {
  @override
  SmsListenState build() {
    print("[SMSDBG][LISTENER] build() => off");
    return SmsListenState.off;
  }

  Future<void> _handleForegroundMessage(SmsMessage msg) async {
    try {
      print("[SMSDBG][FG] STEP 1: foreground SMS received");

      await TxnStore.init();
      print("[SMSDBG][FG] STEP 2: TxnStore.init done");

      final body = msg.body ?? "";
      final sender = msg.address ?? "";
      final smsDate = msg.date == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(msg.date!);

      print("[SMSDBG][FG] STEP 3: sender=$sender");
      print("[SMSDBG][FG] STEP 4: body=$body");

      final net = detectNetwork(sender, body);
      print("[SMSDBG][FG] STEP 5: detected network=$net");

      if (net == null) {
        print("[SMSDBG][FG] STEP 6: network not matched, exiting");
        return;
      }

      final tx = (net == Network.airtel)
          ? parseAirtelMessage(body, smsDate: smsDate)
          : parseMtnMessage(body, smsDate: smsDate);

      print("[SMSDBG][FG] STEP 7: parsed tx=$tx");

      if (tx == null) {
        print("[SMSDBG][FG] STEP 8: parser returned null");
        return;
      }

      await TxnStore.upsert(tx);
      print("[SMSDBG][FG] STEP 9: saved tx tid=${tx.tid}");

      // This only proves save worked. Dashboard still must watch data source.
      print("[SMSDBG][FG] STEP 10: foreground flow complete");
    } catch (e, st) {
      print("[SMSDBG][FG][ERROR] $e");
      print(st);
    }
  }

  Future<void> init() async {
    try {
      print("[SMSDBG][LISTENER] STEP 1: init() called");

      final ok = await _telephony.requestPhoneAndSmsPermissions ?? false;
      print("[SMSDBG][LISTENER] STEP 2: permission result=$ok");

      if (!ok) {
        state = SmsListenState.denied;
        print("[SMSDBG][LISTENER] STEP 3: permission denied");
        return;
      }

      print("[SMSDBG][LISTENER] STEP 4: registering listenIncomingSms");
      _telephony.listenIncomingSms(
        listenInBackground: true,
        onNewMessage: _handleForegroundMessage,
        onBackgroundMessage: backgroundSmsHandler,
      );

      state = SmsListenState.listening;
      print("[SMSDBG][LISTENER] STEP 5: listener registered, state=listening");
    } catch (e, st) {
      print("[SMSDBG][LISTENER][ERROR] SMS listen init failed: $e");
      print(st);
      state = SmsListenState.error;
    }
  }
}

final smsListenStateProvider =
    NotifierProvider<SmsListenStateNotifier, SmsListenState>(
  SmsListenStateNotifier.new,
);