import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class EmployeeListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const EmployeeListScreen({required this.serverUrl, required this.sid});

  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<dynamic> employees = [];
  List<dynamic> filteredEmployees = [];
  List<String> userRoles = [];
  bool isLoading = true;
  bool isLoadingRoles = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserRoles();
    fetchEmployees();
    searchController.addListener(() {
      filterEmployees();
    });
  }

  Future<void> fetchUserRoles() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_user_roles';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userRoles = List<String>.from(data['message']['roles'] ?? []);
          isLoadingRoles = false;
        });
      } else {
        throw Exception(
          'Failed to load user roles: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching user roles: $e');
      setState(() => isLoadingRoles = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching user roles: $e'),
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
        setState(() {
          employees = data['message']['employees'] ?? [];
          filteredEmployees = List.from(employees);
          isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to load employees: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching employees: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching employees: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void filterEmployees() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredEmployees = employees.where((employee) {
        final employeeId = employee['employee'].toString().toLowerCase();
        final employeeName = employee['employee_name'].toString().toLowerCase();
        return employeeId.contains(query) || employeeName.contains(query);
      }).toList();
    });
  }

  bool canAddEmployee() {
    return userRoles.contains('HR User') || userRoles.contains('HR Manager');
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
        title: Text(
          'Employees',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: isLoadingRoles
            ? null
            : canAddEmployee()
            ? [
                IconButton(
                  icon: Icon(Icons.add, color: Colors.white),
                  tooltip: 'New Employee',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmployeeScreen(
                        serverUrl: widget.serverUrl,
                        sid: widget.sid,
                      ),
                    ),
                  ).then((_) => fetchEmployees()),
                ),
              ]
            : null,
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
            ? Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search by Employee ID or Name',
                        labelStyle: TextStyle(color: Colors.white),
                        prefixIcon: Icon(Icons.search, color: Colors.white),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.white),
                                onPressed: () {
                                  setState(() => searchController.clear());
                                  filterEmployees();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: filteredEmployees.isEmpty
                        ? Center(
                            child: Text(
                              'No employees found',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: filteredEmployees.length,
                            itemBuilder: (context, index) {
                              final employee = filteredEmployees[index];
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Text(
                                      (employee['employee_name'] ?? 'N')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    employee['employee'] ?? 'N/A',
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
                                        employee['employee_name'] ?? 'No name',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                      Text(
                                        employee['designation'] ?? 'N/A',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EmployeeDetailsScreen(
                                            employeeData: employee,
                                          ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: isLoadingRoles
          ? null
          : canAddEmployee()
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeScreen(
                    serverUrl: widget.serverUrl,
                    sid: widget.sid,
                  ),
                ),
              ).then((_) => fetchEmployees()),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Icon(Icons.add, color: Colors.white),
              elevation: 6,
            )
          : null,
    );
  }
}

class EmployeeDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeDetailsScreen({required this.employeeData});

  Widget _buildDetailRow(BuildContext context, String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee: ${employeeData['employee']}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 16),
                _buildDetailRow(
                  context,
                  'Employee ID',
                  employeeData['employee'],
                ),
                _buildDetailRow(
                  context,
                  'Full Name',
                  employeeData['employee_name'],
                ),
                _buildDetailRow(
                  context,
                  'First Name',
                  employeeData['first_name'],
                ),
                _buildDetailRow(
                  context,
                  'Middle Name',
                  employeeData['middle_name'],
                ),
                _buildDetailRow(
                  context,
                  'Last Name',
                  employeeData['last_name'],
                ),
                _buildDetailRow(context, 'Gender', employeeData['gender']),
                _buildDetailRow(
                  context,
                  'Date of Birth',
                  employeeData['date_of_birth'],
                ),
                _buildDetailRow(
                  context,
                  'Date of Joining',
                  employeeData['date_of_joining'],
                ),
                _buildDetailRow(context, 'Status', employeeData['status']),
                _buildDetailRow(
                  context,
                  'Designation',
                  employeeData['designation'],
                ),
                _buildDetailRow(
                  context,
                  'Department',
                  employeeData['department'],
                ),
                _buildDetailRow(context, 'Company', employeeData['company']),
                _buildDetailRow(
                  context,
                  'Cell Number',
                  employeeData['cell_number'],
                ),
                _buildDetailRow(
                  context,
                  'Company Email',
                  employeeData['company_email'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmployeeScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const EmployeeScreen({required this.serverUrl, required this.sid});

  @override
  _EmployeeScreenState createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _companyController = TextEditingController();
  final _cellNumberController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _dateOfJoiningController = TextEditingController();
  String? _gender;
  String? _status;
  bool _isSaving = false;

  List<String> _genderOptions = ['Male', 'Female', 'Other'];
  List<String> _statusOptions = [];
  List<String> _designations = [];
  List<String> _departments = [];
  List<String> _companies = [];

  @override
  void initState() {
    super.initState();
    _dateOfBirthController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    _dateOfJoiningController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    _gender = _genderOptions.first;
    _fetchDesignations();
    _fetchStatusOptions();
    _fetchDepartments();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _companyController.dispose();
    _cellNumberController.dispose();
    _companyEmailController.dispose();
    _dateOfBirthController.dispose();
    _dateOfJoiningController.dispose();
    super.dispose();
  }

  Future<void> _fetchDesignations() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.serverUrl} /api/method/vps_mobile.vps_mobile.role_api.get_employee_designation_options',
        ),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body)['message']['designation_options']
                as List<dynamic>;
        setState(() {
          _designations = data
              .whereType<String>()
              .where((item) => item.trim().isNotEmpty)
              .toList();
          _designationController.text = _designations.isNotEmpty
              ? _designations.first
              : '';
        });
      } else {
        throw Exception(
          'Failed to fetch designations: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching designations: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _fetchStatusOptions() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.serverUrl} /api/method/vps_mobile.vps_mobile.role_api.get_employee_status_options',
        ),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body)['message']['status_options']
                as List<dynamic>;
        setState(() {
          _statusOptions = data
              .whereType<String>()
              .where((item) => item.trim().isNotEmpty)
              .toList();
          _status = _statusOptions.isNotEmpty ? _statusOptions.first : null;
        });
      } else {
        throw Exception(
          'Failed to fetch status options: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching status options: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.serverUrl}/api/resource/Department?fields=["name"]&limit_page_length=0',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cookie': 'sid=${widget.sid}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List<dynamic>;
        setState(() {
          _departments = data.map((dept) => dept['name'] as String).toList();
          _departmentController.text = _departments.isNotEmpty
              ? _departments.first
              : '';
        });
      } else {
        throw Exception('Failed to fetch departments');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching departments: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.serverUrl}/api/resource/Company?fields=["name"]&limit_page_length=0',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cookie': 'sid=${widget.sid}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List<dynamic>;
        setState(() {
          _companies = data
              .map((company) => company['name'] as String)
              .toList();
          _companyController.text = _companies.isNotEmpty
              ? _companies.first
              : '';
        });
      } else {
        throw Exception('Failed to fetch companies');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching companies: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final employee = Employee(
      firstName: _firstNameController.text,
      middleName: _middleNameController.text,
      lastName: _lastNameController.text,
      gender: _gender,
      dateOfBirth: _dateOfBirthController.text,
      dateOfJoining: _dateOfJoiningController.text,
      status: _status,
      designation: _designationController.text,
      department: _departmentController.text,
      company: _companyController.text,
      cellNumber: _cellNumberController.text,
      companyEmail: _companyEmailController.text,
    );

    try {
      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/resource/Employee'),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'data': employee.toJson()}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Employee saved successfully',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception(
          'Failed to save employee: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error saving employee: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save employee: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
    );
    if (picked != null)
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add New Employee',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            child: Form(
              key: _formKey,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Employee',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'First Name',
                      _firstNameController,
                      Icons.person,
                      validator: (value) =>
                          value!.isEmpty ? 'First name is required' : null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Middle Name',
                      _middleNameController,
                      Icons.person,
                      validator: null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Last Name',
                      _lastNameController,
                      Icons.person,
                      validator: null,
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Gender',
                      _gender,
                      _genderOptions,
                      (value) => setState(() => _gender = value),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Date of Birth',
                      _dateOfBirthController,
                      Icons.calendar_today,
                      readOnly: true,
                      onTap: () => _selectDate(context, _dateOfBirthController),
                      validator: (value) =>
                          value!.isEmpty ? 'Date of birth is required' : null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Date of Joining',
                      _dateOfJoiningController,
                      Icons.calendar_today,
                      readOnly: true,
                      onTap: () =>
                          _selectDate(context, _dateOfJoiningController),
                      validator: (value) =>
                          value!.isEmpty ? 'Date of joining is required' : null,
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Status',
                      _status,
                      _statusOptions,
                      (value) => setState(() => _status = value),
                      validator: (value) =>
                          value == null ? 'Status is required' : null,
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Designation',
                      _designationController.text,
                      _designations,
                      (value) => setState(
                        () => _designationController.text = value ?? '',
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Designation is required' : null,
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Department',
                      _departmentController.text,
                      _departments,
                      (value) => setState(
                        () => _departmentController.text = value ?? '',
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Company',
                      _companyController.text,
                      _companies,
                      (value) =>
                          setState(() => _companyController.text = value ?? ''),
                      validator: (value) =>
                          value!.isEmpty ? 'Company is required' : null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Cell Number',
                      _cellNumberController,
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Company Email',
                      _companyEmailController,
                      Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(value)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveEmployee,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          MediaQuery.of(context).size.height * 0.07,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                      ),
                      child: _isSaving
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Save Employee',
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
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            style: TextStyle(fontSize: 16, color: Colors.black),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: Offset(0, 3),
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
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            dropdownBuilder: (context, selectedItem) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedItem ?? 'Select $label',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class Employee {
  final String firstName;
  final String? middleName;
  final String? lastName;
  final String? gender;
  final String dateOfBirth;
  final String dateOfJoining;
  final String? status;
  final String designation;
  final String? department;
  final String company;
  final String? cellNumber;
  final String? companyEmail;

  Employee({
    required this.firstName,
    this.middleName,
    this.lastName,
    this.gender,
    required this.dateOfBirth,
    required this.dateOfJoining,
    this.status,
    required this.designation,
    this.department,
    required this.company,
    this.cellNumber,
    this.companyEmail,
  });

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'employee_name': [
        firstName,
        middleName,
        lastName,
      ].where((e) => e != null && e.isNotEmpty).join(' '),
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'date_of_joining': dateOfJoining,
      'status': status,
      'designation': designation,
      'department': department,
      'company': company,
      'cell_number': cellNumber,
      'company_email': companyEmail,
    };
  }
}
