import 'package:flutter/material.dart';

import 'tabs/admin_disputes_tab.dart';
import 'tabs/admin_orders_tab.dart';
import 'tabs/admin_users_tab.dart';

enum AdminTab {
  orders('orders', 'Commandes', Icons.receipt_long_outlined),
  users('users', 'Comptes', Icons.people_outline),
  disputes('disputes', 'Litiges', Icons.report_problem_outlined);

  const AdminTab(this.query, this.label, this.icon);

  final String query;
  final String label;
  final IconData icon;

  static AdminTab parse(String? query) => values.firstWhere(
    (tab) => tab.query == query,
    orElse: () => AdminTab.orders,
  );
}

class AdminManagementScreen extends StatelessWidget {
  const AdminManagementScreen({super.key, required this.tab});

  final AdminTab tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tab.label)),
      body: switch (tab) {
        AdminTab.orders => const AdminOrdersTab(),
        AdminTab.users => const AdminUsersTab(),
        AdminTab.disputes => const AdminDisputesTab(),
      },
    );
  }
}
