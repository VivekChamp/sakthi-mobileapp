import 'package:flutter/material.dart';

class SalesScreen extends StatelessWidget {
  final String serverUrl;
  final String sid;
  final String email;
  final List<String>
  roles; // Retained, but not used for restriction in this screen

  const SalesScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
    required this.roles, // Required parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // No role-based access control for sales features in this screen, all are visible.
    // The 'roles' parameter is still passed to SalesOrderScreen as needed.

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                // All sales-related cards are now visible unconditionally
                DashboardCard(
                  title: 'Customers',
                  icon: Icons.people,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/customerList',
                      arguments: {
                        'serverUrl': serverUrl,
                        'sid': sid,
                        'email': email,
                      },
                    );
                  },
                ),
                DashboardCard(
                  title: 'Sales Order',
                  icon: Icons.shopping_cart,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/sales_order',
                      arguments: {
                        'serverUrl': serverUrl,
                        'sid': sid,
                        'roles': roles, // Pass roles to SalesOrderScreen
                      },
                    );
                  },
                ),
                DashboardCard(
                  title: 'Sales Invoice',
                  icon: Icons.receipt,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/sales_invoice',
                      arguments: {'serverUrl': serverUrl, 'sid': sid},
                    );
                  },
                ),
                DashboardCard(
                  title: 'Quotations',
                  icon: Icons.request_quote,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/quotation_list',
                      arguments: {'serverUrl': serverUrl, 'sid': sid},
                    );
                  },
                ),
                DashboardCard(
                  title: 'Visit Entry',
                  icon: Icons.event,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/visitEntryList',
                      arguments: {'serverUrl': serverUrl, 'sid': sid},
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge!.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
