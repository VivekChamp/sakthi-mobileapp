import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VisitEntryListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const VisitEntryListScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _VisitEntryListScreenState createState() => _VisitEntryListScreenState();
}

class _VisitEntryListScreenState extends State<VisitEntryListScreen> {
  List<dynamic> _visitEntries = [];
  List<dynamic> _filteredVisitEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVisitEntries();
    _searchController.addListener(() {
      _filterVisitEntries(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVisitEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_visit_entries';
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
            _visitEntries = List.from(data['message']['data'] ?? []);
            _filteredVisitEntries = List.from(_visitEntries);
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching visit entries: $error';
      });
    }
  }

  void _filterVisitEntries(String query) {
    setState(() {
      _filteredVisitEntries = query.isEmpty
          ? List.from(_visitEntries)
          : _visitEntries
                .where(
                  (v) =>
                      (v['customer_name'] ?? '').toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      (v['name'] ?? '').toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Visit Entries',
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
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/createVisitEntry',
                arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
              ).then(
                (_) => _fetchVisitEntries(),
              ); // Refresh list after creating new entry
            },
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
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or customer',
                  hintStyle: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchVisitEntries,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.white,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : _filteredVisitEntries.isEmpty
                    ? Center(
                        child: Text(
                          'No visit entries available',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredVisitEntries.length,
                        itemBuilder: (ctx, index) {
                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Text(
                                  (_filteredVisitEntries[index]['customer_name'] ??
                                          'N')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                _filteredVisitEntries[index]['name'] ??
                                    'No name',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              subtitle: Text(
                                _filteredVisitEntries[index]['customer_name'] ??
                                    'No customer',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              trailing: Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/visitEntryDetail',
                                  arguments: {
                                    'visitEntryName':
                                        _filteredVisitEntries[index]['name'],
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
}
