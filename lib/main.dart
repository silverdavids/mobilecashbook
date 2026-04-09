import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/sms_bootstrap.dart';
import 'features/sms_import/data/txn_store.dart';
import 'features/sms_import/data/sms_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await TxnStore.init();
  await SmsQueue.init();

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