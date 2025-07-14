import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/payment_entry.dart';

class PaymentEntryListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const PaymentEntryListScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _PaymentEntryListScreenState createState() => _PaymentEntryListScreenState();
}

class _PaymentEntryListScreenState extends State<PaymentEntryListScreen> {
  List<PaymentEntry> paymentEntries = [];
  List<PaymentEntry> filteredPaymentEntries = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 1;
  final int pageSize = 20; // Number of payment entries to fetch per page
  TextEditingController searchController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  bool hasMoreData = true;
  String? searchQuery;

  @override
  void initState() {
    super.initState();
    fetchPaymentEntries();
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
      fetchPaymentEntries(loadMore: true);
    }
  }

  void _onSearchChanged() {
    Future.delayed(Duration(milliseconds: 300), () {
      filterPaymentEntries(searchController.text);
    });
  }

  Future<void> fetchPaymentEntries({bool loadMore = false}) async {
    if (loadMore && !hasMoreData) return;

    setState(() {
      if (!loadMore) {
        isLoading = true;
      } else {
        isLoadingMore = true;
      }
    });

    final url =
        "${widget.serverUrl} /api/method/vps_mobile.vps_mobile.role_api.get_payment_entry?page=$currentPage&limit=$pageSize";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'];
        final List<dynamic> newEntries = List.from(
          data['payment_entries'] ?? [],
        );

        setState(() {
          if (!loadMore) {
            paymentEntries = newEntries
                .map((entry) => PaymentEntry.fromJson(entry))
                .toList();
          } else {
            paymentEntries.addAll(
              newEntries.map((entry) => PaymentEntry.fromJson(entry)).toList(),
            );
          }

          filteredPaymentEntries = List.from(paymentEntries)
            ..sort(
              (a, b) => (b.postingDate ?? '9999-12-31').compareTo(
                a.postingDate ?? '9999-12-31',
              ),
            );

          if (searchQuery != null && searchQuery!.isNotEmpty) {
            filterPaymentEntries(searchQuery!);
          }

          currentPage++;
          hasMoreData = data['has_more'] == true; // Use API's has_more flag
          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        throw Exception(
          'Failed to load payment entries: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching payment entries: $e');
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching payment entries: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void filterPaymentEntries(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredPaymentEntries = List.from(paymentEntries)
          ..sort(
            (a, b) => (b.postingDate ?? '9999-12-31').compareTo(
              a.postingDate ?? '9999-12-31',
            ),
          );
      } else {
        filteredPaymentEntries =
            paymentEntries.where((entry) {
              final name = (entry.name ?? '').toLowerCase();
              final party = (entry.partyName ?? '').toLowerCase();
              return name.contains(query.toLowerCase()) ||
                  party.contains(query.toLowerCase());
            }).toList()..sort(
              (a, b) => (b.postingDate ?? '9999-12-31').compareTo(
                a.postingDate ?? '9999-12-31',
              ),
            );
      }
    });
  }

  void showEntryDetailsDialog(BuildContext context, PaymentEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            entry.name ?? 'Payment Entry Details',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Party Name', entry.partyName),
                _buildInfoRow('Payment Type', entry.paymentType),
                _buildInfoRow('Status', entry.status),
                _buildInfoRow('Posting Date', formatDate(entry.postingDate)),
                _buildInfoRow(
                  'Paid Amount',
                  entry.paidAmount?.toStringAsFixed(2) ?? '0',
                ),
                _buildInfoRow('Mode of Payment', entry.modeOfPayment),
                SizedBox(height: 16),
                Text(
                  'Remarks',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  entry.remarks ?? 'No remarks',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment Entries',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Entry ID or Party',
                  hintStyle: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
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
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : filteredPaymentEntries.isEmpty
                  ? Center(
                      child: Text(
                        'No payment entries found',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          filteredPaymentEntries.length + (hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredPaymentEntries.length &&
                            hasMoreData) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton(
                              onPressed: isLoadingMore
                                  ? null
                                  : () => fetchPaymentEntries(loadMore: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isLoadingMore
                                  ? CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      'Load More',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          );
                        }

                        final entry = filteredPaymentEntries[index];
                        return Card(
                          margin: EdgeInsets.symmetric(
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
                                entry.name?[0] ?? 'P',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            title: Text(
                              entry.name ?? 'No Entry ID',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.partyName ?? 'No Party',
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(color: Colors.black87),
                                ),
                                Text(
                                  'Date: ${formatDate(entry.postingDate)}',
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onTap: () => showEntryDetailsDialog(context, entry),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/paymentEntryCreate',
            arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
          );
          if (result == true) {
            setState(() {
              currentPage = 1;
              paymentEntries.clear();
              filteredPaymentEntries.clear();
              hasMoreData = true;
            });
            fetchPaymentEntries();
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return dateStr ?? 'N/A';
    }
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'N/A',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
