import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

class QuotationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> quotation;
  final String serverUrl;
  final String sid;

  const QuotationDetailScreen({
    Key? key,
    required this.quotation,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _QuotationDetailScreenState createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  Map<String, dynamic> quotationDetails = {};
  bool isLoading = true;
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<String> _sections = [
    'Quotation Details',
    'Customer Details',
    'Summary',
    'Items',
    'Taxes',
    'Sales Order',
    'Sales Invoice',
  ];

  final List<IconData> _sectionIcons = [
    Icons.description,
    Icons.person,
    Icons.account_balance_wallet,
    Icons.inventory,
    Icons.account_balance,
    Icons.shopping_cart,
    Icons.receipt,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    setState(() {
      quotationDetails = widget.quotation;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    return (quotationDetails['items'] as List<dynamic>?)?.fold<double>(
          0.0,
          (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0),
        ) ??
        0.0;
  }

  double get _totalTaxAmount {
    return (quotationDetails['taxes'] as List<dynamic>?)?.fold<double>(
          0.0,
          (sum, tax) => sum + (tax['tax_amount']?.toDouble() ?? 0.0),
        ) ??
        0.0;
  }

  double get _grandTotal {
    return _totalAmount + _totalTaxAmount;
  }

  int get _totalQuantity {
    return (quotationDetails['items'] as List<dynamic>?)?.fold<int>(
          0,
          (sum, item) => sum + (item['qty'] as num? ?? 0).toInt(),
        ) ??
        0;
  }

  Future<pw.Document> generatePdf() async {
    final pdf = pw.Document();

    // Load a font that supports Unicode characters (like ₹)
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    // Load logo if available
    final logoImage = await _loadLogoImage();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 6.0),
          child: pw.Text(
            'SAKTHI STEEL INDUSTRIES LTD, Madurai',
            style: pw.TextStyle(font: ttf, fontSize: 8),
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
                  logoImage != null
                      ? pw.Image(logoImage, width: 70, height: 70)
                      : pw.Text(
                          'SAKTHI STEEL INDUSTRIES LTD',
                          style: pw.TextStyle(font: ttf, fontSize: 16),
                        ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'QUOTATION',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        quotationDetails['name'] ?? 'N/A',
                        style: pw.TextStyle(font: ttf, fontSize: 12),
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
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          quotationDetails['customer_name'] ?? 'N/A',
                          style: pw.TextStyle(font: ttf),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Date:',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          formatDate(quotationDetails['transaction_date']) ??
                              'N/A',
                          style: pw.TextStyle(font: ttf),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Quotation To:',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          quotationDetails['quotation_to'] ?? 'N/A',
                          style: pw.TextStyle(font: ttf),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Valid Till:',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          formatDate(quotationDetails['valid_till']) ?? 'N/A',
                          style: pw.TextStyle(font: ttf),
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
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          removeHtmlTags(quotationDetails['address_display']) ??
                              'N/A',
                          style: pw.TextStyle(font: ttf),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Company:',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          quotationDetails['company'] ?? 'N/A',
                          style: pw.TextStyle(font: ttf),
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
                  5: const pw.FixedColumnWidth(60),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _pdfTableHeader('Sr', ttf),
                      _pdfTableHeader('Item', ttf),
                      _pdfTableHeader('Quantity', ttf),
                      _pdfTableHeader('Rate (₹)', ttf),
                      _pdfTableHeader('Discount (₹)', ttf),
                      _pdfTableHeader('Amount (₹)', ttf),
                    ],
                  ),
                  ...(quotationDetails['items'] as List<dynamic>?)?.asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        return pw.TableRow(
                          children: [
                            _pdfTableCell(index.toString(), ttf),
                            _pdfTableCell(
                              item['item_code'] ?? item['item_name'] ?? 'N/A',
                              ttf,
                            ),
                            _pdfTableCell(item['qty']?.toString() ?? '0', ttf),
                            _pdfTableCell(
                              '₹ ${(item['price_list_rate']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                              ttf,
                            ),
                            _pdfTableCell(
                              '₹ ${(item['discount_amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                              ttf,
                            ),
                            _pdfTableCell(
                              '₹ ${(item['amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                              ttf,
                            ),
                          ],
                        );
                      })?.toList() ??
                      [],
                ],
              ),
              pw.SizedBox(height: 10),
              if (quotationDetails['taxes'] != null &&
                  quotationDetails['taxes'].isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Taxes',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Table(
                      border: pw.TableBorder.all(),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(),
                        1: const pw.FlexColumnWidth(),
                        2: const pw.FlexColumnWidth(),
                        3: const pw.FixedColumnWidth(60),
                        4: const pw.FixedColumnWidth(60),
                        5: const pw.FixedColumnWidth(60),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey300,
                          ),
                          children: [
                            _pdfTableHeader('Charge Type', ttf),
                            _pdfTableHeader('Account Head', ttf),
                            _pdfTableHeader('Description', ttf),
                            _pdfTableHeader('Rate (%)', ttf),
                            _pdfTableHeader('Tax Amount (₹)', ttf),
                            _pdfTableHeader('Total (₹)', ttf),
                          ],
                        ),
                        ...(quotationDetails['taxes'] as List<dynamic>?)?.map((
                              tax,
                            ) {
                              return pw.TableRow(
                                children: [
                                  _pdfTableCell(
                                    tax['charge_type']?.toString() ?? 'N/A',
                                    ttf,
                                  ),
                                  _pdfTableCell(
                                    tax['account_head']?.toString() ?? 'N/A',
                                    ttf,
                                  ),
                                  _pdfTableCell(
                                    tax['description']?.toString() ?? 'N/A',
                                    ttf,
                                  ),
                                  _pdfTableCell(
                                    (tax['rate']?.toDouble() ?? 0.0).toString(),
                                    ttf,
                                  ),
                                  _pdfTableCell(
                                    '₹ ${(tax['tax_amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                    ttf,
                                  ),
                                  _pdfTableCell(
                                    '₹ ${(tax['total']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                    ttf,
                                  ),
                                ],
                              );
                            })?.toList() ??
                            [],
                      ],
                    ),
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
                        'Total Quantity: $_totalQuantity',
                        style: pw.TextStyle(
                          font: ttf,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Total: ₹ $_totalAmount',
                        style: pw.TextStyle(
                          font: ttf,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (_totalTaxAmount > 0)
                        pw.Column(
                          children: [
                            pw.SizedBox(height: 5),
                            pw.Text(
                              'Total Tax: ₹ $_totalTaxAmount',
                              style: pw.TextStyle(
                                font: ttf,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Grand Total: ₹ $_grandTotal',
                        style: pw.TextStyle(
                          font: ttf,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'In Words: ${quotationDetails['in_words'] ?? 'N/A'}',
                style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Sales Order Details',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'No Sales Order linked to this Quotation.',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 12,
                  color: PdfColors.grey,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Sales Invoice Details',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'No Sales Invoice linked to this Quotation.',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 12,
                  color: PdfColors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return pdf;
  }

  pw.Widget _pdfTableHeader(String title, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTableCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10)),
    );
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

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<pw.MemoryImage?> _loadLogoImage() async {
    try {
      final byteData = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      print('Error loading logo: $e');
      return null;
    }
  }

  Future<void> _printQuotation() async {
    if (quotationDetails.isEmpty) return;
    final pdf = await generatePdf();
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsPdf() async {
    if (quotationDetails.isEmpty) return;
    final pdf = await generatePdf();
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'quotation_${quotationDetails['name']}.pdf',
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
          quotationDetails['name'] ?? 'Quotation Details',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF005BAC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/quotation',
                arguments: {
                  'serverUrl': widget.serverUrl,
                  'sid': widget.sid,
                  'initialData': quotationDetails,
                },
              );
            },
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printQuotation,
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: _saveAsPdf,
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
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : quotationDetails.isEmpty
            ? Center(
                child: Text(
                  'Quotation not found',
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
                        _buildQuotationDetailsSection(),
                        _buildCustomerDetailsSection(),
                        _buildSummarySection(),
                        _buildItemsSection(),
                        _buildTaxesSection(),
                        _buildSalesOrderSection(),
                        _buildSalesInvoiceSection(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQuotationDetailsSection() {
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
              _buildSectionTitle('Quotation Details'),
              const SizedBox(height: 16),
              _buildInfoRow('Quotation ID', quotationDetails['name']),
              _buildInfoRow('Quotation To', quotationDetails['quotation_to']),
              _buildInfoRow(
                'Status',
                quotationDetails['status'],
                status: quotationDetails['status'],
              ),
              _buildInfoRow(
                'Salesperson',
                quotationDetails['salesperson_name'],
              ),
              _buildInfoRow(
                'Transaction Date',
                formatDate(quotationDetails['transaction_date']),
              ),
              _buildInfoRow(
                'Valid Till',
                formatDate(quotationDetails['valid_till']),
              ),
              _buildInfoRow('Cost Center', quotationDetails['cost_center']),
              _buildInfoRow('Company', quotationDetails['company']),
              _buildInfoRow('Currency', quotationDetails['currency']),
              _buildInfoRow('In Words', quotationDetails['in_words']),
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
              _buildInfoRow('Customer', quotationDetails['customer_name']),
              _buildInfoRow(
                'Address Display',
                removeHtmlTags(quotationDetails['address_display']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
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
              _buildSectionTitle('Summary'),
              const SizedBox(height: 16),
              _buildInfoRow('Total Quantity', _totalQuantity.toString()),
              _buildInfoRow('Total Amount', '₹ $_totalAmount'),
              if (_totalTaxAmount > 0)
                _buildInfoRow('Total Tax', '₹ $_totalTaxAmount'),
              _buildInfoRow('Grand Total', '₹ $_grandTotal'),
              _buildInfoRow('In Words', quotationDetails['in_words']),
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
              ...List<Widget>.from(
                (quotationDetails['items'] as List<dynamic>? ?? []).asMap().entries.map((
                  entry,
                ) {
                  final index = entry.key;
                  final item = entry.value as Map<String, dynamic>;
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
                            _buildInfoRow('Item Code', item['item_code']),
                            _buildInfoRow('Item Name', item['item_name']),
                            _buildInfoRow('Qty', item['qty']?.toString()),
                            _buildInfoRow('Stock UOM', item['stock_uom']),
                            _buildInfoRow('UOM', item['uom']),
                            _buildInfoRow(
                              'Conversion Factor',
                              item['conversion_factor']?.toString(),
                            ),
                            _buildInfoRow(
                              'Stock Qty',
                              item['stock_qty']?.toString(),
                            ),
                            _buildInfoRow(
                              'Price List Rate',
                              '₹ ${item['price_list_rate']?.toString() ?? '0'}',
                            ),
                            _buildInfoRow(
                              'Discount Amount',
                              '₹ ${item['discount_amount']?.toString() ?? '0'}',
                            ),
                            _buildInfoRow(
                              'Rate',
                              '₹ ${item['rate']?.toString() ?? '0'}',
                            ),
                            _buildInfoRow(
                              'Amount',
                              '₹ ${item['amount']?.toString() ?? '0'}',
                            ),
                            if (item['image'] != null &&
                                item['image'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Image.network(
                                  item['image'].startsWith('http')
                                      ? item['image']
                                      : '${widget.serverUrl}${item['image']}',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.broken_image,
                                        color: Color(0xFF757575),
                                        size: 40,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxesSection() {
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
              _buildSectionTitle('Taxes'),
              const SizedBox(height: 16),
              ...List<Widget>.from(
                (quotationDetails['taxes'] as List<dynamic>? ?? [])
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final tax = entry.value as Map<String, dynamic>;
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
                                _buildSubSectionTitle('Tax ${index + 1}'),
                                _buildInfoRow(
                                  'Charge Type',
                                  tax['charge_type'],
                                ),
                                _buildInfoRow(
                                  'Account Head',
                                  tax['account_head'],
                                ),
                                _buildInfoRow(
                                  'Description',
                                  tax['description'],
                                ),
                                _buildInfoRow(
                                  'Rate (%)',
                                  tax['rate']?.toString(),
                                ),
                                _buildInfoRow(
                                  'Tax Amount',
                                  '₹ ${tax['tax_amount']?.toString() ?? '0'}',
                                ),
                                _buildInfoRow(
                                  'Total',
                                  '₹ ${tax['total']?.toString() ?? '0'}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
              ),
              if (quotationDetails['taxes'] == null ||
                  (quotationDetails['taxes'] as List<dynamic>).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No taxes applied.',
                    style: TextStyle(color: Color(0xFF757575)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesOrderSection() {
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
              _buildSectionTitle('Sales Order'),
              const SizedBox(height: 16),
              const Text(
                'No Sales Order linked to this Quotation.',
                style: TextStyle(color: Color(0xFF757575)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesInvoiceSection() {
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
              _buildSectionTitle('Sales Invoice'),
              const SizedBox(height: 16),
              const Text(
                'No Sales Invoice linked to this Quotation.',
                style: TextStyle(color: Color(0xFF757575)),
              ),
            ],
          ),
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

  Widget _buildInfoRow(String label, dynamic value, {String? status}) {
    Color textColor = const Color(0xFF333333);
    if (status != null) {
      if (status == 'Ordered') {
        textColor = const Color(0xFF4CAF50);
      } else if (status == 'Partially Ordered') {
        textColor = const Color(0xFFFFA000);
      } else if (status == 'Open') {
        textColor = const Color(0xFF2196F3);
      } else if (status == 'Cancelled') {
        textColor = const Color(0xFFF44336);
      }
    }

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
                color: textColor,
                fontWeight: status != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
