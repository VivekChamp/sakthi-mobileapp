import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final String serverUrl;
  final String sid;

  const CustomerDetailScreen({
    Key? key,
    required this.customer,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CustomerDetailScreenState createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic> customerDetails = {};
  bool isLoading = true;
  String errorMessage = '';
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<String> _sections = [
    'Basic Information',
    'Address Information',
    'Credit Limits', // Moved Credit Limits here
    'Contact Information',
    'Bank Details',
    'Attachments',
    // 'Location', // Commented out as in original
    'Sales Team',
  ];

  final List<IconData> _sectionIcons = [
    Icons.person,
    Icons.location_on,
    Icons.account_balance_wallet, // Moved Credit Limits icon here
    Icons.contact_phone,
    Icons.account_balance,
    Icons.attachment,
    // Icons.map, // Commented out as in original
    Icons.group,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchCustomerDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerDetails() async {
    final customerName =
        widget.customer['name'] ?? ''; // Use 'name' (e.g., DUN01)
    if (customerName.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = 'Invalid customer name';
      });
      return;
    }

    final url = "${widget.serverUrl}/api/resource/Customer/$customerName";
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
        setState(() {
          customerDetails = data['data'] ?? {};
          isLoading = false;
          errorMessage = '';
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching customer details: $e';
      });
    }
  }

  String removeHtmlTags(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return 'N/A';
    final RegExp exp = RegExp(
      r'<[^>]*>',
      multiLine: true,
      caseSensitive: false,
    );
    return htmlString.replaceAll(exp, ' ').trim();
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

  Widget _buildInfoRow(String label, dynamic value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF005BAC),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: const Color(0xFF333333),
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInformationSection() {
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
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Customer Name',
                customerDetails['customer_name'],
                isBold: true,
              ),
              _buildInfoRow('Customer Type', customerDetails['customer_type']),
              _buildInfoRow(
                'Customer Group',
                customerDetails['customer_group'],
              ),
              _buildInfoRow('Sub Group', customerDetails['custom_sub_group']),
              _buildInfoRow(
                'Target',
                customerDetails['custom_target']?.toString(),
              ),
              _buildInfoRow('PHP ID', customerDetails['custom_php_id']),
              _buildInfoRow(
                'Brand Dealing',
                customerDetails['custom_brand_dealing'],
              ),
              _buildInfoRow(
                'MSME Category',
                customerDetails['custom_msme_cat'],
              ),
              _buildInfoRow(
                'Annual Turnover',
                customerDetails['custom_annual_turnover']?.toString(),
              ),
              _buildInfoRow(
                'Classification',
                customerDetails['custom_classification'],
              ),
              _buildInfoRow('Payment Terms', customerDetails['payment_terms']),
              _buildInfoRow('GSTIN', customerDetails['gstin']),
              _buildInfoRow('PAN', customerDetails['pan']),
              _buildInfoRow('GST Category', customerDetails['gst_category']),
              _buildInfoRow('LHS ID', customerDetails['custom_lhs_id']),
              _buildInfoRow(
                'Is Internal Customer',
                customerDetails['is_internal_customer'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Is Frozen',
                customerDetails['is_frozen'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Disabled',
                customerDetails['disabled'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow('Owner', customerDetails['owner']),
              _buildInfoRow('Creation', customerDetails['creation']),
              _buildInfoRow('Modified', customerDetails['modified']),
              _buildInfoRow('Modified By', customerDetails['modified_by']),
              _buildInfoRow(
                'Account Manager',
                customerDetails['account_manager'],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressInformationSection() {
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
              _buildSectionTitle('Address Information'),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Primary Address',
                removeHtmlTags(customerDetails['primary_address']),
              ),
              _buildInfoRow(
                'Customer Primary Address',
                customerDetails['customer_primary_address'],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactInformationSection() {
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
              _buildSectionTitle('Contact Information'),
              const SizedBox(height: 16),
              _buildInfoRow('Phone Number', customerDetails['phone']),
              _buildInfoRow('Email', customerDetails['email_id']),
              _buildInfoRow(
                'Contact Person Name',
                customerDetails['contact_person_name'],
              ),
              _buildInfoRow(
                'Customer Owner',
                customerDetails['custom_customer_owner'],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankDetailsSection() {
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
              _buildSectionTitle('Bank Details'),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Account Number',
                customerDetails['custom_account_no'],
              ),
              _buildInfoRow('Bank Name', customerDetails['custom_bank_name']),
              _buildInfoRow('Branch', customerDetails['custom_branch']),
              _buildInfoRow('IFSC Code', customerDetails['custom_ifsc_code']),
              _buildInfoRow(
                'Security Cheque Number',
                customerDetails['custom_security_cheque_no'],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
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
              _buildSectionTitle('Attachments'),
              const SizedBox(height: 16),
              _buildInfoRow(
                'GST Certificate',
                customerDetails['custom_gst_certificate'],
              ),
              _buildInfoRow(
                'Aadhar Card',
                customerDetails['custom_adhar_card'],
              ),
              _buildInfoRow(
                'Other Document',
                customerDetails['custom_other_document'],
              ),
              _buildInfoRow(
                'Bank Statement',
                customerDetails['custom_bank_statement'],
              ),
              _buildInfoRow('PAN Card', customerDetails['custom_pan_card']),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildLocationSection() {
  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.all(16),
  //     child: Card(
  //       color: const Color(0xFFFFFFFF),
  //       elevation: 4,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       child: Padding(
  //         padding: const EdgeInsets.all(16),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             _buildSectionTitle('Location'),
  //             const SizedBox(height: 16),
  //             _buildInfoRow('Latitude', customerDetails['custom_latitude']),
  //             _buildInfoRow('Longitude', customerDetails['custom_longtitude']),
  //             _buildInfoRow('Map Link', customerDetails['custom_map_link']),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

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
              ...List<Widget>.from(
                (customerDetails['sales_team'] as List<dynamic>? ?? [])
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
                                ),
                                _buildInfoRow(
                                  'Allocated Percentage',
                                  member['allocated_percentage']?.toString(),
                                ),
                                _buildInfoRow(
                                  'Allocated Amount',
                                  member['allocated_amount']?.toString(),
                                ),
                                _buildInfoRow(
                                  'Incentives',
                                  member['incentives']?.toString(),
                                ),
                                _buildInfoRow(
                                  'Parent Sales Person',
                                  member['custom_parent_sales_person'],
                                ),
                                _buildInfoRow(
                                  'Regional Sales Person',
                                  member['custom_regional_sales_person'],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
              ),
              if (customerDetails['sales_team'] == null ||
                  (customerDetails['sales_team'] as List<dynamic>).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No sales team assigned.',
                    style: TextStyle(color: Color(0xFF757575)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditLimitsSection() {
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
              _buildSectionTitle('Credit Limits'),
              const SizedBox(height: 16),
              ...List<Widget>.from(
                (customerDetails['credit_limits'] as List<dynamic>? ?? [])
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final limit = entry.value as Map<String, dynamic>;
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
                                  'Credit Limit ${index + 1}',
                                ),
                                _buildInfoRow('Company', limit['company']),
                                _buildInfoRow(
                                  'Credit Limit',
                                  limit['credit_limit']?.toString(),
                                ),
                                _buildInfoRow(
                                  'Bypass Credit Limit Check',
                                  limit['bypass_credit_limit_check'] == 1
                                      ? 'Yes'
                                      : 'No',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
              ),
              if (customerDetails['credit_limits'] == null ||
                  (customerDetails['credit_limits'] as List<dynamic>).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No credit limits assigned.',
                    style: TextStyle(color: Color(0xFF757575)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onNavBarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          customerDetails['customer_name'] ?? 'Customer Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF005BAC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF005BAC), Color(0xFFFFFFFF)],
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : errorMessage.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchCustomerDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005BAC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
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
                              onTap: () => _onNavBarTap(index),
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
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _sections[index],
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white,
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
                                          borderRadius: BorderRadius.circular(
                                            1,
                                          ),
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
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      children: [
                        _buildBasicInformationSection(),
                        _buildAddressInformationSection(),
                        _buildCreditLimitsSection(), // Moved here
                        _buildContactInformationSection(),
                        _buildBankDetailsSection(),
                        _buildAttachmentsSection(),
                        // _buildLocationSection(),
                        _buildSalesTeamSection(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
