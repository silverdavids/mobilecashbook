import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telephony/telephony.dart';

import '../features/sms_import/background/sms_background_handler.dart';

final Telephony _telephony = Telephony.instance;

enum SmsListenState { off, listening, denied, error }

class SmsListenStateNotifier extends Notifier<SmsListenState> {
  @override
  SmsListenState build() => SmsListenState.off;

  Future<void> init() async {
    try {
      final ok = await _telephony.requestPhoneAndSmsPermissions ?? false;

      if (!ok) {
        state = SmsListenState.denied;
        return;
      }

      _telephony.listenIncomingSms(
        listenInBackground: true,
        onNewMessage: (SmsMessage msg) async => onBackgroundMessage(msg),
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