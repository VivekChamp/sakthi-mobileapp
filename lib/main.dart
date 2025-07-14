import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/customer_list_screen.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/add_new_customer_screen.dart';
import 'screens/sales_invoice_screen.dart';
import 'screens/sales_order_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/create_sales_order_screen.dart';
import 'screens/hr_screen.dart';
import 'screens/leave_application_list_screen.dart';
import 'screens/employee_list_screen.dart';
import 'screens/attendance_list_screen.dart';
import 'screens/attendance_details_screen.dart';
import 'screens/create_attendance_screen.dart';
import 'screens/accounting_screen.dart';
import 'screens/payment_entry_list_screen.dart';
import 'screens/payment_entry_create_screen.dart';
import 'screens/payment_entry_detail_screen.dart';
import 'screens/sales_invoice_detail_screen.dart';
import 'screens/quotation_list_screen.dart';
import 'screens/quotation_screen.dart';
import 'screens/quotation_detail_screen.dart';
import 'screens/visit_entry_list_screen.dart';
import 'screens/visit_entry_detail_screen.dart';
import 'screens/create_visit_entry_screen.dart';
// Import the new ReceivableReportScreen
import 'screens/receivable_report_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    debugPrint(
      "dotenv loaded successfully. GOOGLE_MAPS_API_KEY: ${dotenv.env['GOOGLE_MAPS_API_KEY']}",
    );
  } catch (e, stackTrace) {
    debugPrint("Failed to load .env file: $e\n$stackTrace");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPS Business Solutions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005BAC), // Blue from "Apply" button
          brightness: Brightness.light,
          primary: const Color(0xFF005BAC), // Blue for primary actions
          secondary: const Color(0xFF757575), // Light gray for borders
          tertiary: const Color(0xFF333333), // Dark gray for text
          background: const Color(0xFFFFFFFF), // White background
        ),
        fontFamily: 'Dubai',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF333333), // Dark gray text
          ),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF757575), // Light gray for secondary text
          ),
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;

    bool _hasServerArgs(Map<String, dynamic>? args) {
      return args != null &&
          args.containsKey('serverUrl') &&
          args['serverUrl'] is String &&
          args.containsKey('sid') &&
          args['sid'] is String;
    }

    List<String>? _convertToStringList(dynamic list) {
      if (list == null) return null;
      if (list is List) {
        return list.map((item) => item.toString()).toList();
      }
      return null;
    }

    debugPrint('Navigating to route: ${settings.name}, Arguments: $args');

    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/dashboard':
        if (_hasServerArgs(args) && args!.containsKey('email')) {
          return MaterialPageRoute(
            builder: (_) => DashboardScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
              fullName: args['fullName'] as String? ?? 'User',
              email: args['email'] as String,
              roles: _convertToStringList(args['roles']) ?? [], // Pass roles
            ),
          );
        }
        break;
      case '/sales':
        if (_hasServerArgs(args) && args!.containsKey('email')) {
          return MaterialPageRoute(
            builder: (_) => SalesScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
              email: args['email'] as String,
              roles: _convertToStringList(args['roles']) ?? [], // Pass roles
            ),
          );
        }
        break;
      case '/customerList':
        if (_hasServerArgs(args) && args!.containsKey('email')) {
          return MaterialPageRoute(
            builder: (_) => CustomerListScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
              email: args['email'] as String,
            ),
          );
        }
        break;
      case '/customerDetail':
        if (_hasServerArgs(args) && args!.containsKey('customer')) {
          return MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(
              customer: args!['customer'],
              serverUrl: args['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/addNewCustomer':
        if (_hasServerArgs(args) && args!.containsKey('email')) {
          return MaterialPageRoute(
            builder: (_) => AddNewCustomerScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
              email: args['email'] as String,
            ),
          );
        }
        break;
      case '/sales_invoice':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => SalesInvoiceScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
              filterIds: _convertToStringList(args['filterIds']),
            ),
          );
        }
        break;
      case '/salesInvoiceDetail':
        if (_hasServerArgs(args) && args!.containsKey('invoiceId')) {
          return MaterialPageRoute(
            builder: (_) => SalesInvoiceDetailScreen(
              invoiceId: args!['invoiceId'] as String,
              serverUrl: args['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/sales_order':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => SalesOrderScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
              roles: _convertToStringList(args['roles']) ?? [], // Pass roles
            ),
          );
        }
        break;
      case '/createSalesOrder':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => CreateSalesOrderScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/quotation_list':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => QuotationListScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/quotation':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => QuotationScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
              initialData: args['initialData'],
            ),
          );
        }
        break;
      case '/quotation_detail':
        if (_hasServerArgs(args) && args!.containsKey('quotation')) {
          return MaterialPageRoute(
            builder: (_) => QuotationDetailScreen(
              quotation: args!['quotation'],
              serverUrl: args['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/hr':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => HRScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/leaveApplicationList':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => LeaveApplicationListScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/employeeList':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => EmployeeListScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/attendanceList':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => AttendanceListScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/attendanceDetails':
        if (_hasServerArgs(args) && args!.containsKey('attendance')) {
          return MaterialPageRoute(
            builder: (_) => AttendanceDetailsScreen(
              attendance: args!['attendance'],
              serverUrl: args['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/createAttendance':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => CreateAttendanceScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/accounting':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => AccountingScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/paymentEntryList':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => PaymentEntryListScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/paymentEntryCreate':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => PaymentEntryCreateScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/paymentEntryDetail':
        if (_hasServerArgs(args) && args!.containsKey('paymentEntry')) {
          return MaterialPageRoute(
            builder: (_) => PaymentEntryDetailScreen(
              paymentEntry: args!['paymentEntry'],
              serverUrl: args['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      case '/visitEntryList':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => VisitEntryListScreen(
              serverUrl: args!['serverUrl'],
              sid: args['sid'],
            ),
          );
        }
        break;
      case '/visitEntryDetail':
        if (_hasServerArgs(args) && args!.containsKey('visitEntryName')) {
          return MaterialPageRoute(
            builder: (_) => VisitEntryDetailScreen(
              visitEntryName: args!['visitEntryName'],
              serverUrl: args!['serverUrl'],
              sid: args['sid'],
            ),
          );
        }
        break;
      case '/createVisitEntry':
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => CreateVisitEntryScreen(
              serverUrl: args!['serverUrl'],
              sid: args['sid'],
            ),
          );
        }
        break;
      case '/receivableReport': // Add route for ReceivableReportScreen
        if (_hasServerArgs(args)) {
          return MaterialPageRoute(
            builder: (_) => ReceivableReportScreen(
              serverUrl: args!['serverUrl'] as String,
              sid: args['sid'] as String,
            ),
          );
        }
        break;
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
        );
    }

    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(child: Text('Invalid arguments for this route')),
      ),
    );
  }
}
