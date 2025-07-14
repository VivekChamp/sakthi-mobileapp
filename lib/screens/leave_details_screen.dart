import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class LeaveDetailsScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final Map<String, dynamic> leave;
  final VoidCallback onLeaveUpdated;

  const LeaveDetailsScreen({
    required this.serverUrl,
    required this.sid,
    required this.leave,
    required this.onLeaveUpdated,
    super.key,
  });

  @override
  _LeaveDetailsScreenState createState() => _LeaveDetailsScreenState();
}

class _LeaveDetailsScreenState extends State<LeaveDetailsScreen> {
  File? attachment;
  String? attachmentName;
  String? fetchedAttachmentUrl;
  String? fetchedAttachmentName;
  bool isUploading = false;
  bool isLoadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _fetchAttachmentUrl();
  }

  Future<void> _fetchAttachmentUrl() async {
    if (widget.leave['name'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid leave application ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoadingAttachment = true);

    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_leave_attachment?leave_application_id=${widget.leave['name']}';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      print(
        'Fetch Attachment Response: ${response.statusCode} - ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success' &&
            data['message']['file_url'] != null) {
          setState(() {
            fetchedAttachmentUrl =
                '${widget.serverUrl}${data['message']['file_url']}';
            fetchedAttachmentName = data['message']['file_name'];
          });
        } else {
          setState(() {
            fetchedAttachmentUrl = null;
            fetchedAttachmentName = null;
          });
        }
      } else {
        setState(() {
          fetchedAttachmentUrl = null;
          fetchedAttachmentName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch attachment: ${response.statusCode} - ${response.body}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        fetchedAttachmentUrl = null;
        fetchedAttachmentName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching attachment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoadingAttachment = false);
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          openAppSettings();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Storage permission is required. Please enable it in settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _pickAttachment() async {
    print('Attempting to pick attachment...');
    if (!(await _requestStoragePermission())) {
      print('Storage permission denied');
      return;
    }
    try {
      print('Opening file picker...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        print('File selected: ${result.files.single.path}');
        setState(() {
          attachment = File(result.files.single.path!);
          attachmentName = result.files.single.name;
        });
      } else {
        print('No file selected');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No file selected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error picking attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking attachment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadAttachment(String leaveId) async {
    if (attachment == null) return null;

    setState(() => isUploading = true);
    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.upload_leave_attachment';
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Cookie'] = 'sid=${widget.sid}'
      ..headers['Accept'] = 'application/json'
      ..fields['leave_application_id'] = leaveId
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          attachment!.path,
          filename: attachmentName,
        ),
      );

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print(
        'Upload Attachment Response: ${response.statusCode} - $responseBody',
      );
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data['message']['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Attachment uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
          return '${widget.serverUrl}${data['message']['file_url']}';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Upload failed: ${data['message']['message'] ?? 'Unknown error'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload attachment: ${response.statusCode} - $responseBody',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading attachment: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _submitLeaveApplication() async {
    final leaveId = widget.leave['name'];
    if (leaveId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid leave ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? fileUrl = fetchedAttachmentUrl;
    if (attachment != null) {
      fileUrl = await _uploadAttachment(leaveId);
      if (fileUrl == null) return;
    } else if (widget.leave['leave_type'] == 'Sick Leave' &&
        widget.leave['status'] == 'Open' &&
        fetchedAttachmentUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach a medical certificate.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = '${widget.serverUrl}/api/resource/Leave Application/$leaveId';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = json.encode({'status': 'Open', 'attachment': fileUrl});

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      print('Submit Leave Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          fetchedAttachmentUrl = fileUrl;
          fetchedAttachmentName = attachmentName ?? fileUrl?.split('/').last;
          attachment = null;
          attachmentName = null;
        });
        widget.onLeaveUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave application updated (ID: $leaveId)'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(
          'Failed to submit leave: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting leave application: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isImage(String url) {
    final imageExtensions = ['jpg', 'jpeg', 'png'];
    final extension = url.split('.').last.toLowerCase();
    return imageExtensions.contains(extension);
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $url'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailSection() {
    final leave = widget.leave;
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave Details',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Leave ID', leave['name']),
          _buildDetailRow('Employee', leave['employee']),
          _buildDetailRow('Employee Name', leave['employee_name']),
          _buildDetailRow('Leave Type', leave['leave_type']),
          _buildDetailRow('Leave Approver', leave['leave_approver']),
          _buildDetailRow('From Date', leave['from_date']),
          _buildDetailRow('To Date', leave['to_date']),
          _buildDetailRow(
            'Total Leave Days',
            leave['total_leave_days'].toString(),
          ),
          _buildDetailRow('Description', leave['description']),
          _buildDetailRow('Posting Date', leave['posting_date']),
          _buildDetailRow('Company', leave['company']),
          _buildDetailRow('Status', leave['status']),
          _buildDetailRow('Letter Head', leave['letter_head']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attachment',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (isLoadingAttachment)
            const Center(child: CircularProgressIndicator()),
          if (!isLoadingAttachment && fetchedAttachmentUrl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _launchURL(fetchedAttachmentUrl!),
                  child: Text(
                    fetchedAttachmentName ??
                        fetchedAttachmentUrl!.split('/').last,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_isImage(fetchedAttachmentUrl!))
                  Image.network(
                    fetchedAttachmentUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.red),
                      );
                    },
                  ),
              ],
            ),
          if (!isLoadingAttachment && fetchedAttachmentUrl == null)
            const Text(
              'N/A',
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload New Attachment',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isUploading ? null : _pickAttachment,
                  icon: const Icon(Icons.attach_file),
                  label: Text(attachmentName ?? 'Upload Medical Certificate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isUploading ? null : _submitLeaveApplication,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: Size(
                double.infinity,
                MediaQuery.of(context).size.height * 0.07,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Submit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final isSickLeaveOpen =
        leave['leave_type'] == 'Sick Leave' && leave['status'] == 'Open';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Leave Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.white, // Fully white background
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection(),
                _buildAttachmentSection(),
                if (isSickLeaveOpen) _buildUploadSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
