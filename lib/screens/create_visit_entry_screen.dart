import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';

class CreateVisitEntryScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const CreateVisitEntryScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CreateVisitEntryScreenState createState() => _CreateVisitEntryScreenState();
}

class _CreateVisitEntryScreenState extends State<CreateVisitEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _handlingController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _freightController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _visitedDateTimeController =
      TextEditingController();
  final TextEditingController _followUpPurposeController =
      TextEditingController();
  final TextEditingController _followUpDateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  bool _followUpNeeded = false;
  bool _isQc = false;
  File? _selectedFile;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _customers = [];
  List<dynamic> _purposes = [];

  @override
  void initState() {
    super.initState();
    _visitedDateTimeController.text = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.now());
    _followUpDateController.text = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.now().add(Duration(days: 7)));
    _fetchCustomers();
    _fetchPurposes();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _purposeController.dispose();
    _handlingController.dispose();
    _gstController.dispose();
    _freightController.dispose();
    _paymentController.dispose();
    _visitedDateTimeController.dispose();
    _followUpPurposeController.dispose();
    _followUpDateController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_customers';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            _customers = List.from(data['message']['customers'] ?? []);
          });
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Error fetching customers: $error';
      });
    }
  }

  Future<void> _fetchPurposes() async {
    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_all_purpose_names';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            _purposes = List.from(data['message']['data'] ?? []);
          });
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Error fetching purposes: $error';
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allow any file type
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _errorMessage = null;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Error picking file: $error';
      });
    }
  }

  Future<void> _submitVisitEntry() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = '${widget.serverUrl}/api/resource/Visit Entry';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Accept': 'application/json',
    };

    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll(headers)
      ..fields['naming_series'] = 'DV-.####'
      ..fields['customer_name'] = _customerNameController.text
      ..fields['purpose_of_visit'] = _purposeController.text
      ..fields['visited_date_time'] = _visitedDateTimeController.text
      ..fields['follow_up_needed'] = _followUpNeeded ? 'Yes' : 'No'
      ..fields['is_qc'] = _isQc ? '1' : '0';

    if (_handlingController.text.isNotEmpty) {
      request.fields['handling'] = _handlingController.text;
    }
    if (_gstController.text.isNotEmpty) {
      request.fields['gst'] = _gstController.text;
    }
    if (_freightController.text.isNotEmpty) {
      request.fields['freight'] = _freightController.text;
    }
    if (_paymentController.text.isNotEmpty) {
      request.fields['payment'] = _paymentController.text;
    }
    if (_followUpPurposeController.text.isNotEmpty) {
      request.fields['purpose_of_next_visit'] = _followUpPurposeController.text;
    }
    if (_followUpDateController.text.isNotEmpty) {
      request.fields['follow_up_date'] = _followUpDateController.text;
    }
    if (_remarksController.text.isNotEmpty) {
      request.fields['remarks'] = _remarksController.text;
    }

    if (_selectedFile != null && await _selectedFile!.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_recording',
          _selectedFile!.path,
          filename: _selectedFile!.path.split('/').last,
        ),
      );
    }

    try {
      final response = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        if (data['data']['name'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Visit entry created successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          Navigator.pop(context);
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - $responseBody');
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Error creating visit entry: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(
          DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          ),
        );
        controller.text = formattedDateTime;
      }
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    int maxLines = 1,
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
            validator: validator,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField(
    String label,
    TextEditingController controller,
    List<dynamic> items,
    String displayKey,
    String valueKey,
    String? Function(String?)? validator,
  ) {
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
                    (item) => (item[displayKey] as String)
                        .toLowerCase()
                        .contains(filter.toLowerCase()),
                  )
                  .map((item) => item[displayKey] as String)
                  .toList(),
            ),
            selectedItem: controller.text.isNotEmpty ? controller.text : null,
            onChanged: (value) {
              if (value != null) {
                final selectedItem = items.firstWhere(
                  (item) => item[displayKey] == value,
                  orElse: () => {valueKey: ''},
                );
                controller.text = selectedItem[valueKey] ?? '';
              }
            },
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

  Widget _buildFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachment',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
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
            children: [
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: Icon(Icons.attach_file),
                label: Text('Select File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (_selectedFile != null) ...[
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedFile!.path.split('/').last,
                        style: TextStyle(fontSize: 16, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() {
                        _selectedFile = null;
                      }),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Visit Entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                      'Create Visit Entry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Customer',
                      _customerNameController,
                      _customers,
                      'customer_name',
                      'name',
                      (value) => value == null || value.isEmpty
                          ? 'Please select a customer'
                          : null,
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Purpose of Visit',
                      _purposeController,
                      _purposes,
                      'purpose_name',
                      'purpose_id',
                      (value) => value == null || value.isEmpty
                          ? 'Please select a purpose'
                          : null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Visited Date & Time',
                      _visitedDateTimeController,
                      readOnly: true,
                      onTap: () =>
                          _selectDateTime(context, _visitedDateTimeController),
                      validator: (value) => value!.isEmpty
                          ? 'Visited date & time is required'
                          : null,
                    ),
                    SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Follow Up Needed'),
                      value: _followUpNeeded,
                      onChanged: (value) =>
                          setState(() => _followUpNeeded = value ?? false),
                      activeColor: Theme.of(context).colorScheme.primary,
                      checkColor: Colors.white,
                    ),
                    if (_followUpNeeded) ...[
                      SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Purpose of Next Visit',
                        _followUpPurposeController,
                        _purposes,
                        'purpose_name',
                        'purpose_id',
                        (value) => null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        'Follow Up Date',
                        _followUpDateController,
                        readOnly: true,
                        onTap: () =>
                            _selectDateTime(context, _followUpDateController),
                        validator: (value) => null,
                      ),
                    ],
                    SizedBox(height: 16),
                    _buildTextField(
                      'Handling',
                      _handlingController,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'GST',
                      _gstController,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Freight',
                      _freightController,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Payment',
                      _paymentController,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Quality Complaint'),
                      value: _isQc,
                      onChanged: (value) =>
                          setState(() => _isQc = value ?? false),
                      activeColor: Theme.of(context).colorScheme.primary,
                      checkColor: Colors.white,
                    ),
                    SizedBox(height: 16),
                    _buildTextField('Remarks', _remarksController, maxLines: 4),
                    SizedBox(height: 16),
                    _buildFilePicker(),
                    SizedBox(height: 16),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitVisitEntry,
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
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Submit',
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
}
