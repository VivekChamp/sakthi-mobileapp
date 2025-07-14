import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dropdown_search/dropdown_search.dart';

class CreateAttendanceScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const CreateAttendanceScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CreateAttendanceScreenState createState() => _CreateAttendanceScreenState();
}

class _CreateAttendanceScreenState extends State<CreateAttendanceScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _series;
  String? _employee;
  String? _status;
  final TextEditingController _attendanceDateController =
      TextEditingController();
  String? _company = 'SAKTHI STEEL INDUSTRIES LTD';
  bool _lateEntry = false;
  bool _earlyExit = false;
  String latitude = ''; // Store latitude
  String longitude = ''; // Store longitude

  List<String> namingSeriesOptions = [];
  List<String> employeeOptions = []; // Store employee names
  List<String> statusOptions = [];
  List<Map<String, dynamic>> employeeData = []; // Store full employee data

  bool isLoading = false;

  final http.Client _httpClient = http.Client();

  // Obfuscated API key (base64 encoded version of AIzaSyCdFNwtk2D39JYUd4xgDunueRPGqaa83Jc)
  final String _obfuscatedApiKey = '';
  String get _apiKey => utf8.decode(base64Decode(_obfuscatedApiKey));

  @override
  void initState() {
    super.initState();
    _attendanceDateController.text = DateFormat(
      'dd-MM-yyyy',
    ).format(DateTime.now());
    fetchNamingSeries();
    fetchEmployees();
    fetchStatusOptions();
    _getCurrentLocation(); // Fetch location on init
  }

  // Fetch naming series options
  Future<void> fetchNamingSeries() async {
    try {
      final response = await _httpClient.get(
        Uri.parse(
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_attendance_naming_series',
        ),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(
          response.body,
        )['message']['naming_series_options'];
        setState(() {
          namingSeriesOptions = List<String>.from(data);
          _series = namingSeriesOptions.isNotEmpty
              ? namingSeriesOptions[0]
              : null;
        });
      } else {
        throw Exception(
          'Failed to fetch naming series: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching naming series: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch employee options
  Future<void> fetchEmployees() async {
    try {
      final response = await _httpClient.get(
        Uri.parse(
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_employee',
        ),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message']['employees'];
        setState(() {
          employeeData = List<Map<String, dynamic>>.from(data);
          employeeOptions = employeeData
              .map((item) => '${item['employee_name']} (${item['employee']})')
              .toList();
          _employee = employeeData.isNotEmpty
              ? employeeData[0]['employee']
              : null;
        });
      } else {
        throw Exception(
          'Failed to fetch employees: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching employees: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch status options with retry logic, type safety, and enhanced debugging
  Future<void> fetchStatusOptions() async {
    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final response = await _httpClient.get(
          Uri.parse(
            '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_attendance_status_options',
          ),
          headers: {
            'Cookie': 'sid=${widget.sid}',
            'Content-Type': 'application/json',
            'Connection': 'close', // Disable Expect: 100-continue
          },
        );
        if (response.statusCode == 200) {
          final decodedResponse = json.decode(response.body);
          print(
            'Raw API response for status: $decodedResponse',
          ); // Debug the raw response
          final data = decodedResponse['message']['status_options'];
          if (data is List) {
            setState(() {
              statusOptions = (data as List<dynamic>)
                  .whereType<String>()
                  .where((item) => item.trim().isNotEmpty)
                  .toList();
              _status = statusOptions.isNotEmpty ? statusOptions[0] : null;
              print('Fetched status options: $statusOptions'); // Debug log
            });
            if (statusOptions.isEmpty) {
              print(
                'Warning: statusOptions is empty despite successful API call',
              );
            }
          } else {
            throw Exception(
              'Invalid data format: status_options is not a list, got ${data.runtimeType}',
            );
          }
          return; // Exit the loop on success
        } else {
          throw Exception(
            'Failed to fetch status options: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        retryCount++;
        print('Attempt $retryCount failed for status options: $e');
        if (retryCount == maxRetries) {
          print('All retries failed for status options: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'All retries failed: Error fetching status options: $e',
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          await Future.delayed(Duration(seconds: 1)); // Wait before retry
        }
      }
    }
  }

  // Fetch the current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied, we cannot request them.',
          ),
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
      });
    } catch (e) {
      print('Error fetching location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  // Generate map link with the requested format
  String _generateMapLink(String lat, String lon) {
    // Using the search format as requested, no API key needed for this format
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }

  Future<void> _createAttendance() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final url = "${widget.serverUrl}/api/resource/Attendance";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'close', // Disable Expect: 100-continue
    };

    // Parse the date from dd-MM-yyyy to yyyy-MM-dd for ERPNext
    final dateFormat = DateFormat('dd-MM-yyyy');
    final parsedDate = dateFormat.parse(_attendanceDateController.text);
    final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

    // Generate map link
    final customMapLink = _generateMapLink(latitude, longitude);

    final body = jsonEncode({
      "naming_series": _series,
      "employee": _employee,
      "status": _status,
      "attendance_date": formattedDate,
      "company": _company,
      "late_entry": _lateEntry ? 1 : 0,
      "early_exit": _earlyExit ? 1 : 0,
      "custom_latitude": latitude,
      "custom_longtitude": longitude,
      "custom_map_link": customMapLink, // Save the new link format
    });

    try {
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['data'] != null &&
            responseData['data']['name'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Attendance ${responseData['data']['name']} created successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
          'Failed to create attendance: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _attendanceDateController.text = DateFormat(
          'dd-MM-yyyy',
        ).format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
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
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchableDropdownField(
                    label: 'Series',
                    value: _series,
                    items: namingSeriesOptions,
                    onChanged: (value) => setState(() => _series = value),
                    validator: (value) =>
                        value == null ? 'Please select a series' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildTextField(
                    label: 'Attendance Date',
                    controller: _attendanceDateController,
                    icon: Icons.calendar_today,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    validator: (value) =>
                        value!.isEmpty ? 'Please select a date' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildSearchableDropdownField(
                    label: 'Employee',
                    value: employeeOptions.isNotEmpty && _employee != null
                        ? employeeOptions[employeeData.indexWhere(
                            (data) => data['employee'] == _employee,
                          )]
                        : null,
                    items: employeeOptions,
                    onChanged: (value) {
                      if (value != null) {
                        final index = employeeOptions.indexOf(value);
                        setState(
                          () => _employee = employeeData[index]['employee'],
                        );
                      }
                    },
                    validator: (value) =>
                        value == null ? 'Please select an employee' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildSearchableDropdownField(
                    label: 'Status',
                    value: _status,
                    items: statusOptions,
                    onChanged: (value) => setState(() => _status = value),
                    validator: (value) =>
                        value == null ? 'Please select a status' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildTextField(
                    label: 'Company',
                    value: _company,
                    icon: Icons.business,
                    readOnly: true,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      Checkbox(
                        value: _lateEntry,
                        onChanged: (value) {
                          setState(() => _lateEntry = value ?? false);
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      Text(
                        'Late Entry',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _earlyExit,
                        onChanged: (value) {
                          setState(() => _earlyExit = value ?? false);
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      Text(
                        'Early Exit',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Text(
                    'Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Latitude: ${latitude.isNotEmpty ? latitude : 'Not available'}',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'Longitude: ${longitude.isNotEmpty ? longitude : 'Not available'}',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  ElevatedButton(
                    onPressed: isLoading ? null : _createAttendance,
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
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                    ),
                    child: isLoading
                        ? CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : Text(
                            'Create Attendance',
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
    String? value,
    TextEditingController? controller,
    IconData? icon = Icons.text_fields,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
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
            initialValue: value,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            decoration: InputDecoration(
              prefixIcon: icon != null
                  ? Icon(icon, color: Theme.of(context).colorScheme.primary)
                  : null,
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            style: TextStyle(fontSize: 16),
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
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
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
                      Icons.search,
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

  @override
  void dispose() {
    _httpClient.close(); // Close the HTTP client
    _attendanceDateController.dispose(); // Dispose the controller
    super.dispose(); // Call the superclass dispose
  }
}
