import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sms_listener.dart';

class SmsBootstrap extends ConsumerStatefulWidget {
  final Widget child;
  const SmsBootstrap({super.key, required this.child});

  @override
  ConsumerState<SmsBootstrap> createState() => _SmsBootstrapState();
}

class _SmsBootstrapState extends ConsumerState<SmsBootstrap>
    with WidgetsBindingObserver {
  bool started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print("[SMSDBG][BOOT] STEP 1: SmsBootstrap initState");

    Future.microtask(() async {
      print("[SMSDBG][BOOT] STEP 2: microtask entered, started=$started");

      if (started) {
        print("[SMSDBG][BOOT] STEP 3: already started, skipping init");
        return;
      }

      started = true;
      print("[SMSDBG][BOOT] STEP 4: calling sms listener init()");
      await ref.read(smsListenStateProvider.notifier).init();
      print("[SMSDBG][BOOT] STEP 5: sms listener init() finished");
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("[SMSDBG][BOOT] LIFECYCLE: $state");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    print("[SMSDBG][BOOT] dispose()");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smsListenStateProvider);
    print("[SMSDBG][BOOT] build() state=$state");

    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.symmetric(horizontal: 12).copyWith(
              bottom: kBottomNavigationBarHeight + 24,
            ),
            child: _SmsIndicator(state: state),
          ),
        ),
      ],
    );
  }
}

class _SmsIndicator extends StatelessWidget {
  final SmsListenState state;
  const _SmsIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    print("[SMSDBG][INDICATOR] build() state=$state");

    if (state == SmsListenState.off) return const SizedBox.shrink();

    final text = switch (state) {
      SmsListenState.listening => "✅ SMS Listener: ON",
      SmsListenState.denied => "⚠️ SMS Permission denied",
      SmsListenState.error => "❌ SMS Listener error",
      SmsListenState.off => "",
    };

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}