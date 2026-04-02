import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telephony/telephony.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/sms_bootstrap.dart';
import 'features/sms_import/background/sms_background_handler.dart' as sms_bg;
import 'features/sms_import/data/txn_store.dart';
import 'features/sms_import/domain/airtel_money_txn.dart';
import 'features/sms_import/data/sms_queue.dart';

enum SmsListenState { off, listening, denied, error }

final Telephony telephony = Telephony.instance;


Future<void> initSmsListener() async {
  final bool ok = await telephony.requestPhoneAndSmsPermissions ?? false;
  if (!ok) return;

  telephony.listenIncomingSms(
    onNewMessage: (SmsMessage msg) async {
      final body = msg.body ?? "";

      // ✅ Try Airtel first
      var tx = parseAirtelMoneyTxn(body,
          smsDate: msg.date != null
              ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
              : DateTime.now());

      // ✅ If not Airtel, try MTN
      tx ??= parseMtnMoMoTxn(
        body,
        smsDate: msg.date != null
            ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
            : DateTime.now(),
      );

      if (tx != null) {
        await TxnStore.upsert(tx);
        debugPrint("✅ TX SAVED: ${tx.tid} ${tx.amount}");
      } else {
        debugPrint("⚠️ SMS ignored (not a transaction)");
      }
    },
    listenInBackground: false,
  );
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await TxnStore.init();
  await SmsQueue.init();

  await initSmsListener();

  runApp(const ProviderScope(child: MobileCashBookApp()));
}

class MobileCashBookApp extends ConsumerWidget {
  const MobileCashBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Mobile CashBooks",
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) => SmsBootstrap(
        child: child ?? const SizedBox(),
      ),
    );
  }
}