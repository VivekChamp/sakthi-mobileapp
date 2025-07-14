import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/payment_entry.dart';

class PaymentEntryDetailScreen extends StatefulWidget {
  final PaymentEntry paymentEntry;
  final String serverUrl;
  final String sid;

  const PaymentEntryDetailScreen({
    Key? key,
    required this.paymentEntry,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _PaymentEntryDetailScreenState createState() =>
      _PaymentEntryDetailScreenState();
}

class _PaymentEntryDetailScreenState extends State<PaymentEntryDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment Entry Details',
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.paymentEntry.name ?? 'Payment Entry',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildInfoRow(
                        'Payment Type',
                        widget.paymentEntry.paymentType,
                      ),
                      _buildInfoRow(
                        'Posting Date',
                        formatDate(widget.paymentEntry.postingDate),
                      ),
                      _buildInfoRow('Company', widget.paymentEntry.company),
                      _buildInfoRow(
                        'Mode of Payment',
                        widget.paymentEntry.modeOfPayment,
                      ),
                      _buildInfoRow(
                        'Party Type',
                        widget.paymentEntry.partyType,
                      ),
                      _buildInfoRow('Party', widget.paymentEntry.party),
                      _buildInfoRow(
                        'Party Name',
                        widget.paymentEntry.partyName,
                      ),
                      _buildInfoRow('Paid From', widget.paymentEntry.paidFrom),
                      _buildInfoRow('Paid To', widget.paymentEntry.paidTo),
                      _buildInfoRow(
                        'Paid Amount',
                        widget.paymentEntry.paidAmount != null
                            ? 'AED ${widget.paymentEntry.paidAmount!.toStringAsFixed(2)}'
                            : 'N/A',
                      ),
                      _buildInfoRow('Status', widget.paymentEntry.status),
                      _buildInfoRow(
                        'PDC Cleared',
                        widget.paymentEntry.pdcCleared == true ? 'Yes' : 'No',
                      ),
                      _buildInfoRow('Created By', widget.paymentEntry.owner),
                      _buildInfoRow(
                        'Created On',
                        formatDate(widget.paymentEntry.creation),
                      ),
                      _buildInfoRow(
                        'Modified By',
                        widget.paymentEntry.modifiedBy,
                      ),
                      _buildInfoRow(
                        'Modified On',
                        formatDate(widget.paymentEntry.modified),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Remarks',
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.paymentEntry.remarks ?? 'No remarks',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
