import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import 'notification_screen.dart'; // Import the notification screen

class ParentDashboard extends StatefulWidget {
  final User user;

  const ParentDashboard({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardStats = {};
  late AnimationController _animationController;
  
  // Theme colors
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;
  late List<Color> _gradientColors;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _loadThemeColors();
    _loadDashboardData();
    _loadStudentsData();
  }

  // Student data for the children of the parent
  List<Map<String, dynamic>> _studentsData = [];
  
  void _loadStudentsData() {
    // Simulated data for parent's children
    _studentsData = [
      {
        'name': 'John Smith',
        'grade': '10th Grade',
        'section': 'A',
        'rollNumber': '1023',
        'image': 'https://randomuser.me/api/portraits/children/1.jpg',
        'attendance': '95%',
        'gpa': '3.8',
        'fees': {
          'status': 'Paid',
          'dueAmount': '0',
          'nextDueDate': 'Apr 15, 2023',
        }
      },
      {
        'name': 'Emily Smith',
        'grade': '7th Grade',
        'section': 'B',
        'rollNumber': '2045',
        'image': 'https://randomuser.me/api/portraits/children/2.jpg',
        'attendance': '92%',
        'gpa': '3.9',
        'fees': {
          'status': 'Pending',
          'dueAmount': '125',
          'nextDueDate': 'Mar 30, 2023',
        }
      },
    ];
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
          'fee_notifications': 1,
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
              const Text('Parent',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, size: 28),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _tertiaryColor,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${(_dashboardStats['announcements'] ?? 0) + (_dashboardStats['absences'] ?? 0) + (_dashboardStats['fee_notifications'] ?? 0)}',
                        style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
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
                      // Show parent profile
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
              icon: Icon(Icons.payment),
              label: 'Fees',
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
                Navigator.pushNamed(context, '/parents/performance');
                break;
              case 1:
                Navigator.pushNamed(context, '/parents/attendance');
                break;
              case 2:
                Navigator.pushNamed(context, '/parents/fee_management');
                break;
              case 3:
                _showNotifications(context);
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
  
  Widget _buildStudentsCarousel() {
    if (_studentsData.isEmpty) {
      return const Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No student data available')),
        ),
      );
    }
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _studentsData.length,
        itemBuilder: (context, index) {
          final student = _studentsData[index];
          final fees = student['fees'] as Map<String, dynamic>;
          final feeStatus = fees['status'] as String;
          final isFeePending = feeStatus == 'Pending';
          
          return GestureDetector(
            onTap: () {
              _showStudentDetails(context, student);
            },
            child: Container(
              width: 300,
              margin: const EdgeInsets.only(right: 16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            backgroundImage: NetworkImage(student['image'] as String),
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
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStudentStatCard(
                            title: 'GPA',
                            value: student['gpa'] as String,
                            icon: Icons.workspace_premium,
                            color: Colors.indigo,
                          ),
                          _buildStudentStatCard(
                            title: 'Attendance',
                            value: student['attendance'] as String,
                            icon: Icons.event_available,
                            color: Colors.green,
                          ),
                          _buildStudentStatCard(
                            title: 'Fees',
                            value: feeStatus,
                            icon: Icons.payments,
                            color: isFeePending ? Colors.orange : Colors.teal,
                            isWarning: isFeePending,
                          ),
                        ],
                      ),
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
  
  Widget _buildStudentStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isWarning = false,
  }) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isWarning ? Colors.orange : color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  void _showStudentDetails(BuildContext context, Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
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
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: NetworkImage(student['image']),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                "${student['grade']} - Section ${student['section']}",
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: _primaryColor,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: _accentColor,
                            tabs: const [
                              Tab(text: 'Performance'),
                              Tab(text: 'Attendance'),
                              Tab(text: 'Fees'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Performance Tab
                                _buildPerformanceTab(student),
                                // Attendance Tab
                                _buildAttendanceTab(student),
                                // Fees Tab
                                _buildFeesTab(student),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildPerformanceTab(Map<String, dynamic> student) {
    // Sample subject data
    final subjects = [
      {'name': 'Mathematics', 'grade': 'A', 'score': 92, 'color': Colors.blue},
      {'name': 'Science', 'grade': 'A-', 'score': 88, 'color': Colors.green},
      {'name': 'English', 'grade': 'B+', 'score': 85, 'color': Colors.purple},
      {'name': 'History', 'grade': 'A', 'score': 90, 'color': Colors.orange},
      {'name': 'Physical Education', 'grade': 'A+', 'score': 95, 'color': Colors.teal},
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current GPA',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    student['gpa'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outstanding Performance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${student['name'] as String} is performing well in most subjects with consistent attendance.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Subject Grades',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final subjectName = subject['name'] as String;
              final subjectGrade = subject['grade'] as String;
              final subjectScore = subject['score'] as int;
              final subjectColor = subject['color'] as Color;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: subjectColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.book, color: subjectColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: subjectScore / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(subjectColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: subjectColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: subjectColor, width: 1),
                        ),
                        child: Text(
                          subjectGrade,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: subjectColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the bottom sheet first
                Navigator.pushNamed(context, '/parents/performance');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
              ),
              child: const Text('View Full Report', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAttendanceTab(Map<String, dynamic> student) {
    // Sample monthly attendance data
    final monthlyData = [
      {'month': 'Jan', 'percentage': 95, 'present': 19, 'absent': 1},
      {'month': 'Feb', 'percentage': 90, 'present': 18, 'absent': 2},
      {'month': 'Mar', 'percentage': 100, 'present': 20, 'absent': 0},
    ];
    
    // Sample recent attendance data
    final recentAttendance = [
      {'date': 'Mar 21, 2023', 'status': 'Present', 'color': Colors.green},
      {'date': 'Mar 20, 2023', 'status': 'Present', 'color': Colors.green},
      {'date': 'Mar 17, 2023', 'status': 'Present', 'color': Colors.green},
      {'date': 'Mar 16, 2023', 'status': 'Absent', 'color': Colors.red},
      {'date': 'Mar 15, 2023', 'status': 'Present', 'color:': Colors.green},
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Attendance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAttendanceStatCard(
                title: 'Current',
                value: student['attendance'] as String,
                color: Colors.green,
              ),
              _buildAttendanceStatCard(
                title: 'Present Days',
                value: '57/60',
                color: Colors.blue,
              ),
              _buildAttendanceStatCard(
                title: 'Absent Days',
                value: '3',
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Monthly Attendance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  for (var month in monthlyData)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              month['month'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: (month['percentage'] as int) / 100.0,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    (month['percentage'] as int) >= 90
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Present: ${month['present']} days, Absent: ${month['absent']} days',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${month['percentage']}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (month['percentage'] as int) >= 90
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Attendance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentAttendance.length,
            itemBuilder: (context, index) {
              final attendance = recentAttendance[index];
              final attendanceDate = attendance['date'] as String;
              final attendanceStatus = attendance['status'] as String;
              final attendanceColor = attendance['color'] as Color;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: attendanceColor.withValues(alpha: 0.2),
                    child: Icon(
                      attendanceStatus == 'Present'
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: attendanceColor,
                    ),
                  ),
                  title: Text(attendanceDate),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: attendanceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      attendanceStatus,
                      style: TextStyle(
                        color: attendanceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the bottom sheet first
                Navigator.pushNamed(context, '/parents/attendance');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
              ),
              child: const Text('View Full Attendance', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeesTab(Map<String, dynamic> student) {
    final fees = student['fees'] as Map<String, dynamic>;
    final feeStatus = fees['status'] as String;
    final dueAmount = fees['dueAmount'] as String;
    final nextDueDate = fees['nextDueDate'] as String;
    final isFeePending = feeStatus == 'Pending';
    
    // Sample fee records
    final feeRecords = [
      {
        'term': 'Term 1 2023',
        'amount': '500',
        'date': 'Jan 15, 2023',
        'status': 'Paid',
        'color': Colors.green
      },
      {
        'term': 'Term 2 2023',
        'amount': '500',
        'date': 'Mar 15, 2023',
        'status': isFeePending ? 'Pending' : 'Paid',
        'color': isFeePending ? Colors.orange : Colors.green
      },
      {
        'term': 'Term 3 2023',
        'amount': '500',
        'date': 'May 15, 2023',
        'status': 'Upcoming',
        'color': Colors.grey
      },
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isFeePending ? Colors.orange.shade50 : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isFeePending ? Icons.warning_amber : Icons.check_circle,
                        color: isFeePending ? Colors.orange : Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFeePending ? 'Payment Pending' : 'All Fees Paid',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isFeePending ? Colors.orange.shade800 : Colors.green.shade800,
                              ),
                            ),
                            Text(
                              isFeePending
                                  ? 'Due on $nextDueDate'
                                  : 'Next payment due on $nextDueDate',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isFeePending) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet first
                        Navigator.pushNamed(context, '/parents/fee_management');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.payment, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Pay Now \$${dueAmount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Payment History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: feeRecords.length,
            itemBuilder: (context, index) {
              final record = feeRecords[index];
              final termName = record['term'] as String;
              final termAmount = record['amount'] as String;
              final termDate = record['date'] as String;
              final termStatus = record['status'] as String;
              final termColor = record['color'] as Color;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: termColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          termStatus == 'Paid'
                              ? Icons.receipt_long
                              : termStatus == 'Pending'
                                  ? Icons.pending
                                  : Icons.schedule,
                          color: termColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              termName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Due: $termDate',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${termAmount}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: termColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              termStatus,
                              style: TextStyle(
                                color: termColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Fee Structure',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildFeeItem('Tuition Fee', '400'),
                  const Divider(),
                  _buildFeeItem('Library Fee', '25'),
                  const Divider(),
                  _buildFeeItem('Lab Fee', '50'),
                  const Divider(),
                  _buildFeeItem('Extra-curricular', '25'),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Per Term',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\$500',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context); // Close the bottom sheet first
                Navigator.pushNamed(context, '/parents/fee_management');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
              child: const Text('View All Payment Details'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeeItem(String title, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text('\$$amount'),
        ],
      ),
    );
  }
  
  Widget _buildAttendanceStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // Update quick actions grid to include key parent functions
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
          onTap: () => Navigator.pushNamed(context, '/parents/performance'),
          badge: null,
        ),
        _buildDashboardCard(
          context: context,
          title: 'Attendance',
          icon: Icons.calendar_today,
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, '/parents/attendance'),
          badge: _dashboardStats['absences']?.toString(),
        ),
        _buildDashboardCard(
          context: context,
          title: 'Fee Payment',
          icon: Icons.receipt_long,
          color: Colors.purple,
          onTap: () => Navigator.pushNamed(context, '/parents/fee_management'),
          badge: _dashboardStats['fee_notifications']?.toString(),
        ),
        _buildDashboardCard(
          context: context,
          title: 'School Updates',
          icon: Icons.notifications,
          color: Colors.red,
          onTap: () => _showNotifications(context),
          badge: _dashboardStats['announcements']?.toString(),
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
    String? badge,
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
        child: Stack(
          children: [
            Container(
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
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tertiaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
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
                  
                  _buildDrawerItem(Icons.grade, 'Performance Reports', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/parents/performance');
                  }, color: Colors.indigo),
                  
                  _buildDrawerItem(Icons.calendar_today, 'Attendance Reports', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/parents/attendance');
                  }, color: Colors.green),
                  
                  _buildDrawerSectionHeader('FINANCES'),
                  
                  _buildDrawerItem(Icons.payment, 'Fee Management', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/parents/fee_management');
                  }, color: Colors.purple),
                  
                  _buildDrawerSectionHeader('COMMUNICATION'),
                  
                  _buildDrawerItem(Icons.notifications_outlined, 'Notifications', () {
                    Navigator.pop(context);
                    _showNotifications(context);
                  }, color: Colors.red, badge: '${(_dashboardStats['announcements'] ?? 0) + (_dashboardStats['absences'] ?? 0) + (_dashboardStats['fee_notifications'] ?? 0)}'),
                ],
              ),
            ),
          ),
          
          // Bottom fixed logout button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: _buildDrawerItem(Icons.logout, 'Logout', () {
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
                        child: Text('Cancel', style: TextStyle(color: _accentColor)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Navigate to login screen after logout
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            }, color: Colors.red, isLogout: true),
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
  
  void _showNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParentNotificationScreen(user: widget.user),
      ),
    );
  }
}