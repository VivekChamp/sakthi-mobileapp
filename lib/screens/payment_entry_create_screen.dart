import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/payment_entry.dart';
import '../services/api_service.dart';

class PaymentEntryCreateScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const PaymentEntryCreateScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _PaymentEntryCreateScreenState createState() =>
      _PaymentEntryCreateScreenState();
}

class _PaymentEntryCreateScreenState extends State<PaymentEntryCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late PaymentEntry _paymentEntry;
  final _partyTypes = ['Customer', 'Supplier', 'Employee', 'Shareholder'];
  final _paymentTypes = ['Receive', 'Pay', 'Internal Transfer'];
  List<String> _modesOfPayment = [];
  List<String> _namingSeriesOptions = [];
  List<String> _partyList = [];
  List<String> _accountPaidToOptions = [];
  List<String> _accountPaidFromOptions = [];
  List<String> _accountHeadOptions = [];

  bool _isLoadingParties = false;
  bool _isLoadingInitialData = true;

  // Additional fields for specific modes of payment
  String? _cashAmount;
  String? _bankTransactionDate;
  String? _bankAmount;
  String? _chequeNumber;
  String? _chequeAmount;
  String? _accountCurrencyFrom;
  String? _accountCurrencyTo;
  double? _receivedAmount;

  @override
  void initState() {
    super.initState();
    _paymentEntry = PaymentEntry(
      paymentType: 'Receive',
      postingDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      company: 'SAKTHI STEEL INDUSTRIES LTD',
      pdcCleared: false,
    );
    _fetchInitialData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoadingInitialData = true;
    });

    try {
      // Fetch Naming Series
      final namingSeriesResponse = await ApiService.fetchNamingSeries(
        widget.serverUrl,
        widget.sid,
      );
      setState(() {
        _namingSeriesOptions = namingSeriesResponse
            .toSet()
            .toList(); // Remove duplicates
        if (_namingSeriesOptions.isNotEmpty) {
          _paymentEntry.namingSeries = _namingSeriesOptions[0];
        }
      });

      // Fetch Modes of Payment
      _modesOfPayment = ['Cash', 'Cheque', 'Bank Transfer', 'Petty Cash'];

      // Fetch Account Paid To
      final accountPaidToResponse = await ApiService.fetchAccountPaidTo(
        widget.serverUrl,
        widget.sid,
      );
      setState(() {
        _accountPaidToOptions = accountPaidToResponse;
        if (_accountPaidToOptions.isNotEmpty) {
          _paymentEntry.paidTo = _accountPaidToOptions[0];
        }
      });

      // Fetch Account Paid From
      final accountPaidFromResponse = await ApiService.fetchAccountPaidFrom(
        widget.serverUrl,
        widget.sid,
      );
      setState(() {
        _accountPaidFromOptions = accountPaidFromResponse;
        if (_accountPaidFromOptions.isNotEmpty) {
          _paymentEntry.paidFrom = _accountPaidFromOptions[0];
        }
      });

      // Fetch Account Head
      final accountHeadResponse = await ApiService.fetchAccountHead(
        widget.serverUrl,
        widget.sid,
      );
      setState(() {
        _accountHeadOptions = accountHeadResponse;
        if (_accountHeadOptions.isNotEmpty) {
          _accountCurrencyFrom = _accountHeadOptions[0];
          _accountCurrencyTo = _accountHeadOptions[0];
        }
      });

      setState(() {
        _isLoadingInitialData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingInitialData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching initial data: $e')),
      );
    }
  }

  Future<void> _fetchParties(String partyType) async {
    setState(() {
      _isLoadingParties = true;
      _partyList = [];
      _paymentEntry.party = null;
    });

    try {
      List<String> parties;
      switch (partyType) {
        case 'Customer':
          final customers = await ApiService.fetchCustomers(
            widget.serverUrl,
            widget.sid,
          );
          parties = customers
              .map((customer) => customer['customer_name'] as String)
              .toList();
          break;
        case 'Supplier':
          parties = await ApiService.fetchSuppliers(
            widget.serverUrl,
            widget.sid,
          );
          break;
        case 'Employee':
          parties = await ApiService.fetchEmployees(
            widget.serverUrl,
            widget.sid,
          );
          break;
        case 'Shareholder':
          parties = await ApiService.fetchShareholders(
            widget.serverUrl,
            widget.sid,
          );
          break;
        default:
          parties = [];
      }
      setState(() {
        _partyList = parties;
        _isLoadingParties = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingParties = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching parties: $e')));
    }
  }

  Future<void> _createPaymentEntry() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final paymentEntryData = {
        ..._paymentEntry.toJson(),
        'cash_amount': _cashAmount,
        'bank_transaction_date': _bankTransactionDate,
        'bank_amount': _bankAmount,
        'cheque_number': _chequeNumber,
        'cheque_amount': _chequeAmount,
        'account_currency_from': _accountCurrencyFrom,
        'account_currency_to': _accountCurrencyTo,
        'received_amount': _receivedAmount,
      };

      await ApiService.createPaymentEntry(
        widget.serverUrl,
        widget.sid,
        paymentEntryData,
      );

      String successMessage = 'Completed\n\nCreated Payment Entry Details:\n';
      successMessage += 'Payment Type: ${_paymentEntry.paymentType}\n';
      successMessage += 'Posting Date: ${_paymentEntry.postingDate}\n';
      successMessage += 'Party: ${_paymentEntry.party}\n';
      successMessage +=
          'Paid Amount: ${_paymentEntry.paidAmount?.toStringAsFixed(2) ?? '0.00'} AED\n';
      successMessage += 'Mode of Payment: ${_paymentEntry.modeOfPayment}\n';
      successMessage += 'Remarks: ${_paymentEntry.remarks ?? 'No remarks'}\n';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage, style: TextStyle(fontSize: 16)),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: Duration(seconds: 10),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error creating Payment Entry: $e\nEnsure all linked fields exist in ERPNext.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    String field, {
    String? initialValue,
  }) async {
    DateTime initialDate = initialValue != null
        ? DateTime.parse(initialValue)
        : DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (field == 'postingDate') {
          _paymentEntry.postingDate = DateFormat('yyyy-MM-dd').format(picked);
        } else if (field == 'bankTransactionDate') {
          _bankTransactionDate = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Payment Entry',
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
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchableDropdownField(
                      label: 'Series',
                      value: _paymentEntry.namingSeries,
                      items: _namingSeriesOptions,
                      onChanged: (value) {
                        setState(() {
                          _paymentEntry.namingSeries = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a series' : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      label: 'Posting Date',
                      controller: TextEditingController(
                        text: _paymentEntry.postingDate ?? '',
                      ),
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: () => _selectDate(
                        context,
                        'postingDate',
                        initialValue: _paymentEntry.postingDate,
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please select a date' : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildSearchableDropdownField(
                      label: 'Payment Type',
                      value: _paymentEntry.paymentType,
                      items: _paymentTypes,
                      onChanged: (value) {
                        setState(() {
                          _paymentEntry.paymentType = value;
                          if (value == 'Internal Transfer') {
                            _paymentEntry.partyType = null;
                            _paymentEntry.party = null;
                            _partyList = [];
                          }
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a payment type' : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildSearchableDropdownField(
                      label: 'Mode of Payment',
                      value: _paymentEntry.modeOfPayment,
                      items: _modesOfPayment,
                      onChanged: (value) {
                        setState(() {
                          _paymentEntry.modeOfPayment = value;
                          _cashAmount = null;
                          _bankTransactionDate = null;
                          _bankAmount = null;
                          _chequeNumber = null;
                          _chequeAmount = null;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select a mode of payment'
                          : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    if (_paymentEntry.modeOfPayment == 'Cash')
                      _buildTextField(
                        label: 'Cash Amount (AED)',
                        controller: TextEditingController(
                          text: _cashAmount ?? '',
                        ),
                        icon: Icons.monetization_on,
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _cashAmount = value,
                        validator: (value) {
                          if (_paymentEntry.modeOfPayment == 'Cash' &&
                              (value == null || value.isEmpty)) {
                            return 'Please enter the cash amount';
                          }
                          return null;
                        },
                      ),
                    if (_paymentEntry.modeOfPayment == 'Bank Transfer') ...[
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.02,
                      ),
                      _buildTextField(
                        label: 'Bank Transaction Date',
                        controller: TextEditingController(
                          text: _bankTransactionDate ?? '',
                        ),
                        icon: Icons.calendar_today,
                        readOnly: true,
                        onTap: () =>
                            _selectDate(context, 'bankTransactionDate'),
                        validator: (value) {
                          if (_paymentEntry.modeOfPayment == 'Bank Transfer' &&
                              (value == null || value.isEmpty)) {
                            return 'Please select a transaction date';
                          }
                          return null;
                        },
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.02,
                      ),
                      _buildTextField(
                        label: 'Bank Amount (AED)',
                        controller: TextEditingController(
                          text: _bankAmount ?? '',
                        ),
                        icon: Icons.monetization_on,
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _bankAmount = value,
                        validator: (value) {
                          if (_paymentEntry.modeOfPayment == 'Bank Transfer' &&
                              (value == null || value.isEmpty)) {
                            return 'Please enter the bank amount';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_paymentEntry.modeOfPayment == 'Cheque') ...[
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.02,
                      ),
                      _buildTextField(
                        label: 'Cheque Number',
                        controller: TextEditingController(
                          text: _chequeNumber ?? '',
                        ),
                        icon: Icons.receipt,
                        onChanged: (value) => _chequeNumber = value,
                        validator: (value) {
                          if (_paymentEntry.modeOfPayment == 'Cheque' &&
                              (value == null || value.isEmpty)) {
                            return 'Please enter the cheque number';
                          }
                          return null;
                        },
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.02,
                      ),
                      _buildTextField(
                        label: 'Cheque Amount (AED)',
                        controller: TextEditingController(
                          text: _chequeAmount ?? '',
                        ),
                        icon: Icons.monetization_on,
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _chequeAmount = value,
                        validator: (value) {
                          if (_paymentEntry.modeOfPayment == 'Cheque' &&
                              (value == null || value.isEmpty)) {
                            return 'Please enter the cheque amount';
                          }
                          return null;
                        },
                      ),
                    ],
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    if (_paymentEntry.paymentType == 'Receive')
                      Row(
                        children: [
                          Checkbox(
                            value: _paymentEntry.pdcCleared,
                            onChanged: (value) {
                              setState(() {
                                _paymentEntry.pdcCleared = value;
                              });
                            },
                          ),
                          Text(
                            'PDC Cleared',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildSearchableDropdownField(
                      label: 'Party Type',
                      value: _paymentEntry.partyType,
                      items: _partyTypes,
                      onChanged: (value) {
                        setState(() {
                          _paymentEntry.partyType = value;
                          if (value != null) {
                            _fetchParties(value);
                          }
                        });
                      },
                      validator: (value) {
                        if (_paymentEntry.paymentType != 'Internal Transfer' &&
                            value == null) {
                          return 'Please select a party type';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    if (_paymentEntry.paymentType != 'Internal Transfer')
                      _buildSearchableDropdownField(
                        label: 'Party',
                        value: _paymentEntry.party,
                        items: _partyList,
                        onChanged: (value) {
                          setState(() {
                            _paymentEntry.party = value;
                          });
                        },
                        validator: (value) {
                          if (_paymentEntry.paymentType !=
                                  'Internal Transfer' &&
                              (value == null || value.isEmpty)) {
                            return 'Please select a party';
                          }
                          return null;
                        },
                        suffixIcon: _isLoadingParties
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              )
                            : null,
                      ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildSearchableDropdownField(
                      label: 'Account Paid From',
                      value: _paymentEntry.paidFrom,
                      items: _accountPaidFromOptions,
                      onChanged: (value) {
                        setState(() {
                          _paymentEntry.paidFrom = value;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select an account paid from'
                          : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildSearchableDropdownField(
                      label: 'Account Currency (From)',
                      value: _accountCurrencyFrom,
                      items: _accountHeadOptions,
                      onChanged: (value) {
                        setState(() {
                          _accountCurrencyFrom = value;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select an account currency (from)'
                          : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildSearchableDropdownField(
                      label: 'Account Paid To',
                      value: _paymentEntry.paidTo,
                      items: _accountPaidToOptions,
                      onChanged: (value) {
                        setState(() {
                          _paymentEntry.paidTo = value;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select an account paid to'
                          : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildSearchableDropdownField(
                      label: 'Account Currency (To)',
                      value: _accountCurrencyTo,
                      items: _accountHeadOptions,
                      onChanged: (value) {
                        setState(() {
                          _accountCurrencyTo = value;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select an account currency (to)'
                          : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      label: 'Paid Amount (AED)',
                      controller: TextEditingController(
                        text: _paymentEntry.paidAmount?.toString() ?? '',
                      ),
                      icon: Icons.monetization_on,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _paymentEntry.paidAmount = double.tryParse(value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the paid amount';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      label: 'Received Amount (AED)',
                      controller: TextEditingController(
                        text: _receivedAmount?.toString() ?? '',
                      ),
                      icon: Icons.monetization_on,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _receivedAmount = double.tryParse(value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the received amount';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      label: 'Remarks',
                      controller: TextEditingController(
                        text: _paymentEntry.remarks ?? '',
                      ),
                      icon: Icons.note,
                      maxLines: 3,
                      onChanged: (value) {
                        _paymentEntry.remarks = value;
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                    ElevatedButton(
                      onPressed: _isLoadingInitialData
                          ? null
                          : _createPaymentEntry,
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
                      child: _isLoadingInitialData
                          ? CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : Text(
                              'Create Payment Entry',
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
        onPressed: () {
          // Placeholder for future extensibility (e.g., adding payment lines)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Feature not implemented yet')),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: Icon(Icons.add, color: Colors.white),
        elevation: 6,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLines,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
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
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
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
    Widget? suffixIcon,
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
                    if (suffixIcon != null) suffixIcon,
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
