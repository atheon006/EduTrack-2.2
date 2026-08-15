import 'package:flutter/material.dart';
import 'package:school_app/screens/role_selection_screen.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import '../utils/storage_util.dart';
import '../utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/parents/attendance_screen.dart';
import '../screens/parents/performance_screen.dart';
import '../services/student_service.dart';
import '../services/attendance_service.dart';
import '../services/grading_service.dart';
import '../services/class_services.dart';
import './parents/notification_screen.dart';
import '../services/fcm_service.dart';
import '../utils/constants.dart'; // Import constants for base URL
import '../screens/parents/profile_screen.dart';

class ParentDashboard extends StatefulWidget {
  final User user;

  const ParentDashboard({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String studentId= '';
  String schoolId = '';
  Map<String, dynamic> _dashboardStats = {};
  late AnimationController _animationController;

  // Theme colors
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;
  late List<Color> _gradientColors;

  // Services
  late StudentService _studentService;
  late AttendanceService _attendanceService;
  late GradingService _gradingService;
  late ClassService _classService;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Initialize services with baseUrl like other dashboards
    const baseUrl = Constants.apiBaseUrl; // Use the constant for base URL
    _studentService = StudentService(baseUrl: baseUrl);
    _attendanceService = AttendanceService(baseUrl: baseUrl);
    _gradingService = GradingService(baseUrl: baseUrl);
    _classService = ClassService(baseUrl: baseUrl);

    _loadThemeColors();
    _loadDashboardData();
    _loadStudentsData();
  }

  // Student data for the children of the parent
  List<Map<String, dynamic>> _studentsData = [];

  Future<void> _loadStudentsData() async {
    try {
      print('👨‍👩‍👧‍👦 Loading students for parent: ${widget.user.id}');

      // Get students for this parent directly from the API
      final response =
          await _studentService.getStudentsByParentId(widget.user.id);
      print('👨‍👩‍👧‍👦 Found ${response.length} children for parent');

      // Transform student data to the format expected by the UI
      final transformedStudents = await Future.wait(
        response.map((student) async {
          // Get attendance data - use academicReport if available, otherwise fetch it
          Map<String, dynamic> attendanceData;
          if (student['academicReport'] != null &&
              student['academicReport']['attendancePct'] != null) {
            final attendancePct =
                student['academicReport']['attendancePct'] as int;
            attendanceData = {
              'percentage': '$attendancePct%',
              'presentDays': 0, // Not available in the report
              'totalDays': 0, // Not available in the report
            };
          } else {
            attendanceData = await _getStudentAttendance(student['_id']);
          }

          // Get grade data - use academicReport if it has grades, otherwise fetch it
          Map<String, dynamic> gradeData;
          if (student['academicReport'] != null &&
              student['academicReport']['grades'] != null &&
              (student['academicReport']['grades'] as List).isNotEmpty) {
            // Calculate from academicReport grades
            final average = 85.0; // Placeholder, would calculate from grades
            final gpa = (average / 25).clamp(0.0, 4.0);
            gradeData = {
              'gpa': gpa.toStringAsFixed(1),
              'average': average,
            };
          } else {
            gradeData = await _getStudentGrades(student['_id']);
          }

          // Extract class info directly from the response if classId is expanded
          Map<String, dynamic> classInfo;
          if (student['classId'] is Map<String, dynamic>) {
            final classData = student['classId'] as Map<String, dynamic>;
            classInfo = {
              'grade': classData['grade'] ?? 'Unknown',
              'section': classData['section'] ?? 'A',
              'name': classData['name'] ?? 'Unknown Class',
            };
          } else {
            // Fallback to fetching class info if not expanded
            classInfo = await _getClassInfo(student['classId']);
          }

          return {
            '_id': student['_id'] ?? '',
            'name': student['name'] ?? 'Unknown Student',
            'grade': classInfo['grade'] ?? 'Unknown Grade',
            'section': classInfo['section'] ?? 'A',
            studentId : student['studentId']??" ",
            'rollNumber': student['studentId'] ?? '',
            'image': _getStudentImage(student),
            'attendance': attendanceData['percentage'],
            'gpa': gradeData['gpa'],
            'email': student['email'] ?? '',
            'phone': student['phone'] ?? '',
            'dob': student['dob'] ?? '',
            'gender': student['gender'] ?? '',
            'address': student['address'] ?? '',
          };
        }).toList(),
      );

      if (mounted) {
        setState(() {
          _studentsData = transformedStudents;
        });
      }
    } catch (e) {
      print('👨‍👩‍👧‍👦 Error loading students: $e');
      if (mounted) {
        setState(() {
          _studentsData = [];
        });
      }
    }
  }

  // Get real attendance data for a student
  Future<Map<String, dynamic>> _getStudentAttendance(String studentId) async {
    try {
      final attendanceRecords =
          await _attendanceService.listAttendance(studentId: studentId);

      if (attendanceRecords.isEmpty) {
        return {'percentage': '0%', 'presentDays': 0, 'totalDays': 0};
      }

      int totalDays = 0;
      int presentDays = 0;

      for (var record in attendanceRecords) {
        if (record['entries'] is List) {
          for (var entry in record['entries']) {
            if (entry['studentId'] == studentId) {
              totalDays++;
              if (entry['status'] == 'present') {
                presentDays++;
              }
            }
          }
        }
      }

      final percentage =
          totalDays > 0 ? ((presentDays / totalDays) * 100).round() : 0;

      return {
        'percentage': '$percentage%',
        'presentDays': presentDays,
        'totalDays': totalDays,
      };
    } catch (e) {
      print('📊 Error getting attendance for student $studentId: $e');
      return {'percentage': 'N/A', 'presentDays': 0, 'totalDays': 0};
    }
  }

  // Get real grade data for a student
  Future<Map<String, dynamic>> _getStudentGrades(String studentId) async {
    try {
      final grades = await _gradingService.getStudentGrades(studentId);

      if (grades.isEmpty) {
        return {'gpa': '0.0', 'average': 0.0};
      }

      final average = GradingService.calculateOverallAverage(grades);
      final gpa =
          (average / 25).clamp(0.0, 4.0); // Convert percentage to 4.0 scale

      return {
        'gpa': gpa.toStringAsFixed(1),
        'average': average,
      };
    } catch (e) {
      print('📊 Error getting grades for student $studentId: $e');
      return {'gpa': 'N/A', 'average': 0.0};
    }
  }

  // Get class information
  Future<Map<String, dynamic>> _getClassInfo(dynamic classId) async {
    try {
      if (classId == null) return {'grade': 'Unknown', 'section': 'A'};

      String actualClassId;
      if (classId is Map<String, dynamic>) {
        actualClassId = classId['_id'] ?? '';
      } else {
        actualClassId = classId.toString();
      }

      if (actualClassId.isEmpty) return {'grade': 'Unknown', 'section': 'A'};

      final classData = await _classService.getClassById(actualClassId);

      return {
        'grade': classData['grade'] ?? 'Unknown',
        'section': classData['section'] ?? 'A',
        'name': classData['name'] ?? 'Unknown Class',
      };
    } catch (e) {
      print('📊 Error getting class info: $e');
      return {'grade': 'Unknown', 'section': 'A'};
    }
  }

  // Helper methods for mock data (replace with actual service calls)


  String _getStudentImage(Map<String, dynamic> student) {
    // Return a default student image or use profile picture if available
    final profilePicture = student['profilePicture'];
    if (profilePicture != null && profilePicture.isNotEmpty) {
      return profilePicture;
    }

    // Generate a consistent random image based on student ID
    final studentId = student['_id'] ?? student['studentId'] ?? '';
    final imageIndex = studentId.hashCode.abs() % 10 + 1;
    return 'https://randomuser.me/api/portraits/children/$imageIndex.jpg';
  }

  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _tertiaryColor = AppTheme.getTertiaryColor(AppTheme.defaultTheme);
    _gradientColors = AppTheme.getGradientColors(AppTheme.defaultTheme);
  }

  Future<void> _loadDashboardData() async {
    // Simulate loading data
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _dashboardStats = {
          'announcements': 3,
          'absences': 2,
        };

        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360 || screenSize.height < 700;

    return Theme(
      data: AppTheme.getTheme(AppTheme.defaultTheme),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.family_restroom,
                  color: Colors.white, size: isSmallScreen ? 22 : 28),
              SizedBox(width: isSmallScreen ? 8 : 12),
              const Text(
                'Parent',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, size: 28),
                ],
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ParentNotificationScreen(user: widget.user),
                    ));
              },
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Material(
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Navigate to profile screen when avatar is tapped
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ParentProfileScreen(user: widget.user),
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'profile-${widget.user.id}',
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(widget.user.profile.profilePicture),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: _accentColor),
              )
            : RefreshIndicator(
                color: _accentColor,
                onRefresh: () async {
                  setState(() {
                    _isLoading = true;
                  });
                  await _loadDashboardData();
                  return Future.value();
                },
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGreetingCard(),
                      const SizedBox(height: 24),

                      // My Children Section
                      _buildSectionHeader('My Children'),
                      const SizedBox(height: 12),
                      _buildStudentsCarousel(),
                      const SizedBox(height: 24),

                      // Performance Reports Section
                      _buildSectionHeader('Quick Access'),
                      const SizedBox(height: 12),
                      _buildQuickActionsGrid(),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.assessment),
              label: 'Performance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
          ],
          currentIndex: 0,
          selectedItemColor: _primaryColor,
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ParentPerformanceScreen(user: widget.user),
                    ));
                break;
              case 1:
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ParentAttendanceScreen(user: widget.user),
                    ));
                break;
              case 2:
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ParentNotificationScreen(user: widget.user),
                    ));
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage(widget.user.profile.profilePicture),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  Text(
                    widget.user.profile.firstName,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
              color: _accentColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStudentsCarousel() {
    if (_studentsData.isEmpty) {
      return Card(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.family_restroom,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Children Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No students are associated with your account.\nPlease contact the school administration.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _studentsData.length,
        itemBuilder: (context, index) {
          final student = _studentsData[index];

          return GestureDetector(
            child: Container(
              width: 300,
              margin: const EdgeInsets.only(right: 16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.white, _accentColor.withValues(alpha: 0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                NetworkImage(student['image'] as String),
                            onBackgroundImageError: (exception, stackTrace) {
                              // Handle image loading error
                              print('Error loading student image: $exception');
                            },
                            child: student['image'] == null ||
                                    (student['image'] as String).isEmpty
                                ? Text(
                                    (student['name'] as String).isNotEmpty
                                        ? (student['name'] as String)[0]
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "${student['grade'] as String} - Section ${student['section'] as String}",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                Text(
                                  "Roll #: ${student['rollNumber'] as String}",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            
          );
        },
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildDashboardCard(
          context: context,
          title: 'Grades & Reports',
          icon: Icons.grade,
          color: Colors.indigo,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParentPerformanceScreen(user: widget.user),
            ),
          ),
        ),
        _buildDashboardCard(
          context: context,
          title: 'Attendance',
          icon: Icons.calendar_today,
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParentAttendanceScreen(user: widget.user),
            ),
          ),
        ),
        _buildDashboardCard(
          context: context,
          title: 'School Updates',
          icon: Icons.notifications,
          color: Colors.red,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParentNotificationScreen(user: widget.user),
            ),
          ),
        ),
       
      ],
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, color.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              '${widget.user.profile.firstName} ${widget.user.profile.lastName}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white),
            ),
            accountEmail: Text(
              widget.user.email,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage(widget.user.profile.profilePicture),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.dashboard, color: _accentColor),
                    ),
                    title: const Text('Dashboard'),
                    selected: true,
                    selectedTileColor: _accentColor.withValues(alpha: 0.1),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(Icons.person, 'My Profile', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParentProfileScreen(user: widget.user),
                      ),
                    );
                  }, color: Colors.blue),
                  _buildDrawerSectionHeader('ACADEMICS'),
                  _buildDrawerItem(Icons.grade, 'Performance Reports', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ParentPerformanceScreen(user: widget.user),
                      ),
                    );
                  }, color: Colors.indigo),
                  _buildDrawerItem(Icons.calendar_today, 'Attendance Reports',
                      () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ParentAttendanceScreen(user: widget.user),
                      ),
                    );
                  }, color: Colors.green),
                  _buildDrawerSectionHeader('COMMUNICATION'),
                  _buildDrawerItem(
                      Icons.notifications_outlined, 'Notifications', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ParentNotificationScreen(user: widget.user),
                      ),
                    );
                  }, color: Colors.red),
                ],
              ),
            ),
          ),

          // Bottom fixed logout button
          ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red),
                ),
                title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  // Show confirmation dialog before logout
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to log out?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              // Close the confirmation dialog first
                              Navigator.of(dialogContext).pop();
                              
                              // Store the current context
                              final currentContext = context;
                              
                              // Check if still mounted before showing loading dialog
                              if (mounted) {
                                // Show loading indicator
                                showDialog(
                                  context: currentContext,
                                  barrierDismissible: false,
                                  builder: (context) => Dialog(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(color: _primaryColor),
                                          const SizedBox(height: 16),
                                          const Text('Logging out...'),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              try {
                                // Delete FCM token from server
                                final fcmService = FCMService();
                                await fcmService.deleteFCMTokenFromServer(widget.user.id);
                                
                                // Clear user auth credentials and other storage
                                await StorageUtil.setString('accessToken', '');
                                await StorageUtil.setString('refreshToken', '');

                                // Clear user profile information
                                await StorageUtil.setString('userId', '');
                                await StorageUtil.setString('userEmail', '');
                                await StorageUtil.setString('userRole', '');
                                await StorageUtil.setString('userFirstName', '');
                                await StorageUtil.setString('userLastName', '');
                                await StorageUtil.setString('userPhone', '');
                                await StorageUtil.setString('userAddress', '');
                                await StorageUtil.setString('userProfilePic', '');

                                // Clear school-related information
                                await StorageUtil.setString('schoolToken', '');
                                await StorageUtil.setString('schoolName', '');
                                await StorageUtil.setString('schoolId', '');
                                await StorageUtil.setString('schoolAddress', '');
                                await StorageUtil.setString('schoolPhone', '');

                                // Set login status to false
                                await StorageUtil.setBool('isLoggedIn', false);

                                // Clear SharedPreferences as well
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.clear();
                                
                                // Close loading dialog if still mounted
                                if (mounted) {
                                  Navigator.of(currentContext).pop();
                                }
                                
                                // Create navigation destination
                                final navigationDestination = MaterialPageRoute(
                                  builder: (context) => const RoleSelectionScreen(
                                    schoolName: "",
                                    schoolToken: "",
                                    schoolAddress: "",
                                    schoolPhone: "",
                                  ),
                                );
                                
                                // Only navigate if still mounted
                                if (mounted) {
                                  // Navigate to role selection screen
                                  Navigator.of(currentContext).pushAndRemoveUntil(
                                    navigationDestination,
                                    (route) => false,
                                  );
                                }
                              } catch (e) {
                                print('⚠️ Error during logout: $e');
                                
                                // Create navigation destination
                                final navigationDestination = MaterialPageRoute(
                                  builder: (context) => const RoleSelectionScreen(
                                    schoolName: "",
                                    schoolToken: "",
                                    schoolAddress: "",
                                    schoolPhone: "",
                                  ),
                                );
                                
                                // Only access context if still mounted
                                if (mounted) {
                                  // Try to close loading dialog
                                  Navigator.of(currentContext).pop();
                                  
                                  // Show error and navigate
                                  ScaffoldMessenger.of(currentContext).showSnackBar(
                                    SnackBar(
                                      content: Text('Logout error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  
                                  Navigator.of(currentContext).pushAndRemoveUntil(
                                    navigationDestination,
                                    (route) => false,
                                  );
                                }
                              }
                            },
                            child: const Text('Logout', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: _accentColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {String? badge, required Color color, bool isLogout = false}) {
    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isLogout ? FontWeight.bold : FontWeight.normal,
          color: isLogout ? Colors.red : null,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _tertiaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      hoverColor: color.withValues(alpha: 0.05),
      selectedColor: color,
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _dashboardStats['announcements'] = 0;
                            _dashboardStats['absences'] = 0;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Mark all as read'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Update the logout functionality to match school admin dashboard
    }