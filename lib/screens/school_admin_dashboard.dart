import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:edutrack/screens/role_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../models/user_model.dart';
import '../models/school_model.dart';
import 'package:flutter/src/material/scaffold.dart';
import '../utils/app_theme.dart';
import '../utils/storage_util.dart';
import '../services/fcm_service.dart';
import '../services/firestore_service.dart';
import '../services/image_service.dart' as image_service;
import 'school_admin/class_management_screen.dart';
import 'school_admin/teacher_management_screen.dart';
import 'school_admin/student_management_screen.dart';
import 'school_admin/academic_calender_screen.dart';
import 'school_admin/event_management_screen.dart';
import 'school_admin/schedule_management_screen.dart';
import 'school_admin/notifiaction_management_screen.dart';
import 'school_admin/analytic_dashboard.dart';
import 'school_admin/profile.dart'; 
import 'school_selection_screen.dart';

class SchoolAdminDashboard extends StatefulWidget {
  final User user;

  const SchoolAdminDashboard({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _SchoolAdminDashboardState createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> with TickerProviderStateMixin {
  bool _isLoading = true;
  School? _school;
  int _currentIndex = 0;
  String _schoolName = "";
  String? profileImageUrl;

  // Add theme-related variables
  String _currentTheme = AppTheme.defaultTheme;
  String _currentBrightness = AppTheme.defaultBrightness;
  bool get _isDarkMode => _currentBrightness == 'dark';

  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;
  late List<Color> _gradientColors;

  // Add these new variables to track story state
  bool _hasStories = false;
  List<image_service.Story> _schoolStories = [];

  // Add these new variables for story viewer
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  int _currentStoryIndex = 0;
  bool _isPaused = false;

  // Add this variable to track back press timing
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _loadThemePreferences(); // Load theme preferences first
    _loadSchoolInfo();
    _loadDashboardData();
    _fetchSchoolStories();
    _loadProfileImage();

    // Initialize animation controller
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // 5 seconds per story
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_progressController);
  }

  // Helper method for debug logging
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // New method to load school information
  Future<void> _loadSchoolInfo() async {
    try {
      var schoolName = await StorageUtil.getString('schoolName') ?? '';
      var schoolId = await StorageUtil.getString('schoolId') ?? widget.user.schoolToken;

      // Fallback : Chercher dans Firestore si schoolId ou schoolName est absent
      if (schoolId.isEmpty || schoolName.isEmpty || schoolName == 'Unknown School') {
        final firestoreService = FirestoreServiceRDC();
        final userDoc = await firestoreService.getUtilisateur(widget.user.id);
        if (userDoc != null && (userDoc.schoolId ?? '').isNotEmpty) {
          schoolId = userDoc.schoolId!;
          await StorageUtil.setString('schoolId', schoolId);
          await StorageUtil.setString('schoolToken', schoolId);

          final ecole = await firestoreService.getEcoleParId(schoolId);
          if (ecole != null) {
            schoolName = ecole.nom;
            await StorageUtil.setString('schoolName', schoolName);
          }
        }
      }

      if (mounted) {
        setState(() {
          _schoolName = schoolName.isNotEmpty ? schoolName : 'EduTrack School';
        });
      }
    } catch (e) {
      _debugLog('⚠️ Error loading school info: $e');
    }
  }

  // Add method to load theme preferences
  Future<void> _loadThemePreferences() async {
    try {
      final theme = await StorageUtil.getString('selectedTheme') ?? AppTheme.defaultTheme;
      final brightness = await StorageUtil.getString('selectedBrightness') ?? AppTheme.defaultBrightness;
      
      setState(() {
        _currentTheme = theme;
        _currentBrightness = brightness;
      });
      
      _loadThemeColors();
    } catch (e) {
      _debugLog('⚠️ Error loading theme preferences: $e');
      _loadThemeColors();
    }
  }

  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(_currentTheme, brightness: _currentBrightness);
    _accentColor = AppTheme.getAccentColor(_currentTheme, brightness: _currentBrightness);
    _tertiaryColor = AppTheme.getTertiaryColor(_currentTheme, brightness: _currentBrightness);
    _gradientColors = AppTheme.getGradientColors(_currentTheme, brightness: _currentBrightness);
  }

  // Add method to toggle theme brightness
  Future<void> _toggleTheme() async {
    try {
      final newBrightness = _isDarkMode ? 'light' : 'dark';
      
      await StorageUtil.setString('selectedBrightness', newBrightness);
      
      setState(() {
        _currentBrightness = newBrightness;
      });
      
      _loadThemeColors();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${_isDarkMode ? 'Dark' : 'Light'} mode'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      _debugLog('⚠️ Error toggling theme: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
        
      // For now, just simulate loading without API call
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      _debugLog('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add this method to fetch stories
  Future<void> _fetchSchoolStories() async {
    try {
      final schoolId = await StorageUtil.getString('schoolId') ?? '';
      if (schoolId.isEmpty) {
        _debugLog('⚠️ School ID not found in storage');
        return;
      }

      // Get access token to check if we're authenticated
      final accessToken = await StorageUtil.getString('accessToken') ?? '';
      if (accessToken.isEmpty) {
        _debugLog('⚠️ No access token available, cannot fetch stories');
        return;
      }

      _debugLog('🔍 Fetching stories for school ID: $schoolId');
      final imageService = image_service.ImageService();
      final stories = await imageService.getStoriesBySchool(schoolId);
      
      setState(() {
        _schoolStories = stories;
        _hasStories = stories.isNotEmpty;
      });
      
      _debugLog('📚 Fetched ${stories.length} stories for school $schoolId');
    } catch (e) {
      _debugLog('⚠️ Error fetching school stories: $e');
      setState(() {
        _hasStories = false;
        _schoolStories = [];
      });
    }
  }

  // Add this new method to load profile image using the same logic as profile screen
  Future<void> _loadProfileImage() async {
    try {
      // First try to get from SharedPreferences (same as profile screen)
      final prefs = await SharedPreferences.getInstance();
      final cachedImageUrl = prefs.getString('profileImageUrl');
      if (cachedImageUrl != null && cachedImageUrl.isNotEmpty) {
        setState(() {
          profileImageUrl = cachedImageUrl;
        });
      }
      
      // Then fetch fresh from server using the same method as profile screen
      final userId = await StorageUtil.getString('userId');
      if (userId != null && userId.isNotEmpty) {
        final imageService = image_service.ImageService();
        final imageUrl = await imageService.getProfileImage(userId);
        if (imageUrl != null) {
          setState(() {
            profileImageUrl = imageUrl;
          });
          
          // Save to SharedPreferences for future use (same as profile screen)
          await prefs.setString('profileImageUrl', imageUrl);
        }
      }
    } catch (e) {
      _debugLog('Error loading profile image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360 || screenSize.height < 700;

    return WillPopScope(
      onWillPop: () async {
        // Handle double-tap to exit app
        final now = DateTime.now();
        if (_lastBackPressed == null || now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return false; // Don't exit yet
        }
        return true; // Exit app on second press
      },
      child: Theme(
        data: AppTheme.getTheme(_currentTheme, brightness: _currentBrightness),
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.school,
                    color: Colors.white, size: isSmallScreen ? 22 : 28),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Text(
                    'School Admin',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 18 : 20),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                onPressed: _navigateToNotifications,
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Material(
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToProfile,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: profileImageUrl != null
                          ? Image.network(
                              profileImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white,
                                  child: Center(
                                    child: Text(
                                      '${widget.user.profile.firstName[0]}${widget.user.profile.lastName[0]}',
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.white,
                              child: Center(
                                child: Text(
                                  '${widget.user.profile.firstName[0]}${widget.user.profile.lastName[0]}',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
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
                  
                  accountName: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.user.profile.firstName} ${widget.user.profile.lastName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _schoolName, // Display school name here
                        style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                  accountEmail: Text(
                    widget.user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.dashboard, color: _accentColor),
                  title: const Text('Dashboard'),
                  selected: _currentIndex == 0,
                  selectedTileColor: _accentColor.withValues(alpha: 0.1),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentIndex = 0;
                    });
                  },
                ),
                const Divider(),
                _buildCategoryHeader('ACADEMICS'),
                _buildDrawerTile(
                    Icons.class_, 'Class Management', _navigateToClassManagement),
                _buildDrawerTile(Icons.schedule, 'Schedule Management',
                    _navigateToScheduleManagement),
                _buildDrawerTile(Icons.calendar_today, 'Academic Calendar',
                    _navigateToAcademicCalendar),
                _buildDrawerTile(Icons.analytics, 'Analytics Dashboard',
                    _navigateToAnalyticsDashboard),
                const Divider(),
                _buildCategoryHeader('PEOPLE'),
                _buildDrawerTile(Icons.people, 'Students', _navigateToStudents),
                _buildDrawerTile(Icons.person, 'Teachers', _navigateToTeachers),
                // _buildDrawerTile(
                //     Icons.family_restroom, 'Parents', _navigateToParents),
                const Divider(),
                // _buildCategoryHeader('FINANCE'),
                // _buildDrawerTile(
                //     Icons.payment, 'Fee Collection', _navigateToFeeManagement),
                // const Divider(),
                _buildCategoryHeader('COMMUNICATION'),
                _buildDrawerTile(
                    Icons.message, 'Calendar', _navigateToAcademicCalendar),
                _buildDrawerTile(Icons.announcement, 'Notifications',
                    _navigateToNotifications),
                _buildDrawerTile(Icons.event, 'Events', _navigateToEvents),
                const Divider(),
                _buildDrawerTile(Icons.exit_to_app, 'Logout', () {
                  // Show confirmation dialog before logout
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to log out?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop(); // Close dialog first
                              await _handleLogout();
                            },
                            child: const Text('Logout',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                }),
              ],
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: _accentColor))
              : RefreshIndicator(
                  color: _accentColor,
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSchoolHeader(),
                        if (_school != null) _buildSchoolInfoCard(),
                        SizedBox(height: isSmallScreen ? 16 : 24),
                        _buildSectionHeader('Administrative Tools'),
                        const SizedBox(height: 16),
                        _buildAdminToolsGrid(),
                        SizedBox(height: isSmallScreen ? 16 : 24),
                        const SizedBox(height: 24), // Add bottom padding for better scrolling
                      ],
                    ),
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: _accentColor,
            onPressed: _showQuickActions,
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: _primaryColor,
            unselectedItemColor: Colors.grey[600],
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: 'People'),
              BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Classes'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.analytics), label: 'Analytics'),
            ],
            onTap: _handleBottomNavTap,
          ),
        ),
      ),
      );
  }

  // New widget to display school information at the top of the dashboard
  Widget _buildSchoolHeader() {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Story viewing circle with profile image - clickable
                GestureDetector(
                  onTap: _viewSchoolStories,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: _hasStories ? _accentColor : Colors.white,
                        width: _hasStories ? 2 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipOval(
                          child: profileImageUrl != null
                            ? Image.network(
                                profileImageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 56,
                                    height: 56,
                                    color: _primaryColor,
                                    child: Center(
                                      child: Text(
                                        '${widget.user.profile.firstName[0]}${widget.user.profile.lastName[0]}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: _primaryColor,
                                child: Center(
                                  child: Text(
                                    '${widget.user.profile.firstName[0]}${widget.user.profile.lastName[0]}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
                      const Text(
                        'Welcome to',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _schoolName.isNotEmpty ? _schoolName : 'Loading...',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Add story button
                GestureDetector(
                  onTap: _addSchoolStory,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
            
    
      



  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
            color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildAdminToolsGrid() {
    final adminTools = [
      {
        'icon': Icons.class_,
        'label': 'Class',
        'color': Colors.green,
        'onTap': _navigateToClassManagement,
      },
      {
        'icon': Icons.person,
        'label': 'Teacher',
        'color': Colors.blue,
        'onTap': _navigateToTeachers,
      },
      {
        'icon': Icons.people,
        'label': 'Student',
        'color': _accentColor,
        'onTap': _navigateToStudents,
      },
      {
        'icon': Icons.schedule,
        'label': 'Schedule',
        'color': Colors.orange,
        'onTap': _navigateToScheduleManagement,
      },
      {
        'icon': Icons.calendar_month,
        'label': 'Calendar',
        'color': Colors.indigo,
        'onTap': _navigateToAcademicCalendar,
      },
      {
        'icon': Icons.notifications_active,
        'label': 'Notifications',
        'color': _tertiaryColor,
        'onTap': _navigateToNotifications,
      },
      {
        'icon': Icons.event,
        'label': 'Event',
        'color': Colors.purple,
        'onTap': _navigateToEvents,
      },
      // {
      //   'icon': Icons.analytics,
      //   'label': 'Dashboard',
      //   'color': Colors.blue,
      //   'onTap': _navigateToAnalyticsDashboard,
      // },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio:
            1.2, // Adjusted back since we don't need space for description
      ),
      itemCount: adminTools.length,
      itemBuilder: (context, index) {
        final tool = adminTools[index];
        return _buildModernAdminTool(
          icon: tool['icon'] as IconData,
          label: tool['label'] as String,
          color: tool['color'] as Color,
          onTap: tool['onTap'] as VoidCallback,
        );
      },
    );
  }
Widget _buildModernAdminTool({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 1.0, end: 1.0),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    builder: (context, scale, child) {
      return Transform.scale(
        scale: scale,
        child: child,
      );
    },
    child: GestureDetector(
      onTapDown: (_) {
        // Trigger scale animation on tap
        // The TweenAnimationBuilder will handle the animation
      },
      onTapUp: (_) => onTap(),
      onTapCancel: () {},
      child: Card(
        elevation: 6,
        shadowColor: color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: color.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, color.withValues(alpha: 0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }


  Widget _buildSchoolInfoCard() {
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
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: profileImageUrl != null
                  ? Image.network(
                      profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              '${widget.user.profile.firstName[0]}${widget.user.profile.lastName[0]}',
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
                      color: Colors.white,
                      child: Center(
                        child: Text(
                          '${widget.user.profile.firstName[0]}${widget.user.profile.lastName[0]}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _schoolName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 16),
            ),
            _buildQuickActionTile(
              icon: Icons.person_add,
              color: _accentColor,
              title: 'Add Student',
              onTap: _navigateToAddStudent,
            ),
            _buildQuickActionTile(
              icon: Icons.class_,
              color: _primaryColor,
              title: 'Create Class',
              onTap: _navigateToCreateClass,
            ),
            _buildQuickActionTile(
              icon: Icons.schedule,
              color: Colors.orange,
              title: 'Add Timetable',
              onTap: _navigateToScheduleManagement,
            ),
            // _buildQuickActionTile(
            //   icon: Icons.payment,
            //   color: _tertiaryColor,
            //   title: 'Manage Fees',
            //   onTap: _navigateToFeeManagement,
            // ),
            _buildQuickActionTile(
              icon: Icons.notifications,
              color: _tertiaryColor,
              title: 'Send Notification',
              onTap: _navigateToSendNotification,
            ),
            _buildQuickActionTile(
              icon: Icons.event,
              color: Colors.purple,
              title: 'Add Event',
              onTap: _navigateToAddEvent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _handleBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    switch (index) {
      case 0: // Dashboard
        break;
      case 1:
        _showPeopleOptions();
        break;
      case 2:
        _navigateToClassManagement();
        break;
      case 3:
        _navigateToAnalyticsDashboard();
        break;
     
    }
  }

  void _showPeopleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
            margin: const EdgeInsets.symmetric(vertical: 16),
          ),
          _buildQuickActionTile(
            icon: Icons.person,
            color: _primaryColor,
            title: 'Teachers',
            onTap: _navigateToTeachers,
          ),
          _buildQuickActionTile(
            icon: Icons.people,
            color: _accentColor,
            title: 'Students',
            onTap: _navigateToStudents,
          ),
          // _buildQuickActionTile(
          //   icon: Icons.family_restroom,
          //   color: Colors.amber,
          //   title: 'Parents',
          //   onTap: _navigateToParents,
          // ),
        ],
      ),
    );
  }

  // Navigation methods aligned with LaTeX features
  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const NotificationManagementScreen()),
    );
  }

  void _navigateToProfile() async {
    // Navigate to profile screen and refresh image when returning
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SchoolAdminProfileScreen(),
      ),
    );
    
    // Refresh profile image when returning from profile screen
    await _loadProfileImage();
  }

  void _navigateToClassManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ClassManagementScreen(user: widget.user)),
    );
  }

  void _navigateToTeachers() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => TeacherManagementScreen(user: widget.user)),
    );
  }

  void _navigateToStudents() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudentManagementScreen()),
    );
  }

  void _navigateToScheduleManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScheduleManagementScreen()),
    );
  }

  void _navigateToAcademicCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AcademicCalenderScreen()),
    );
  }

  void _navigateToAnalyticsDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnalyticsDashboard()),
    );
  }

  // void _navigateToFeeManagement() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => const FeeCollectionScreen()),
  //   );
  // }

  void _navigateToEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EventManagementScreen()),
    );
  }

  void _navigateToAddEvent() {
    // Navigate to EventManagementScreen with parameter to indicate adding new event
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EventManagementScreen()),
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use the + button to add a new event')),
      );
    });
  }

  // void _navigateToParents() {
  //   _launchFeature(
  //       'Parent Management', 'Manage parent information and communication');
  // }


  void _navigateToAddStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudentManagementScreen()),
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use the + button to add a new student')),
      );
    });
  }

  void _navigateToCreateClass() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ClassManagementScreen(user: widget.user)),
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use the + button to create a new class')),
      );
    });
  }

  void _navigateToSendNotification() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const NotificationManagementScreen()),
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Use the options to send a new notification')),
      );
    });
  }

  // Keep this method for any features still in development
  void _launchFeature(String title, String description) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Coming Soon'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Add this new method to handle logout
  Future<void> _handleLogout() async {
    try {
      _debugLog('🔐 Starting logout process...');
      
      // Store the current context
      final currentContext = context;
      
      // Show loading indicator only if still mounted
      if (mounted) {
        showDialog(
          context: currentContext,
          barrierDismissible: false,
          builder: (dialogContext) => Dialog(
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

      // Clear all user-related stored data
      await _performLogout();
      
      _debugLog('🔐 Logout successful, navigating...');
      
      // Create navigation destination
      final navigationDestination = MaterialPageRoute(
        builder: (context) => const RoleSelectionScreen(
          schoolName: "",
          schoolToken: "",
          schoolAddress: "",
          schoolPhone: "",
        ),
      );
      
      // Navigate safely if still mounted
      if (mounted) {
        // Close loading dialog
        Navigator.of(currentContext).pop();
        
        // Navigate to role selection screen
        Navigator.of(currentContext).pushAndRemoveUntil(
          navigationDestination,
          (route) => false,
        );
      }
      
      _debugLog('🚀 Navigation completed');
    } catch (e) {
      _debugLog('⚠️ Error during logout: $e');
      
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
        try {
          // Try to close any open dialogs
          Navigator.of(context).pop();
        } catch (dialogError) {
          _debugLog('Failed to close dialog: $dialogError');
        }
        
        // Show error message if we can
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (snackBarError) {
          _debugLog('Failed to show snackbar: $snackBarError');
        }
        
        // Still try to navigate even if other UI operations failed
        Navigator.of(context).pushAndRemoveUntil(
          navigationDestination,
          (route) => false,
        );
      }
    }
  }

  // Add this new method to handle logout
  Future<void> _performLogout() async {
    try {
      _debugLog('🔐 Performing logout and clearing user data...');
      
      // Delete FCM token from server
      final fcmService = FCMService();
      await fcmService.deleteFCMTokenFromServer(widget.user.id);
      _debugLog('🔔 FCM token deleted from server');

      // Clear user auth credentials
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

      _debugLog('🔐 Logout completed. All user data cleared.');
      _debugLog('🚀 Navigating to school selection screen...');

      // Optional: Dump storage to verify everything was cleared
      await StorageUtil.debugDumpAll();
    } catch (e) {
      _debugLog('⚠️ Error during logout: $e');
      // Don't rethrow the error - still proceed with navigation
    }
  }

  // Method to view school stories - update with better error handling
  void _viewSchoolStories() {
    if (_schoolStories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stories available. Try refreshing the app.')),
      );
      // Try to fetch again in case they were added recently
      _fetchSchoolStories();
      return;
    }
    
    // Reset story index and progress
    _currentStoryIndex = 0;
    _progressController.reset();
    
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
                      _progressController.stop();
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
              animation: _progressAnimation,
              builder: (context, child) {
                double progress = 0.0;
                if (index < _currentStoryIndex) {
                  progress = 1.0; // Completed stories
                } else if (index == _currentStoryIndex) {
                  progress = _progressAnimation.value; // Current story progress
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
                if (!_isPaused && _progressController.status != AnimationStatus.forward) {
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

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  // Add the missing _getTimeAgo method
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

  // Build story header with user info - fix the timestamp display
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
    _progressController.forward().then((_) {
      if (_currentStoryIndex < _schoolStories.length - 1) {
        _nextStory(setModalState ?? (fn) => setState(() {}));
      } else {
        // All stories completed, close viewer
        Navigator.pop(context);
      }
    });
  }

  void _restartProgress(StateSetter setModalState) {
    _progressController.reset();
    setModalState(() {});
    if (!_isPaused) {
      _startProgress(setModalState);
    }
  }

  void _pauseStory(StateSetter setModalState) {
    _progressController.stop();
    setModalState(() {
      _isPaused = true;
    });
  }

  void _resumeStory(StateSetter setModalState) {
    setModalState(() {
      _isPaused = false;
    });
    _progressController.forward();
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

  // Updated method to add a new school story with gallery functionality
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

  // Updated helper method to build story option buttons
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

  // Updated method to pick and upload a story with correct response handling
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
      _debugLog('⚠️ Error uploading story: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload story: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}