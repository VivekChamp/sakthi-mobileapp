import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'leave_details_screen.dart';

class CreateLeaveScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final List<Map<String, dynamic>> employees;
  final VoidCallback onLeaveCreated;

  const CreateLeaveScreen({
    required this.serverUrl,
    required this.sid,
    required this.employees,
    required this.onLeaveCreated,
    super.key,
  });

  @override
  _CreateLeaveScreenState createState() => _CreateLeaveScreenState();
}

class _CreateLeaveScreenState extends State<CreateLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  String? employee;
  String? employeeName;
  String? leaveType;
  String? leaveApprover;
  String? leaveApproverName;
  DateTime fromDate = DateTime.now(); // Set to today (May 28, 2025)
  DateTime toDate = DateTime.now(); // Set to today (May 28, 2025)
  double totalLeavesAllocated = 0.0;
  double totalLeaveDays = 1.0;

  late List<Map<String, dynamic>> employees;
  List<Map<String, dynamic>> leaveAllocations = [];
  List<Map<String, dynamic>> existingLeaves = [];
  List<String> leaveTypes = [];
  List<Map<String, String>> leaveApprovers =
      []; // List of approvers (single item for now)
  String? lastSelectedEmployee;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    employees = widget.employees;
    if (employees.isNotEmpty) {
      employee = employees.first['employee'];
      employeeName = employees.first['employee_name'];
      lastSelectedEmployee = employee;
      fetchLeaveTypes();
      fetchLeaveApprover(); // Fetch single leave approver
      fetchLeaveAllocations();
      fetchExistingLeaves();
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> fetchLeaveTypes() async {
    print('Fetching leave types...');
    try {
      final url =
          "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_leave_type_options";
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      print('Leave Types Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            leaveTypes = List<String>.from(
              data['message']['leave_types'] ?? [],
            );
            if (!leaveTypes.contains('Leave Without Pay')) {
              leaveTypes.add('Leave Without Pay');
            }
            leaveType = leaveTypes.contains('Absent')
                ? 'Absent'
                : leaveTypes.first;
          });
        } else {
          throw Exception('Failed to fetch leave types');
        }
      } else {
        throw Exception('Failed to fetch leave types');
      }
    } catch (e) {
      print('Error fetching leave types: $e');
      await fetchAllLeaveTypes();
    }
  }

  Future<void> fetchAllLeaveTypes() async {
    print('Fetching all leave types...');
    try {
      final url =
          "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_all_leave_types";
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      print(
        'All Leave Types Response: ${response.statusCode} - ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            leaveTypes = List<Map<String, dynamic>>.from(
              data['message']['leave_types'] ?? [],
            ).map((lt) => lt['leave_type_name'] as String).toList();
            if (!leaveTypes.contains('Leave Without Pay')) {
              leaveTypes.add('Leave Without Pay');
            }
            leaveType = leaveTypes.contains('Absent')
                ? 'Absent'
                : leaveTypes.first;
          });
        } else {
          throw Exception('Failed to fetch all leave types');
        }
      } else {
        throw Exception('Failed to fetch all leave types');
      }
    } catch (e) {
      print('Error fetching all leave types: $e');
      setState(() {
        leaveTypes = ['Absent', 'Leave Without Pay'];
        leaveType = 'Absent';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching leave types: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchLeaveApprover() async {
    if (employee == null) return;
    print('Fetching leave approver for employee: $employee');
    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_leave_approver?employee=$employee";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      print(
        'Leave Approver Response: ${response.statusCode} - ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            leaveApprover = data['message']['leave_approver'] ?? ' ';
            leaveApproverName = leaveApprover == ' ' ? 'Rafeek' : leaveApprover;
            leaveApprovers = [
              {'email': leaveApprover!, 'name': leaveApproverName!},
            ];
          });
        } else {
          throw Exception('Failed to fetch leave approver');
        }
      } else {
        throw Exception('Failed to fetch leave approver');
      }
    } catch (e) {
      print('Error fetching leave approver: $e');
      setState(() {
        leaveApprover = ' ';
        leaveApproverName = 'Rafeek';
        leaveApprovers = [
          {'email': ' ', 'name': 'Rafeek'},
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching leave approver: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchLeaveAllocations() async {
    if (employee == null) return;
    print('Fetching leave allocations for employee: $employee');
    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_employee_leave_allocations";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = json.encode({'employee': employee});

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      print(
        'Leave Allocations Response: ${response.statusCode} - ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            leaveAllocations = List<Map<String, dynamic>>.from(
              data['message']['data'] ?? [],
            );
            if (leaveType != null && leaveType != 'Absent') {
              final allocation = leaveAllocations.firstWhere(
                (alloc) => alloc['leave_type'] == leaveType,
                orElse: () => {'total_leaves_allocated': 0.0},
              );
              totalLeavesAllocated =
                  allocation['total_leaves_allocated']?.toDouble() ?? 0.0;
            }
          });
        } else {
          throw Exception('Failed to fetch leave allocations');
        }
      } else {
        throw Exception('Failed to fetch leave allocations');
      }
    } catch (e) {
      print('Error fetching leave allocations: $e');
      setState(() {
        leaveAllocations = [];
        totalLeavesAllocated = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching leave allocations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchExistingLeaves() async {
    if (employee == null) return;
    print('Fetching existing leaves for employee: $employee');
    final url =
        "${widget.serverUrl}/api/resource/Leave Application?filters=[[\"employee\",\"=\",\"$employee\"]]&fields=[\"name\",\"from_date\",\"to_date\",\"leave_type\"]";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      print(
        'Existing Leaves Response: ${response.statusCode} - ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          existingLeaves = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else {
        throw Exception('Failed to fetch existing leaves');
      }
    } catch (e) {
      print('Error fetching existing leaves: $e');
      setState(() {
        existingLeaves = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching existing leaves: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool hasDateOverlap(DateTime from, DateTime to) {
    for (var leave in existingLeaves) {
      final leaveFrom = DateTime.parse(leave['from_date']);
      final leaveTo = DateTime.parse(leave['to_date']);
      if (!(to.isBefore(leaveFrom) || from.isAfter(leaveTo))) {
        return true;
      }
    }
    return false;
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
          if (toDate.isBefore(fromDate)) {
            toDate = fromDate;
          }
        } else {
          toDate = picked;
          if (fromDate.isAfter(toDate)) {
            fromDate = toDate;
          }
        }
        totalLeaveDays = toDate.difference(fromDate).inDays + 1.0;
      });
      if (hasDateOverlap(fromDate, toDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected dates overlap with an existing leave.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitLeaveApplication({String status = 'Open'}) async {
    if (!_formKey.currentState!.validate()) return;

    if (hasDateOverlap(fromDate, toDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected dates overlap with an existing leave.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (leaveType != 'Absent' &&
        totalLeaveDays > totalLeavesAllocated &&
        totalLeavesAllocated > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient leave allocation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = '${widget.serverUrl}/api/resource/Leave Application';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = json.encode({
      'employee': employee,
      'employee_name': employeeName,
      'leave_type': leaveType,
      'leave_approver': leaveApprover ?? '',
      'from_date': fromDate.toIso8601String().split('T')[0],
      'to_date': toDate.toIso8601String().split('T')[0],
      'total_leave_days': totalLeaveDays,
      'description': _reasonController.text.isNotEmpty
          ? _reasonController.text
          : null,
      'posting_date': DateTime.now().toIso8601String().split('T')[0],
      'company': 'SAKTHI STEEL INDUSTRIES LTD',
      'status': status,
      'letter_head': 'SAKTHI STEEL INDUSTRIES LTD',
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      print('Create Leave Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final leaveId = responseData['data']['name'];
        final leaveData = {
          'name': leaveId,
          'employee': employee,
          'employee_name': employeeName,
          'leave_type': leaveType,
          'leave_approver': leaveApprover ?? '',
          'from_date': fromDate.toIso8601String().split('T')[0],
          'to_date': toDate.toIso8601String().split('T')[0],
          'total_leave_days': totalLeaveDays,
          'description': _reasonController.text.isNotEmpty
              ? _reasonController.text
              : null,
          'posting_date': DateTime.now().toIso8601String().split('T')[0],
          'company': 'SAKTHI STEEL INDUSTRIES LTD',
          'status': status,
          'letter_head': 'SAKTHI STEEL INDUSTRIES LTD',
        };
        Navigator.pop(context);
        if (leaveType == 'Sick Leave') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeaveDetailsScreen(
                serverUrl: widget.serverUrl,
                sid: widget.sid,
                leave: leaveData,
                onLeaveUpdated: widget.onLeaveCreated,
              ),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sick leave created (ID: $leaveId). Upload medical certificate.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          widget.onLeaveCreated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Leave application created successfully (ID: $leaveId)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to create leave: ${response.statusCode}';
        if (errorData['exception'] != null &&
            errorData['exception'].contains('OverlapError')) {
          errorMessage =
              'Leave overlaps with an existing application: ${errorData['exception'].split(': ')[1]}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error creating leave: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating leave application: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Create Leave Application',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
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
          child: const Center(
            child: Text(
              'No employees available. Please go back and try again.',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Leave Application',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchableDropdownField(
                    label: 'Employee *',
                    value: employee != null
                        ? '${employees.firstWhere((e) => e['employee'] == employee)['employee_name']} (${employee})'
                        : null,
                    items: employees
                        .map((e) => '${e['employee_name']} (${e['employee']})')
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final selected = employees.firstWhere(
                          (e) =>
                              '${e['employee_name']} (${e['employee']})' ==
                              value,
                        );
                        setState(() {
                          employee = selected['employee'];
                          employeeName = selected['employee_name'];
                          leaveType = null;
                          leaveApprover = null;
                          leaveApproverName = null;
                          totalLeavesAllocated = 0.0;
                          leaveAllocations.clear();
                          leaveTypes.clear();
                          leaveApprovers.clear();
                          existingLeaves.clear();
                          if (employee != lastSelectedEmployee) {
                            lastSelectedEmployee = employee;
                            fetchLeaveTypes();
                            fetchLeaveApprover();
                            fetchLeaveAllocations();
                            fetchExistingLeaves();
                          }
                        });
                      }
                    },
                    validator: (value) =>
                        value == null ? 'Please select an employee' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildTextField(
                    label: 'Employee Name',
                    controller: TextEditingController(text: employeeName ?? ''),
                    icon: Icons.person,
                    readOnly: true,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildSearchableDropdownField(
                    label: 'Leave Type *',
                    value: leaveType,
                    items: leaveTypes,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          leaveType = value;
                          if (leaveType != 'Absent') {
                            final allocation = leaveAllocations.firstWhere(
                              (alloc) => alloc['leave_type'] == value,
                              orElse: () => {'total_leaves_allocated': 0.0},
                            );
                            totalLeavesAllocated =
                                allocation['total_leaves_allocated']
                                    ?.toDouble() ??
                                0.0;
                          } else {
                            totalLeavesAllocated = 0.0;
                          }
                        });
                      }
                    },
                    validator: (value) =>
                        value == null ? 'Please select a leave type' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildSearchableDropdownField(
                    label: 'Leave Approver *',
                    value: leaveApprover != null
                        ? '$leaveApproverName ($leaveApprover)'
                        : null,
                    items: leaveApprovers
                        .map(
                          (approver) =>
                              '${approver['name']} (${approver['email']})',
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final selected = leaveApprovers.firstWhere(
                          (approver) =>
                              '${approver['name']} (${approver['email']})' ==
                              value,
                        );
                        setState(() {
                          leaveApprover = selected['email'];
                          leaveApproverName = selected['name'];
                        });
                      }
                    },
                    validator: (value) =>
                        value == null ? 'Please select a leave approver' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildTextField(
                    label: 'From Date *',
                    controller: TextEditingController(
                      text: DateFormat('yyyy-MM-dd').format(fromDate),
                    ),
                    icon: Icons.calendar_today,
                    readOnly: true,
                    onTap: () => _selectDate(context, true),
                    validator: (value) =>
                        fromDate == null ? 'From Date is required' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildTextField(
                    label: 'To Date *',
                    controller: TextEditingController(
                      text: DateFormat('yyyy-MM-dd').format(toDate),
                    ),
                    icon: Icons.calendar_today,
                    readOnly: true,
                    onTap: () => _selectDate(context, false),
                    validator: (value) =>
                        toDate == null ? 'To Date is required' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildReasonField(
                    context: context,
                    label: 'Reason *',
                    controller: _reasonController,
                    maxLines: 4,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Reason is required'
                        : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Text(
                    'Total Leave Days: ${totalLeaveDays.toStringAsFixed(1)} days',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  ElevatedButton(
                    onPressed: () => _submitLeaveApplication(status: 'Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      minimumSize: Size(
                        double.infinity,
                        MediaQuery.of(context).size.height * 0.07,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit Leave Application',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    IconData? icon,
    int? maxLines,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: icon != null
                  ? Icon(icon, color: Theme.of(context).colorScheme.primary)
                  : null,
              hintText: 'Enter $label',
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildReasonField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    int? maxLines,
    ValueChanged<String>? onChanged,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            onChanged: onChanged,
            textAlign: TextAlign.left,
            textDirection: Directionality.of(context),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.note,
                color: Theme.of(context).colorScheme.primary,
              ),
              hintText: 'Enter $label',
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: DropdownSearch<String>(
            items: (String filter, LoadProps? loadProps) => Future.value(
              items
                  .where(
                    (item) => item.toLowerCase().contains(filter.toLowerCase()),
                  )
                  .toList(),
            ),
            selectedItem: value,
            onChanged: onChanged,
            validator: validator,
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  labelText: 'Search $label',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            dropdownBuilder: (context, selectedItem) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedItem ?? 'Select $label',
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
