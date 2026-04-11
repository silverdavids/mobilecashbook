import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/sms_bootstrap.dart';
import 'features/sms_import/data/txn_store.dart';
import 'features/sms_import/data/sms_queue.dart';
import 'services/sms/SmsNativeBridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("[SMSDBG] STEP 1: WidgetsFlutterBinding initialized");

  await Hive.initFlutter();
  print("[SMSDBG] STEP 2: Hive initialized");

  await TxnStore.init();
  print("[SMSDBG] STEP 3: TxnStore initialized");
  SmsNativeBridge.start();
print("[SMSDBG] STEP X: SmsNativeBridge started");

  await SmsQueue.init();
  print("[SMSDBG] STEP 4: SmsQueue initialized");

  runApp(const ProviderScope(child: MobileCashBookApp()));
  print("[SMSDBG] STEP 5: runApp called");
}

class MobileCashBookApp extends ConsumerWidget {
  const MobileCashBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print("[SMSDBG] STEP 6: MobileCashBookApp build");

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Mobile CashBooks",
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        print("[SMSDBG] STEP 7: MaterialApp builder called");
        return SmsBootstrap(
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}