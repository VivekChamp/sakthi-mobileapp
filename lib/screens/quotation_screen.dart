import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:retry/retry.dart';
import 'package:dropdown_search/dropdown_search.dart';

class QuotationScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final Map<String, dynamic>? initialData;

  const QuotationScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    this.initialData,
  }) : super(key: key);

  @override
  _QuotationScreenState createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> _itemsList = [];
  List<dynamic> _customersList = [];
  List<dynamic> _salespersonsList = [];
  List<Map<String, dynamic>> _selectedItems = [];
  List<dynamic> _costCenters = [];
  String? _selectedCostCenter;
  dynamic _selectedCustomer;
  dynamic _selectedSalesperson;
  bool _isLoading = true;
  bool _isFetchingItems = false;
  bool _isFetchingCustomers = false;
  bool _isFetchingSalespersons = false;
  bool _isFetchingCostCenters = false;
  static List<dynamic>? _cachedItems;
  static List<dynamic>? _cachedCustomers;
  static List<dynamic>? _cachedSalespersons;
  static List<dynamic>? _cachedCostCenters;
  final _quotationToController = TextEditingController(text: 'Customer');
  DateTime _transactionDate = DateTime.now();
  double _cachedTotalAmount = 0.0;
  double _cachedGrandTotal = 0.0;
  int _cachedTotalQuantity = 0;

  String _namingSeries = 'SAL-QTN-.YYYY';
  String _sellingPriceList = 'Standard Selling';
  String _currency = 'INR';

  List<String> _uomList = [
    'Unit',
    'Box',
    'Nos',
    'Pair',
    'Set',
    'Meter',
    'Barleycorn',
    'Calibre',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _quotationToController.dispose();
    for (var item in _selectedItems) {
      item['quantityController']?.dispose();
      item['discountPercentController']?.dispose();
      item['discountAmountController']?.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (_cachedItems != null &&
        _cachedCustomers != null &&
        _cachedSalespersons != null &&
        _cachedCostCenters != null) {
      setState(() {
        _itemsList = _cachedItems!;
        _customersList = _cachedCustomers!;
        _salespersonsList = _cachedSalespersons!;
        _costCenters = _cachedCostCenters!;
        _selectedCostCenter = _costCenters.isNotEmpty
            ? _costCenters[0]['name']
            : null;
        _isLoading = false;
      });
      _loadInitialData();
      _updateTotals();
      return;
    }

    await Future.wait([
      _fetchItems(),
      _fetchCustomers(),
      _fetchSalespersons(),
      _fetchCostCenters(),
    ]);
    _loadInitialData();
    _updateTotals();
  }

  void _loadInitialData() {
    if (widget.initialData != null) {
      final data = widget.initialData!;
      setState(() {
        _quotationToController.text =
            data['quotation_to']?.toString() ?? 'Customer';
        _transactionDate =
            DateTime.tryParse(data['transaction_date']?.toString() ?? '') ??
            DateTime.now();
        _selectedItems = List<Map<String, dynamic>>.from(
          (data['items'] as List<dynamic>?)?.map(
                (item) => ({
                  'item_name': item['item_name']?.toString() ?? 'Unknown',
                  'item_code': item['item_code']?.toString() ?? '',
                  'quantity': item['qty'] is num ? item['qty'].toInt() : 1,
                  'uom': item['uom']?.toString() ?? 'Nos',
                  'conversion_factor':
                      (item['conversion_factor'] as num?)?.toDouble() ?? 0.0,
                  'price_list_rate':
                      (item['price_list_rate'] as num?)?.toDouble() ?? 0.0,
                  'discount_percent':
                      (item['discount_percentage'] as num?)?.toDouble() ?? 0.0,
                  'discount_amount':
                      (item['discount_amount'] as num?)?.toDouble() ?? 0.0,
                  'amount': _calculateAmount(item),
                  'image': item['image']?.toString(),
                  'barcode': item['barcode']?.toString() ?? '',
                  'quantityController': TextEditingController(
                    text: (item['qty'] ?? 1).toString(),
                  ),
                  'discountPercentController': TextEditingController(
                    text: ((item['discount_percentage'] ?? 0.0) as num)
                        .toDouble()
                        .toStringAsFixed(2),
                  ),
                  'discountAmountController': TextEditingController(
                    text: ((item['discount_amount'] ?? 0.0) as num)
                        .toDouble()
                        .toStringAsFixed(2),
                  ),
                  'selectedUom': item['uom']?.toString() ?? 'Nos',
                }),
              ) ??
              [],
        );
        final customerNameFromData =
            data['customer']?.toString() ?? data['customer_name']?.toString();
        if (customerNameFromData != null) {
          _selectedCustomer = _customersList.firstWhere(
            (customer) => customer['name'] == customerNameFromData,
            orElse: () => {
              'name': customerNameFromData,
              'customer_name': customerNameFromData,
            },
          );
        }
        _selectedSalesperson = data['salesperson_name'] != null
            ? {'salesperson_name': data['salesperson_name'].toString()}
            : null;
        _selectedCostCenter =
            data['cost_center']?.toString() ??
            (_costCenters.isNotEmpty ? _costCenters[0]['name'] : null);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchItems() async {
    if (_cachedItems != null) {
      setState(() {
        _itemsList = _cachedItems!;
        _isFetchingItems = false;
      });
      return;
    }
    setState(() => _isFetchingItems = true);
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
            "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.qtn.get_item_details",
          ),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _itemsList =
              (data['message'] as List<dynamic>?)
                  ?.map(
                    (item) => ({
                      'item_code': item['item_code']?.toString() ?? '',
                      'item_name': item['item_name']?.toString() ?? '',
                      'image': item['image']?.toString(),
                      'price_list_rate':
                          (item['price_list_rate'] as num?)?.toDouble() ?? 0.0,
                      'uom': item['uom']?.toString() ?? 'Nos',
                      'conversion_factor':
                          (item['conversion_factor'] as num?)?.toDouble() ??
                          0.0,
                      'barcode': item['barcode']?.toString() ?? '',
                    }),
                  )
                  .toList() ??
              [];
          _cachedItems = _itemsList;
          _isFetchingItems = false;
        });
      } else {
        _showError('Failed to fetch items: ${response.statusCode}');
        setState(() => _isFetchingItems = false);
      }
    } catch (e) {
      _showError('Failed to fetch items: $e');
      setState(() => _isFetchingItems = false);
    }
  }

  Future<void> _fetchCustomers() async {
    if (_cachedCustomers != null) {
      setState(() {
        _customersList = _cachedCustomers!;
        _isFetchingCustomers = false;
      });
      return;
    }
    setState(() => _isFetchingCustomers = true);
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
            "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.qtn.get_customers",
          ),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _customersList =
              (data['message'] as List<dynamic>?)
                  ?.map(
                    (customer) => ({
                      'name': customer['name']?.toString() ?? '',
                      'customer_name':
                          customer['customer_name']?.toString() ??
                          customer['name']?.toString() ??
                          '',
                    }),
                  )
                  .toList() ??
              [];
          _cachedCustomers = _customersList;
          _isFetchingCustomers = false;
        });
      } else {
        _showError('Failed to fetch customers: ${response.statusCode}');
        setState(() => _isFetchingCustomers = false);
      }
    } catch (e) {
      _showError('Failed to fetch customers: $e');
      setState(() => _isFetchingCustomers = false);
    }
  }

  Future<void> _fetchSalespersons() async {
    if (_cachedSalespersons != null) {
      setState(() {
        _salespersonsList = _cachedSalespersons!;
        _isFetchingSalespersons = false;
      });
      return;
    }
    setState(() => _isFetchingSalespersons = true);
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
            "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.qtn.get_salesperson",
          ),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _salespersonsList =
              (data['message'] as List<dynamic>?)
                  ?.map(
                    (item) => ({
                      'salesperson_name':
                          item['sales_person_name']?.toString() ?? '',
                    }),
                  )
                  .toList() ??
              [];
          _cachedSalespersons = _salespersonsList;
          _isFetchingSalespersons = false;
        });
      } else {
        _showError('Failed to fetch salespersons: ${response.statusCode}');
        setState(() => _isFetchingSalespersons = false);
      }
    } catch (e) {
      _showError('Failed to fetch salespersons: $e');
      setState(() => _isFetchingSalespersons = false);
    }
  }

  Future<void> _fetchCostCenters() async {
    if (_cachedCostCenters != null) {
      setState(() {
        _costCenters = _cachedCostCenters!;
        _selectedCostCenter = _costCenters.isNotEmpty
            ? _costCenters[0]['name']
            : null;
        _isFetchingCostCenters = false;
      });
      return;
    }
    setState(() => _isFetchingCostCenters = true);
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
            "${widget.serverUrl}/api/resource/Cost%20Center?fields=[\"name\"]",
          ),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _costCenters = (data['data'] as List<dynamic>?) ?? [];
          _cachedCostCenters = _costCenters;
          _selectedCostCenter = _costCenters.isNotEmpty
              ? _costCenters[0]['name']
              : null;
          _isFetchingCostCenters = false;
        });
      } else {
        _showError('Failed to fetch cost centers: ${response.statusCode}');
        setState(() => _isFetchingCostCenters = false);
      }
    } catch (e) {
      _showError('Failed to fetch cost centers: $e');
      setState(() => _isFetchingCostCenters = false);
    }
  }

  Map<String, String> _getHeaders() => {
    'Cookie': 'sid=${widget.sid}',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<void> _scanBarcode() async {
    if (await Permission.camera.request().isGranted) {
      try {
        final result = await BarcodeScanner.scan();
        if (result.type == ResultType.Barcode) {
          final barcode = result.rawContent;
          final item = _itemsList.firstWhere(
            (item) => item['barcode'] == barcode,
            orElse: () => null,
          );
          if (item != null) {
            _addItemToResult(item);
          } else {
            _showError('No item found for barcode: $barcode');
          }
        }
      } catch (e) {
        _showError('Failed to scan barcode: $e');
      }
    } else {
      _showError('Camera permission denied');
    }
  }

  void _addItemToResult(dynamic item) {
    setState(() {
      _selectedItems.add({
        'item_code': item['item_code'] ?? '',
        'item_name': item['item_name'] ?? 'Unknown',
        'quantity': 1,
        'uom': item['uom'] ?? 'Nos',
        'conversion_factor':
            (item['conversion_factor'] as num?)?.toDouble() ?? 0.0,
        'price_list_rate': (item['price_list_rate'] as num?)?.toDouble() ?? 0.0,
        'discount_percent': 0.0,
        'discount_amount': 0.0,
        'amount': _calculateAmount(item),
        'image': item['image'],
        'barcode': item['barcode'] ?? '',
        'quantityController': TextEditingController(text: '1'),
        'discountPercentController': TextEditingController(text: '0.00'),
        'discountAmountController': TextEditingController(text: '0.00'),
        'selectedUom': item['uom'] ?? 'Nos',
      });
      _updateTotals();
    });
  }

  double _calculateAmount(Map<String, dynamic> item) {
    final price = (item['price_list_rate'] as double?) ?? 0.0;
    final qty = (item['quantity'] as int?) ?? 1;
    final discount = (item['discount_amount'] as double?) ?? 0.0;
    return (price * qty - discount).clamp(0.0, double.infinity);
  }

  void _updateItem(
    int index, {
    String? quantity,
    String? discountPercent,
    String? discountAmount,
    String? uom,
  }) {
    setState(() {
      final item = _selectedItems[index];
      final price = item['price_list_rate'] as double;

      if (quantity != null) {
        final qty = int.tryParse(quantity) ?? 1;
        if (qty <= 0) {
          _selectedItems[index]['quantityController']?.dispose();
          _selectedItems[index]['discountPercentController']?.dispose();
          _selectedItems[index]['discountAmountController']?.dispose();
          _selectedItems.removeAt(index);
          _updateTotals();
          return;
        }
        item['quantity'] = qty;
        item['quantityController'].text = qty.toString();
      }

      if (discountPercent != null) {
        final percent = double.tryParse(discountPercent) ?? 0.0;
        item['discount_percent'] = percent.clamp(0, 100);
        final subtotal = price * (item['quantity'] as int);
        item['discount_amount'] = (subtotal * item['discount_percent'] / 100)
            .clamp(0, subtotal);
        item['discountPercentController'].text = item['discount_percent']
            .toStringAsFixed(2);
        item['discountAmountController'].text = item['discount_amount']
            .toStringAsFixed(2);
      }

      if (discountAmount != null) {
        final amount = double.tryParse(discountAmount) ?? 0.0;
        final subtotal = price * (item['quantity'] as int);
        item['discount_amount'] = amount.clamp(0, subtotal);
        item['discount_percent'] = subtotal > 0
            ? (item['discount_amount'] / subtotal * 100).clamp(0, 100)
            : 0.0;
        item['discountPercentController'].text = item['discount_percent']
            .toStringAsFixed(2);
        item['discountAmountController'].text = item['discount_amount']
            .toStringAsFixed(2);
      }

      if (uom != null) {
        item['selectedUom'] = uom;
      }

      item['amount'] = _calculateAmount(item);
      _updateTotals();
    });
  }

  void _updateTotals() {
    _cachedTotalQuantity = _selectedItems.fold(
      0,
      (sum, item) => sum + (item['quantity'] as int),
    );
    _cachedTotalAmount = _selectedItems.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as double),
    );
    _cachedGrandTotal = _cachedTotalAmount;
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF005BAC)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _transactionDate = picked;
      });
    }
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      _showError('Please select a customer');
      return;
    }
    if (_selectedSalesperson == null) {
      _showError('Please select a salesperson');
      return;
    }
    if (_selectedItems.isEmpty) {
      _showError('Please add at least one item');
      return;
    }
    if (_selectedCostCenter == null && _costCenters.isNotEmpty) {
      _showError('Please select a cost center');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final itemsToSave = _selectedItems.map((item) {
        final percent =
            double.tryParse(item['discountPercentController'].text) ?? 0.0;
        final amount =
            double.tryParse(item['discountAmountController'].text) ?? 0.0;
        return {
          'item_code': item['item_code'],
          'item_name': item['item_name'],
          'qty': item['quantity'],
          'uom': item['selectedUom'],
          'conversion_factor': item['conversion_factor'],
          'price_list_rate': item['price_list_rate'],
          'discount_percentage': percent,
          'discount_amount': amount,
          'amount': item['amount'],
          'barcode': item['barcode'],
          if (_selectedCostCenter != null) 'cost_center': _selectedCostCenter,
        };
      }).toList();

      final quotationData = {
        'quotation_to': _quotationToController.text.isEmpty
            ? 'Customer'
            : _quotationToController.text,
        'customer': _selectedCustomer['name']?.toString() ?? '',
        'party_name': _selectedCustomer['customer_name']?.toString() ?? '',
        'salesperson':
            _selectedSalesperson['salesperson_name']?.toString() ?? '',
        'transaction_date': DateFormat('yyyy-MM-dd').format(_transactionDate),
        'status': widget.initialData?['status']?.toString() ?? 'Draft',
        'items': itemsToSave,
        if (_selectedCostCenter != null) 'cost_center': _selectedCostCenter,
        'naming_series': _namingSeries,
        'selling_price_list': _sellingPriceList,
        'currency': _currency,
      };

      final response = await retry(
        () => http.post(
          Uri.parse("${widget.serverUrl}/api/resource/Quotation"),
          headers: _getHeaders(),
          body: json.encode(quotationData),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Quotation saved successfully',
              style: TextStyle(fontFamily: 'Dubai'),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        debugPrint(
          'Failed to save quotation. Status Code: ${response.statusCode}',
        );
        debugPrint('Response Body: ${response.body}');
        _showError('Failed to save quotation: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Exception during saveQuotation: $e');
      _showError('Failed to save quotation: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems[index]['quantityController']?.dispose();
      _selectedItems[index]['discountPercentController']?.dispose();
      _selectedItems[index]['discountAmountController']?.dispose();
      _selectedItems.removeAt(index);
      _updateTotals();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Dubai')),
        backgroundColor: const Color(0xFF757575),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Dubai',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            decoration: InputDecoration(
              hintText: 'Enter $label',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(fontFamily: 'Dubai'),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField(
    String label,
    dynamic value,
    List<dynamic> items,
    ValueChanged<dynamic>? onChanged,
    String compareKey, // Key to compare items (e.g., 'name', 'customer_name')
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Dubai',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: DropdownSearch<dynamic>(
            items: (String filter, LoadProps? loadProps) => Future.value(
              items
                  .where(
                    (item) =>
                        item[compareKey]?.toString().toLowerCase().contains(
                          filter.toLowerCase(),
                        ) ??
                        false,
                  )
                  .toList(),
            ),
            selectedItem: value,
            onChanged: onChanged,
            compareFn: (item1, item2) => item1[compareKey] == item2[compareKey],
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
              padding: const EdgeInsets.all(16),
              child: Text(
                selectedItem?[compareKey] ?? 'Select $label',
                style: const TextStyle(fontSize: 16, fontFamily: 'Dubai'),
              ),
            ),
            itemAsString: (item) => item[compareKey]?.toString() ?? '',
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
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Row(
              children: [
                _buildTableHeaderCell('No.', 60),
                _buildTableHeaderCell('Item Name', 250),
                _buildTableHeaderCell('Qty', 100),
                _buildTableHeaderCell('Disc %', 100),
                _buildTableHeaderCell('Disc ₹', 100),
                _buildTableHeaderCell('UOM', 100),
                _buildTableHeaderCell('Amount (₹)', 100),
                _buildTableHeaderCell('', 60),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._selectedItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTableCell(
                    Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Dubai'),
                    ),
                    60,
                  ),
                  _buildTableCell(
                    Text(
                      item['item_name'],
                      style: const TextStyle(fontSize: 14, fontFamily: 'Dubai'),
                    ),
                    250,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['quantityController'],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      onChanged: (value) => _updateItem(index, quantity: value),
                      style: const TextStyle(fontFamily: 'Dubai', fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    100,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['discountPercentController'],
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      onChanged: (value) =>
                          _updateItem(index, discountPercent: value),
                      style: const TextStyle(fontFamily: 'Dubai', fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    100,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['discountAmountController'],
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      onChanged: (value) =>
                          _updateItem(index, discountAmount: value),
                      style: const TextStyle(fontFamily: 'Dubai', fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    100,
                  ),
                  _buildTableCell(
                    DropdownButtonFormField<String>(
                      value: item['selectedUom'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      items: _uomList
                          .map(
                            (uom) => DropdownMenuItem<String>(
                              value: uom,
                              child: Text(
                                uom,
                                style: const TextStyle(
                                  fontFamily: 'Dubai',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (newValue) =>
                          _updateItem(index, uom: newValue),
                    ),
                    100,
                  ),
                  _buildTableCell(
                    Text(
                      item['amount'].toStringAsFixed(2),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Dubai'),
                    ),
                    100,
                  ),
                  _buildTableCell(
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeItem(index),
                    ),
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
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'Dubai',
        ),
        textAlign:
            title == 'No.' ||
                title == 'Qty' ||
                title == 'Disc %' ||
                title == 'Disc ₹' ||
                title == 'Amount (₹)'
            ? TextAlign.center
            : TextAlign.left,
      ),
    );
  }

  Widget _buildTableCell(Widget child, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialData == null ? 'Create Quotation' : 'Edit Quotation',
          style: const TextStyle(color: Colors.white, fontFamily: 'Dubai'),
        ),
        backgroundColor: const Color(0xFF005BAC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF005BAC)),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField('Quotation To', _quotationToController),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Transaction Date',
                        TextEditingController(
                          text: DateFormat(
                            'yyyy-MM-dd',
                          ).format(_transactionDate),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Customer',
                        _selectedCustomer,
                        _customersList,
                        (value) => setState(() => _selectedCustomer = value),
                        'customer_name', // Unique key for comparison
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Salesperson',
                        _selectedSalesperson,
                        _salespersonsList,
                        (value) => setState(() => _selectedSalesperson = value),
                        'salesperson_name', // Unique key for comparison
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Cost Center',
                        _costCenters.isNotEmpty
                            ? {'name': _selectedCostCenter}
                            : null,
                        _costCenters,
                        (value) => setState(
                          () => _selectedCostCenter = value?['name'],
                        ),
                        'name', // Unique key for comparison
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final selected = await showSearch(
                                  context: context,
                                  delegate: ItemSearchDelegate(
                                    _itemsList,
                                    widget.serverUrl,
                                  ),
                                );
                                if (selected != null)
                                  _addItemToResult(selected);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Select Item',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Dubai',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: Color(0xFF005BAC),
                            ),
                            onPressed: _scanBarcode,
                          ),
                        ],
                      ),
                      if (_selectedItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Selected Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Dubai',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildItemsTable(context),
                      ],
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Quantity:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF005BAC),
                                      fontFamily: 'Dubai',
                                    ),
                                  ),
                                  Text(
                                    '$_cachedTotalQuantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Dubai',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF005BAC),
                                      fontFamily: 'Dubai',
                                    ),
                                  ),
                                  Text(
                                    '₹${_cachedTotalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Dubai',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Grand Total:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF005BAC),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Dubai',
                                    ),
                                  ),
                                  Text(
                                    '₹${_cachedGrandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Dubai',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveQuotation,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF005BAC),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Save Quotation',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Dubai',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class CustomerSearchDelegate extends SearchDelegate<dynamic> {
  final List<dynamic> customers;

  CustomerSearchDelegate(this.customers);

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF005BAC),
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontFamily: 'Dubai', color: Colors.white),
    ),
  );

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    final results = customers
        .where(
          (customer) =>
              (customer['name']?.toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false) ||
              (customer['customer_name']?.toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final customer = results[index];
        return ListTile(
          title: Text(
            customer['customer_name'],
            style: const TextStyle(fontFamily: 'Dubai'),
          ),
          onTap: () => close(context, customer),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class SalespersonSearchDelegate extends SearchDelegate<dynamic> {
  final List<dynamic> salespersons;

  SalespersonSearchDelegate(this.salespersons);

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF005BAC),
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontFamily: 'Dubai', color: Colors.white),
    ),
  );

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    final results = salespersons
        .where(
          (salesperson) => salesperson['salesperson_name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final salesperson = results[index];
        return ListTile(
          title: Text(
            salesperson['salesperson_name'],
            style: const TextStyle(fontFamily: 'Dubai'),
          ),
          onTap: () => close(context, salesperson),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class ItemSearchDelegate extends SearchDelegate<dynamic> {
  final List<dynamic> items;
  final String serverUrl;

  ItemSearchDelegate(this.items, this.serverUrl);

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF005BAC),
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontFamily: 'Dubai', color: Colors.white),
    ),
  );

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    final results = items
        .where(
          (item) =>
              item['item_name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              item['item_code'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          leading: item['image'] != null
              ? CachedNetworkImage(
                  imageUrl: item['image'].startsWith('http')
                      ? item['image']
                      : '$serverUrl${item['image']}',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: (context, _) =>
                      const CircularProgressIndicator(color: Color(0xFF005BAC)),
                  errorWidget: (context, _, __) =>
                      const Icon(Icons.broken_image, color: Color(0xFF757575)),
                )
              : const Icon(Icons.image_not_supported, color: Color(0xFF757575)),
          title: Text(
            item['item_name'],
            style: const TextStyle(fontFamily: 'Dubai'),
          ),
          subtitle: Text(
            'Code: ${item['item_code']}',
            style: const TextStyle(
              fontFamily: 'Dubai',
              color: Color(0xFF757575),
            ),
          ),
          onTap: () => close(context, item),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
