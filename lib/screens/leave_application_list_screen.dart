import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'create_leave_screen.dart';
import 'leave_details_screen.dart';

class LeaveApplicationListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const LeaveApplicationListScreen({
    required this.serverUrl,
    required this.sid,
    super.key,
  });

  @override
  _LeaveApplicationListScreenState createState() =>
      _LeaveApplicationListScreenState();
}

class _LeaveApplicationListScreenState
    extends State<LeaveApplicationListScreen> {
  List<Map<String, dynamic>> leaveApplications = [];
  List<Map<String, dynamic>> filteredLeaveApplications = [];
  bool isLoading = true;
  List<Map<String, dynamic>> employees = [];
  bool isLoadingEmployees = true;
  TextEditingController searchController = TextEditingController();
  String selectedStatus = 'All';
  List<String> statusOptions = [
    'All',
    'Draft',
    'Open',
    'Approved',
    'Rejected',
    'Cancelled',
  ];
  bool isNavigating = false;

  @override
  void initState() {
    super.initState();
    fetchLeaveApplications();
    fetchEmployees();
    searchController.addListener(() {
      filterLeaveApplications(searchController.text);
    });
  }

  Future<void> fetchLeaveApplications() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_leave_application';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            leaveApplications = List<Map<String, dynamic>>.from(
              data['message']['leave_applications'] ?? [],
            );
            filteredLeaveApplications = List.from(leaveApplications)
              ..sort(
                (a, b) => (b['creation'] ?? '9999-12-31 23:59:59').compareTo(
                  a['creation'] ?? '9999-12-31 23:59:59',
                ),
              );
            isLoading = false;
          });
          filterLeaveApplications(searchController.text);
        } else {
          throw Exception(
            'Failed to load leave applications: ${data['message']['message']}',
          );
        }
      } else {
        throw Exception(
          'Failed to load leave applications: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching leave applications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchEmployees() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_employee';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            employees = List<Map<String, dynamic>>.from(
              data['message']['employees'] ?? [],
            );
            isLoadingEmployees = false;
          });
        } else {
          throw Exception(
            'Failed to load employees: ${data['message']['message']}',
          );
        }
      } else {
        throw Exception(
          'Failed to load employees: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      setState(() => isLoadingEmployees = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load employees. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void filterLeaveApplications(String query) {
    setState(() {
      filteredLeaveApplications =
          leaveApplications.where((leave) {
            final leaveId = leave['name'].toString().toLowerCase();
            final employeeName = leave['employee_name']
                .toString()
                .toLowerCase();
            final matchesSearch =
                leaveId.contains(query.toLowerCase()) ||
                employeeName.contains(query.toLowerCase());
            final matchesStatus =
                selectedStatus == 'All' ||
                leave['status'].toString() == selectedStatus;
            return matchesSearch && matchesStatus;
          }).toList()..sort(
            (a, b) => (b['creation'] ?? '9999-12-31 23:59:59').compareTo(
              a['creation'] ?? '9999-12-31 23:59:59',
            ),
          );
    });
  }

  void _navigateToCreateLeaveScreen() {
    if (isNavigating) return;
    if (isLoadingEmployees) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, loading employees...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No employees available to create a leave application.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => isNavigating = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateLeaveScreen(
          serverUrl: widget.serverUrl,
          sid: widget.sid,
          employees: employees,
          onLeaveCreated: fetchLeaveApplications,
        ),
      ),
    ).then((_) => setState(() => isNavigating = false));
  }

  void _navigateToLeaveDetailsScreen(Map<String, dynamic> leave) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaveDetailsScreen(
          serverUrl: widget.serverUrl,
          sid: widget.sid,
          leave: leave,
          onLeaveUpdated: fetchLeaveApplications,
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Leave Applications',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: isNavigating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToCreateLeaveScreen,
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
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: searchController,
                          onChanged: filterLeaveApplications,
                          decoration: const InputDecoration(
                            hintText: 'Search by Leave ID or Employee Name',
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Status',
                            labelStyle: TextStyle(color: Colors.white),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: statusOptions
                              .map(
                                (status) => DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedStatus = value ?? 'All';
                              filterLeaveApplications(searchController.text);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredLeaveApplications.isEmpty
                        ? const Center(
                            child: Text(
                              'No leave applications found',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredLeaveApplications.length,
                            itemBuilder: (context, index) {
                              final leave = filteredLeaveApplications[index];
                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Text(
                                      (leave['employee_name'] ?? 'N')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    leave['name'] ?? 'No ID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        leave['employee_name'] ?? 'No name',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        'Status: ${leave['status']}',
                                        style: TextStyle(
                                          color: leave['status'] == 'Draft'
                                              ? Colors.orange
                                              : leave['status'] == 'Approved'
                                              ? Colors.green
                                              : leave['status'] == 'Rejected'
                                              ? Colors.red
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Created: ${leave['creation'] ?? 'N/A'}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    Icons.info_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  onTap: () =>
                                      _navigateToLeaveDetailsScreen(leave),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
