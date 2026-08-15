import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../services/schedule_service.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class StudentScheduleScreen extends StatefulWidget {
  final User? user;

  const StudentScheduleScreen({super.key, this.user});

  @override
  // ignore: library_private_types_in_public_api
  _StudentScheduleScreenState createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDay;
  
  // Add these for real schedule data
  late ScheduleService _scheduleService;
  Map<String, dynamic>? _realScheduleData;
  bool _hasRealData = false;
  bool _isLoading = true;

  // Theme colors
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;
  late List<Color> _gradientColors;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = DateTime.now();

    // Initialize services
    _scheduleService = ScheduleService(baseUrl: Constants.apiBaseUrl); // Use Constants for base URL

    // Load theme colors
    _loadThemeColors();
    
    // Load real schedule data
    _loadRealScheduleData();
  }

  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _tertiaryColor = AppTheme.getTertiaryColor(AppTheme.defaultTheme);
    _gradientColors = AppTheme.getGradientColors(AppTheme.defaultTheme);
  }

  Future<void> _loadRealScheduleData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (widget.user != null) {
        final scheduleData = await _scheduleService.getStudentSchedule(widget.user!.id);
        
        if (scheduleData != null && scheduleData.containsKey('success') && scheduleData['success'] == true) {
          setState(() {
            // The schedule data is in the 'schedule' key, not 'data'
            _realScheduleData = scheduleData['schedule'];
            _hasRealData = _realScheduleData != null;
            _isLoading = false;
          });
          print('📅 Real schedule data loaded successfully');
          print('📅 Schedule data structure: ${_realScheduleData?.keys.toList()}');
        } else {
          setState(() {
            _hasRealData = false;
            _isLoading = false;
          });
          print('📅 No valid schedule data in response: $scheduleData');
        }
      }
    } catch (e) {
      print('📅 Failed to load real schedule data: $e');
      setState(() {
        _hasRealData = false;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(AppTheme.defaultTheme),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('My Schedule', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: const [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
            ],
          ),
        ),
        body: _isLoading 
          ? _buildLoadingState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDailySchedule(),
                _buildWeeklySchedule(),
              ],
            ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[50]!, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 5,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading your schedule...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySchedule() {
    return Column(
      children: [
        _buildDateSelector(),
        Expanded(
          child: _buildScheduleForDay(_selectedDay),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: _primaryColor),
              onPressed: () {
                setState(() {
                  _selectedDay = _selectedDay.subtract(const Duration(days: 1));
                });
              },
            ),
          ),
          InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor.withValues(alpha: 0.1), _accentColor.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE').format(_selectedDay),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  Text(
                    DateFormat('MMMM d, y').format(_selectedDay),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: _primaryColor),
              onPressed: () {
                setState(() {
                  _selectedDay = _selectedDay.add(const Duration(days: 1));
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2023, 1),
      lastDate: DateTime(2025, 12),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDay) {
      setState(() {
        _selectedDay = picked;
      });
    }
  }

  Widget _buildScheduleForDay(DateTime day) {
    List<Map<String, dynamic>> classes = [];
    
    // Try to get real data first
    if (_hasRealData && _realScheduleData != null) {
      classes = _getRealClassesForDay(day);
    }
  
    // Weekend check - but only if no classes are scheduled for that day
    final weekday = day.weekday;
    if ((weekday == DateTime.saturday || weekday == DateTime.sunday) && classes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.weekend,
        title: 'No Classes Scheduled',
        subtitle: 'Enjoy your weekend!',
      );
    }

    if (classes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_busy,
        title: 'No Classes Today',
        subtitle: 'You have a free day!',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show class info if available
          if (_hasRealData && _realScheduleData != null && _realScheduleData!.containsKey('classId'))
            _buildClassInfoCard(),
          
          Row(
            children: [
              Text(
                'Today\'s Classes',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              if (_hasRealData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[400]!, Colors.green[600]!],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '🟢 Live Data',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final classItem = classes[index];
              return _buildClassCard(classItem, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[50]!, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 5,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, size: 60, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassInfoCard() {
    // Check if we have classInfo directly
    if (_realScheduleData!.containsKey('classInfo')) {
      final classInfo = _realScheduleData!['classInfo'];
      
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor.withValues(alpha: 0.1), _accentColor.withValues(alpha: 0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.1),
              spreadRadius: 2,
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Class Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow(Icons.class_, 'Class', classInfo['name'] ?? 'N/A'),
            const SizedBox(height: 12),
            _infoRow(Icons.grade, 'Grade', 'Grade ${classInfo['grade'] ?? 'N/A'}'),
            const SizedBox(height: 12),
            _infoRow(Icons.group, 'Section', 'Section ${classInfo['section'] ?? 'N/A'}'),
            const SizedBox(height: 12),
            _infoRow(Icons.calendar_today, 'Academic Year', '${classInfo['year'] ?? 'N/A'}'),
          ],
        ),
      );
    }
    // Otherwise, check if we have classId directly from API response
    else if (_realScheduleData!.containsKey('classId')) {
      final classInfo = _realScheduleData!['classId'];
      
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor.withValues(alpha: 0.1), _accentColor.withValues(alpha: 0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.1),
              spreadRadius: 2,
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Class Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow(Icons.class_, 'Class', classInfo['name'] ?? 'N/A'),
            const SizedBox(height: 12),
            _infoRow(Icons.grade, 'Grade', 'Grade ${classInfo['grade'] ?? 'N/A'}'),
            const SizedBox(height: 12),
            _infoRow(Icons.group, 'Section', 'Section ${classInfo['section'] ?? 'N/A'}'),
            const SizedBox(height: 12),
            _infoRow(Icons.calendar_today, 'Academic Year', '${classInfo['year'] ?? 'N/A'}'),
          ],
        ),
      );
    }
    
    return Container();
  }

  List<Map<String, dynamic>> _getRealClassesForDay(DateTime day) {
    if (_realScheduleData == null) {
      print('📅 Real schedule data is null');
      return [];
    }
    
    final dayName = DateFormat('EEEE').format(day);
    print('📅 Finding classes for day: $dayName');
    
    // Check if we have weekSchedule data structure
    if (_realScheduleData!.containsKey('weekSchedule')) {
      final weekSchedule = _realScheduleData!['weekSchedule'] as Map<String, dynamic>;
      final dayKey = dayName.toLowerCase();
      
      print('📅 Available days in schedule: ${weekSchedule.keys.toList()}');
      
      if (weekSchedule.containsKey(dayKey)) {
        final daySchedule = weekSchedule[dayKey] as List;
        print('📅 Found ${daySchedule.length} classes for $dayName');
        
        return daySchedule.map((period) {
          return {
            'subject': period['subject'] ?? 'Unknown Subject',
            'time': period['timeSlot'] ?? '${period['startTime'] ?? ''} - ${period['endTime'] ?? ''}',
            'teacher': period['teacher'] ?? 'Unknown Teacher',
            'teacherCode': period['teacherCode'] ?? '',
            'room': 'Period ${period['periodNumber'] ?? 'TBD'}',
            'periodNumber': period['periodNumber'] ?? 0,
            'color': _getColorForSubject(period['subject'] ?? ''),
          };
        }).toList().cast<Map<String, dynamic>>();
      }
    }
    
    // Direct periods array (as in the API response)
    if (_realScheduleData!.containsKey('periods')) {
      final periods = _realScheduleData!['periods'] as List;
      
      return periods.where((period) {
        return period['dayOfWeek'] == dayName;
      }).map((period) {
        var teacherName = 'Unknown Teacher';
        var teacherCode = '';
        
        if (period['teacherId'] is Map) {
          teacherName = period['teacherId']['name'] ?? 'Unknown Teacher';
          teacherCode = period['teacherId']['teacherId'] ?? '';
        }
        
        return {
          'subject': period['subject'] ?? 'Unknown Subject',
          'time': '${period['startTime'] ?? ''} - ${period['endTime'] ?? ''}',
          'teacher': teacherName,
          'teacherCode': teacherCode,
          'room': 'Period ${period['periodNumber'] ?? 'TBD'}',
          'periodNumber': period['periodNumber'] ?? 0,
          'color': _getColorForSubject(period['subject'] ?? ''),
        };
      }).toList().cast<Map<String, dynamic>>();
    }
    
    print('📅 No valid schedule structure found');
    return [];
  }

  Color _getColorForSubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return Colors.blue;
      case 'physics':
        return Colors.green;
      case 'chemistry':
        return Colors.pink;
      case 'biology':
        return Colors.teal;
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

  IconData _getIconForEventType(String type) {
    switch (type) {
      case 'Mid-term Examination':
        return Icons.edit_document;
      case 'Assignment Due':
        return Icons.assignment;
      case 'School Event':
        return Icons.event;
      case 'Holiday':
        return Icons.celebration;
      default:
        return Icons.event;
    }
  }

  Widget _buildClassCard(Map<String, dynamic> classItem, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: classItem['color'].withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [classItem['color'], classItem['color'].withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: classItem['color'].withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.book, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classItem['subject'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    classItem['teacher'],
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    classItem['time'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (classItem.containsKey('periodNumber'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [classItem['color'], classItem['color'].withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'P${classItem['periodNumber']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showClassDetails(BuildContext context, Map<String, dynamic> classItem) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(bottom: 20),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: classItem['color'].withValues(alpha: 0.2),
                  child: Icon(Icons.class_, color: classItem['color']),
                ),
                title: Text(
                  classItem['subject'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text('${classItem['time']}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Teacher'),
                subtitle: Text(classItem['teacher']),
              ),
              ListTile(
                leading: const Icon(Icons.room),
                title: const Text('Room'),
                subtitle: Text(classItem['room']),
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Materials Required'),
                subtitle: const Text('Textbook, notebook, calculator'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklySchedule() {
    // Build a weekly view with days of the week
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    return Column(
      children: [
        _buildWeekSelector(startOfWeek),
        Expanded(
          child: _buildWeekView(startOfWeek),
        ),
      ],
    );
  }

  Widget _buildWeekSelector(DateTime startOfWeek) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () {
              setState(() {
                _selectedDay = startOfWeek.subtract(const Duration(days: 7));
              });
            },
            color: _primaryColor,
          ),
          Text(
            'Week of ${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(startOfWeek.add(const Duration(days: 6)))}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () {
              setState(() {
                _selectedDay = startOfWeek.add(const Duration(days: 7));
              });
            },
            color: _primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekView(DateTime startOfWeek) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = startOfWeek.add(Duration(days: index));
        return _buildDayCard(day);
      },
    );
  }

  Widget _buildDayCard(DateTime day) {
    // Determine if this is today
    final isToday = day.year == DateTime.now().year && 
                    day.month == DateTime.now().month && 
                    day.day == DateTime.now().day;
    
    // Get the weekday name and date
    final dayName = DateFormat('EEEE').format(day);
    final dateText = DateFormat('MMMM d').format(day);
    
    // Get classes for this day
    final classes = _getRealClassesForDay(day);
    final hasClasses = classes.isNotEmpty;
    
    // Weekend logic - only show the "No Classes" message if there are actually no classes
    final isWeekend = (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) && !hasClasses;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isToday ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isToday 
              ? Border.all(color: _accentColor, width: 2)
              : null,
        ),
        child: ExpansionTile(
          initiallyExpanded: isToday || hasClasses,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isToday ? _accentColor : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('E').format(day)[0],
                  style: TextStyle(
                    color: isToday ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? _accentColor : null,
                    ),
                  ),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _accentColor, width: 1),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
              if (hasClasses) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Text(
                    '${classes.length} class${classes.length > 1 ? 'es' : ''}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: [
            if (isWeekend)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.weekend, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(
                      'No Classes (Weekend)',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else if (!hasClasses)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(
                      'No Classes Scheduled',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              _buildMiniScheduleForDay(day),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniScheduleForDay(DateTime day) {
    // Get real data for this day
    final classes = _getRealClassesForDay(day);

    if (classes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No classes scheduled for this day'),
      );
    }

    return Column(
      children: classes.map((classItem) => Card(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: classItem['color'],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classItem['subject'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      classItem['teacher'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    classItem['time'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (classItem.containsKey('periodNumber'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: classItem['color'].withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'P${classItem['periodNumber']}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: classItem['color'],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  List<Widget> _buildEventsForDay(DateTime day) {
    // No events to display right now
    return [];
  }

  void _showEventDetails(BuildContext context, Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(event['title']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${event['type']}'),
              const SizedBox(height: 8),
              Text('Date: ${DateFormat('MMMM d, y').format(_selectedDay)}'),
              const SizedBox(height: 8),
              const Text('Details: More information about this event would appear here.'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close', style: TextStyle(color: _accentColor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

}