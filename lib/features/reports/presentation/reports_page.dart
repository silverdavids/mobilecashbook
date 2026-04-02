import 'package:flutter/material.dart';
import '../../sms_import/domain/airtel_money_txn.dart';

import 'SummaryByPeriodPage.dart';
import 'txns_by_recipient_page.dart';
import 'txns_by_source_page.dart';
import 'daily_breakdown_page.dart';
import 'network_split_page.dart';

class ReportsPage extends StatelessWidget {
  final List<AirtelMoneyTxn> txns;
  const ReportsPage({super.key, required this.txns});

  @override
  Widget build(BuildContext context) {
    final items = <_ReportItem>[
      _ReportItem(
        title: "Summary by Period",
        subtitle: "Today / Week / Month / Custom. Totals In/Out, Net, Count, Balances.",
        icon: Icons.analytics_outlined,
        builder: (_) => SummaryByPeriodPage(txns: txns), // ✅ pass here
      ),
 
      _ReportItem(
        title: "By Source",
        subtitle: "Group credits by sender/source (phone/name) for selected period.",
        icon: Icons.call_received_outlined,
        builder: (_) => TxnsBySourcePage(txns: txns),
      ),
     
       _ReportItem(
        title: "By Recipient",
        subtitle: "Group debits by receiver (phone/name) for selected period.",
        icon: Icons.person_search_outlined,
        builder: (_) => TxnsByRecipientPage(txns: txns),
      ),
      
      _ReportItem(
        title: "Daily Breakdown",
        subtitle: "Day-by-day totals in/out and net for a chosen range.",
        icon: Icons.calendar_month_outlined,
        builder: (_) => DailyBreakdownPage(txns: txns),
      ),
         
      _ReportItem(
        title: "Network Split",
        subtitle: "Compare Airtel vs MTN totals for the same period.",
        icon: Icons.swap_horiz_outlined,
        builder: (_) => NetworkSplitPage(txns: txns),
      ), 
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Reports")),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final it = items[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: it.builder)),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                    ),
                    child: Icon(it.icon, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.title,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          it.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.black45),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;

  const _ReportItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}
