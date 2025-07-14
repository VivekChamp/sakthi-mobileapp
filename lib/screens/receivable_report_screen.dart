import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:convert'; // For JSON decoding
import 'package:dropdown_search/dropdown_search.dart'; // Add this dependency

class ReceivableReportScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const ReceivableReportScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  State<ReceivableReportScreen> createState() => _ReceivableReportScreenState();
}

class _ReceivableReportScreenState extends State<ReceivableReportScreen> {
  final TextEditingController _dateController = TextEditingController();
  bool _isLoadingPdf = false;
  bool _isLoadingCustomers = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _selectedCustomer; // To store the selected customer

  @override
  void initState() {
    super.initState();
    _fetchCustomers(); // Fetch customers when the screen initializes
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
      _errorMessage = null;
    });

    final String apiUrl =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_customers';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic> &&
            responseData['message'] is Map<String, dynamic> &&
            responseData['message']['status'] == 'success' &&
            responseData['message']['customers'] is List) {
          setState(() {
            _customers = List<Map<String, dynamic>>.from(
              responseData['message']['customers'],
            );
          });
        } else {
          setState(() {
            _errorMessage =
                responseData['message']?['message'] ??
                'Invalid response format from server. Expected a list of customers.';
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Failed to fetch customers. Status: ${response.statusCode}, Body: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred while fetching customers: ${e.toString()}. Check network.';
      });
    } finally {
      setState(() {
        _isLoadingCustomers = false;
      });
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
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isLoadingPdf = true;
      _errorMessage = null;
    });

    final String? customerId = _selectedCustomer?['name'];
    final String date = _dateController.text.trim();

    if (customerId == null && date.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a customer or date to generate the PDF.';
      });
      setState(() {
        _isLoadingPdf = false;
      });
      return;
    }

    String apiUrl =
        '${widget.serverUrl}/api/method/sakthi_tmt.api.receivable_report.generate_receivable_pdf';

    final Map<String, String> queryParams = {};
    if (customerId != null && customerId.isNotEmpty) {
      queryParams['customer'] = customerId;
    }
    if (date.isNotEmpty) {
      queryParams['date'] = date;
    }

    final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String? pdfUrl = responseData['message']?['pdf_url'];

        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          final fullPdfUrl = pdfUrl.startsWith('http')
              ? pdfUrl
              : '${widget.serverUrl}$pdfUrl';

          if (await canLaunchUrl(Uri.parse(fullPdfUrl))) {
            await launchUrl(Uri.parse(fullPdfUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF generated and opened successfully!'),
              ),
            );
          } else {
            setState(() {
              _errorMessage =
                  'Could not launch PDF. Please check the URL: $fullPdfUrl';
            });
          }
        } else {
          setState(() {
            _errorMessage =
                'PDF URL not found in the response from the server.';
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Failed to generate PDF. Status: ${response.statusCode}, Body: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred: ${e.toString()}. Please check your network connection or server URL.';
      });
    } finally {
      setState(() {
        _isLoadingPdf = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Receivable Report',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Searchable Dropdown
            _isLoadingCustomers
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _customers.isEmpty
                ? Text(
                    'Error loading customers: $_errorMessage',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Customer (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownSearch<Map<String, dynamic>>(
                          items: (String filter, LoadProps? loadProps) =>
                              Future.value(
                                _customers
                                    .where(
                                      (customer) =>
                                          (customer['customer_name'] ?? '')
                                              .toLowerCase()
                                              .contains(filter.toLowerCase()) ||
                                          (customer['name'] ?? '')
                                              .toLowerCase()
                                              .contains(filter.toLowerCase()),
                                    )
                                    .toList(),
                              ),
                          selectedItem: _selectedCustomer,
                          onChanged: (Map<String, dynamic>? newValue) {
                            setState(() {
                              _selectedCustomer = newValue;
                            });
                          },
                          compareFn: (item1, item2) =>
                              (item1?['customer_name'] ?? item1?['name'] ?? '')
                                  .compareTo(
                                    item2?['customer_name'] ??
                                        item2?['name'] ??
                                        '',
                                  ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration: InputDecoration(
                                labelText: 'Search Customer',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          dropdownBuilder: (context, selectedItem) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              selectedItem?['customer_name'] ??
                                  selectedItem?['name'] ??
                                  'Select Customer',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          itemAsString: (Map<String, dynamic>? item) =>
                              item?['customer_name'] ?? item?['name'] ?? '',
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 16),
            // Date Picker Field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posting Date (<=) (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    decoration: InputDecoration(
                      hintText: 'Select a date',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Generate PDF Button
            ElevatedButton.icon(
              onPressed: _isLoadingPdf ? null : _generatePdf,
              icon: _isLoadingPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(
                _isLoadingPdf ? 'Generating PDF...' : 'Generate PDF',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
            ),
            // Error Message Display
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
