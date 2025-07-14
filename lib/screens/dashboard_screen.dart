import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatelessWidget {
  final String serverUrl;
  final String sid;
  final String fullName;
  final String email;
  final List<String>
  roles; // Retained as it might be used by other features not shown

  const DashboardScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.fullName,
    required this.email,
    required this.roles, // Required parameter
  }) : super(key: key);

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Logout',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Close',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Yes',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        final logoutUrl = '$serverUrl/api/method/logout';
        final response = await http.get(
          Uri.parse(logoutUrl),
          headers: {
            'Cookie': 'sid=$sid',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged out successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: ${response.statusCode}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error during logout: $e')));
      }

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No role restrictions on the DashboardScreen
    return WillPopScope(
      onWillPop: () async {
        await _handleLogout(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Dashboard',
            style: Theme.of(
              context,
            ).textTheme.titleLarge!.copyWith(color: Colors.white),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () => _handleLogout(context),
            ),
          ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome to VPS Business Solutions, $fullName!',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        // All cards are now visible
                        DashboardCard(
                          title: 'Sales',
                          icon: Icons.store,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/sales',
                              arguments: {
                                'serverUrl': serverUrl,
                                'sid': sid,
                                'email': email,
                                'roles': roles, // Pass roles to SalesScreen
                              },
                            );
                          },
                        ),
                        DashboardCard(
                          title: 'HR',
                          icon: Icons.person,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/hr',
                              arguments: {'serverUrl': serverUrl, 'sid': sid},
                            );
                          },
                        ),
                        // DashboardCard(
                        //   title: 'Accounting',
                        //   icon: Icons.account_balance,
                        //   onTap: () {
                        //     Navigator.pushNamed(
                        //       context,
                        //       '/accounting',
                        //       arguments: {'serverUrl': serverUrl, 'sid': sid},
                        //     );
                        //   },
                        // ),
                        // New Dashboard Card for Receivable Report
                        DashboardCard(
                          title: 'Receivable Report',
                          icon: Icons.receipt_long, // A suitable icon
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/receivableReport',
                              arguments: {'serverUrl': serverUrl, 'sid': sid},
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
              const SizedBox(height: 16),
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
