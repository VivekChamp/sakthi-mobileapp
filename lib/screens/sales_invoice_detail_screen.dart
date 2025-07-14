import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

class SalesInvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  final String serverUrl;
  final String sid;

  const SalesInvoiceDetailScreen({
    Key? key,
    required this.invoiceId,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _SalesInvoiceDetailScreenState createState() =>
      _SalesInvoiceDetailScreenState();
}

class _SalesInvoiceDetailScreenState extends State<SalesInvoiceDetailScreen> {
  Map<String, dynamic> invoiceDetails = {};
  bool isLoading = true;
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<String> _sections = [
    'Invoice Details',
    'Customer Details',
    'Financial Summary',
    'Items',
    'Sales Team',
    'Payment Schedule',
  ];

  final List<IconData> _sectionIcons = [
    Icons.description,
    Icons.person,
    Icons.account_balance_wallet,
    Icons.inventory,
    Icons.group,
    Icons.schedule,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    fetchInvoiceDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> fetchInvoiceDetails() async {
    final url =
        "${widget.serverUrl}/api/resource/Sales Invoice/${widget.invoiceId}";
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
            invoiceDetails = data['data'] ?? {};
            isLoading = false;
          });
        }
      } else {
        throw Exception(
          'Failed to load sales invoice details: ${response.statusCode}',
        );
      }
    } catch (error) {
      print('Error fetching invoice details: $error');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load invoice details. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double get _totalAmount {
    return (invoiceDetails['items'] as List<dynamic>?)?.fold<double>(
          0.0,
          (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0),
        ) ??
        0.0;
  }

  double get _totalTaxAmount {
    return invoiceDetails['total_taxes_and_charges']?.toDouble() ?? 0.0;
  }

  double get _grandTotal {
    return invoiceDetails['grand_total']?.toDouble() ??
        (_totalAmount + _totalTaxAmount);
  }

  num get _totalQuantity {
    return (invoiceDetails['items'] as List<dynamic>?)
            ?.fold<num>(0, (sum, item) => sum + (item['qty'] as num? ?? 0))
            ?.toInt() ??
        0;
  }

  Future<pw.Document> generatePdf() async {
    final pdf = pw.Document();

    // Load a font that supports Unicode characters (like ₹)
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    // Load logo if available
    final logoImage = await _loadLogoImage();

    final currency = invoiceDetails['currency'] ?? 'INR';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 6.0),
          child: pw.Text(
            'VPS Business Solution, Madurai',
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
                          'VPS Business Solution',
                          style: pw.TextStyle(font: ttf, fontSize: 16),
                        ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        invoiceDetails['name'] ?? 'N/A',
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
                          invoiceDetails['customer_name'] ?? 'N/A',
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
                          formatDate(invoiceDetails['posting_date']) ?? 'N/A',
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
                          'Tax Id:',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          invoiceDetails['tax_id'] ?? 'N/A',
                          style: pw.TextStyle(font: ttf),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Company TRN:',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          invoiceDetails['company_tax_id'] ?? 'N/A',
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
                          removeHtmlTags(invoiceDetails['address_display']) ??
                              'N/A',
                          style: pw.TextStyle(font: ttf),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Payment Terms:',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          invoiceDetails['payment_terms_template'] ?? 'N/A',
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
                      _pdfTableHeader('Rate', ttf),
                      _pdfTableHeader('Amount', ttf),
                    ],
                  ),
                  ...(invoiceDetails['items'] as List<dynamic>?)?.asMap().entries.map((
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
                              '$currency ${(item['rate']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                              ttf,
                            ),
                            _pdfTableCell(
                              '$currency ${(item['amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                              ttf,
                            ),
                          ],
                        );
                      })?.toList() ??
                      [],
                ],
              ),
              if (invoiceDetails['taxes'] != null &&
                  (invoiceDetails['taxes'] as List<dynamic>).isNotEmpty)
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
                            _pdfTableHeader('Tax Amount', ttf),
                            _pdfTableHeader('Total', ttf),
                          ],
                        ),
                        ...(invoiceDetails['taxes'] as List<dynamic>?)?.map((
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
                                    '$currency ${(tax['tax_amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                    ttf,
                                  ),
                                  _pdfTableCell(
                                    '$currency ${(tax['total']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
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
                        'Total: $currency ${_totalAmount.toStringAsFixed(2)}',
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
                              'Total Tax: $currency ${_totalTaxAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                font: ttf,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Grand Total: $currency ${_grandTotal.toStringAsFixed(2)}',
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
                'In Words: ${invoiceDetails['in_words'] ?? numberToWords(_grandTotal, currency)}',
                style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
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

  String numberToWords(num number, String currency) {
    final units = [
      'Zero',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
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
    final tens = [
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

    int wholeNumber = number.toInt();
    int decimalPart = ((number - wholeNumber) * 100).round();

    String wholeWords = '';
    if (wholeNumber == 0) {
      wholeWords = units[0];
    } else if (wholeNumber < 20) {
      wholeWords = units[wholeNumber];
    } else if (wholeNumber < 100) {
      wholeWords = '${tens[wholeNumber ~/ 10]} ${units[wholeNumber % 10]}'
          .trim();
    } else if (wholeNumber < 1000) {
      wholeWords =
          '${units[wholeNumber ~/ 100]} Hundred ${numberToWords(wholeNumber % 100, "")}'
              .trim();
    } else if (wholeNumber < 1000000) {
      wholeWords =
          '${numberToWords(wholeNumber ~/ 1000, "")} Thousand ${numberToWords(wholeNumber % 1000, "")}'
              .trim();
    } else if (wholeNumber < 1000000000) {
      wholeWords =
          '${numberToWords(wholeNumber ~/ 1000000, "")} Million ${numberToWords(wholeNumber % 1000000, "")}'
              .trim();
    } else {
      wholeWords = 'Too Large';
    }

    String decimalWords = decimalPart == 0
        ? 'Zero'
        : numberToWords(decimalPart, "");
    return '$currency $wholeWords and $decimalWords Paise Only';
  }

  Future<void> _printSalesInvoice() async {
    if (invoiceDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No invoice data to print.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final pdf = await generatePdf();
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsPdf() async {
    if (invoiceDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No invoice data to save.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final pdf = await generatePdf();
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'sales_invoice_${invoiceDetails['name'] ?? 'invoice'}.pdf',
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
          invoiceDetails['name'] ?? 'Sales Invoice Details',
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
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printSalesInvoice,
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
            : invoiceDetails.isEmpty
            ? Center(
                child: Text(
                  'Sales invoice not found',
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
                        _buildInvoiceDetailsSection(),
                        _buildCustomerDetailsSection(),
                        _buildFinancialSummarySection(),
                        _buildItemsSection(),
                        _buildSalesTeamSection(),
                        _buildPaymentScheduleSection(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInvoiceDetailsSection() {
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
              _buildSectionTitle('Invoice Details'),
              const SizedBox(height: 16),
              _buildInfoRow('Invoice ID', invoiceDetails['name'], isBold: true),
              _buildInfoRow('Title', invoiceDetails['title']),
              _buildInfoRow(
                'Status',
                invoiceDetails['status'],
                status: invoiceDetails['status'],
              ),
              _buildInfoRow('Naming Series', invoiceDetails['naming_series']),
              _buildInfoRow(
                'Posting Date',
                formatDate(invoiceDetails['posting_date']),
              ),
              _buildInfoRow('Posting Time', invoiceDetails['posting_time']),
              _buildInfoRow('Due Date', formatDate(invoiceDetails['due_date'])),
              _buildInfoRow(
                'Set Posting Time',
                invoiceDetails['set_posting_time'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Is POS',
                invoiceDetails['is_pos'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Is Consolidated',
                invoiceDetails['is_consolidated'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Is Return',
                invoiceDetails['is_return'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Is Debit Note',
                invoiceDetails['is_debit_note'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow('Is Opening', invoiceDetails['is_opening']),
              _buildInfoRow(
                'Is Internal Customer',
                invoiceDetails['is_internal_customer'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Is Discounted',
                invoiceDetails['is_discounted'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow('Company', invoiceDetails['company']),
              _buildInfoRow('Language', invoiceDetails['language']),
              _buildInfoRow('Remarks', invoiceDetails['remarks']),
              _buildInfoRow('Owner', invoiceDetails['owner']),
              _buildInfoRow('Creation', formatDate(invoiceDetails['creation'])),
              _buildInfoRow('Modified', formatDate(invoiceDetails['modified'])),
              _buildInfoRow('Modified By', invoiceDetails['modified_by']),
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
              _buildInfoRow('Customer', invoiceDetails['customer']),
              _buildInfoRow('Customer Name', invoiceDetails['customer_name']),
              _buildInfoRow(
                'Customer Address',
                invoiceDetails['customer_address'],
              ),
              _buildInfoRow(
                'Address Display',
                removeHtmlTags(invoiceDetails['address_display']),
              ),
              _buildInfoRow('Tax Category', invoiceDetails['tax_category']),
              _buildInfoRow('PO Number', invoiceDetails['po_no']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialSummarySection() {
    final currency = invoiceDetails['currency'] ?? 'INR';
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
              _buildInfoRow('Total Quantity', _totalQuantity.toString()),
              _buildInfoRow(
                'Total Amount',
                '$currency ${_totalAmount.toStringAsFixed(2)}',
              ),
              if (_totalTaxAmount > 0)
                _buildInfoRow(
                  'Total Tax',
                  '$currency ${_totalTaxAmount.toStringAsFixed(2)}',
                ),
              _buildInfoRow(
                'Grand Total',
                '$currency ${_grandTotal.toStringAsFixed(2)}',
                isBold: true,
              ),
              _buildInfoRow('In Words', invoiceDetails['in_words']),
              const Divider(),
              _buildInfoRow('Currency', invoiceDetails['currency']),
              _buildInfoRow(
                'Conversion Rate',
                invoiceDetails['conversion_rate']?.toString(),
              ),
              _buildInfoRow(
                'Selling Price List',
                invoiceDetails['selling_price_list'],
              ),
              _buildInfoRow(
                'Price List Currency',
                invoiceDetails['price_list_currency'],
              ),
              _buildInfoRow(
                'PLC Conversion Rate',
                invoiceDetails['plc_conversion_rate']?.toString(),
              ),
              _buildInfoRow(
                'Total Net Weight',
                invoiceDetails['total_net_weight']?.toString(),
              ),
              _buildInfoRow(
                'Base Total',
                '${invoiceDetails['base_total'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Base Net Total',
                '${invoiceDetails['base_net_total'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Total',
                '${invoiceDetails['total'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Net Total',
                '${invoiceDetails['net_total'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Base Total Taxes and Charges',
                '${invoiceDetails['base_total_taxes_and_charges'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Total Taxes and Charges',
                '${invoiceDetails['total_taxes_and_charges'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Base Grand Total',
                '${invoiceDetails['base_grand_total'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Base Rounding Adjustment',
                '${invoiceDetails['base_rounding_adjustment'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Base Rounded Total',
                '${invoiceDetails['base_rounded_total'] ?? 0} $currency',
              ),
              _buildInfoRow('Base In Words', invoiceDetails['base_in_words']),
              _buildInfoRow(
                'Rounding Adjustment',
                '${invoiceDetails['rounding_adjustment'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Use Company Roundoff Cost Center',
                invoiceDetails['use_company_roundoff_cost_center'] == 1
                    ? 'Yes'
                    : 'No',
              ),
              _buildInfoRow(
                'Rounded Total',
                '${invoiceDetails['rounded_total'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Total Advance',
                '${invoiceDetails['total_advance'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Outstanding Amount',
                '${invoiceDetails['outstanding_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Disable Rounded Total',
                invoiceDetails['disable_rounded_total'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Apply Discount On',
                invoiceDetails['apply_discount_on'],
              ),
              _buildInfoRow(
                'Base Discount Amount',
                '${invoiceDetails['base_discount_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Is Cash or Non-Trade Discount',
                invoiceDetails['is_cash_or_non_trade_discount'] == 1
                    ? 'Yes'
                    : 'No',
              ),
              _buildInfoRow(
                'Additional Discount Percentage',
                invoiceDetails['additional_discount_percentage']?.toString(),
              ),
              _buildInfoRow(
                'Discount Amount',
                '${invoiceDetails['discount_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Total Billing Hours',
                invoiceDetails['total_billing_hours']?.toString(),
              ),
              _buildInfoRow(
                'Total Billing Amount',
                '${invoiceDetails['total_billing_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Base Paid Amount',
                '${invoiceDetails['base_paid_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Paid Amount',
                '${invoiceDetails['paid_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Base Change Amount',
                '${invoiceDetails['base_change_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Change Amount',
                '${invoiceDetails['change_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Allocate Advances Automatically',
                invoiceDetails['allocate_advances_automatically'] == 1
                    ? 'Yes'
                    : 'No',
              ),
              _buildInfoRow(
                'Only Include Allocated Payments',
                invoiceDetails['only_include_allocated_payments'] == 1
                    ? 'Yes'
                    : 'No',
              ),
              _buildInfoRow(
                'Write Off Amount',
                '${invoiceDetails['write_off_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Base Write Off Amount',
                '${invoiceDetails['base_write_off_amount'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Write Off Outstanding Amount Automatically',
                invoiceDetails['write_off_outstanding_amount_automatically'] ==
                        1
                    ? 'Yes'
                    : 'No',
              ),
              _buildInfoRow(
                'Redeem Loyalty Points',
                invoiceDetails['redeem_loyalty_points'] == 1 ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'Loyalty Points',
                invoiceDetails['loyalty_points']?.toString(),
              ),
              _buildInfoRow(
                'Loyalty Amount',
                '${invoiceDetails['loyalty_amount'] ?? 0} $currency',
              ),
              _buildInfoRow('Debit To', invoiceDetails['debit_to']),
              _buildInfoRow(
                'Party Account Currency',
                invoiceDetails['party_account_currency'],
              ),
              _buildInfoRow(
                'Against Income Account',
                invoiceDetails['against_income_account'],
              ),
              _buildInfoRow(
                'Amount Eligible for Commission',
                '${invoiceDetails['amount_eligible_for_commission'] ?? 0} $currency',
              ),
              _buildInfoRow(
                'Commission Rate',
                invoiceDetails['commission_rate']?.toString(),
              ),
              _buildInfoRow(
                'Total Commission',
                '${invoiceDetails['total_commission'] ?? 0} $currency',
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
              ...List<Widget>.from(
                (invoiceDetails['items'] as List<dynamic>? ?? []).asMap().entries.map((
                  entry,
                ) {
                  final index = entry.key;
                  final item = entry.value as Map<String, dynamic>;
                  final currency = invoiceDetails['currency'] ?? 'INR';
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
                            _buildInfoRow(
                              'Description',
                              removeHtmlTags(item['description']),
                            ),
                            _buildInfoRow('Item Group', item['item_group']),
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
                              '${item['price_list_rate'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Base Price List Rate',
                              '${item['base_price_list_rate'] ?? 0} $currency',
                            ),
                            _buildInfoRow('Margin Type', item['margin_type']),
                            _buildInfoRow(
                              'Margin Rate or Amount',
                              item['margin_rate_or_amount']?.toString(),
                            ),
                            _buildInfoRow(
                              'Rate with Margin',
                              '${item['rate_with_margin'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Discount Percentage',
                              item['discount_percentage']?.toString(),
                            ),
                            _buildInfoRow(
                              'Discount Amount',
                              '${item['discount_amount'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Distributed Discount Amount',
                              '${item['distributed_discount_amount'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Base Rate with Margin',
                              '${item['base_rate_with_margin'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Rate',
                              '${item['rate'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Amount',
                              '${item['amount'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Base Rate',
                              '${item['base_rate'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Base Amount',
                              '${item['base_amount'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Stock UOM Rate',
                              '${item['stock_uom_rate'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Is Free Item',
                              item['is_free_item'] == 1 ? 'Yes' : 'No',
                            ),
                            _buildInfoRow(
                              'Grant Commission',
                              item['grant_commission'] == 1 ? 'Yes' : 'No',
                            ),
                            _buildInfoRow(
                              'Net Rate',
                              '${item['net_rate'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Net Amount',
                              '${item['net_amount'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Base Net Rate',
                              '${item['base_net_rate'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Base Net Amount',
                              '${item['base_net_amount'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Delivered by Supplier',
                              item['delivered_by_supplier'] == 1 ? 'Yes' : 'No',
                            ),
                            _buildInfoRow(
                              'Income Account',
                              item['income_account'],
                            ),
                            _buildInfoRow(
                              'Is Fixed Asset',
                              item['is_fixed_asset'] == 1 ? 'Yes' : 'No',
                            ),
                            _buildInfoRow(
                              'Expense Account',
                              item['expense_account'],
                            ),
                            _buildInfoRow(
                              'Enable Deferred Revenue',
                              item['enable_deferred_revenue'] == 1
                                  ? 'Yes'
                                  : 'No',
                            ),
                            _buildInfoRow(
                              'Weight Per Unit',
                              item['weight_per_unit']?.toString(),
                            ),
                            _buildInfoRow(
                              'Total Weight',
                              item['total_weight']?.toString(),
                            ),
                            _buildInfoRow('Warehouse', item['warehouse']),
                            _buildInfoRow(
                              'Use Serial Batch Fields',
                              item['use_serial_batch_fields'] == 1
                                  ? 'Yes'
                                  : 'No',
                            ),
                            _buildInfoRow(
                              'Allow Zero Valuation Rate',
                              item['allow_zero_valuation_rate'] == 1
                                  ? 'Yes'
                                  : 'No',
                            ),
                            _buildInfoRow(
                              'Incoming Rate',
                              '${item['incoming_rate'] ?? 0} $currency',
                            ),
                            _buildInfoRow(
                              'Item Tax Rate',
                              item['item_tax_rate'],
                            ),
                            _buildInfoRow(
                              'Actual Batch Qty',
                              item['actual_batch_qty']?.toString(),
                            ),
                            _buildInfoRow(
                              'Actual Qty',
                              item['actual_qty']?.toString(),
                            ),
                            _buildInfoRow(
                              'Company Total Stock',
                              item['company_total_stock']?.toString(),
                            ),
                            _buildInfoRow(
                              'Delivered Qty',
                              item['delivered_qty']?.toString(),
                            ),
                            _buildInfoRow('Cost Center', item['cost_center']),
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
                (invoiceDetails['sales_team'] as List<dynamic>? ?? [])
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final member = entry.value as Map<String, dynamic>;
                      final currency = invoiceDetails['currency'] ?? 'INR';
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
                                  '${member['allocated_amount'] ?? 0} $currency',
                                ),
                                _buildInfoRow(
                                  'Incentives',
                                  '${member['incentives'] ?? 0} $currency',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
              ),
              if (invoiceDetails['sales_team'] == null ||
                  (invoiceDetails['sales_team'] as List<dynamic>).isEmpty)
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
              ...List<Widget>.from(
                (invoiceDetails['payment_schedule'] as List<dynamic>? ?? [])
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final schedule = entry.value as Map<String, dynamic>;
                      final currency = invoiceDetails['currency'] ?? 'INR';
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
                                  schedule['invoice_portion']?.toString(),
                                ),
                                _buildInfoRow(
                                  'Discount',
                                  '${schedule['discount'] ?? 0} $currency',
                                ),
                                _buildInfoRow(
                                  'Payment Amount',
                                  '${schedule['payment_amount'] ?? 0} $currency',
                                ),
                                _buildInfoRow(
                                  'Outstanding',
                                  '${schedule['outstanding'] ?? 0} $currency',
                                ),
                                _buildInfoRow(
                                  'Paid Amount',
                                  '${schedule['paid_amount'] ?? 0} $currency',
                                ),
                                _buildInfoRow(
                                  'Discounted Amount',
                                  '${schedule['discounted_amount'] ?? 0} $currency',
                                ),
                                _buildInfoRow(
                                  'Base Payment Amount',
                                  '${schedule['base_payment_amount'] ?? 0} $currency',
                                ),
                                _buildInfoRow(
                                  'Base Outstanding',
                                  '${schedule['base_outstanding'] ?? 0} $currency',
                                ),
                                _buildInfoRow(
                                  'Base Paid Amount',
                                  '${schedule['base_paid_amount'] ?? 0} $currency',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
              ),
              if (invoiceDetails['payment_schedule'] == null ||
                  (invoiceDetails['payment_schedule'] as List<dynamic>).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No payment schedule available.',
                    style: TextStyle(color: Color(0xFF757575)),
                  ),
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

  Widget _buildInfoRow(
    String label,
    dynamic value, {
    String? status,
    bool isBold = false,
  }) {
    Color textColor = const Color(0xFF333333);
    if (status != null) {
      if (status == 'Paid') {
        textColor = const Color(0xFF4CAF50); // Green
      } else if (status == 'Overdue') {
        textColor = const Color(0xFFF44336); // Red
      } else if (status == 'Draft') {
        textColor = const Color(0xFF2196F3); // Blue
      } else if (status == 'Cancelled') {
        textColor = const Color(0xFF9E9E9E); // Grey
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
                fontWeight: isBold || status != null
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
