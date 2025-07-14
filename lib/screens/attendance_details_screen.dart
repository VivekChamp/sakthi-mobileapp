import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> attendance;
  final String serverUrl;
  final String sid;

  const AttendanceDetailsScreen({
    Key? key,
    required this.attendance,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _AttendanceDetailsScreenState createState() =>
      _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.attendance['name'] ?? 'Attendance Details',
            style: Theme.of(context)
                .textTheme
                .titleLarge!
                .copyWith(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: Theme.of(context).textTheme.bodyMedium,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'General'),
            Tab(icon: Icon(Icons.work), text: 'Work Details'),
            Tab(icon: Icon(Icons.person), text: 'Employee Info'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.background
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildGeneralInfo(),
            _buildWorkDetails(),
            _buildEmployeeInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralInfo() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Attendance ID', widget.attendance['name']),
              _buildInfoRow('Employee', widget.attendance['employee']),
              _buildInfoRow(
                  'Employee Name', widget.attendance['employee_name']),
              _buildInfoRow('Status', widget.attendance['status']),
              _buildInfoRow('Attendance Date',
                  formatDate(widget.attendance['attendance_date'])),
              _buildInfoRow('Company', widget.attendance['company']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkDetails() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Status', widget.attendance['status']),
              _buildInfoRow('Late Entry',
                  widget.attendance['late_entry'] == 1 ? 'Yes' : 'No'),
              _buildInfoRow('Early Exit',
                  widget.attendance['early_exit'] == 1 ? 'Yes' : 'No'),
              _buildInfoRow('Working Hours',
                  widget.attendance['working_hours'].toString()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeInfo() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Employee', widget.attendance['employee']),
              _buildInfoRow(
                  'Employee Name', widget.attendance['employee_name']),
              _buildInfoRow(
                  'Department', widget.attendance['department'] ?? 'N/A'),
              _buildInfoRow('Created By', widget.attendance['owner']),
              _buildInfoRow(
                  'Created On', formatDateTime(widget.attendance['creation'])),
              _buildInfoRow('Modified By', widget.attendance['modified_by']),
              _buildInfoRow(
                  'Modified On', formatDateTime(widget.attendance['modified'])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${value ?? 'N/A'}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date); // e.g., "January 22, 2017"
    } catch (e) {
      return dateStr;
    }
  }

  String formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMMM d, y, HH:mm')
          .format(dateTime); // e.g., "January 22, 2017, 14:30"
    } catch (e) {
      return dateTimeStr;
    }
  }
}
