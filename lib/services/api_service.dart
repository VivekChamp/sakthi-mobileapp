import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/payment_entry.dart';

class ApiService {
  static Future<Map<String, dynamic>> fetchPaymentEntries(
    String serverUrl,
    String sid, {
    int page = 1,
    int limit = 10,
  }) async {
    final url =
        '$serverUrl /api/method/vps_mobile.vps_mobile.role_api.get_payment_entry?page=$page&limit=$limit';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 4));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to load payment entries: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching payment entries: $e');
    }
  }

  static Future<List<String>> fetchNamingSeries(
    String serverUrl,
    String sid,
  ) async {
    final url =
        '$serverUrl /api/method/vps_mobile.vps_mobile.role_api.get_payment_entry_naming_series';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['message']['naming_series_options']);
      } else {
        throw Exception(
          'Failed to fetch naming series: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching naming series: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCustomers(
    String serverUrl,
    String sid,
  ) async {
    final url =
        '$serverUrl /api/method/vps_mobile.vps_mobile.role_api.get_customers';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['message']);
      } else {
        throw Exception('Failed to fetch customers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching customers: $e');
    }
  }

  static Future<List<String>> fetchSuppliers(
    String serverUrl,
    String sid,
  ) async {
    return [];
  }

  static Future<List<String>> fetchEmployees(
    String serverUrl,
    String sid,
  ) async {
    return [];
  }

  static Future<List<String>> fetchShareholders(
    String serverUrl,
    String sid,
  ) async {
    return [];
  }

  static Future<List<String>> fetchAccountPaidTo(
    String serverUrl,
    String sid,
  ) async {
    final url =
        '$serverUrl /api/method/vps_mobile.vps_mobile.role_api.get_account_paid_to';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['message']['account_paid_to']);
      } else {
        throw Exception(
          'Failed to fetch account paid to options: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching account paid to options: $e');
    }
  }

  static Future<List<String>> fetchAccountPaidFrom(
    String serverUrl,
    String sid,
  ) async {
    final url =
        '$serverUrl /api/method/vps_mobile.vps_mobile.role_api.get_account_paid_from';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['message']['account_paid_from']);
      } else {
        throw Exception(
          'Failed to fetch account paid from options: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching account paid from options: $e');
    }
  }

  static Future<List<String>> fetchAccountHead(
    String serverUrl,
    String sid,
  ) async {
    final url =
        '$serverUrl /api/method/vps_mobile.vps_mobile.role_api.get_account_head';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['message']['account_head']);
      } else {
        throw Exception(
          'Failed to fetch account head options: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching account head options: $e');
    }
  }

  static Future<void> createPaymentEntry(
    String serverUrl,
    String sid,
    Map<String, dynamic> paymentEntryData,
  ) async {
    final url =
        '$serverUrl /api/method/vps_mobile.vps_mobile.role_api.create_payment_entry';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(paymentEntryData),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create payment entry: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating payment entry: $e');
    }
  }
}
