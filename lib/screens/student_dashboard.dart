import 'package:flutter/material.dart';
import 'package:edutrack/screens/role_selection_screen.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart'; 
import 'student/schedule_screen.dart';
import 'student/grades_screen.dart';
import 'student/forms_screen.dart';
import 'student/resource_library_screen.dart';
import '../utils/storage_util.dart';
import 'student/student_profile_screen.dart';
import '../services/schedule_service.dart';
import '../services/assignment_service.dart';
import '../services/student_service.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'student/student_notifications_screen.dart'; 
import '../services/fcm_service.dart'; 
import '../utils/constants.dart'; 

class StudentDashboard extends StatefulWidget {
  final User user;

  const StudentDashboard({super.key, required this.user});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isLoading = true;
  int _notificationCount = 3; // Example notification count
  List<Map<String, dynamic>> _upcomingAssignments = [];
  List<Map<String, dynamic>> _todaysClasses = [];
  
  // Add color variables to match teacher dashboard
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;
  late List<Color> _gradientColors;
  late ScheduleService _scheduleService;
  late StudentService _studentService; // Add StudentService
  String? _studentClassId; // Store the student's class ID

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // Initialize services
    _scheduleService = ScheduleService(baseUrl: Constants.apiBaseUrl); // Use Constants for base URL
    _studentService = StudentService(baseUrl: Constants.apiBaseUrl); // Initialize StudentService
    
    // Load theme colors like in teacher dashboard
    _loadThemeColors();
    
    // Fetch student data including class ID
    _fetchStudentData();
  }
  
  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _tertiaryColor = AppTheme.getTertiaryColor(AppTheme.defaultTheme);
    _gradientColors = AppTheme.getGradientColors(AppTheme.defaultTheme);
  }
  
  // Fix the _fetchStudentData method and remove the closing brace issue
  Future<void> _fetchStudentData() async {
    try {
      final studentData = await _studentService.getStudentById(widget.user.id);
      
      if (mounted) {
        setState(() {
          // Extract classId from the student data
          if (studentData.containsKey('classId')) {
            if (studentData['classId'] is Map<String, dynamic>) {
              _studentClassId = studentData['classId']['_id']; // If classId is an object with _id
            } else {
              _studentClassId = studentData['classId']; // If classId is directly the ID string
            }
          }
          
          print('📚 Fetched student classId: $_studentClassId');
          
          _isLoading = false;
          // Load data that depends on student information
          _loadUpcomingAssignments();
          _loadTodaysClasses();
        });
        _animationController.forward();
      }
    } catch (e) {
      print('📚 Error fetching student data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Initialize with empty data instead of mock data
          _upcomingAssignments = [];
          _todaysClasses = [];
        });
        _animationController.forward();
      }
    }
  }
  
  void _loadUpcomingAssignments() {
    // Load real data and handle errors properly
    _loadRealAssignments().catchError((error) {
      print('Failed to load real assignment data: $error');
      // Initialize with empty data instead of mock data
      setState(() {
        _upcomingAssignments = [];
      });
    });
  }

  Future<void> _loadRealAssignments() async {
    try {
      // Use the fetched class ID from student data
      final classId = _studentClassId;
      
      if (classId == null || classId.isEmpty) {
        print('📚 No class ID found for student');
        setState(() {
          _upcomingAssignments = [];
        });
        return;
      }

      print('📚 Fetching assignments for class: $classId');
      final assignments = await AssignmentService.getAssignments(
        classId: classId,
      );
      
      print('📚 Fetched ${assignments.length} assignments');
      
      if (assignments.isEmpty) {
        setState(() {
          _upcomingAssignments = [];
        });
        return;
      }
      
      // Get the completed assignments from local storage
      final prefs = await SharedPreferences.getInstance();
      final completedAssignments = prefs.getStringList('completed_assignments') ?? [];
      
      // Convert the Assignment objects to the map format used by the UI
      // Include description field from assignment
      final formattedAssignments = assignments.map((assignment) {
        final isCompleted = completedAssignments.contains(assignment.id);
        
        return {
          'id': assignment.id,
          'title': assignment.title,
          'subject': assignment.subject,
          'description': assignment.description,
          'dueDate': assignment.dueDate,
          'status': isCompleted ? 'Completed' : 'Pending'  // Set status based on local storage
        };
      }).toList();
      
      // Sort by due date (closest first)
      formattedAssignments.sort((a, b) => 
        (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime));
      
      setState(() {
        _upcomingAssignments = formattedAssignments;
      });
    } catch (e) {
      print('📚 Error loading assignments: $e');
      setState(() {
        _upcomingAssignments = [];
      });
      throw e; // Rethrow to be caught by the catchError
    }
  }

 

  void _loadTodaysClasses() {
    // Load real data and handle errors properly
    _loadRealTodaysClasses().catchError((error) {
      print('Failed to load real schedule data: $error');
      // Initialize with empty data instead of mock data
      setState(() {
        _todaysClasses = [];
      });
    });
  }

  Future<void> _loadRealTodaysClasses() async {
    try {
      final scheduleData = await _scheduleService.getStudentSchedule(widget.user.id);
      
      if (scheduleData != null && scheduleData.containsKey('schedule')) {
        final schedule = scheduleData['schedule'];
        final today = DateFormat('EEEE').format(DateTime.now()).toLowerCase();
        
        print('📅 Processing schedule data for today: $today');
        print('📅 Schedule data: $schedule');
        
        List<Map<String, dynamic>> classes = [];
        
        // Check if we have weekSchedule data
        if (schedule is Map && schedule.containsKey('weekSchedule')) {
          final weekSchedule = schedule['weekSchedule'];
          print('📅 Week schedule: $weekSchedule');
          
          if (weekSchedule is Map && weekSchedule.containsKey(today)) {
            final todaySchedule = weekSchedule[today];
            print('📅 Today\'s schedule: $todaySchedule');
            
            if (todaySchedule is List) {
              classes = todaySchedule.map((period) {
                if (period is Map<String, dynamic>) {
                  // Format time display
                  String timeDisplay = period['timeSlot'] ?? 
                      '${period['startTime'] ?? ''} - ${period['endTime'] ?? ''}';
                  
                  return {
                    'subject': period['subject'] ?? 'Unknown Subject',
                    'time': timeDisplay,
                    'teacher': period['teacher'] ?? 'Unknown Teacher',
                    'room': 'Room ${period['periodNumber'] ?? 'TBD'}', // You can enhance this if room data is available
                    'color': _getColorForSubject(period['subject'] ?? 'Unknown'),
                    'periodNumber': period['periodNumber'] ?? 0,
                  };
                }
                return <String, dynamic>{};
              }).where((item) => item.isNotEmpty).toList().cast<Map<String, dynamic>>();
              
              // Sort by period number or start time
              classes.sort((a, b) {
                int periodA = a['periodNumber'] ?? 0;
                int periodB = b['periodNumber'] ?? 0;
                return periodA.compareTo(periodB);
              });
            }
          }
        }
        
        print('📅 Final classes list: $classes');
        
        setState(() {
          _todaysClasses = classes;
        });
        
        if (classes.isEmpty) {
          print('📅 No classes found for today');
          setState(() {
            _todaysClasses = [];
          });
        }
      } else {
        print('📅 No schedule data found');
        setState(() {
          _todaysClasses = [];
        });
      }
    } catch (e) {
      print('📅 Error loading real schedule: $e');
      setState(() {
        _todaysClasses = [];
      });
      throw e; // Rethrow to be caught by the catchError
    }
  }

  

  Color _getColorForSubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return Colors.blue;
      case 'science':
      case 'physics':
      case 'chemistry':
      case 'biology':
        return Colors.green;
      case 'english':
      case 'literature':
        return Colors.purple;
      case 'history':
        return Colors.orange;
      case 'computer science':
        return Colors.indigo;
      case 'physical education':
      case 'pe':
        return Colors.red;
      case 'art':
        return Colors.amber;
      case 'music':
        return Colors.deepPurple;
      case 'geography':
        return Colors.brown;
      default:
        return Colors.grey;
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
              Icon(Icons.school, 
                  color: Colors.white, size: isSmallScreen ? 22 : 28),
              SizedBox(width: isSmallScreen ? 8 : 12),
              const Text('Student',
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
                _showNotifications(context);
              },
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Material(
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showProfile(context);
                    },
                    child: widget.user.profile.profilePicture.isNotEmpty
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(widget.user.profile.profilePicture),
                          radius: 16,
                        )
                      : Text(
                          widget.user.profile.firstName[0],
                          style: TextStyle(
                              color: _primaryColor, fontWeight: FontWeight.bold),
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
                // Fetch all data again starting with student data
                await _fetchStudentData();
                return Future.value();
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreetingCard(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Today\'s Schedule'),
                    const SizedBox(height: 12),
                    _buildTodaySchedule(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('HomeWork & Assignments'),
                    const SizedBox(height: 12),
                    _buildUpcomingAssignments(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Quick Actions'),
                    const SizedBox(height: 12),
                    _buildQuickActionsGrid(),
                  ],
                ),
              ),
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
                      color: Colors.white
                    ),
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
                  
                  _buildDrawerSectionHeader('ACADEMICS'),
                  
                  _buildDrawerItem(Icons.calendar_today, 'Schedule', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentScheduleScreen(user: widget.user),
                      ),
                    );
                  }, color: Colors.blue),
                  
                  _buildDrawerItem(Icons.trending_up, 'Grades & Progress', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GradesScreen(user: widget.user),
                      ),
                    );
                  }, color: Colors.orange),
                  
                  _buildDrawerItem(Icons.library_books, 'Resource Library', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ResourceLibraryScreen(),
                      ),
                    );
                  }, color: Colors.teal),
                  
                  _buildDrawerSectionHeader('COMMUNICATION'),
                  
                  _buildDrawerItem(Icons.notifications_outlined, 'Notifications', () {
                    Navigator.pop(context);
                    _showNotifications(context);
                  }, color: Colors.pinkAccent),

                  _buildDrawerSectionHeader('SERVICES'),
                  
                  _buildDrawerItem(Icons.description, 'Forms & Requests', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormsScreen(user: widget.user),
                      ),
                    );
                  }, color: Colors.deepPurple),
                  
                  const Divider(height: 1),
                  const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(2)),
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTodaySchedule() {
    if (_todaysClasses.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No classes scheduled for today',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _todaysClasses.length,
      itemBuilder: (context, index) {
        final classItem = _todaysClasses[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: classItem['color'].withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.class_, color: classItem['color']),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            classItem['subject'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            classItem['time'],
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        classItem['teacher'],
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingAssignments() {
    if (_upcomingAssignments.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No upcoming assignments',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _upcomingAssignments.length,
      itemBuilder: (context, index) {
        final assignment = _upcomingAssignments[index];
        final daysLeft = assignment['dueDate'].difference(DateTime.now()).inDays;
        
        Color statusColor;
        switch (assignment['status']) {
          case 'Submitted':
            statusColor = Colors.green;
            break;
          case 'Graded':
            statusColor = Colors.purple;
            break;
          case 'Draft Saved':
            statusColor = Colors.orange;
            break;
          default:
            statusColor = daysLeft <= 1 ? Colors.red : Colors.blue;
        }
        
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 100)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(20 * (1 - value), 0),
                child: child,
              ),
            );
          },
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment, color: statusColor),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment['subject'], // Display subject
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (assignment.containsKey('description') && assignment['description'] != null)
                    Text(
                      assignment['description'].toString().length > 60
                          ? '${assignment['description'].toString().substring(0, 60)}...'
                          : assignment['description'].toString(),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${DateFormat('MMM dd, yyyy').format(assignment['dueDate'])} (${daysLeft} days left)',
                    style: TextStyle(
                      color: daysLeft <= 1 ? Colors.red : Colors.black54, 
                      fontSize: 12,
                      fontWeight: daysLeft <= 1 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  assignment['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () {
                _showAssignmentDetails(context, assignment);
              },
            ),
          ),
        );
      },
    );
  }

  // Add a method to show assignment details in a modal
  void _showAssignmentDetails(BuildContext context, Map<String, dynamic> assignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  
                  // Subject chip
                  Wrap(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8, bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getColorForSubject(assignment['subject']).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getColorForSubject(assignment['subject']).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          assignment['subject'],
                          style: TextStyle(
                            color: _getColorForSubject(assignment['subject']),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      // Status chip
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          assignment['status'],
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Due date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today, color: _accentColor),
                    title: const Text('Due Date'),
                    subtitle: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(assignment['dueDate']),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  
                  const Divider(),
                  
                  // Description
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      assignment.containsKey('description') && assignment['description'] != null
                          ? assignment['description']
                          : 'No description provided',
                      style: TextStyle(
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Submit button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text(
                      'Mark as Completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      // Store completed status in local storage
                      final prefs = await SharedPreferences.getInstance();
                      final String assignmentId = assignment['id'] ?? DateTime.now().toString();
                      final completedAssignments = prefs.getStringList('completed_assignments') ?? [];
                      
                      if (!completedAssignments.contains(assignmentId)) {
                        completedAssignments.add(assignmentId);
                        await prefs.setStringList('completed_assignments', completedAssignments);
                        
                        // Update the state
                        setState(() {
                          // Update the status of this assignment in the list
                          for (var i = 0; i < _upcomingAssignments.length; i++) {
                            if (_upcomingAssignments[i]['id'] == assignmentId) {
                              _upcomingAssignments[i]['status'] = 'Completed';
                              break;
                            }
                          }
                        });
                        
                        // Close the dialog
                        Navigator.pop(context);
                        
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assignment marked as completed'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        // Assignment was already marked as completed
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assignment was already marked as completed'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
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
          title: 'Class Schedule',
          icon: Icons.calendar_today,
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentScheduleScreen(user: widget.user),
            ),
          ),
        ),
        _buildDashboardCard(
          context: context,
          title: 'Grades & Progress',
          icon: Icons.trending_up,
          color: Colors.orange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GradesScreen(user: widget.user),
            ),
          ),
        ),
        _buildDashboardCard(
          context: context,
          title: 'Resource Library',
          icon: Icons.library_books,
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ResourceLibraryScreen(),
            ),
          ),
        ),
        _buildDashboardCard(
          context: context,
          title: 'Forms & Requests',
          icon: Icons.description,
          color: Colors.purple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormsScreen(user: widget.user),
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

  void _showProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudentProfileScreen(user: widget.user),
      ),
    );
  }
  
  void _showNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentNotificationsScreen(user: widget.user),
      ),
    );
  }
}

