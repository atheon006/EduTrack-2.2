import 'package:flutter/material.dart';
import 'package:edutrack/screens/role_selection_screen.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../services/schedule_service.dart';
import '../services/fcm_service.dart';
import '../services/image_service.dart' as image_service;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../utils/storage_util.dart';
import '../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'teachers/teacher_classes_screen.dart';
import 'teachers/teacher_assignments_screen.dart';
import 'teachers/teacher_attendance_screen.dart';
import 'teachers/teacher_grading_screen.dart';
import 'teachers/teacher_notifications_screen.dart';
import 'teachers/teacher_profile_screen.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';

class TeacherDashboard extends StatefulWidget {
  final User user;

  const TeacherDashboard({super.key, required this.user});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> with TickerProviderStateMixin {
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;
  late List<Color> _gradientColors;
  bool _isLoading = true;
  List<Map<String, dynamic>> _todaysClasses = [];
  late ScheduleService _scheduleService;
  String? _profileImageUrl; // Add this variable

  // Add these new variables to track story state
  bool _hasStories = false;
  List<image_service.Story> _schoolStories = [];

  // Add these new variables for story viewer - make them nullable initially
  AnimationController? _progressController;
  Animation<double>? _progressAnimation;
  int _currentStoryIndex = 0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _scheduleService = ScheduleService(baseUrl: Constants.apiBaseUrl);
    _loadThemeColors();
    _loadTodaysClasses();
    _fetchSchoolStories();
    _loadProfileImageFromPrefs(); // Add this line

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAnimationController();
    });
  }

  // Add this method to safely initialize the animation controller
  void _initializeAnimationController() {
    if (mounted) {
      _progressController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 5), // 5 seconds per story
      );
      _progressAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(_progressController!);
    }
  }

  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _tertiaryColor = AppTheme.getTertiaryColor(AppTheme.defaultTheme);
    _gradientColors = AppTheme.getGradientColors(AppTheme.defaultTheme);
  }

  Future<void> _loadTodaysClasses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current day of week (Monday = 1, Sunday = 7)
      final now = DateTime.now();
      final currentDayOfWeek = now.weekday;
      final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final todayName = dayNames[currentDayOfWeek - 1];
      
      print('📅 Loading schedule for teacher ID: ${widget.user.id}');
      print('📅 Today is: $todayName (day $currentDayOfWeek)');

      // Fetch teacher's schedule from API
      final teacherScheduleResponse = await _scheduleService.getTeacherSchedule(widget.user.id);
      
      // Extract today's classes from the schedule
      List<Map<String, dynamic>> todaysClasses = [];
      
      if (teacherScheduleResponse != null) {
        print('📅 Full response: $teacherScheduleResponse');
        
        // Handle the nested structure where data contains an array of schedule objects
        dynamic scheduleData;
        if (teacherScheduleResponse.containsKey('data') && teacherScheduleResponse['data'] is List) {
          scheduleData = teacherScheduleResponse['data'] as List<dynamic>;
        } else if (teacherScheduleResponse is List) {
          scheduleData = teacherScheduleResponse as List<dynamic>;
        } else {
          // Single schedule object
          scheduleData = [teacherScheduleResponse];
        }
        
        // Process each schedule object
        for (var scheduleObj in scheduleData) {
          if (scheduleObj is Map<String, dynamic> && scheduleObj.containsKey('periods')) {
            final periods = scheduleObj['periods'] as List<dynamic>;
            final classInfo = scheduleObj['classId'] as Map<String, dynamic>?;
            
            print('📅 Processing ${periods.length} periods for class: ${classInfo?['name']}');
            
            for (var period in periods) {
              if (period is Map<String, dynamic>) {
                final dayOfWeek = period['dayOfWeek']?.toString();
                
                print('📅 Checking period: day=$dayOfWeek, subject=${period['subject']}, time=${period['startTime']}-${period['endTime']}');
                
                // Check if this period is for today
                if (dayOfWeek == todayName) {
                  print('📅 Found matching day: $dayOfWeek');
                  
                  // Extract teacher info
                  final teacherInfo = period['teacherId'] as Map<String, dynamic>?;
                  
                  todaysClasses.add({
                    'id': period['_id'] ?? scheduleObj['_id'] ?? '',
                    'subject': period['subject']?.toString() ?? 'Unknown Subject',
                    'startTime': period['startTime']?.toString() ?? '',
                    'endTime': period['endTime']?.toString() ?? '',
                    'classId': classInfo?['_id']?.toString() ?? '',
                    'className': '${classInfo?['name'] ?? 'Unknown Class'} - Grade ${classInfo?['grade']}${classInfo?['section']}',
                    'roomNumber': period['room']?.toString() ?? period['roomNumber']?.toString() ?? 'TBA',
                    'teacherId': teacherInfo?['_id']?.toString() ?? '',
                    'teacherName': teacherInfo?['name']?.toString() ?? '',
                    'day': dayOfWeek,
                    'periodNumber': period['periodNumber']?.toString() ?? '',
                    'grade': classInfo?['grade']?.toString() ?? '',
                    'section': classInfo?['section']?.toString() ?? '',
                  });
                }
              }
            }
          }
        }
      }

      // Sort classes by start time
      todaysClasses.sort((a, b) {
        final timeA = a['startTime']?.toString() ?? '';
        final timeB = b['startTime']?.toString() ?? '';
        return timeA.compareTo(timeB);
      });

      setState(() {
        _todaysClasses = todaysClasses;
        _isLoading = false;
      });
      
      print('📅 Found ${todaysClasses.length} classes for today: $todaysClasses');
    } catch (e) {
      print('📅 Error loading teacher schedule: $e');
      setState(() {
        _isLoading = false;
        _todaysClasses = [];
      });
    }
  }

  Future<void> _fetchSchoolStories() async {
    try {
      var schoolId = await StorageUtil.getString('schoolId') ?? widget.user.schoolToken;
      if (schoolId.isEmpty) {
        final firestoreService = FirestoreServiceRDC();
        final userDoc = await firestoreService.getUtilisateur(widget.user.id);
        if (userDoc != null && (userDoc.schoolId ?? '').isNotEmpty) {
          schoolId = userDoc.schoolId!;
          await StorageUtil.setString('schoolId', schoolId);
          await StorageUtil.setString('schoolToken', schoolId);
        }
      }

      if (schoolId.isEmpty) {
        print('⚠️ School ID not found in storage');
        setState(() {
          _hasStories = false;
          _schoolStories = [];
        });
        return;
      }

      // Get access token to check if we're authenticated
      final accessToken = await StorageUtil.getString('accessToken') ?? '';
      if (accessToken.isEmpty) {
        print('⚠️ No access token available, cannot fetch stories');
        setState(() {
          _hasStories = false;
          _schoolStories = [];
        });
        return;
      }

      print('🔍 Fetching stories for school ID: $schoolId');
      final imageService = image_service.ImageService();
      final stories = await imageService.getStoriesBySchool(schoolId);
      
      setState(() {
        _schoolStories = stories;
        _hasStories = stories.isNotEmpty;
      });
      
      print('📚 Fetched ${stories.length} stories for school $schoolId');
    } catch (e) {
      print('⚠️ Error fetching school stories: $e');
      setState(() {
        _hasStories = false;
        _schoolStories = [];
      });
    }
  }

  // Add this method to load profile image from SharedPreferences
  Future<void> _loadProfileImageFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedImageUrl = prefs.getString('profileImageUrl');
      if (cachedImageUrl != null) {
        setState(() {
          _profileImageUrl = cachedImageUrl;
        });
      } else {
        setState(() {
          _profileImageUrl = widget.user.profile.profilePicture;
        });
      }
      
      // Fetch fresh image from server
      _fetchProfileImage();
    } catch (e) {
      print('Error loading profile image from prefs: $e');
      setState(() {
        _profileImageUrl = widget.user.profile.profilePicture;
      });
      _fetchProfileImage();
    }
  }

  // Add this method to fetch profile image from server
  Future<void> _fetchProfileImage() async {
    try {
      final imageService = image_service.ImageService();
      final imageUrl = await imageService.getProfileImage(widget.user.id);
      if (imageUrl != null) {
        setState(() {
          _profileImageUrl = imageUrl;
        });
        
        // Save to preferences for future use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profileImageUrl', imageUrl);
      }
    } catch (e) {
      print('Error fetching profile image: $e');
    }
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
              const Text(
                'Teacher',
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
                    builder: (context) => TeacherNotificationsScreen(user: widget.user),
                  ),
                );
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeacherProfileScreen(user: widget.user),
                        ),
                      );
                    },
                    child: _profileImageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _profileImageUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                widget.user.profile.firstName[0],
                                style: TextStyle(
                                    color: _primaryColor, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
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
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
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
                currentAccountPicture: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeacherProfileScreen(user: widget.user),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage: _profileImageUrl != null 
                      ? NetworkImage(_profileImageUrl!)
                      : NetworkImage(widget.user.profile.profilePicture),
                    backgroundColor: Colors.white,
                    onBackgroundImageError: (exception, stackTrace) {
                      print('Error loading drawer profile image: $exception');
                    },
                  ),
                ),
              ),
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
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeacherProfileScreen(user: widget.user),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'TEACHING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.class_, color: Colors.blue),
                ),
                title: const Text('My Classes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => TeacherClassesScreen(user: widget.user))
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment, color: Colors.green),
                ),
                title: const Text('Homework'),  
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => TeacherAssignmentsScreen(user: widget.user))
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.red),
                ),
                title: const Text('Attendance'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => TeacherAttendanceScreen(user: widget.user))
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_up, color: Colors.orange),
                ),
                title: const Text('Grading'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => TeacherGradingScreen(user: widget.user))
                  );
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'COMMUNICATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.announcement, color: Colors.purple),
                ),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeacherNotificationsScreen(user: widget.user),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'OTHER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
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
        ),
        body: RefreshIndicator(
          color: _accentColor,
          onRefresh: _loadTodaysClasses,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingCard(),
                const SizedBox(height: 16),
                _buildSectionHeader('Today\'s Classes'),
                const SizedBox(height: 12),
                _buildTodayClassesList(),
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
            // Story viewing circle with profile image - clickable
            GestureDetector(
              onTap: _viewSchoolStories,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hasStories ? _accentColor : Colors.white,
                    width: _hasStories ? 3 : 2,
                  ),
                ),
                child: Stack(
                  children: [
                    ClipOval(
                      child: _profileImageUrl != null
                        ? Image.network(
                            _profileImageUrl!,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 54,
                                height: 54,
                                color: Colors.white,
                                child: Center(
                                  child: Text(
                                    widget.user.profile.firstName[0],
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 54,
                            height: 54,
                            color: Colors.white,
                            child: Center(
                              child: Text(
                                widget.user.profile.firstName[0],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                            ),
                          ),
                    ),
                    if (_hasStories)
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 2,
                          color: _accentColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70),
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

  // Method to view school stories
  void _viewSchoolStories() {
    if (_schoolStories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stories available. Try refreshing the app.')),
      );
      // Try to fetch again in case they were added recently
      _fetchSchoolStories();
      return;
    }
    
    // Ensure animation controller is initialized
    if (_progressController == null) {
      _initializeAnimationController();
      // Wait a frame for initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_progressController != null) {
          _showStoryViewer();
        }
      });
      return;
    }
    
    _showStoryViewer();
  }

  // Add this helper method to show the story viewer
  void _showStoryViewer() {
    // Reset story index and progress
    _currentStoryIndex = 0;
    _progressController?.reset();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (context) => _buildInstagramStoryViewer(),
    );
  }

  // Instagram-like story viewer widget
  Widget _buildInstagramStoryViewer() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTapDown: (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              final tapPosition = details.globalPosition.dx;
              
              if (tapPosition < screenWidth / 3) {
                // Tap on left side - previous story
                _previousStory(setModalState);
              } else if (tapPosition > 2 * screenWidth / 3) {
                // Tap on right side - next story
                _nextStory(setModalState);
              } else {
                // Tap on center - pause/resume
                _togglePause(setModalState);
              }
            },
            onLongPressStart: (_) => _pauseStory(setModalState),
            onLongPressEnd: (_) => _resumeStory(setModalState),
            child: Stack(
              children: [
                // Background story content
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: _buildStoryContent(_schoolStories[_currentStoryIndex], setModalState),
                ),
                
                // Progress bars at the top
                Positioned(
                  top: 50,
                  left: 8,
                  right: 8,
                  child: _buildProgressBars(),
                ),
                
                // Story header
                Positioned(
                  top: 80,
                  left: 16,
                  right: 16,
                  child: _buildStoryHeader(_schoolStories[_currentStoryIndex]),
                ),
                
                // Close button
                Positioned(
                  top: 50,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () {
                      _progressController?.stop();
                      Navigator.pop(context);
                    },
                  ),
                ),
                
                // Invisible tap areas for navigation
                _buildTapAreas(),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build progress bars
  Widget _buildProgressBars() {
    if (_progressAnimation == null) {
      return const SizedBox.shrink();
    }
    
    return Row(
      children: List.generate(_schoolStories.length, (index) {
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimation!,
              builder: (context, child) {
                double progress = 0.0;
                if (index < _currentStoryIndex) {
                  progress = 1.0; // Completed stories
                } else if (index == _currentStoryIndex) {
                  progress = _progressAnimation!.value; // Current story progress
                }
                
                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            ),
          ),
        );
      }),
    );
  }

  // Build story content
  Widget _buildStoryContent(image_service.Story story, StateSetter setModalState) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: story.mediaType.startsWith('image')
        ? Image.network(
            story.mediaUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // Start progress when image is loaded
                if (!_isPaused && _progressController != null && _progressController!.status != AnimationStatus.forward) {
                  _startProgress(setModalState);
                }
                return child;
              }
              return Center(
                child: CircularProgressIndicator(
                  color: _accentColor,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text('Failed to load story', style: TextStyle(color: Colors.white)),
                  ],
                ),
              );
            },
          )
        : Center(
            child: Text(
              'Unsupported media type: ${story.mediaType}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
    );
  }

  // Get time ago helper
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Build story header with user info
  Widget _buildStoryHeader(image_service.Story story) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            gradient: LinearGradient(
              colors: [_primaryColor, _accentColor],
            ),
          ),
          child: Center(
            child: Text(
              story.user.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                story.user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${story.user.role} • ${_getTimeAgo(story.createdAt)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build invisible tap areas for navigation
  Widget _buildTapAreas() {
    return Row(
      children: [
        // Left tap area - previous story
        Expanded(
          child: Container(
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
        // Center tap area - pause/play
        Expanded(
          child: Container(
            height: double.infinity,
            color: Colors.transparent,
            child: _isPaused 
              ? const Center(
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 64,
                  ),
                )
              : null,
          ),
        ),
        // Right tap area - next story
        Expanded(
          child: Container(
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }

  // Progress control methods
  void _startProgress([StateSetter? setModalState]) {
    if (_progressController == null) return;
    
    _progressController!.forward().then((_) {
      if (_currentStoryIndex < _schoolStories.length - 1) {
        _nextStory(setModalState ?? (fn) => setState(() {}));
      } else {
        // All stories completed, close viewer
        Navigator.pop(context);
      }
    });
  }

  void _restartProgress(StateSetter setModalState) {
    if (_progressController == null) return;
    
    _progressController!.reset();
    setModalState(() {});
    if (!_isPaused) {
      _startProgress(setModalState);
    }
  }

  void _pauseStory(StateSetter setModalState) {
    if (_progressController == null) return;
    
    _progressController!.stop();
    setModalState(() {
      _isPaused = true;
    });
  }

  void _resumeStory(StateSetter setModalState) {
    if (_progressController == null) return;
    
    setModalState(() {
      _isPaused = false;
    });
    _progressController!.forward();
  }

  void _togglePause(StateSetter setModalState) {
    if (_isPaused) {
      _resumeStory(setModalState);
    } else {
      _pauseStory(setModalState);
    }
  }

  void _nextStory(StateSetter setModalState) {
    if (_currentStoryIndex < _schoolStories.length - 1) {
      setModalState(() {
        _currentStoryIndex++;
      });
      _restartProgress(setModalState);
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory(StateSetter setModalState) {
    if (_currentStoryIndex > 0) {
      setModalState(() {
        _currentStoryIndex--;
      });
      _restartProgress(setModalState);
    }
  }

  // Method to add a new school story with gallery functionality
  void _addSchoolStory() async {
    final schoolId = await StorageUtil.getString('schoolId') ?? '';
    if (schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School ID not found. Cannot add story.')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Create School Story',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Share what\'s happening at your school',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStoryOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: _primaryColor,
                  onTap: () => _pickAndUploadStory(schoolId, ImageSource.gallery),
                ),
                _buildStoryOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: _accentColor,
                  onTap: () => _pickAndUploadStory(schoolId, ImageSource.camera),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Helper method to build story option buttons
  Widget _buildStoryOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to pick and upload a story
  Future<void> _pickAndUploadStory(String schoolId, ImageSource source) async {
    Navigator.pop(context);
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image == null) {
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _primaryColor),
                const SizedBox(height: 16),
                const Text('Uploading story...'),
              ],
            ),
          ),
        ),
      );

      // Upload image
      final imageService = image_service.ImageService();
      final uploadResult = await imageService.uploadImage(image);
      
      if (uploadResult != null && uploadResult.success) {
        final imageUrl = uploadResult.url;
        
        // Create story
        final storyResult = await imageService.uploadStory(
          schoolId: schoolId,
          mediaUrl: imageUrl,
          mediaType: 'image/jpeg',
        );
        
        Navigator.pop(context); // Close loading dialog
        
        if (storyResult != null && storyResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Story uploaded successfully!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  _fetchSchoolStories(); // Refresh stories
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _viewSchoolStories(); // Auto-open story viewer
                  });
                },
              ),
            ),
          );
          
          // Refresh stories list
          await _fetchSchoolStories();
        } else {
          throw Exception('Failed to create story');
        }
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      Navigator.of(context).popUntil((route) => route.isFirst); // Close any open dialogs
      print('⚠️ Error uploading story: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload story: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressController?.dispose();
    super.dispose();
  }

  Widget _buildTodayClassesList() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: _accentColor),
        ),
      );
    }

    if (_todaysClasses.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.free_breakfast,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No classes scheduled for today',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enjoy your free day!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
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
        final startTime = classItem['startTime']?.toString() ?? '';
        final endTime = classItem['endTime']?.toString() ?? '';
        
        // Format time display
        String timeDisplay = '';
        if (startTime.isNotEmpty && endTime.isNotEmpty) {
          timeDisplay = '$startTime - $endTime';
        } else if (startTime.isNotEmpty) {
          timeDisplay = startTime;
        }

        // Determine if class is current, upcoming, or completed
        final now = DateTime.now();
        Color statusColor = Colors.grey;
        String statusText = '';
        
        try {
          if (startTime.isNotEmpty) {
            // Parse time (assuming format like "09:00" or "9:00 AM")
            final startDateTime = _parseTimeToDateTime(startTime);
            final endDateTime = endTime.isNotEmpty ? _parseTimeToDateTime(endTime) : null;
            
            if (endDateTime != null && now.isAfter(endDateTime)) {
              statusColor = Colors.green;
              statusText = 'Completed';
            } else if (now.isAfter(startDateTime) && (endDateTime == null || now.isBefore(endDateTime))) {
              statusColor = Colors.orange;
              statusText = 'In Progress';
            } else {
              statusColor = Colors.blue;
              statusText = 'Upcoming';
            }
          }
        } catch (e) {
          // Handle time parsing errors
          statusColor = Colors.grey;
          statusText = 'Scheduled';
        }

        return Card(
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
              child: Icon(Icons.class_, color: statusColor),
            ),
            title: Text(
              classItem['subject']?.toString() ?? 'Unknown Subject',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (classItem['className']?.toString().isNotEmpty == true)
                  Text(
                    classItem['className'].toString(),
                    style: const TextStyle(color: Colors.black87),
                  ),
                Row(
                  children: [
                    if (classItem['roomNumber']?.toString().isNotEmpty == true) ...[
                      Icon(Icons.room, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Room ${classItem['roomNumber']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                    if (timeDisplay.isNotEmpty) ...[
                      if (classItem['roomNumber']?.toString().isNotEmpty == true)
                        Text(' • ', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        timeDisplay,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.arrow_forward_ios, size: 16, color: _primaryColor),
              ],
            ),
            onTap: () {
              // Navigate to class details or show more info
              _showClassDetails(classItem);
            },
          ),
        );
      },
    );
  }

  DateTime _parseTimeToDateTime(String timeString) {
    try {
      final now = DateTime.now();
      
      // Handle different time formats
      if (timeString.contains('AM') || timeString.contains('PM')) {
        // 12-hour format like "9:00 AM"
        final format = DateFormat('h:mm a');
        final time = format.parse(timeString);
        return DateTime(now.year, now.month, now.day, time.hour, time.minute);
      } else {
        // 24-hour format like "09:00"
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          return DateTime(now.year, now.month, now.day, hour, minute);
        }
      }
    } catch (e) {
      print('Error parsing time: $timeString - $e');
    }
    
    // Fallback to current time
    return DateTime.now();
  }

  void _showClassDetails(Map<String, dynamic> classItem) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(classItem['subject']?.toString() ?? 'Class Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (classItem['className']?.toString().isNotEmpty == true)
                _buildDetailRow('Class', classItem['className'].toString()),
              if (classItem['roomNumber']?.toString().isNotEmpty == true)
                _buildDetailRow('Room', classItem['roomNumber'].toString()),
              if (classItem['startTime']?.toString().isNotEmpty == true)
                _buildDetailRow('Start Time', classItem['startTime'].toString()),
              if (classItem['endTime']?.toString().isNotEmpty == true)
                _buildDetailRow('End Time', classItem['endTime'].toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
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
          title: 'My Classes',
          icon: Icons.class_,
          color: Colors.blue,
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => TeacherClassesScreen(user: widget.user))
          ),
        ),
        _buildDashboardCard(
          context: context,
          title: 'Homework',
          icon: Icons.assignment,
          color: Colors.green,
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => TeacherAssignmentsScreen(user: widget.user))
          ),
        ),
        _buildDashboardCard(
          context: context,
          title: 'Attendance',
          icon: Icons.check_circle,
          color: Colors.red,
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => TeacherAttendanceScreen(user: widget.user))
          ),
        ),
        _buildDashboardCard(
          context: context,
          title: 'Grading',
          icon: Icons.trending_up,
          color: Colors.orange,
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => TeacherGradingScreen(user: widget.user))
          ),
        ),
      ],
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
}

class Class {
  final String id;
  final String name;
  final String grade;
  final String section;
  final String subject;
  final String startTime;
  final String endTime;
  final String roomNumber;
  final String weekday;

  Class({
    required this.id,
    required this.name,
    required this.grade,
    required this.section,
    required this.subject,
    required this.startTime,
    required this.endTime,
    required this.roomNumber,
    required this.weekday,
  });
}
