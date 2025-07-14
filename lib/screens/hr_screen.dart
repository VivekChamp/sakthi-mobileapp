import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class HRScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const HRScreen({required this.serverUrl, required this.sid, super.key});

  @override
  State<HRScreen> createState() => _HRScreenState();
}

class _HRScreenState extends State<HRScreen>
    with SingleTickerProviderStateMixin {
  String? checkInTime;
  String? checkOutTime;
  String? duration;
  bool isCheckedIn = false;
  int _selectedIndex = 0;
  String employeeName = 'Loading...';
  String employeeId = 'Loading...';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String? latitude;
  String? longitude;
  String? customLocation; // Human-readable address
  String? customMapLink; // Google Maps URL
  Timer? _timer; // Timer for real-time duration updates

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _fetchCheckIns(); // Fetch check-in/check-out history
    _getCurrentLocation(); // Fetch location when screen loads
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  // Fetch logged-in user info using the provided API
  Future<void> _fetchUserInfo() async {
    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_logged_in_user_info';
    final headers = {'Cookie': 'sid=${widget.sid}'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['message'];
        if (data['status'] == 'success') {
          setState(() {
            employeeName = data['user']['full_name'] ?? 'Unknown User';
            employeeId = data['user']['employee_id'] ?? 'N/A';
          });
        } else {
          setState(() {
            employeeName = 'User Not Found';
            employeeId = 'N/A';
          });
        }
      } else {
        setState(() {
          employeeName = 'Error Fetching Name';
          employeeId = 'Error Fetching ID';
        });
      }
    } catch (e) {
      setState(() {
        employeeName = 'Error Fetching Name';
        employeeId = 'Error Fetching ID';
      });
    }
  }

  // Fetch check-in/check-out history using the provided API
  Future<void> _fetchCheckIns() async {
    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_employee_checkins';
    final headers = {'Cookie': 'sid=${widget.sid}'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['message'];
        if (data['status'] == 'success') {
          final currentDate = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime.now()); // e.g., "2025-06-10"
          List<dynamic> checkIns = data['checkins']['in'] ?? [];
          List<dynamic> checkOuts = data['checkins']['out'] ?? [];

          // Filter check-ins and check-outs for the current day
          checkIns = checkIns.where((checkIn) {
            final checkInDate = checkIn['time'].split(' ')[0];
            return checkInDate == currentDate;
          }).toList();
          checkOuts = checkOuts.where((checkOut) {
            final checkOutDate = checkOut['time'].split(' ')[0];
            return checkOutDate == currentDate;
          }).toList();

          // Sort by time (latest first for check-ins, latest first for check-outs)
          checkIns.sort(
            (a, b) =>
                DateTime.parse(b['time']).compareTo(DateTime.parse(a['time'])),
          );
          checkOuts.sort(
            (a, b) =>
                DateTime.parse(b['time']).compareTo(DateTime.parse(a['time'])),
          );

          setState(() {
            if (checkIns.isNotEmpty) {
              // Latest check-in
              checkInTime = checkIns[0]['time'];
              // Check if there's a check-out after the latest check-in
              if (checkOuts.isNotEmpty &&
                  DateTime.parse(
                    checkOuts[0]['time'],
                  ).isAfter(DateTime.parse(checkInTime!))) {
                checkOutTime = checkOuts[0]['time'];
                isCheckedIn = false;
                duration = _calculateDuration(checkInTime!, checkOutTime!);
                _timer
                    ?.cancel(); // Stop the timer since the user has checked out
              } else {
                isCheckedIn = true;
                // Start a timer to update the duration every second
                _timer?.cancel(); // Cancel any existing timer
                _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                  setState(() {
                    duration = _calculateDuration(
                      checkInTime!,
                      DateTime.now().toString(),
                    );
                  });
                });
              }
            } else {
              isCheckedIn = false;
              duration = null;
              _timer?.cancel(); // Stop the timer if no check-in
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching check-ins: $e')));
    }
  }

  // Capture location using Geolocator (same as DailyVisitScreen)
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    PermissionStatus permission = await Permission.location.status;
    if (permission.isDenied || permission.isPermanentlyDenied) {
      permission = await Permission.location.request();
      if (permission.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      } else if (permission.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
        await openAppSettings();
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String? placeName = await _getPlaceName(
        position.latitude,
        position.longitude,
      );
      String mapLink = _generateMapLink(
        position.latitude.toString(),
        position.longitude.toString(),
      );
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
        customLocation = placeName;
        customMapLink = mapLink;
        print(
          'Device Location: lat=$latitude, lon=$longitude, customLocation=$customLocation, customMapLink=$customMapLink',
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      print('Error fetching location: $e');
    }
  }

  // Convert latitude and longitude to place name (same as DailyVisitScreen)
  Future<String?> _getPlaceName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        print('Placemark: $placemark'); // Debug log
        return placemark.locality != null && placemark.country != null
            ? "${placemark.locality}, ${placemark.country}"
            : placemark.locality ?? placemark.name ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      print('Error fetching place name: $e'); // Debug log
      return 'Unknown';
    }
  }

  // Generate a Google Maps link (same as DailyVisitScreen)
  String _generateMapLink(String lat, String lon) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }

  // Handle check-in or check-out with location capture
  Future<void> _handleCheckInOut(bool isCheckIn) async {
    // Ensure location is available
    if (latitude == null ||
        longitude == null ||
        customLocation == null ||
        customMapLink == null) {
      await _getCurrentLocation();
      if (latitude == null ||
          longitude == null ||
          customLocation == null ||
          customMapLink == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location unavailable, please enable location services',
            ),
          ),
        );
        return;
      }
    }

    // Make API call for employee check-in/check-out
    final url = '${widget.serverUrl}/api/resource/Employee Checkin';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'employee': employeeId,
      'employee_name': employeeName,
      'log_type': isCheckIn ? 'IN' : 'OUT',
      'time': DateTime.now().toIso8601String(),
      'device_id':
          customLocation?.toLowerCase() ?? 'unknown', // e.g., "calicut"
      'latitude': latitude,
      'longitude': longitude,
      'custom_map_link': customMapLink, // Add custom_map_link
      'custom_location': customLocation, // Add custom_location
      'skip_auto_attendance': 0,
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        setState(() {
          if (isCheckIn) {
            checkInTime = DateTime.now().toString();
            isCheckedIn = true;
            duration = '0h 0m 0s'; // Start at 00:00:00
            // Start the timer to update duration every second
            _timer?.cancel();
            _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
              setState(() {
                duration = _calculateDuration(
                  checkInTime!,
                  DateTime.now().toString(),
                );
              });
            });
          } else {
            checkOutTime = DateTime.now().toString();
            duration = _calculateDuration(checkInTime!, checkOutTime!);
            isCheckedIn = false;
            _timer?.cancel(); // Stop the timer after check-out
          }
        });
        // Show simplified snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCheckIn
                  ? 'Checked In Successfully'
                  : 'Checked Out Successfully',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        // Refresh check-in/check-out history
        await _fetchCheckIns();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isCheckIn ? 'check in' : 'check out'}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Calculate duration with seconds precision
  String _calculateDuration(String start, String end) {
    final startTime = DateTime.parse(start);
    final endTime = DateTime.parse(end);
    final diff = endTime.difference(startTime);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _onItemTapped(int index) {
    _animationController.forward(from: 0);
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushNamed(
          context,
          '/leaveApplicationList',
          arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
        );
        break;
      // case 1:
      //   Navigator.pushNamed(context, '/taskList', arguments: {
      //     'serverUrl': widget.serverUrl,
      //     'sid': widget.sid,
      //   });
      //   break;
      case 2:
        Navigator.pushNamed(
          context,
          '/employeeList',
          arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
        );
        break;
      case 3:
        Navigator.pushNamed(
          context,
          '/attendanceList',
          arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'EEE, d MMM yyyy',
    ).format(DateTime.now());
    final String greeting = _getGreeting();

    return Scaffold(
      body: Column(
        children: [
          // Deep Blue Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0074c9),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF0074c9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, $employeeName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Employee ID: $employeeId',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate, // Tue, 10 Jun 2025
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isCheckedIn ? 'Checked In' : 'Not Checked In',
                        style: TextStyle(
                          color: isCheckedIn
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Theme.of(context).colorScheme.background,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Today\'s Attendance',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            duration ?? '--h --m --s',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isCheckedIn
                                      ? null
                                      : () => _handleCheckInOut(true),
                                  icon: const Icon(Icons.login, size: 20),
                                  label: const Text('Check In'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isCheckedIn
                                      ? () => _handleCheckInOut(false)
                                      : null,
                                  icon: const Icon(Icons.logout, size: 20),
                                  label: const Text('Check Out'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildDashboardCard(
                        context,
                        'Leave',
                        Icons.event,
                        '/leaveApplicationList',
                      ),
                      _buildDashboardCard(
                        context,
                        'Attendance',
                        Icons.check_circle,
                        '/attendanceList',
                      ),
                      // _buildDashboardCard(context, 'Tasks', Icons.task, '/taskList'),
                      _buildDashboardCard(
                        context,
                        'Employee',
                        Icons.person,
                        '/employeeList',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            BottomNavigationBarItem(
              icon: _buildNavIcon(FontAwesomeIcons.calendar, 0),
              label: 'Leave',
            ),
            // BottomNavigationBarItem(
            //   icon: _buildNavIcon(FontAwesomeIcons.listCheck, 1),
            //   label: 'Task',
            // ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(FontAwesomeIcons.user, 2),
              label: 'Employee',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(FontAwesomeIcons.clipboardCheck, 3),
              label: 'Attendance',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index) {
    return ScaleTransition(
      scale: _selectedIndex == index
          ? _scaleAnimation
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _selectedIndex == index
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: FaIcon(icon, size: 24),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    String? route,
  ) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: route != null
            ? () => Navigator.pushNamed(
                context,
                route,
                arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
              )
            : () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$title coming soon!'))),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Theme.of(context).colorScheme.background],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
