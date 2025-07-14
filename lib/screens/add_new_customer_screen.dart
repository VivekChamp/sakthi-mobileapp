import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:geocoding/geocoding.dart';

class AddNewCustomerScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const AddNewCustomerScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _AddNewCustomerScreenState createState() => _AddNewCustomerScreenState();
}

class _AddNewCustomerScreenState extends State<AddNewCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Fields
  final TextEditingController customerNameController = TextEditingController();
  String? selectedCustomerType = 'Company';
  final TextEditingController addressLine1Controller = TextEditingController();
  final TextEditingController addressLine2Controller = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  String? selectedPhoneCode = '+91';
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactPersonNameController =
      TextEditingController();
  final TextEditingController dateOfEstdController = TextEditingController();
  final TextEditingController brandDealingController = TextEditingController();
  final TextEditingController annualTurnoverController =
      TextEditingController();
  final TextEditingController msmeCatController = TextEditingController();
  final TextEditingController classificationController =
      TextEditingController();
  final TextEditingController accountNoController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
  final TextEditingController ifscCodeController = TextEditingController();
  final TextEditingController remarksBySalesPersonController =
      TextEditingController();
  final TextEditingController remarksByRMController = TextEditingController();
  final TextEditingController remarksByGMController = TextEditingController();
  String?
  selectedAccountManager; // This remains as per original request for 'Account Manager Email'

  // New fields for Sales Person
  String? selectedSalesPersonName; // To display sales person's name
  String?
  selectedSalesPersonId; // To store the 'name' (e.g., SSIL-0001) for API submission

  String? selectedCountry = 'India';
  String? selectedState;
  String? selectedAddressType = 'Billing';
  String? selectedGstCategory;

  String latitude = '';
  String longitude = '';
  Map<String, File?> attachments = {
    'custom_adhar_card': null,
    'custom_other_document': null,
    'custom_bank_statement': null,
    'custom_pan_card': null,
  };

  // Dropdown Lists
  List<String> customerTypes = ['Company', 'Individual', 'Partnership'];
  Map<String, String> countryISDCodes = {
    'India': '+91',
    'United States': '+1',
    'United Kingdom': '+44',
    'United Arab Emirates': '+971',
    'Australia': '+61',
  };
  List<String> accountManagerEmails = [];
  // Removed customerOwnerEmails as per request

  // List to hold sales person data (name and sales_person_name)
  List<Map<String, String>> salesPersons = [];

  List<String> countries = [
    'India',
    'United States',
    'United Kingdom',
    'United Arab Emirates',
    'Australia',
    'Canada',
    'Germany',
    'France',
    'Japan',
    'China',
    'Singapore',
  ];

  Map<String, List<String>> statesByCountry = {
    'India': [
      'Kerala',
      'Tamil Nadu',
      'Karnataka',
      'Maharashtra',
      'Delhi',
      'Uttar Pradesh',
    ],
    'United States': ['California', 'Texas', 'New York', 'Florida'],
    'United Arab Emirates': [
      'Dubai',
      'Abu Dhabi',
      'Sharjah',
      'Ajman',
      'Umm Al-Quwain',
      'Ras Al Khaimah',
      'Fujairah',
    ],
  };

  List<String> addressTypes = ['Billing', 'Shipping', 'Home', 'Work', 'Other'];
  List<String> gstCategories = [
    'Registered Regular',
    'Registered Composition',
    'Unregistered',
    'SEZ',
    'Overseas',
    'Deemed Export',
    'UIN Holders',
    'Tax Deductor',
    'Tax Collector',
    'Input Service Distributor',
  ];

  String? selectedEmirate;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchEmails(); // Fetches account manager emails
    _fetchSalesPersons(); // Fetches sales persons
    _getCurrentLocation();
    if (selectedCountry != null &&
        statesByCountry.containsKey(selectedCountry) &&
        statesByCountry[selectedCountry]!.isNotEmpty) {
      selectedState = statesByCountry[selectedCountry]!.first;
    }
  }

  @override
  void dispose() {
    customerNameController.dispose();
    addressLine1Controller.dispose();
    addressLine2Controller.dispose();
    cityController.dispose();
    districtController.dispose();
    pincodeController.dispose();
    phoneController.dispose();
    emailController.dispose();
    contactPersonNameController.dispose();
    dateOfEstdController.dispose();
    brandDealingController.dispose();
    annualTurnoverController.dispose();
    msmeCatController.dispose();
    classificationController.dispose();
    accountNoController.dispose();
    bankNameController.dispose();
    branchController.dispose();
    ifscCodeController.dispose();
    remarksBySalesPersonController.dispose();
    remarksByRMController.dispose();
    remarksByGMController.dispose();
    super.dispose();
  }

  /// Fetches a list of user emails from the server to populate the Account Manager dropdown.
  Future<void> fetchEmails() async {
    final url =
        "${widget.serverUrl}/api/resource/User?fields=[\"email\"]&filters=[[\"enabled\", \"=\", 1]]";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body)['data'];
        setState(() {
          accountManagerEmails = data
              .map((user) => user['email'] as String)
              .toList();

          // Set selectedAccountManager if the logged-in email exists in the list
          if (accountManagerEmails.contains(widget.email)) {
            selectedAccountManager = widget.email;
          } else {
            selectedAccountManager = accountManagerEmails.isNotEmpty
                ? accountManagerEmails.first
                : null;
          }
        });
      } else {
        throw Exception('Failed to fetch emails: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching emails for Account Manager: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Fetches the list of sales persons from the dedicated API endpoint.
  /// Handles scenarios for admin/GM/RM (full list) and sales person (their own name).
  Future<void> _fetchSalesPersons() async {
    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_salesperson";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['message'] != null &&
            responseData['message']['data'] != null) {
          List<dynamic> data = responseData['message']['data'];
          setState(() {
            salesPersons = data
                .map(
                  (sp) => {
                    'name': sp['name'] as String,
                    'sales_person_name': sp['sales_person_name'] as String,
                  },
                )
                .toList();

            // Set the initial selected sales person
            // Check if the current user's email corresponds to a sales_person_name
            final currentUserSalesPerson = salesPersons.firstWhereOrNull(
              (sp) =>
                  sp['sales_person_name'] ==
                  widget.email
                      .split('@')
                      .first
                      .toUpperCase(), // Assuming email format allows this mapping
            );

            if (currentUserSalesPerson != null) {
              selectedSalesPersonName =
                  currentUserSalesPerson['sales_person_name'];
              selectedSalesPersonId = currentUserSalesPerson['name'];
            } else {
              // Default to the first available sales person if no direct match or for admin/GM/RM
              selectedSalesPersonName = salesPersons.isNotEmpty
                  ? salesPersons.first['sales_person_name']
                  : null;
              selectedSalesPersonId = salesPersons.isNotEmpty
                  ? salesPersons.first['name']
                  : null;
            }
          });
        } else {
          throw Exception('Invalid sales person data format');
        }
      } else {
        throw Exception(
          'Failed to fetch sales persons: ${response.statusCode}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching sales persons: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Gets the current geographical location of the device and populates address fields.
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied.'),
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        cityController.text = place.locality ?? '';
        pincodeController.text = place.postalCode ?? '';
        districtController.text = place.subAdministrativeArea ?? '';

        if (place.country != null && countries.contains(place.country)) {
          selectedCountry = place.country;
        } else {
          selectedCountry = 'India'; // Default to India if country not in list
        }

        if (selectedCountry == 'India' &&
            place.administrativeArea != null &&
            statesByCountry['India']!.contains(place.administrativeArea)) {
          selectedState = place.administrativeArea;
        } else if (selectedCountry == 'United Arab Emirates' &&
            place.administrativeArea != null &&
            statesByCountry['United Arab Emirates']!.contains(
              place.administrativeArea,
            )) {
          selectedEmirate = place.administrativeArea;
        } else {
          selectedState = null;
          selectedEmirate = null;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  /// Generates a Google Maps link based on provided latitude and longitude.
  String _generateMapLink(String lat, String lon) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }

  /// Opens a file picker to allow the user to select an attachment.
  Future<void> _pickFile(String attachmentKey) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        attachments[attachmentKey] = File(result.files.single.path!);
      });
    }
  }

  /// Opens a selected file using the device's default application.
  Future<void> _openFile(File file) async {
    try {
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Creates a new address record linked to the customer.
  Future<String> _createAddress(String customerId) async {
    final url = "${widget.serverUrl}/api/resource/Address";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final addressData = {
      'address_title': customerNameController.text.isNotEmpty
          ? customerNameController.text
          : 'Default Address',
      'address_type': selectedAddressType,
      'address_line1': addressLine1Controller.text,
      'address_line2': addressLine2Controller.text,
      'city': cityController.text,
      'district': districtController.text,
      'state': selectedCountry == 'United Arab Emirates'
          ? selectedEmirate
          : selectedState,
      'country': selectedCountry,
      'pincode': pincodeController.text,
      'links': [
        {'link_doctype': 'Customer', 'link_name': customerId},
      ],
    };
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(addressData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body)['data']['name'];
      } else {
        throw Exception(
          'Failed to create address: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a new contact record linked to the customer.
  Future<String> _createContact(String customerId) async {
    final url = "${widget.serverUrl}/api/resource/Contact";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final contactData = {
      'first_name': contactPersonNameController.text.isNotEmpty
          ? contactPersonNameController.text
          : customerNameController.text,
      if (emailController.text.isNotEmpty)
        'email_ids': [
          {'email_id': emailController.text, 'is_primary': 1},
        ],
      if (phoneController.text.isNotEmpty)
        'phone_nos': [
          {
            'phone': "$selectedPhoneCode${phoneController.text}",
            'is_primary_phone': 1,
          },
        ],
      'links': [
        {'link_doctype': 'Customer', 'link_name': customerId},
      ],
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(contactData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body)['data']['name'];
      } else {
        throw Exception(
          'Failed to create contact: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Main function to add a new customer, including addresses, contacts, and attachments.
  Future<void> addNewCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final url = "${widget.serverUrl}/api/resource/Customer";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final customMapLink = _generateMapLink(latitude, longitude);

    final customerData = {
      'customer_name': customerNameController.text,
      'customer_type': selectedCustomerType,
      'custom_date_of_estd': dateOfEstdController.text,
      'custom_brand_dealing': brandDealingController.text,
      'custom_annual_turnover': annualTurnoverController.text,
      'custom_msme_cat': msmeCatController.text,
      'custom_classification': classificationController.text,
      'custom_account_no': accountNoController.text,
      'custom_bank_name': bankNameController.text,
      'custom_branch': branchController.text,
      'custom_ifsc_code': ifscCodeController.text,
      'custom_remarks_by_sales_person': remarksBySalesPersonController.text,
      'custom_remarks_by_rm': remarksByRMController.text,
      'custom_remarks_by_gm': remarksByGMController.text,
      'account_manager': selectedAccountManager,
      // Removed 'custom_customer_owner'
      'sales_team': [
        // Use selectedSalesPersonId here, which stores the 'name' from the API
        {'sales_person': selectedSalesPersonId, 'allocated_percentage': 100.0},
      ],
      'custom_country': selectedCountry,
      'custom_latitude': latitude,
      'custom_longtitude': longitude,
      'custom_map_link': customMapLink,
      'custom_gst_category': selectedGstCategory,
    };

    try {
      final customerResponse = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(customerData),
      );
      if (customerResponse.statusCode != 200 &&
          customerResponse.statusCode != 201) {
        throw Exception(
          'Failed to add customer: ${customerResponse.statusCode} - ${customerResponse.body}',
        );
      }

      final customerId = json.decode(customerResponse.body)['data']['name'];

      String? addressId;
      if (addressLine1Controller.text.isNotEmpty ||
          addressLine2Controller.text.isNotEmpty ||
          cityController.text.isNotEmpty ||
          pincodeController.text.isNotEmpty ||
          selectedCountry != null ||
          selectedState != null ||
          selectedEmirate != null) {
        addressId = await _createAddress(customerId);
      }

      String? contactId;
      if (contactPersonNameController.text.isNotEmpty ||
          emailController.text.isNotEmpty ||
          phoneController.text.isNotEmpty) {
        contactId = await _createContact(customerId);
      }

      if (addressId != null || contactId != null) {
        final updateCustomerData = {
          'name': customerId,
          if (addressId != null) 'customer_primary_address': addressId,
          if (contactId != null) 'customer_primary_contact': contactId,
        };
        final updateResponse = await http.put(
          Uri.parse("$url/$customerId"),
          headers: headers,
          body: json.encode(updateCustomerData),
        );
        if (updateResponse.statusCode != 200) {
          throw Exception(
            'Failed to update customer: ${updateResponse.statusCode} - ${updateResponse.body}',
          );
        }
      }

      for (var entry in attachments.entries) {
        if (entry.value != null) {
          await _uploadAttachment(customerId, entry.key, entry.value!);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Customer added successfully!'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Uploads an attachment file to the server.
  Future<void> _uploadAttachment(
    String customerId,
    String fieldName,
    File file,
  ) async {
    final url = "${widget.serverUrl}/api/method/upload_file";
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Cookie'] = 'sid=${widget.sid}'
      ..fields['doctype'] = 'Customer'
      ..fields['docname'] = customerId
      ..fields['fieldname'] = fieldName
      ..fields['filename'] = file.path.split('/').last
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload attachment: ${response.statusCode}');
    }
  }

  /// Builds a standard text input field with a label and icon.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a generic dropdown field with a label, current value, list of items, and onChanged callback.
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    IconData? icon, // Added optional icon for consistency
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: icon != null
                  ? Icon(icon, color: Theme.of(context).colorScheme.primary)
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            value: value,
            items: items.map((item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Builds the specialized phone number input field with a country code dropdown.
  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phone Number',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 12.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: selectedPhoneCode,
                  items: countryISDCodes.values.toSet().toList().map((code) {
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Text(code, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedPhoneCode = value),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 7,
                child: TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 12.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a field for attaching files, with a button to pick a file and display the selected file's name.
  Widget _buildAttachmentField(String label, String fieldName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _pickFile(fieldName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Pick File'),
              ),
            ],
          ),
          if (attachments[fieldName] != null)
            ListTile(
              title: Text(
                attachments[fieldName]!.path.split('/').last,
                style: const TextStyle(color: Colors.black54),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, color: Colors.blue),
                onPressed: () => _openFile(attachments[fieldName]!),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a header for different sections of the form.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onBackground,
        ),
      ),
    );
  }

  /// Wraps a widget in a Card with consistent styling for sections.
  Widget _buildSection(Widget child) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white, // Consistent white background
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Customer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.white, // Remove gradient, use solid white background
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader('Basic Information'),
                    _buildSection(
                      Column(
                        children: [
                          _buildTextField(
                            controller: customerNameController,
                            label: 'Customer Name',
                            icon: Icons.business,
                          ),
                          _buildDropdownField(
                            label: 'Customer Type',
                            value: selectedCustomerType,
                            items: customerTypes,
                            onChanged: (value) =>
                                setState(() => selectedCustomerType = value),
                            icon: Icons.person_outline, // Added icon
                          ),
                          _buildTextField(
                            controller: dateOfEstdController,
                            label: 'Date of Establishment',
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.datetime,
                          ),
                          _buildTextField(
                            controller: brandDealingController,
                            label: 'Brand Dealing',
                            icon: Icons.branding_watermark,
                          ),
                          _buildTextField(
                            controller: annualTurnoverController,
                            label: 'Annual Turnover',
                            icon: Icons.monetization_on,
                            keyboardType: TextInputType.number,
                          ),
                          _buildTextField(
                            controller: msmeCatController,
                            label: 'MSME Category',
                            icon: Icons.category,
                          ),
                          _buildTextField(
                            controller: classificationController,
                            label: 'Classification',
                            icon: Icons.class_,
                          ),
                          _buildDropdownField(
                            label: 'GST Category',
                            value: selectedGstCategory,
                            items: gstCategories,
                            onChanged: (value) =>
                                setState(() => selectedGstCategory = value),
                            icon: Icons.receipt_long, // Added icon
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader('Address Information'),
                    _buildSection(
                      Column(
                        children: [
                          _buildDropdownField(
                            label: 'Address Type',
                            value: selectedAddressType,
                            items: addressTypes,
                            onChanged: (value) =>
                                setState(() => selectedAddressType = value),
                            icon: Icons.location_history, // Added icon
                          ),
                          _buildTextField(
                            controller: addressLine1Controller,
                            label: 'Address Line 1',
                            icon: Icons.location_on,
                          ),
                          _buildTextField(
                            controller: addressLine2Controller,
                            label: 'Address Line 2',
                            icon: Icons.location_on,
                          ),
                          _buildTextField(
                            controller: cityController,
                            label: 'City',
                            icon: Icons.location_city,
                          ),
                          _buildTextField(
                            controller: districtController,
                            label: 'District',
                            icon: Icons.location_city,
                          ),
                          _buildDropdownField(
                            label: 'Country',
                            value: selectedCountry,
                            items: countries,
                            onChanged: (value) {
                              setState(() {
                                selectedCountry = value;
                                selectedPhoneCode =
                                    countryISDCodes[value] ?? '+91';
                                selectedEmirate = null;
                                selectedState = null;
                                if (value == 'United Arab Emirates' &&
                                    statesByCountry[value]!.isNotEmpty) {
                                  selectedEmirate =
                                      statesByCountry[value]!.first;
                                } else if (statesByCountry.containsKey(value) &&
                                    statesByCountry[value]!.isNotEmpty) {
                                  selectedState = statesByCountry[value]!.first;
                                }
                              });
                            },
                            icon: Icons.public, // Added icon
                          ),
                          if (selectedCountry == 'United Arab Emirates')
                            _buildDropdownField(
                              label: 'Emirate',
                              value: selectedEmirate,
                              items: statesByCountry['United Arab Emirates']!,
                              onChanged: (value) =>
                                  setState(() => selectedEmirate = value),
                              icon: Icons.map, // Added icon
                            ),
                          if (selectedCountry != null &&
                              selectedCountry != 'United Arab Emirates' &&
                              statesByCountry.containsKey(selectedCountry))
                            _buildDropdownField(
                              label: 'State',
                              value: selectedState,
                              items: statesByCountry[selectedCountry]!,
                              onChanged: (value) =>
                                  setState(() => selectedState = value),
                              icon: Icons.map, // Added icon
                            ),
                          _buildTextField(
                            controller: pincodeController,
                            label: 'Pincode',
                            icon: Icons.location_searching,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader('Contact Information'),
                    _buildSection(
                      Column(
                        children: [
                          _buildPhoneField(),
                          _buildTextField(
                            controller: emailController,
                            label: 'Email',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _buildTextField(
                            controller: contactPersonNameController,
                            label: 'Contact Person Name',
                            icon: Icons.person,
                          ),
                          _buildDropdownField(
                            label: 'Account Manager Email',
                            value: selectedAccountManager,
                            items: accountManagerEmails,
                            onChanged: (value) =>
                                setState(() => selectedAccountManager = value),
                            icon: Icons.person_pin_circle, // Added icon
                          ),
                          // New Sales Person dropdown
                          _buildDropdownField(
                            label: 'Sales Person',
                            value: selectedSalesPersonName, // Display the name
                            items: salesPersons
                                .map((sp) => sp['sales_person_name']!)
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSalesPersonName = value;
                                // Find the corresponding 'name' (ID) for the selected sales_person_name
                                selectedSalesPersonId = salesPersons
                                    .firstWhereOrNull(
                                      (sp) => sp['sales_person_name'] == value,
                                    )?['name'];
                              });
                            },
                            icon: Icons.group, // Added icon
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader('Remarks Details'),
                    _buildSection(
                      Column(
                        children: [
                          _buildTextField(
                            controller: remarksBySalesPersonController,
                            label: 'Remarks by Sales Person',
                            icon: Icons.comment,
                            maxLines: 3,
                          ),
                          _buildTextField(
                            controller: remarksByRMController,
                            label: 'Remarks by RM',
                            icon: Icons.comment,
                            maxLines: 3,
                          ),
                          _buildTextField(
                            controller: remarksByGMController,
                            label: 'Remarks by GM',
                            icon: Icons.comment,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader('Bank Details'),
                    _buildSection(
                      Column(
                        children: [
                          _buildTextField(
                            controller: accountNoController,
                            label: 'Account Number',
                            icon: Icons.account_balance,
                            keyboardType: TextInputType.number,
                          ),
                          _buildTextField(
                            controller: bankNameController,
                            label: 'Bank Name',
                            icon: Icons.account_balance_wallet,
                          ),
                          _buildTextField(
                            controller: branchController,
                            label: 'Branch',
                            icon: Icons.location_on,
                          ),
                          _buildTextField(
                            controller: ifscCodeController,
                            label: 'IFSC Code',
                            icon: Icons.code,
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader('Attachments'),
                    _buildSection(
                      Column(
                        children: [
                          _buildAttachmentField(
                            'Aadhar Card',
                            'custom_adhar_card',
                          ),
                          _buildAttachmentField(
                            'Other Document',
                            'custom_other_document',
                          ),
                          _buildAttachmentField(
                            'Bank Statement',
                            'custom_bank_statement',
                          ),
                          _buildAttachmentField('PAN Card', 'custom_pan_card'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isLoading ? null : addNewCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Add Customer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Extension to easily find an element in a list, similar to Swift's first(where:)
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (T element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
