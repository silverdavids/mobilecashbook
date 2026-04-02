// app/sms_bootstrap.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sms_listener.dart';

class SmsBootstrap extends ConsumerStatefulWidget {
  final Widget child;
  const SmsBootstrap({super.key, required this.child});

  @override
  ConsumerState<SmsBootstrap> createState() => _SmsBootstrapState();
}

class _SmsBootstrapState extends ConsumerState<SmsBootstrap> {
  bool started = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (started) return;
      started = true;
      await ref.read(smsListenStateProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smsListenStateProvider);

 return Stack(
  children: [
    widget.child,

    Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        // ✅ push it ABOVE the BottomNavigationBar area
        minimum: const EdgeInsets.symmetric(horizontal: 12).copyWith(
          bottom: kBottomNavigationBarHeight + 24, // extra buffer
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
    // show only when useful
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