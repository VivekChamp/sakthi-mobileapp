import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class CreateSalesOrderScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const CreateSalesOrderScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CreateSalesOrderScreenState createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends State<CreateSalesOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _companySelected = false; // Track if company is explicitly selected

  // Fields to show in UI
  String? _series = 'SAL-ORD-.YYYY.-';
  final TextEditingController _transactionDateController =
      TextEditingController();
  String? _customer;
  String? _company;
  final String _orderType = 'Sales'; // Default order type
  final TextEditingController _poNoController = TextEditingController();
  final TextEditingController _poDateController = TextEditingController();
  final List<Map<String, dynamic>> _items = [
    {
      'itemCode': null,
      'itemName': null,
      'deliveryDate': TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ),
      'qty': TextEditingController(text: '1.000'),
      'uom': null,
      'rate': 0.0,
      'rateController': TextEditingController(),
      'amount': 0.0,
    },
  ];

  // Sales Taxes and Charges
  String? _taxTemplate;
  List<Map<String, dynamic>> _taxTemplates = [];
  List<Map<String, dynamic>> _selectedTaxes = [];

  // Terms and Conditions
  String? _termsCondition;
  List<Map<String, dynamic>> _termsConditions = [];

  // Payment Terms Template
  String? _paymentTermsTemplate;
  List<String> _paymentTermsTemplates = [
    "Advance",
    "20 days",
    "30 days",
    "IMMEDIATE",
    "15 days",
    "7 days",
    "3 days",
    "5 days",
    "50% adv 50% 7 days",
    "80% advance 20% Immediate",
    "90% Advance 10% Immediate",
  ];

  bool isLoading = false;

  List<Map<String, dynamic>> customerList = [];
  List<Map<String, dynamic>> itemList = [];
  List<Map<String, dynamic>> companyList = [];

  @override
  void initState() {
    super.initState();
    _transactionDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    fetchNamingSeries();
    fetchCustomers();
    fetchItems();
    fetchCompanyList();
    fetchTermsConditions();
    // Set default company to "Sakthi Steel Industries Ltd" if it exists
    if (companyList.isNotEmpty) {
      _company = companyList.firstWhere(
        (company) => company['name'] == 'Sakthi Steel Industries Ltd',
        orElse: () => companyList[0],
      )['name'];
    }
  }

  @override
  void dispose() {
    _transactionDateController.dispose();
    _poNoController.dispose();
    _poDateController.dispose();
    for (var item in _items) {
      item['deliveryDate'].dispose();
      item['qty'].dispose();
      item['rateController'].dispose();
    }
    super.dispose();
  }

  // API Methods
  Future<void> fetchNamingSeries() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_order_naming_series';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] != 'success' &&
            data['message']?['naming_series_options'] == null) {
          throw Exception('API returned unsuccessful status');
        }
        setState(() {
          final series = List<String>.from(
            data['message']['naming_series_options'] ?? [],
          );
          series.removeWhere((item) => item.isEmpty);
          series.sort((a, b) => a == 'SAL-ORD-.YYYY.-' ? -1 : 1);
          _series = series.isNotEmpty ? 'SAL-ORD-.YYYY.-' : null;
        });
      } else {
        throw Exception(
          'Failed to fetch naming series: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching naming series: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching naming series: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchCustomers() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_customers';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] != 'success') {
          throw Exception('API returned unsuccessful status');
        }
        setState(() {
          customerList = List<Map<String, dynamic>>.from(
            data['message']['customers'] ?? [],
          );
          _customer = customerList.isNotEmpty ? customerList[0]['name'] : null;
        });
      } else {
        throw Exception('Failed to fetch customers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching customers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchItems() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_item_details';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] != 'success') {
          throw Exception('API returned unsuccessful status');
        }
        setState(() {
          itemList = List<Map<String, dynamic>>.from(
            data['message']['items'] ?? [],
          );
        });
      } else {
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching items: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching items: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchCompanyList() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_company_list';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] != 'success') {
          throw Exception('API returned unsuccessful status');
        }
        setState(() {
          companyList = List<Map<String, dynamic>>.from(
            data['message']['data'] ?? [],
          );
          if (companyList.isNotEmpty) {
            _company = companyList.firstWhere(
              (company) => company['name'] == 'Sakthi Steel Industries Ltd',
              orElse: () => companyList[0],
            )['name'];
          }
        });
      } else {
        throw Exception('Failed to fetch company list: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching company list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching company list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchTaxTemplates() async {
    try {
      if (_company == null) return;
      final companyAbbr = companyList.firstWhere(
        (company) => company['name'] == _company,
        orElse: () => {'abbr': 'SSIL'},
      )['abbr'];
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_all_sales_taxes_templates?company_abbr=$companyAbbr&filters=Docstatus!=2';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final rawResponse = response.body;
        print('Raw Tax Templates Response: $rawResponse');
        final data = json.decode(rawResponse);
        print('Parsed Tax Templates Data: $data');
        if (data['message'] == null) {
          throw Exception('No message field in response');
        }
        final messageData = data['message'];
        if (messageData is! List) {
          throw Exception(
            'Expected "message" to be a list, got ${messageData.runtimeType}',
          );
        }
        final filteredTemplates = messageData
            .where(
              (template) =>
                  template['template_name'].toString().contains(companyAbbr),
            )
            .toList();
        setState(() {
          _taxTemplates = List<Map<String, dynamic>>.from(filteredTemplates);
          _taxTemplate = null; // Reset to empty instead of defaulting to first
          _updateSelectedTaxes();
        });
      } else {
        throw Exception(
          'Failed to fetch tax templates: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching tax templates: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching tax templates: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchTermsConditions() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_terms_and_conditions';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      print('Terms Conditions Response: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] != 'success') {
          throw Exception('API returned unsuccessful status');
        }
        setState(() {
          _termsConditions = List<Map<String, dynamic>>.from(
            data['message']['data'] ?? [],
          );
          _termsCondition =
              null; // Reset to empty instead of defaulting to first
        });
      } else {
        throw Exception(
          'Failed to fetch terms and conditions: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching terms and conditions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching terms and conditions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateSelectedTaxes() {
    if (_taxTemplate != null) {
      final selectedTemplate = _taxTemplates.firstWhere(
        (template) => template['template_name'] == _taxTemplate,
        orElse: () => {},
      );
      if (selectedTemplate.isNotEmpty) {
        setState(() {
          _selectedTaxes = List<Map<String, dynamic>>.from(
            selectedTemplate['taxes'] ?? [],
          );
          _validateAndAdjustTaxes();
          _calculateTaxAmounts();
        });
      }
    } else {
      setState(() {
        _selectedTaxes = [];
      });
    }
  }

  void _validateAndAdjustTaxes() {
    final currentCompanyAbbr = companyList.firstWhere(
      (company) => company['name'] == _company,
      orElse: () => {'abbr': 'SSIL'},
    )['abbr'];
    _selectedTaxes = _selectedTaxes.map((tax) {
      if (tax['account_head']?.contains(currentCompanyAbbr) == false) {
        return {
          ...tax,
          'account_head':
              '${tax['account_head']?.replaceAll(RegExp(r'-[^-]+$'), '')}-$currentCompanyAbbr',
          'description':
              '${tax['description']} (Adjusted for $currentCompanyAbbr)',
        };
      }
      return tax;
    }).toList();
  }

  void _calculateTaxAmounts() {
    double netTotal = getTotalAmount();
    List<Map<String, dynamic>> calculatedTaxes = [];
    Map<int?, double> rowTotals = {null: netTotal};

    _selectedTaxes.sort(
      (a, b) => (a['row_id'] ?? '').compareTo(b['row_id'] ?? ''),
    );

    for (var tax in _selectedTaxes) {
      final rate = (tax['rate'] as num? ?? 0.0).toDouble();
      final chargeType = tax['charge_type'] as String? ?? 'On Net Total';
      double baseAmount = 0.0;
      int? rowId = int.tryParse(
        tax['row_id']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0',
      );

      switch (chargeType) {
        case 'On Item Quantity':
        case 'On Net Total':
          baseAmount = netTotal;
          break;
        case 'On Previous Row Total':
          baseAmount = rowId != null && rowId > 0
              ? (rowTotals[rowId - 1] ?? netTotal)
              : netTotal;
          break;
        default:
          baseAmount = netTotal;
      }

      final taxAmount = (baseAmount * rate) / 100;
      calculatedTaxes.add({
        ...tax,
        'amount': taxAmount,
        'total':
            (rowTotals[rowId ?? calculatedTaxes.length - 1] ?? 0.0) + taxAmount,
      });
      rowTotals[rowId ?? calculatedTaxes.length - 1] =
          (rowTotals[rowId ?? calculatedTaxes.length - 1] ?? 0.0) + taxAmount;
    }

    setState(() {
      _selectedTaxes = calculatedTaxes;
    });
  }

  Future<void> _createSalesOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final url = "${widget.serverUrl}/api/resource/Sales Order";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final items = _items.map((item) {
      return {
        "item_code": item['itemCode'],
        "item_name": item['itemName'],
        "delivery_date": item['deliveryDate'].text,
        "qty": double.tryParse(item['qty'].text) ?? 0.0,
        "uom": item['uom'],
        "rate": item['rate'],
        "amount": item['amount'],
      };
    }).toList();

    final taxes = _selectedTaxes.map((tax) {
      final Map<String, dynamic> taxData = {
        "charge_type": tax['charge_type'],
        "account_head": tax['account_head'],
        "rate": tax['rate'],
        "amount": tax['amount'],
        "description": tax['description'],
        "cost_center": tax['cost_center'],
        "total": tax['total'],
      };
      if (tax['row_id'] != null) {
        taxData['row_id'] = tax['row_id'];
      }
      return taxData;
    }).toList();

    final body = jsonEncode({
      "naming_series": _series,
      "transaction_date": _transactionDateController.text,
      "customer": _customer,
      "order_type": _orderType,
      "po_no": _poNoController.text,
      "po_date": _poDateController.text.isNotEmpty
          ? _poDateController.text
          : null,
      "items": items,
      "taxes": taxes,
      "taxes_and_charges": _taxTemplate,
      "tc_name": _termsCondition,
      "payment_terms_template": _paymentTermsTemplate, // Added new field
      "company": _company,
      "currency": companyList.firstWhere(
        (company) => company['name'] == _company,
        orElse: () => {'default_currency': 'INR'},
      )['default_currency'],
      "selling_price_list": "Standard Selling",
      "status": "Draft",
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final createdOrder = json.decode(response.body)['data'];
        String successMessage =
            'Sales Order Created Successfully!\n\nDetails:\n';
        successMessage += 'Naming Series: ${_series}\n';
        successMessage += 'Customer: ${_customer}\n';
        successMessage += 'Company: ${_company}\n';
        successMessage +=
            'Transaction Date: ${_transactionDateController.text}\n';
        successMessage += 'Order Type: ${_orderType}\n';
        successMessage += 'Purchase Order No: ${_poNoController.text}\n';
        successMessage += 'Purchase Order Date: ${_poDateController.text}\n';
        successMessage += 'Items:\n';
        for (var item in _items) {
          successMessage +=
              '- ${item['itemCode']} (${item['itemName']}, Qty: ${item['qty'].text}, Rate: ${item['rate']}, Amount: ${item['amount']})\n';
        }
        successMessage += 'Taxes:\n';
        for (var tax in _selectedTaxes) {
          successMessage +=
              '- ${tax['account_head']} (Rate: ${tax['rate']}%, Amount: ${tax['amount']}, Total: ${tax['total']})\n';
        }
        successMessage += 'Terms & Conditions: ${_termsCondition}\n';
        successMessage +=
            'Payment Terms Template: ${_paymentTermsTemplate ?? "Not Selected"}\n';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 10),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorBody = json.decode(response.body);
        String errorMsg =
            'Failed to create sales order: ${response.statusCode}';
        if (errorBody['exception']?.contains('LinkValidationError') == true) {
          errorMsg +=
              '\n"${errorBody['exception'].split(": ").last}" not found in ERPNext.';
        }
        throw Exception('$errorMsg - ${response.body}');
      }
    } catch (e) {
      print('Sales Order creation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error creating Sales Order: $e\nEnsure all linked fields exist in ERPNext.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addItemRow() {
    setState(() {
      _items.add({
        'itemCode': null,
        'itemName': null,
        'deliveryDate': TextEditingController(
          text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        ),
        'qty': TextEditingController(text: '1.000'),
        'uom': null,
        'rate': 0.0,
        'rateController': TextEditingController(),
        'amount': 0.0,
      });
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      if (_items.length > 1) {
        _items[index]['deliveryDate'].dispose();
        _items[index]['qty'].dispose();
        _items[index]['rateController'].dispose();
        _items.removeAt(index);
        _calculateTaxAmounts(); // Recalculate taxes after removing an item
      }
    });
  }

  double getTotalQuantity() {
    return _items.fold(
      0.0,
      (sum, item) => sum + (double.tryParse(item['qty'].text) ?? 0.0),
    );
  }

  double getTotalAmount() {
    return _items.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  double getTotalTaxAmount() {
    return _selectedTaxes.fold(
      0.0,
      (sum, tax) => sum + ((tax['amount'] as double?) ?? 0.0),
    );
  }

  String _stripHtmlTags(String htmlString) {
    final regExp = RegExp(r'<[^>]*>|&[a-z]+;');
    return htmlString.replaceAll(regExp, '').trim();
  }

  void _showTermsDetails() {
    if (_termsCondition != null) {
      final selectedTerm = _termsConditions.firstWhere(
        (term) => term['name'] == _termsCondition,
        orElse: () => {},
      );
      if (selectedTerm.isNotEmpty) {
        final termsText = _stripHtmlTags(selectedTerm['terms']);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Terms & Conditions Details'),
            content: SingleChildScrollView(
              child: Text(termsText, style: TextStyle(fontSize: 16)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );
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
    ValueChanged<String>? onChanged,
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
            onChanged: onChanged,
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
    String? value,
    List<String> items,
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator, {
    bool enabled = true,
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
            onChanged: enabled ? onChanged : null,
            validator: enabled ? validator : null,
            enabled: enabled,
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  labelText: 'Search $label',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            dropdownBuilder: (context, selectedItem) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                      style: TextStyle(fontSize: 16, color: Colors.grey),
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

  Widget _buildItemsTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
            child: Row(
              children: [
                _buildTableHeaderCell('No.', 60),
                _buildTableHeaderCell('Item Code', 250),
                _buildTableHeaderCell('Quantity', 100),
                _buildTableHeaderCell('Rate (INR)', 150),
                _buildTableHeaderCell('Amount (INR)', 100),
                _buildTableHeaderCell('', 60),
              ],
            ),
          ),
          SizedBox(height: 8),
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            if (item['rateController'].text.isEmpty ||
                double.tryParse(item['rateController'].text) != item['rate']) {
              item['rateController'].text = item['rate'].toStringAsFixed(2);
            }
            final qty = double.tryParse(item['qty'].text) ?? 0.0;
            item['amount'] = qty * item['rate'];

            return Container(
              margin: EdgeInsets.symmetric(vertical: 4),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTableCell(
                    Text(
                      '${index + 1}',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    60,
                  ),
                  _buildTableCell(
                    DropdownSearch<String>(
                      items: (String filter, LoadProps? loadProps) => Future.value(
                        itemList
                            .map(
                              (item) =>
                                  '${item['item_code']} - ${item['item_name']}',
                            )
                            .toList(),
                      ),
                      selectedItem: item['itemCode'] != null
                          ? '${item['itemCode']} - ${item['itemName']}'
                          : null,
                      onChanged: (value) {
                        setState(() {
                          item['itemCode'] = value?.split(' - ')[0];
                          final selectedItem = itemList.firstWhere(
                            (element) =>
                                element['item_code'] == item['itemCode'],
                            orElse: () => {
                              'item_name': '',
                              'uom': '',
                              'price_list_rate': 0.0,
                            },
                          );
                          item['itemName'] = selectedItem['item_name'];
                          item['uom'] = selectedItem['uom'];
                          item['rate'] =
                              (selectedItem['price_list_rate'] as num)
                                  .toDouble();
                          item['rateController'].text = item['rate']
                              .toStringAsFixed(2);
                          final qty = double.tryParse(item['qty'].text) ?? 0.0;
                          item['amount'] = qty * item['rate'];
                          _calculateTaxAmounts();
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Select an item' : null,
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            labelText: 'Search Item Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        child: Text(
                          selectedItem ?? 'Select Item Code',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    250,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['qty'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) =>
                          value!.isEmpty || double.tryParse(value) == null
                          ? 'Enter a valid quantity'
                          : null,
                      onChanged: (value) {
                        setState(() {
                          final qty = double.tryParse(value) ?? 0.0;
                          item['amount'] = qty * item['rate'];
                          _calculateTaxAmounts();
                        });
                      },
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    100,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['rateController'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) =>
                          value!.isEmpty || double.tryParse(value) == null
                          ? 'Enter a valid rate'
                          : null,
                      onEditingComplete: () {
                        setState(() {
                          final rate =
                              double.tryParse(item['rateController'].text) ??
                              0.0;
                          item['rate'] = rate;
                          if (rate == rate.truncateToDouble())
                            item['rateController'].text = rate.toStringAsFixed(
                              2,
                            );
                          final qty = double.tryParse(item['qty'].text) ?? 0.0;
                          item['amount'] = qty * item['rate'];
                          _calculateTaxAmounts();
                        });
                      },
                      onTap: () =>
                          item['rateController'].selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: item['rateController'].text.length,
                          ),
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    150,
                  ),
                  _buildTableCell(
                    Text(
                      item['amount'].toStringAsFixed(2),
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    100,
                  ),
                  _buildTableCell(
                    _items.length > 1
                        ? IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItemRow(index),
                          )
                        : SizedBox(),
                    60,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String title, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
        textAlign:
            title == 'No.' ||
                title == 'Quantity' ||
                title == 'Rate (INR)' ||
                title == 'Amount (INR)'
            ? TextAlign.center
            : TextAlign.left,
      ),
    );
  }

  Widget _buildTableCell(Widget child, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Sales Order',
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
                      'Create Sales Order',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Naming Series',
                      _series,
                      ['SAL-ORD-.YYYY.-'],
                      (value) => setState(() => _series = value),
                      (value) => value == null
                          ? 'Please select a naming series'
                          : null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      'Transaction Date',
                      _transactionDateController,
                      readOnly: true,
                      onTap: () =>
                          _selectDate(context, _transactionDateController),
                      validator: (value) =>
                          value!.isEmpty ? 'Please select a date' : null,
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Company',
                      _company,
                      companyList
                          .map((company) => company['name'] as String)
                          .toList(),
                      (value) {
                        setState(() {
                          _company = value;
                          _companySelected = true; // Mark company as selected
                          _taxTemplate = null;
                          _selectedTaxes = [];
                          fetchTaxTemplates();
                        });
                      },
                      (value) =>
                          value == null ? 'Please select a company' : null,
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Customer',
                      _customer,
                      customerList
                          .map(
                            (customer) =>
                                '${customer['name']} - ${customer['customer_name']}',
                          )
                          .toList(),
                      (value) =>
                          setState(() => _customer = value?.split(' - ')[0]),
                      (value) =>
                          value == null ? 'Please select a customer' : null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      "Customer's Purchase Order (PO No)",
                      _poNoController,
                      onChanged: (value) => setState(() {}),
                    ),
                    if (_poNoController.text.isNotEmpty) ...[
                      SizedBox(height: 16),
                      _buildTextField(
                        "Customer's Purchase Order Date",
                        _poDateController,
                        readOnly: true,
                        onTap: () => _selectDate(context, _poDateController),
                      ),
                    ],
                    SizedBox(height: 16),
                    Text(
                      'Items',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildItemsTable(context),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Sales Taxes and Charges Template',
                      _taxTemplate,
                      _taxTemplates
                          .map(
                            (template) => template['template_name'] as String,
                          )
                          .toList(),
                      (value) {
                        setState(() {
                          _taxTemplate = value;
                          _updateSelectedTaxes();
                        });
                      },
                      (value) => null,
                      enabled: _companySelected,
                    ),
                    if (_taxTemplate != null && _selectedTaxes.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Container(
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
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              columnSpacing: 20,
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'No.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Charge Type',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Account Head',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Tax Rate (%)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Amount (INR)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Total (INR)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: _selectedTaxes.asMap().entries.map((entry) {
                                final index = entry.key;
                                final tax = entry.value;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        '${index + 1}',
                                        style: TextStyle(fontSize: 14),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        tax['charge_type'] ?? '',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        tax['account_head'] ?? '',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${tax['rate'] ?? 0}%',
                                        style: TextStyle(fontSize: 14),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${(tax['amount'] ?? 0.0).toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 14),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${(tax['total'] ?? 0.0).toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 14),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Total Taxes and Charges (INR): ₹${getTotalTaxAmount().toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Terms & Conditions',
                      _termsCondition,
                      _termsConditions
                          .map((term) => '${term['name']} - ${term['title']}')
                          .toList(),
                      (value) {
                        setState(() {
                          _termsCondition = value?.split(' - ')[0];
                          _showTermsDetails();
                        });
                      },
                      (value) => value == null
                          ? 'Please select terms and conditions'
                          : null,
                      enabled: _companySelected,
                    ),
                    SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      'Payment Terms Template',
                      _paymentTermsTemplate,
                      _paymentTermsTemplates,
                      (value) {
                        setState(() {
                          _paymentTermsTemplate = value;
                        });
                      },
                      (value) => null,
                      enabled: _companySelected,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Totals',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Quantity',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              getTotalQuantity().toStringAsFixed(3),
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total (INR)',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹${(getTotalAmount() + getTotalTaxAmount()).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _createSalesOrder,
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
                      child: isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Create Sales Order',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addItemRow,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: Icon(Icons.add, color: Colors.white),
        elevation: 6,
      ),
    );
  }
}
