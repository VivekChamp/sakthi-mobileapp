import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SalesInvoiceScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final List<String>? filterIds; // Optional filter for connected sales invoices

  const SalesInvoiceScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    this.filterIds,
  }) : super(key: key);

  @override
  _SalesInvoiceScreenState createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  List<dynamic> salesInvoices = [];
  List<dynamic> filteredInvoices = [];
  List<String>? filterIds; // To store filterIds if passed via navigation
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 0; // API uses 0-based indexing
  final int pageSize = 20; // Fetch 20 invoices per page
  bool hasMore = true;
  TextEditingController searchController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  String? searchQuery;
  bool isSessionValid = true;
  DateTimeRange? selectedDateRange; // Store the selected date range
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Check for filterIds passed via navigation
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final arguments = ModalRoute.of(context)?.settings.arguments as Map?;
      if (arguments != null && arguments.containsKey('filterIds')) {
        filterIds = List<String>.from(arguments['filterIds']);
        print('Filter IDs received: $filterIds'); // Debug log
      } else {
        filterIds = widget.filterIds;
      }
      // Validate session before fetching invoices
      await validateSession();
      if (isSessionValid) {
        fetchSalesInvoices();
      }
    });
    searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Future.delayed(const Duration(milliseconds: 300), () {
      filterInvoices(searchController.text);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      fetchSalesInvoices(loadMore: true);
    }
  }

  // Method to validate the session
  Future<void> validateSession() async {
    final url = "${widget.serverUrl}/api/method/frappe.auth.get_logged_user";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };

    try {
      print('Validating session: $url'); // Debug log
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 4));
      print('Session Validation Response Status: ${response.statusCode}');
      print('Session Validation Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null) {
          print('Session is valid for user: ${data['message']}');
          setState(() {
            isSessionValid = true;
          });
        } else {
          throw Exception('Invalid session response');
        }
      } else {
        throw Exception('Session validation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error validating session: $e');
      setState(() {
        isSessionValid = false;
      });
      // Navigate to login screen if session is invalid
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // Method to refresh the sales invoices
  Future<void> _refreshSalesInvoices() async {
    setState(() {
      currentPage = 0;
      salesInvoices.clear();
      filteredInvoices.clear();
      hasMore = true;
      searchQuery = null;
      searchController.clear();
      selectedDateRange = null; // Clear the date range on refresh
      errorMessage = '';
      // Do not clear filterIds to maintain navigation context
    });
    await fetchSalesInvoices();
  }

  Future<void> fetchSalesInvoices({bool loadMore = false}) async {
    if (loadMore && !hasMore) return;

    setState(() {
      if (!loadMore) {
        isLoading = true;
      } else {
        isLoadingMore = true;
      }
      errorMessage = '';
    });

    // Construct the API URL with pagination
    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_invoices?page=$currentPage&page_size=$pageSize";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache', // Prevent caching
    };

    try {
      print('Fetching sales invoices from API: $url'); // Debug log
      print('Headers: $headers'); // Debug log
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      print('API Response Status: ${response.statusCode}'); // Debug log
      print('API Response Body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['error'] != null) {
          throw Exception(data['message']['error']);
        }
        if (data['message']['message'] ==
                'Sales Invoices fetched successfully.' ||
            data['message']['message'] == 'No Sales Invoices found.') {
          setState(() {
            List<dynamic> newInvoices = List.from(
              data['message']['sales_invoices'] ?? [],
            );

            // Apply filterIds client-side if present
            if (filterIds != null && filterIds!.isNotEmpty) {
              newInvoices = newInvoices
                  .where((invoice) => filterIds!.contains(invoice['name']))
                  .toList();
            }

            if (!loadMore) {
              salesInvoices = newInvoices;
            } else {
              salesInvoices.addAll(newInvoices);
            }

            filteredInvoices = List.from(salesInvoices)
              ..sort(
                (a, b) => (b['posting_date'] ?? '9999-12-31').compareTo(
                  a['posting_date'] ?? '9999-12-31',
                ),
              );

            if (searchQuery != null && searchQuery!.isNotEmpty) {
              filterInvoices(searchQuery!);
            }

            currentPage++;
            hasMore =
                data['message']['has_more'] == true &&
                (filterIds == null ||
                    filterIds!.isEmpty); // No pagination if filtered
            isLoading = false;
            isLoadingMore = false;
          });
          print('Fetched sales invoices: ${salesInvoices.length}');
        } else {
          throw Exception(
            data['message']['message'] ?? 'Failed to load invoices',
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching invoices: $e');
      setState(() {
        isLoading = false;
        isLoadingMore = false;
        errorMessage = 'Error fetching invoices: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  void filterInvoices(String query) {
    setState(() {
      searchQuery = query;
      filteredInvoices =
          salesInvoices.where((invoice) {
            // Filter by search query (invoice ID or customer)
            final name = (invoice['name'] ?? '').toLowerCase();
            final customer = (invoice['customer_name'] ?? '').toLowerCase();
            final matchesSearchQuery =
                query.isEmpty ||
                name.contains(query.toLowerCase()) ||
                customer.contains(query.toLowerCase());

            // Filter by date range
            bool matchesDateRange = true;
            if (selectedDateRange != null) {
              final postingDateStr = invoice['posting_date'];
              if (postingDateStr != null && postingDateStr.isNotEmpty) {
                try {
                  final postingDate = DateTime.parse(postingDateStr);
                  matchesDateRange =
                      postingDate.isAfter(
                        selectedDateRange!.start.subtract(
                          const Duration(days: 1),
                        ),
                      ) &&
                      postingDate.isBefore(
                        selectedDateRange!.end.add(const Duration(days: 1)),
                      );
                } catch (e) {
                  matchesDateRange = false; // Skip invalid dates
                }
              } else {
                matchesDateRange = false; // No date, doesn't match
              }
            }

            return matchesSearchQuery && matchesDateRange;
          }).toList()..sort(
            (a, b) => (b['posting_date'] ?? '9999-12-31').compareTo(
              a['posting_date'] ?? '9999-12-31',
            ),
          );
    });
  }

  // Method to show the date range picker
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
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
      filterInvoices(
        searchController.text,
      ); // Reapply filter with new date range
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isSessionValid) {
      return Scaffold(
        body: Center(
          child: Text(
            'Session expired. Redirecting to login...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales Invoices',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshSalesInvoices,
          ),
        ],
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Invoice ID or Customer',
                        hintStyle: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
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
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
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
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedDateRange = null;
                        });
                        filterInvoices(searchController.text);
                      },
                      tooltip: 'Clear Date Range',
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshSalesInvoices,
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : errorMessage.isNotEmpty
                    ? Center(
                        child: Text(
                          errorMessage,
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : filteredInvoices.isEmpty
                    ? Center(
                        child: Text(
                          'No invoices found',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredInvoices.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filteredInvoices.length && hasMore) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton(
                                onPressed: isLoadingMore
                                    ? null
                                    : () => fetchSalesInvoices(loadMore: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isLoadingMore
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'Load More',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            );
                          }

                          final invoice = filteredInvoices[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Text(
                                  invoice['name']?[0].toUpperCase() ?? 'N',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                invoice['name'] ?? 'No Invoice ID',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invoice['customer_name'] ?? 'No Customer',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(color: Colors.black87),
                                  ),
                                  Text(
                                    'Date: ${formatDate(invoice['posting_date'])}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.grey),
                                  ),
                                  Text(
                                    'Total: ${invoice['currency'] ?? ''} ${invoice['grand_total']?.toStringAsFixed(2) ?? '0.00'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.arrow_forward,
                                color: Theme.of(context).colorScheme.primary,
                              ),
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
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
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
