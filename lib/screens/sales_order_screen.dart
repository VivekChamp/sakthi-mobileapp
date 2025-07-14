import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'create_sales_order_screen.dart';

class SalesOrderScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final List<String> roles; // Added roles parameter

  const SalesOrderScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
    required this.roles, // Required parameter
  });

  @override
  _SalesOrderScreenState createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  List<dynamic> salesOrders = [];
  List<dynamic> filteredSalesOrders = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 0;
  final int pageSize = 20;
  TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool hasMoreData = true;
  String? searchQuery;
  DateTimeRange? selectedDateRange;

  // Maps to store counts for each status field
  Map<String, int> statusCounts = {}; // For the 'status' field
  Map<String, int> workflowStateCounts = {}; // For the 'workflow_state' field

  String?
  selectedStatusFilter; // To hold the currently selected 'status' filter
  String?
  selectedWorkflowStateFilter; // To hold the currently selected 'workflow_state' filter

  Map<String, Map<String, dynamic>> connectionCache = {};
  Map<String, dynamic>? selectedOrder;

  // Define all possible 'status' values for filtering
  final List<String> allStatusValues = [
    'All', // Special filter for all orders
    'Draft',
    'To Deliver and Bill',
    'To Deliver',
    'To Bill',
    'Completed',
    'Closed',
    'Cancelled',
  ];

  // Define all possible 'workflow_state' values
  final List<String> allWorkflowStateValues = [
    'All', // Special filter for all workflow states
    'Draft',
    'Reviewed', // Corrected spelling from 'Reviwed'
    'Pending',
    'Approved By RM',
    'Rejected By RM',
    'Approved By GM',
    'Rejected By GM',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize all counts to zero
    for (var state in allStatusValues) {
      statusCounts[state] = 0;
    }
    for (var state in allWorkflowStateValues) {
      workflowStateCounts[state] = 0;
    }

    fetchSalesOrders();
    _scrollController.addListener(_onScroll);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMoreData) {
      fetchSalesOrders(loadMore: true);
    }
  }

  void _onSearchChanged() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        filterSalesOrders(searchController.text);
      }
    });
  }

  Future<void> _refreshSalesOrders() async {
    setState(() {
      currentPage = 0;
      salesOrders.clear();
      filteredSalesOrders.clear();
      hasMoreData = true;
      searchQuery = null;
      searchController.clear();
      selectedDateRange = null;
      selectedStatusFilter = null; // Reset status filter
      selectedWorkflowStateFilter = null; // Reset workflow state filter

      for (var state in allStatusValues) {
        statusCounts[state] = 0;
      }
      for (var state in allWorkflowStateValues) {
        workflowStateCounts[state] = 0;
      }
      connectionCache.clear();
      selectedOrder = null;
    });
    await fetchSalesOrders();
  }

  Future<void> fetchSalesOrders({bool loadMore = false}) async {
    if (isLoadingMore || (loadMore && !hasMoreData)) return;

    setState(() {
      if (!loadMore) {
        isLoading = true;
      } else {
        isLoadingMore = true;
      }
    });

    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_orders_detailed?page=$currentPage&page_size=$pageSize";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'];
        if (data['status'] != 'success') {
          throw Exception(data['message'] ?? 'Failed to load sales orders');
        }

        final List<dynamic> newOrders = List.from(data['sales_orders'] ?? []);

        if (mounted) {
          setState(() {
            if (!loadMore) {
              salesOrders = newOrders;
            } else {
              salesOrders.addAll(newOrders);
            }
            _updateStatusCounts(); // Update counts based on all fetched orders
            filterSalesOrders(searchController.text);
            currentPage++;
            hasMoreData = data['has_more'] == true;
          });
        }
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching sales orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching sales orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
      }
    }
  }

  // Method to update status counts for both 'status' and 'workflow_state' fields
  void _updateStatusCounts() {
    // Reset counts for both maps
    for (var state in allStatusValues) {
      statusCounts[state] = 0;
    }
    statusCounts['All'] = salesOrders.length;

    for (var state in allWorkflowStateValues) {
      workflowStateCounts[state] = 0;
    }
    workflowStateCounts['All'] = salesOrders.length;

    for (var order in salesOrders) {
      final status = order['status'] ?? 'Unknown';
      statusCounts.update(status, (value) => value + 1, ifAbsent: () => 1);

      final workflowState = order['workflow_state'] ?? 'Unknown';
      workflowStateCounts.update(
        workflowState,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }

  Future<Map<String, dynamic>> fetchConnections(String salesOrderId) async {
    if (connectionCache.containsKey(salesOrderId)) {
      return connectionCache[salesOrderId]!;
    }

    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_order_connections?sales_order_name=$salesOrderId";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          connectionCache[salesOrderId] = data['message'];
          return data['message'];
        } else {
          throw Exception('API returned unsuccessful status for connections');
        }
      } else {
        throw Exception('Failed to load connections: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching connections for $salesOrderId: $e');
      return {'status': 'error', 'sales_invoices': [], 'delivery_notes': []};
    }
  }

  void filterSalesOrders(String query) {
    setState(() {
      searchQuery = query;
      filteredSalesOrders =
          salesOrders.where((order) {
            final name = (order['name'] ?? '').toLowerCase();
            final customer = (order['customer_name'] ?? '').toLowerCase();
            final status = (order['status'] ?? '').toLowerCase();
            final workflowState = (order['workflow_state'] ?? '').toLowerCase();

            final matchesSearchQuery =
                query.isEmpty ||
                name.contains(query.toLowerCase()) ||
                customer.contains(query.toLowerCase());

            bool matchesDateRange = true;
            if (selectedDateRange != null) {
              final transactionDateStr = order['transaction_date'];
              if (transactionDateStr != null && transactionDateStr.isNotEmpty) {
                try {
                  final transactionDate = DateTime.parse(transactionDateStr);
                  matchesDateRange =
                      transactionDate.isAfter(
                        selectedDateRange!.start.subtract(
                          const Duration(days: 1),
                        ),
                      ) &&
                      transactionDate.isBefore(
                        selectedDateRange!.end.add(const Duration(days: 1)),
                      );
                } catch (e) {
                  matchesDateRange = false;
                }
              } else {
                matchesDateRange = false;
              }
            }

            // Filter by selected 'status'
            bool matchesStatusFilter = true;
            if (selectedStatusFilter != null && selectedStatusFilter != 'All') {
              matchesStatusFilter =
                  status == selectedStatusFilter!.toLowerCase();
            }

            // Filter by selected 'workflow_state'
            bool matchesWorkflowStateFilter = true;
            if (selectedWorkflowStateFilter != null &&
                selectedWorkflowStateFilter != 'All') {
              matchesWorkflowStateFilter =
                  workflowState == selectedWorkflowStateFilter!.toLowerCase();
            }

            return matchesSearchQuery &&
                matchesDateRange &&
                matchesStatusFilter &&
                matchesWorkflowStateFilter;
          }).toList()..sort(
            (a, b) => (b['transaction_date'] ?? '9999-12-31').compareTo(
              a['transaction_date'] ?? '9999-12-31',
            ),
          );
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF005BAC),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF333333),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDateRange) {
      setState(() {
        selectedDateRange = picked;
      });
      filterSalesOrders(searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedOrder != null
              ? (selectedOrder!['name'] ?? 'Sales Order Details')
              : 'Sales Orders',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF005BAC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (selectedOrder != null) {
              setState(() {
                selectedOrder = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: selectedOrder == null
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshSalesOrders,
                  tooltip: 'Refresh',
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.white),
                  onPressed: () {
                    if (selectedOrder != null) {
                      // Call print from the detail screen state to access its methods
                      _SalesOrderDetailScreenState? detailScreenState = context
                          .findAncestorStateOfType<
                            _SalesOrderDetailScreenState
                          >();
                      if (detailScreenState != null) {
                        detailScreenState._printSalesOrder(selectedOrder!);
                      } else {
                        // Fallback if state is not found (e.g., if navigated directly)
                        print(
                          'SalesOrderDetailScreenState not found for printing.',
                        );
                      }
                    }
                  },
                  tooltip: 'Print',
                ),
                IconButton(
                  icon: const Icon(Icons.save_alt, color: Colors.white),
                  onPressed: () {
                    if (selectedOrder != null) {
                      // Call save as PDF from the detail screen state
                      _SalesOrderDetailScreenState? detailScreenState = context
                          .findAncestorStateOfType<
                            _SalesOrderDetailScreenState
                          >();
                      if (detailScreenState != null) {
                        detailScreenState._saveAsPdf(selectedOrder!);
                      } else {
                        print(
                          'SalesOrderDetailScreenState not found for saving as PDF.',
                        );
                      }
                    }
                  },
                  tooltip: 'Save as PDF',
                ),
              ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF005BAC), Color(0xFFFFFFFF)],
          ),
        ),
        child: selectedOrder == null
            ? _buildListView(context)
            : SalesOrderDetailScreen(
                orderId: selectedOrder!['name'],
                serverUrl: widget.serverUrl,
                sid: widget.sid,
                fetchConnectionsCallback: fetchConnections,
                roles: widget.roles,
              ),
      ),
      floatingActionButton: selectedOrder == null
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSalesOrderScreen(
                      serverUrl: widget.serverUrl,
                      sid: widget.sid,
                    ),
                  ),
                );
                if (result == true) {
                  _refreshSalesOrders();
                }
              },
              backgroundColor: const Color(0xFF005BAC),
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Create New Sales Order',
            )
          : null,
    );
  }

  Widget _buildListView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Order ID or Customer',
                    hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: const Color(0xFF757575),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF757575),
                    ),
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
                      borderSide: const BorderSide(color: Color(0xFF005BAC)),
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.date_range, color: Colors.white),
                onPressed: () => _selectDateRange(context),
                tooltip: 'Select Date Range',
              ),
            ],
          ),
        ),
        if (selectedDateRange != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date Range: ${formatDate(selectedDateRange!.start.toString())} - ${formatDate(selectedDateRange!.end.toString())}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                  onPressed: () {
                    setState(() {
                      selectedDateRange = null;
                    });
                    filterSalesOrders(searchController.text);
                  },
                  tooltip: 'Clear Date Range',
                ),
              ],
            ),
          ),
        // Dropdown for 'status' field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF005BAC)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: selectedStatusFilter ?? 'All',
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.filter_list, color: Color(0xFF757575)),
                ),
                hint: Text(
                  'Filter by Status',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: const Color(0xFF757575),
                  ),
                ),
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: const Color(0xFF333333),
                ),
                dropdownColor: Colors.white,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedStatusFilter = newValue;
                  });
                  filterSalesOrders(searchController.text);
                },
                items: allStatusValues.map<DropdownMenuItem<String>>((
                  String value,
                ) {
                  final count = statusCounts[value] ?? 0;
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text('$value ($count)'),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        // Dropdown for 'workflow_state' field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF005BAC)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: selectedWorkflowStateFilter ?? 'All',
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.filter_alt,
                    color: Color(0xFF757575),
                  ), // Different icon for clarity
                ),
                hint: Text(
                  'Filter by Workflow State',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: const Color(0xFF757575),
                  ),
                ),
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: const Color(0xFF333333),
                ),
                dropdownColor: Colors.white,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedWorkflowStateFilter = newValue;
                  });
                  filterSalesOrders(searchController.text);
                },
                items: allWorkflowStateValues.map<DropdownMenuItem<String>>((
                  String value,
                ) {
                  final count = workflowStateCounts[value] ?? 0;
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text('$value ($count)'),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshSalesOrders,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : filteredSalesOrders.isEmpty
                ? Center(
                    child: Text(
                      'No sales orders found',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        filteredSalesOrders.length + (isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredSalesOrders.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      }

                      final order = filteredSalesOrders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: const Color(0xFFFFFFFF),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF005BAC),
                            child: Text(
                              order['customer_name']?[0] ?? 'N',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          title: Text(
                            order['name'] ?? 'No Order ID',
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF005BAC),
                                ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['customer_name'] ?? 'No Customer',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(color: const Color(0xFF333333)),
                              ),
                              Text(
                                'Date: ${formatDate(order['transaction_date'])}',
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(color: const Color(0xFF757575)),
                              ),
                              Text(
                                'Status: ${order['status'] ?? 'N/A'}', // Display 'status' field
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(color: const Color(0xFF757575)),
                              ),
                              Text(
                                'Workflow: ${order['workflow_state'] ?? 'N/A'}', // Display 'workflow_state' field
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(color: const Color(0xFF757575)),
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF005BAC),
                          ),
                          onTap: () {
                            setState(() {
                              selectedOrder = order;
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}

class SalesOrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String serverUrl;
  final String sid;
  final Future<Map<String, dynamic>> Function(String) fetchConnectionsCallback;
  final List<String> roles;

  const SalesOrderDetailScreen({
    Key? key,
    required this.orderId,
    required this.serverUrl,
    required this.sid,
    required this.fetchConnectionsCallback,
    required this.roles,
  }) : super(key: key);

  @override
  _SalesOrderDetailScreenState createState() => _SalesOrderDetailScreenState();
}

class _SalesOrderDetailScreenState extends State<SalesOrderDetailScreen> {
  Map<String, dynamic> orderDetails = {};
  bool isLoading = true;
  Map<String, dynamic>? connections;
  Map<String, dynamic>? taxDetails;
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<String> _sections = [
    'Order Details',
    'Customer Details',
    'Items',
    'Sales Taxes and Charges',
    'Financial Summary',
    'Sales Team',
    'Payment Schedule',
    'Connections',
  ];

  final List<IconData> _sectionIcons = [
    Icons.description,
    Icons.person,
    Icons.inventory,
    Icons.receipt,
    Icons.account_balance_wallet,
    Icons.group,
    Icons.schedule,
    Icons.link,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    fetchOrderDetails();
    fetchConnectionsData();
    fetchTaxDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Helper method to format dates
  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Helper method to remove HTML tags from strings
  String removeHtmlTags(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return 'N/A';
    final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlString.replaceAll(exp, ' ').trim();
  }

  // Helper method to convert numbers to words (Indian numbering system)
  String numberToWords(int number) {
    if (number == 0) return 'Zero';
    if (number < 0) return 'Minus ${numberToWords(number.abs())}';

    String words = '';
    const units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    const teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if ((number ~/ 10000000) > 0) {
      words += '${numberToWords(number ~/ 10000000)} Crore ';
      number %= 10000000;
    }
    if ((number ~/ 100000) > 0) {
      words += '${numberToWords(number ~/ 100000)} Lakh ';
      number %= 100000;
    }
    if ((number ~/ 1000) > 0) {
      words += '${numberToWords(number ~/ 1000)} Thousand ';
      number %= 1000;
    }
    if ((number ~/ 100) > 0) {
      words += '${numberToWords(number ~/ 100)} Hundred ';
      number %= 100;
    }

    if (number > 0) {
      if (words.isNotEmpty) words += 'and ';
      if (number < 10) {
        words += units[number];
      } else if (number < 20) {
        words += teens[number - 10];
      } else {
        words += tens[number ~/ 10];
        if (number % 10 > 0) words += ' ${units[number % 10]}';
      }
    }
    return words.trim();
  }

  Future<void> fetchOrderDetails() async {
    final url =
        "${widget.serverUrl}/api/resource/Sales Order/${widget.orderId}";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            orderDetails = data['data'] ?? {};
            isLoading = false;
          });
        }
      } else {
        throw Exception(
          'Failed to load sales order details: ${response.statusCode}',
        );
      }
    } catch (error) {
      print('Error: $error');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching sales order details: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> fetchConnectionsData() async {
    try {
      final data = await widget.fetchConnectionsCallback(widget.orderId);
      if (mounted) {
        setState(() {
          connections = data;
        });
      }
    } catch (error) {
      print('Error fetching connections: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching connections: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> fetchTaxDetails() async {
    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_order_with_taxes?sales_order_name=${widget.orderId}";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          if (mounted) {
            setState(() {
              taxDetails = data['message']['data'];
            });
          }
        } else {
          throw Exception('API returned unsuccessful status for taxes');
        }
      } else {
        throw Exception('Failed to load taxes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching tax details for ${widget.orderId}: $e');
      if (mounted) {
        setState(() {
          taxDetails = {'status': 'error', 'taxes': []};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching tax details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleWorkflowAction(String action, String nextState) async {
    final url =
        "${widget.serverUrl}/api/resource/Sales Order/${widget.orderId}";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final Map<String, dynamic> payload = {'workflow_state': nextState};

    // When GM approves, set the workflow_state to 'Approved By GM',
    // the status to 'To Deliver and Bill', and submit the document (docstatus: 1)
    if (nextState == 'Approved By GM') {
      payload['status'] = 'To Deliver and Bill';
      // Only submit the document if it's still a draft
      if (orderDetails['docstatus'] == 0) {
        payload['docstatus'] = 1; // Submit the document
      }
    }

    final body = json.encode(payload);
    print("Sending payload for workflow action: $body");

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action successful'),
            backgroundColor: Colors.green,
          ),
        );
        await fetchOrderDetails(); // Refresh details after action
      } else {
        print(
          "Workflow action failed. Status: ${response.statusCode}, Body: ${response.body}",
        );
        throw Exception('Failed to $action: ${response.statusCode}');
      }
    } catch (e) {
      print("Error during workflow action: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during $action: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, String>> _getWorkflowButtons() {
    final currentState = orderDetails['workflow_state'] ?? 'Draft';
    final userRoles = widget.roles;
    final List<Map<String, String>> buttons = [];

    // Allow Review from Draft for Sales Person, RM
    if (currentState == 'Draft' &&
        (userRoles.contains('Sakthi Sales Person') ||
            userRoles.contains('Sakthi RM'))) {
      buttons.add({'action': 'Review', 'next_state': 'Pending'});
    }

    // Allow GM to approve directly from Draft
    if (currentState == 'Draft' && userRoles.contains('Sakthi GM')) {
      buttons.add({'action': 'Approve', 'next_state': 'Approved By GM'});
    }

    // Allow Submit from Reviewed for Sales User (assuming 'Reviewed' is a state before 'Pending' for general sales users)
    if (currentState == 'Reviewed' && userRoles.contains('Sales User')) {
      buttons.add({'action': 'Submit', 'next_state': 'Pending'});
    }
    // RM Approval/Rejection from Pending
    if (currentState == 'Pending' && userRoles.contains('Sakthi RM')) {
      buttons.add({'action': 'Approve', 'next_state': 'Approved By RM'});
      buttons.add({'action': 'Reject', 'next_state': 'Rejected By RM'});
    }
    // GM Approval/Rejection from Pending
    if (currentState == 'Pending' && userRoles.contains('Sakthi GM')) {
      buttons.add({'action': 'Approve', 'next_state': 'Approved By GM'});
      buttons.add({'action': 'Reject', 'next_state': 'Rejected By GM'});
    }
    // GM Approval/Rejection from Approved By RM
    if (currentState == 'Approved By RM' && userRoles.contains('Sakthi GM')) {
      buttons.add({'action': 'Approve', 'next_state': 'Approved By GM'});
      buttons.add({'action': 'Reject', 'next_state': 'Rejected By GM'});
    }
    // Mark as Completed
    if (currentState == 'To Deliver and Bill' ||
        currentState == 'To Deliver' ||
        currentState == 'To Bill') {
      buttons.add({'action': 'Mark as Completed', 'next_state': 'Completed'});
    }
    // Allow Cancel from Approved By GM, To Deliver and Bill, To Deliver, To Bill
    if (currentState == 'Approved By GM' ||
        currentState == 'To Deliver and Bill' ||
        currentState == 'To Deliver' ||
        currentState == 'To Bill') {
      buttons.add({'action': 'Cancel', 'next_state': 'Cancelled'});
    }

    return buttons;
  }

  void _onNavItemTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _printSalesOrder(Map<String, dynamic> orderDetails) async {
    if (orderDetails.isEmpty) return;
    final pdf = await _generatePdf(orderDetails);
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsPdf(Map<String, dynamic> orderDetails) async {
    if (orderDetails.isEmpty) return;
    final pdf = await _generatePdf(orderDetails);
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'sales_order_${orderDetails['name']}.pdf',
    );
  }

  Future<pw.Document> _generatePdf(Map<String, dynamic> orderDetails) async {
    final pdf = pw.Document();
    final items = orderDetails['items'] as List<dynamic>? ?? [];

    final totalQuantity = items.fold(
      0,
      (sum, item) => sum + (item['qty'] as num? ?? 0).toInt(),
    );
    final totalAmount = items.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as num? ?? 0).toDouble(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 6.0),
          child: pw.Text(
            'SAKTHI STEEL INDUSTRIES LTD, Madurai',
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SAKTHI STEEL INDUSTRIES LTD',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SALES ORDER',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        orderDetails['name'] ?? '',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Customer Name:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(orderDetails['customer'] ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Date:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          formatDate(orderDetails['transaction_date']) ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'PO No:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(orderDetails['po_no'] ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'PO Date:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          formatDate(orderDetails['po_date']) ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Address:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          removeHtmlTags(orderDetails['address_display']) ??
                              'N/A',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Delivery Date:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          formatDate(orderDetails['delivery_date']) ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(60),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _pdfTableHeader('Sr'),
                      _pdfTableHeader('Item'),
                      _pdfTableHeader('Quantity'),
                      _pdfTableHeader('Rate'),
                      _pdfTableHeader('Amount'),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    return pw.TableRow(
                      children: [
                        _pdfTableCell(index.toString()),
                        _pdfTableCell(
                          item['item_code'] ?? item['item_name'] ?? '',
                        ),
                        _pdfTableCell(item['qty'].toString()),
                        _pdfTableCell('INR ${item['rate'] ?? 0}'),
                        _pdfTableCell('INR ${item['amount'] ?? 0}'),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 200),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Quantity: $totalQuantity',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Total: INR $totalAmount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Grand Total: INR $totalAmount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'In Words: INR ${numberToWords(totalAmount.toInt())} only.',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
    return pdf;
  }

  pw.Widget _pdfTableHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workflowButtons = _getWorkflowButtons();

    return isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : orderDetails.isEmpty
        ? Center(
            child: Text(
              'Sales order not found',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Colors.white),
            ),
          )
        : Column(
            children: [
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_sections.length, (index) {
                      final isSelected = _selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _onNavItemTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF005BAC),
                                        Color(0xFF757575),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(
                                        0xFF757575,
                                      ).withOpacity(0.5),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _sectionIcons[index],
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _sections[index],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    height: 2,
                                    width: 30,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF005BAC),
                                          Color(0xFF757575),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              if (workflowButtons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: workflowButtons.map((button) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              _handleWorkflowAction(
                                button['action']!,
                                button['next_state']!,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  button['action']!.toLowerCase().contains(
                                        'reject',
                                      ) ||
                                      button['action']!.toLowerCase().contains(
                                        'cancel',
                                      )
                                  ? Colors.red
                                  : const Color(0xFF005BAC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(button['action']!),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  children: [
                    _buildOrderDetailsSection(),
                    _buildCustomerDetailsSection(),
                    _buildItemsSection(),
                    _buildSalesTaxesSection(),
                    _buildFinancialSummarySection(),
                    _buildSalesTeamSection(),
                    _buildPaymentScheduleSection(),
                    _buildConnectionsSection(),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildOrderDetailsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Order Details'),
              const SizedBox(height: 16),
              _buildInfoRow('Order ID', orderDetails['name']),
              _buildInfoRow('Title', orderDetails['customer']),
              _buildInfoRow('Naming Series', orderDetails['naming_series']),
              _buildInfoRow('Order Type', orderDetails['order_type']),
              _buildInfoRow(
                'Transaction Date',
                formatDate(orderDetails['transaction_date']),
              ),
              _buildInfoRow(
                'Delivery Date',
                formatDate(orderDetails['delivery_date']),
              ),
              _buildInfoRow('PO Number', orderDetails['po_no']),
              _buildInfoRow('PO Date', formatDate(orderDetails['po_date'])),
              _buildInfoRow('Company', orderDetails['company']),
              _buildInfoRow('Status', orderDetails['status']),
              _buildInfoRow('Delivery Status', orderDetails['delivery_status']),
              _buildInfoRow('Billing Status', orderDetails['billing_status']),
              _buildInfoRow('Letter Head', orderDetails['letter_head']),
              _buildInfoRow('Owner', orderDetails['owner']),
              _buildInfoRow('Creation', orderDetails['creation']),
              _buildInfoRow('Modified', orderDetails['modified']),
              _buildInfoRow('Modified By', orderDetails['modified_by']),
              _buildInfoRow('Workflow State', orderDetails['workflow_state']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDetailsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Customer Details'),
              const SizedBox(height: 16),
              _buildInfoRow('Customer', orderDetails['customer']),
              _buildInfoRow(
                'Customer Name',
                orderDetails['customer_name'],
                isBold: true,
                color: const Color(0xFF2E7D32),
              ),
              _buildInfoRow(
                'Address Display',
                removeHtmlTags(orderDetails['address_display']),
              ),
              _buildInfoRow(
                'Tax Category',
                orderDetails['tax_category'] ?? 'N/A',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Items'),
              const SizedBox(height: 16),
              ...(orderDetails['items'] as List<dynamic>? ?? [])
                  .asMap()
                  .entries
                  .map((entry) {
                    final index = entry.key;
                    final item = entry.value as Map<String, dynamic>;
                    final itemCode = item['item_code'] ?? 'N/A';
                    final itemName = item['item_name'] ?? 'N/A';
                    final qty = item['qty']?.toString() ?? '0';
                    final amount =
                        '${item['amount'] ?? 0} ${orderDetails['currency'] ?? 'N/A'}';
                    final transactionDate = formatDate(
                      item['transaction_date'],
                    );
                    final total = amount;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSubSectionTitle('Item ${index + 1}'),
                              _buildInfoRow('Item Code', itemCode),
                              _buildInfoRow(
                                'Item Name',
                                itemName,
                                isBold: true,
                                color: const Color(0xFF2E7D32),
                              ),
                              _buildInfoRow(
                                'Quantity',
                                qty,
                                isBold: true,
                                color: const Color(0xFF2E7D32),
                              ),
                              _buildInfoRow(
                                'Rate',
                                '${item['rate']} ${orderDetails['currency']}',
                                isBold: true,
                                color: const Color(0xFF2E7D32),
                              ),
                              _buildInfoRow('Amount', amount),
                              _buildInfoRow(
                                'Transaction Date',
                                transactionDate,
                              ),
                              _buildInfoRow('Total', total),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTaxesSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Sales Taxes and Charges'),
              const SizedBox(height: 16),
              if (taxDetails == null)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF005BAC)),
                )
              else if (taxDetails!['status'] == 'error' ||
                  (taxDetails!['taxes'] as List).isEmpty)
                Text(
                  'No tax details available',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: const Color(0xFF333333),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Sales Order',
                      taxDetails!['sales_order'] ?? 'N/A',
                    ),
                    _buildInfoRow('Customer', taxDetails!['customer'] ?? 'N/A'),
                    _buildInfoRow('Company', taxDetails!['company'] ?? 'N/A'),
                    _buildInfoRow(
                      'Posting Date',
                      formatDate(taxDetails!['posting_date']) ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Tax Template',
                      taxDetails!['tax_template'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Total Taxes and Charges',
                      '${taxDetails!['total_taxes_and_charges']} ${orderDetails['currency'] ?? 'N/A'}',
                    ),
                    _buildInfoRow(
                      'Grand Total',
                      '${taxDetails!['grand_total']} ${orderDetails['currency'] ?? 'N/A'}',
                    ),
                    const SizedBox(height: 8),
                    ...((taxDetails!['taxes'] as List<dynamic>).asMap().entries.map((
                      entry,
                    ) {
                      final index = entry.key;
                      final tax = entry.value as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSubSectionTitle('Tax ${index + 1}'),
                                _buildInfoRow(
                                  'Charge Type',
                                  tax['charge_type'] ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  'Account Head',
                                  tax['account_head'] ?? 'N/A',
                                  isBold: true,
                                  color: const Color(0xFF2E7D32),
                                ),
                                _buildInfoRow(
                                  'Description',
                                  tax['description'] ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  'Rate',
                                  '${tax['rate'] ?? 0}%',
                                  isBold: true,
                                  color: const Color(0xFF2E7D32),
                                ),
                                _buildInfoRow(
                                  'Tax Amount',
                                  '${tax['tax_amount'] ?? 0} ${orderDetails['currency'] ?? 'N/A'}',
                                ),
                                _buildInfoRow(
                                  'Total',
                                  '${tax['total'] ?? 0} ${orderDetails['currency'] ?? 'N/A'}',
                                ),
                                _buildInfoRow(
                                  'Cost Center',
                                  tax['cost_center'] ?? 'N/A',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList()),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialSummarySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Financial Summary'),
              const SizedBox(height: 16),
              _buildInfoRow('Currency', orderDetails['currency']),
              _buildInfoRow(
                'Total Quantity',
                orderDetails['total_qty'].toString(),
              ),
              _buildInfoRow(
                'Net Total',
                '${orderDetails['net_total']} ${orderDetails['currency']}',
              ),
              _buildInfoRow(
                'Total Taxes and Charges',
                '${orderDetails['total_taxes_and_charges']} ${orderDetails['currency']}',
              ),
              _buildInfoRow(
                'Base Grand Total',
                '${orderDetails['base_grand_total']} ${orderDetails['currency']}',
              ),
              _buildInfoRow(
                'Base Rounding Adjustment',
                '${orderDetails['base_rounding_adjustment']} ${orderDetails['currency']}',
              ),
              _buildInfoRow(
                'Rounded Total',
                '${orderDetails['rounded_total']} ${orderDetails['currency']}',
              ),
              _buildInfoRow('In Words', orderDetails['in_words']),
              _buildInfoRow(
                'Advance Paid',
                '${orderDetails['advance_paid']} ${orderDetails['currency']}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTeamSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Sales Team'),
              const SizedBox(height: 16),
              ...(orderDetails['sales_team'] as List<dynamic>? ?? [])
                  .asMap()
                  .entries
                  .map((entry) {
                    final index = entry.key;
                    final member = entry.value as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSubSectionTitle(
                                'Sales Person ${index + 1}',
                              ),
                              _buildInfoRow(
                                'Sales Person',
                                member['sales_person'],
                                isBold: true,
                                color: const Color(0xFF2E7D32),
                              ),
                              _buildInfoRow(
                                'Allocated Percentage',
                                member['allocated_percentage'].toString(),
                              ),
                              _buildInfoRow(
                                'Allocated Amount',
                                '${member['allocated_amount']} ${orderDetails['currency']}',
                              ),
                              _buildInfoRow(
                                'Incentives',
                                '${member['incentives']} ${orderDetails['currency']}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentScheduleSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Payment Schedule'),
              const SizedBox(height: 16),
              ...(orderDetails['payment_schedule'] as List<dynamic>? ?? []).asMap().entries.map((
                entry,
              ) {
                final index = entry.key;
                final schedule = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubSectionTitle('Payment ${index + 1}'),
                          _buildInfoRow(
                            'Due Date',
                            formatDate(schedule['due_date']),
                          ),
                          _buildInfoRow(
                            'Invoice Portion',
                            schedule['invoice_portion'].toString(),
                          ),
                          _buildInfoRow(
                            'Discount',
                            '${schedule['discount']} ${orderDetails['currency']}',
                          ),
                          _buildInfoRow(
                            'Payment Amount',
                            '${schedule['payment_amount']} ${orderDetails['currency']}',
                          ),
                          _buildInfoRow(
                            'Outstanding',
                            '${schedule['outstanding']} ${orderDetails['currency']}',
                          ),
                          _buildInfoRow(
                            'Paid Amount',
                            '${schedule['paid_amount']} ${orderDetails['currency']}',
                          ),
                          _buildInfoRow(
                            'Discounted Amount',
                            '${schedule['discounted_amount']} ${orderDetails['currency']}',
                          ),
                          _buildInfoRow(
                            'Base Payment Amount',
                            '${schedule['base_payment_amount']} ${orderDetails['currency']}',
                          ),
                          _buildInfoRow(
                            'Base Outstanding',
                            '${schedule['base_outstanding']} ${orderDetails['currency']}',
                          ),
                          _buildInfoRow(
                            'Base Paid Amount',
                            '${schedule['base_paid_amount']} ${orderDetails['currency']}',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Connections'),
              const SizedBox(height: 16),
              connections == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF005BAC),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildConnectionRow(
                          'Delivery Notes',
                          (connections!['delivery_notes'] as List<dynamic>? ??
                                  [])
                              .length,
                          const Color(0xFF757575),
                        ),
                        const SizedBox(height: 8),
                        ...(connections!['delivery_notes'] as List<dynamic>? ??
                                [])
                            .map(
                              (note) => _buildConnectionItem(
                                note['name'] ?? 'N/A',
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/salesInvoiceDetail', // Assuming Delivery Notes link to SalesInvoiceDetailScreen for simplicity. Adjust if a dedicated DeliveryNoteDetailScreen exists.
                                    arguments: {
                                      'invoiceId': note['name'],
                                      'serverUrl': widget.serverUrl,
                                      'sid': widget.sid,
                                    },
                                  );
                                },
                              ),
                            ),
                        const SizedBox(height: 16),
                        _buildConnectionRow(
                          'Sales Invoices',
                          (connections!['sales_invoices'] as List<dynamic>? ??
                                  [])
                              .length,
                          const Color(0xFF757575),
                        ),
                        const SizedBox(height: 8),
                        ...(connections!['sales_invoices'] as List<dynamic>? ??
                                [])
                            .map(
                              (invoice) => _buildConnectionItem(
                                invoice['name'] ?? 'N/A',
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/salesInvoiceDetail',
                                    arguments: {
                                      'invoiceId': invoice['name'],
                                      'serverUrl': widget.serverUrl,
                                      'sid': widget.sid,
                                    },
                                  );
                                },
                              ),
                            ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionRow(String label, int count, Color badgeColor) {
    return Row(
      children: [
        Text(
          '$label ($count)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: badgeColor == const Color(0xFF757575)
                  ? Colors.white
                  : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionItem(String name, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.arrow_right, color: Color(0xFF005BAC), size: 16),
            const SizedBox(width: 4),
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: const Color(0xFF005BAC)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF005BAC),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF005BAC),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String? value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF333333),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? const Color(0xFF333333),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
