import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AttendanceListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const AttendanceListScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _AttendanceListScreenState createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  List<dynamic> attendanceList = [];
  List<dynamic> filteredAttendanceList = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAttendanceList();
  }

  Future<void> fetchAttendanceList() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_attendance',
        ),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'];
        setState(() {
          attendanceList = List.from(data['attendance_list'] ?? []);
          // Sort by attendance_date descending (latest first)
          attendanceList.sort(
            (a, b) => (b['attendance_date'] ?? '9999-12-31').compareTo(
              a['attendance_date'] ?? '9999-12-31',
            ),
          );
          filteredAttendanceList = List.from(attendanceList);
          isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to fetch attendance list: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching attendance list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void filterAttendanceList(String query) {
    setState(() {
      filteredAttendanceList = attendanceList.where((attendance) {
        final employeeName = (attendance['employee_name'] ?? '').toLowerCase();
        final status = (attendance['status'] ?? '').toLowerCase();
        return employeeName.contains(query.toLowerCase()) ||
            status.contains(query.toLowerCase());
      }).toList();
      // Maintain sort order after filtering
      filteredAttendanceList.sort(
        (a, b) => (b['attendance_date'] ?? '9999-12-31').compareTo(
          a['attendance_date'] ?? '9999-12-31',
        ),
      );
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
      case 'Work From Home':
        return Colors.green;
      case 'Absent':
      case 'On Leave':
        return Colors.red;
      case 'Half Day':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date); // e.g., "February 24, 2025"
    } catch (e) {
      return dateStr ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance List',
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: searchController,
                onChanged: filterAttendanceList,
                decoration: InputDecoration(
                  hintText: 'Search by Employee or Status',
                  hintStyle: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : filteredAttendanceList.isEmpty
                  ? Center(
                      child: Text(
                        'No attendance records found',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredAttendanceList.length,
                      itemBuilder: (context, index) {
                        final attendance = filteredAttendanceList[index];
                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(
                                attendance['status'],
                              ),
                              child: Text(
                                attendance['employee_name']?[0] ?? 'N',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            title: Text(
                              attendance['employee_name'] ?? 'Unknown',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            subtitle: Text(
                              'Date: ${formatDate(attendance['attendance_date'])}',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(color: Colors.black87),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/attendanceDetails',
                                arguments: {
                                  'attendance': attendance,
                                  'serverUrl': widget.serverUrl,
                                  'sid': widget.sid,
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/createAttendance',
            arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
          );
          if (result == true) {
            fetchAttendanceList(); // Refresh to show latest created attendance at the top
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
