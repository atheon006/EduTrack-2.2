import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../../services/attendance_service.dart';
import '../../services/student_service.dart';
import '../../utils/constants.dart';

class ParentAttendanceScreen extends StatefulWidget {
  final User user;

  const ParentAttendanceScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ParentAttendanceScreenState createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen> {
  bool _isLoading = true;
  late Color _primaryColor;
  late Color _accentColor;
  
  // Services
  late AttendanceService _attendanceService;
  late StudentService _studentService;
  
  // Student data for the children of the parent
  List<Map<String, dynamic>> _studentsData = [];
  
  // Selected student for viewing attendance
  Map<String, dynamic>? _selectedStudent;
  
  // Selected month for viewing attendance
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  @override
  void initState() {
    super.initState();
    _loadThemeColors();
    
    // Initialize services
    const baseUrl =  Constants.apiBaseUrl;
    _attendanceService = AttendanceService(baseUrl: baseUrl);
    _studentService = StudentService(baseUrl: baseUrl);
    
    _loadStudentsData();
  }
  
  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
  }
  
  Future<void> _loadStudentsData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Get students for this parent from the API
      final response = await _studentService.getStudentsByParentId(widget.user.id);
      print('👨‍👩‍👧‍👦 Found ${response.length} children for parent');
      
      // Transform student data with attendance information
      final transformedStudents = await Future.wait(
        response.map((student) async {
          // Get attendance data from the API
          Map<String, dynamic> attendanceData = await _getStudentAttendanceData(student['_id']);
          
          // Calculate attendance percentage
          final summary = attendanceData['summary'] ?? {'present': 0, 'absent': 0};
          final totalDays = (summary['present'] ?? 0) + (summary['absent'] ?? 0);
          final presentDays = summary['present'] ?? 0;
          final percentage = totalDays > 0 ? ((presentDays / totalDays) * 100).round() : 0;
          
          // Process attendance records to show in calendar and list views
          final records = attendanceData['records'] ?? [];
          final processedRecords = _processAttendanceRecords(records);
          
          // Get monthly summary
          final monthlyData = _generateMonthlyData(records);
          
          return {
            '_id': student['_id'] ?? '',
            'name': student['name'] ?? 'Unknown Student',
            'grade': student['grade'] ?? 'Unknown Grade',
            'section': student['section'] ?? 'A',
            'rollNumber': student['studentId'] ?? '',
            'image': student['profilePicture'] ?? 'https://i.pravatar.cc/150?img=${student['_id'].hashCode % 10}',
            'attendance': '$percentage%',
            'attendanceData': processedRecords,
            'summary': summary,
            'monthlyData': monthlyData,
          };
        }).toList(),
      );
      
      if (mounted) {
        setState(() {
          _studentsData = transformedStudents;
          _isLoading = false;
          if (_studentsData.isNotEmpty) {
            _selectedStudent = _studentsData[0];
          }
        });
      }
    } catch (e) {
      print('👨‍👩‍👧‍👦 Error loading students: $e');
      if (mounted) {
        setState(() {
          _studentsData = [];
          _isLoading = false;
        });
      }
    }
  }
  
  Future<Map<String, dynamic>> _getStudentAttendanceData(String studentId) async {
    try {
      final attendanceData = await _attendanceService.getStudentAttendance(studentId);
      return attendanceData;
    } catch (e) {
      print('📊 Error getting attendance for student $studentId: $e');
      // Return empty data structure on error
      return {
        'records': [],
        'summary': {'present': 0, 'absent': 0}
      };
    }
  }
  
  List<Map<String, dynamic>> _processAttendanceRecords(List<dynamic> records) {
    return records.map<Map<String, dynamic>>((record) {
      final date = DateTime.parse(record['date']);
      final status = record['status'];
      
      return {
        'date': date,
        'status': status.toString().capitalize(),
        'color': status == 'present' ? Colors.green : 
                 status == 'late' ? Colors.orange : Colors.red,
      };
    }).toList();
  }
  
  List<Map<String, dynamic>> _generateMonthlyData(List<dynamic> records) {
    // Group records by month and generate monthly summaries
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthlyData = <Map<String, dynamic>>[];
    
    // Group records by month
    final Map<String, Map<String, dynamic>> monthGroups = {};
    
    for (var record in records) {
      final date = DateTime.parse(record['date']);
      final monthKey = '${date.year}-${date.month}';
      final monthName = months[date.month - 1];
      
      if (!monthGroups.containsKey(monthKey)) {
        monthGroups[monthKey] = {
          'month': monthName, // Store the month name correctly
          'present': 0,
          'absent': 0,
          'late': 0,
        };
      }
      
      final status = record['status'];
      if (status == 'present') {
        monthGroups[monthKey]!['present'] = (monthGroups[monthKey]!['present'] ?? 0) + 1;
      } else if (status == 'absent') {
        monthGroups[monthKey]!['absent'] = (monthGroups[monthKey]!['absent'] ?? 0) + 1;
      } else if (status == 'late') {
        monthGroups[monthKey]!['late'] = (monthGroups[monthKey]!['late'] ?? 0) + 1;
      }
    }
    
    // Convert to list and calculate percentage
    monthGroups.forEach((key, value) {
      final present = value['present'] ?? 0;
      final absent = value['absent'] ?? 0;
      final late = value['late'] ?? 0;
      final total = present + absent + late;
      
      final percentage = total > 0 ? ((present + (late * 0.5)) / total * 100).round() : 0;
      
      monthlyData.add({
        'month': value['month'], // This was referring to a potentially missing property
        'percentage': percentage,
        'present': present,
        'absent': absent,
        'late': late,
      });
    });
    
    return monthlyData;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(AppTheme.defaultTheme),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white),
              const SizedBox(width: 10),
              const Text('Attendance Records', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadStudentsData,
            ),
          ],
        ),
        body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : Column(
              children: [
                _buildStudentSelector(),
                Expanded(
                  child: _selectedStudent != null
                    ? _buildAttendanceDetails()
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No student data available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
      ),
    );
  }
  
  Widget _buildStudentSelector() {
    if (_studentsData.isEmpty) {
      return Container(
        height: 100,
        padding: const EdgeInsets.all(10),
        child: Center(
          child: Text(
            'No students found for this parent',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }
    
    return Container(
      height: 100,
      padding: const EdgeInsets.all(10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _studentsData.length,
        itemBuilder: (context, index) {
          final student = _studentsData[index];
          final isSelected = _selectedStudent == student;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedStudent = student;
              });
            },
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? _primaryColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(student['image']),
                    onBackgroundImageError: (e, s) {
                      // Fallback for image loading error
                      print('Error loading student image: $e');
                    },
                    child: student['image'] == null || (student['image'] as String).isEmpty
                        ? Text(
                            (student['name'] as String).isNotEmpty 
                                ? (student['name'] as String)[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          student['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? _primaryColor : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: isSelected ? _primaryColor.withValues(alpha: 0.8) : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              student['attendance'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? _primaryColor.withValues(alpha: 0.8) : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildAttendanceDetails() {
    if (_selectedStudent == null) return Container();
    
    final student = _selectedStudent!;
    final attendanceData = student['attendanceData'] as List<Map<String, dynamic>>;
    final summary = student['summary'] as Map<String, dynamic>;
    final monthlyData = student['monthlyData'] as List<Map<String, dynamic>>;
    
    // Filter data for the selected month and year
    final filteredData = attendanceData.where((record) {
      final date = record['date'] as DateTime;
      return date.month == _selectedMonth && date.year == _selectedYear;
    }).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Attendance Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _primaryColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Text(
                      student['attendance'],
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Attendance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getAttendanceStatusText(student['attendance']),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Present: ${summary['present']} days, Absent: ${summary['absent']} days',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Monthly Attendance
          const SizedBox(height: 24),
          _buildSectionHeader('Monthly Attendance'),
          const SizedBox(height: 16),
          _buildMonthSelector(),
          const SizedBox(height: 16),
          
          // Monthly Attendance Stats
          _buildMonthlyStatsCards(monthlyData),
          
          // Calendar View
          const SizedBox(height: 24),
          _buildSectionHeader('Daily Attendance'),
          const SizedBox(height: 16),
          _buildCalendarView(filteredData),
          
          // Recent Records
          const SizedBox(height: 24),
          _buildSectionHeader('Recent Records'),
          const SizedBox(height: 16),
          _buildRecentRecords(filteredData),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  String _getAttendanceStatusText(String attendancePercentage) {
    final percentage = int.tryParse(attendancePercentage.replaceAll('%', '')) ?? 0;
    
    if (percentage >= 90) {
      return 'Excellent Attendance';
    } else if (percentage >= 80) {
      return 'Good Attendance';
    } else if (percentage >= 70) {
      return 'Satisfactory Attendance';
    } else {
      return 'Needs Improvement';
    }
  }
  
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  Widget _buildMonthSelector() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final currentYear = DateTime.now().year;
    // Allow selecting current year and previous year
    final years = [currentYear - 1, currentYear];
    
    return Column(
      children: [
        // Year selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: years.map((year) {
            final isSelected = _selectedYear == year;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedYear = year;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _primaryColor : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  year.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Month selector
        Container(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: months.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedMonth == index + 1;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMonth = index + 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _primaryColor : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    months[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildMonthlyStatsCards(List<Map<String, dynamic>> monthlyData) {
    // Find the data for the selected month and year
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final currentMonthName = months[_selectedMonth - 1];
    
    // Get the current month's data or provide default values
    Map<String, dynamic> currentMonthData = monthlyData.firstWhere(
      (month) => month['month'] == currentMonthName,
      orElse: () => {
        'month': currentMonthName,
        'percentage': 0,
        'present': 0,
        'absent': 0,
        'late': 0
      }
    );
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildAttendanceStatCard(
          title: 'Present',
          value: '${currentMonthData['present']}',
          color: Colors.green,
        ),
        _buildAttendanceStatCard(
          title: 'Absent',
          value: '${currentMonthData['absent']}',
          color: Colors.red,
        ),
        _buildAttendanceStatCard(
          title: 'Late',
          value: '${currentMonthData['late'] ?? 0}',
          color: Colors.orange,
        ),
        _buildAttendanceStatCard(
          title: 'Percentage',
          value: '${currentMonthData['percentage']}%',
          color: _primaryColor,
        ),
      ],
    );
  }
  
  Widget _buildAttendanceStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
              fontSize: 20,
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
  
  Widget _buildCalendarView(List<Map<String, dynamic>> filteredData) {
    if (filteredData.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 150,
          child: Center(
            child: Text(
              'No attendance data available for ${_getMonthName(_selectedMonth)} $_selectedYear',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }
    
    // Group by day for easier access
    final Map<int, Map<String, dynamic>> dayRecords = {};
    for (var record in filteredData) {
      final date = record['date'] as DateTime;
      dayRecords[date.day] = record;
    }
    
    // Calculate calendar grid parameters
    final firstDayOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
    int startPadding = firstDayOfMonth.weekday - 1; // 0 is Monday in our calendar
    if (startPadding < 0) startPadding += 7;
    
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    
    // Build calendar grid
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Days of week header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((day) => 
                Container(
                  width: 36,
                  alignment: Alignment.center,
                  child: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                )
              ).toList(),
            ),
            const SizedBox(height: 8),
            // Calendar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
              ),
              itemCount: startPadding + daysInMonth,
              itemBuilder: (context, index) {
                if (index < startPadding) {
                  return Container(); // Empty space for padding days
                }
                
                final day = index - startPadding + 1;
                final record = dayRecords[day];
                
                if (record == null) {
                  // Day without attendance record
                  return Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  );
                }
                
                final status = record['status'] as String;
                final color = record['color'] as Color;
                
                return Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          status == 'Present' ? Icons.check_circle :
                          status == 'Absent' ? Icons.cancel :
                          Icons.access_time,
                          color: color,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }
  
  Widget _buildRecentRecords(List<Map<String, dynamic>> filteredData) {
    // Sort by date, most recent first
    final sortedRecords = List<Map<String, dynamic>>.from(filteredData)
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    // Take up to 5 records
    final recordsToShow = sortedRecords.take(5).toList();
    
    if (recordsToShow.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 100,
          child: Center(
            child: Text(
              'No attendance records for ${_getMonthName(_selectedMonth)} $_selectedYear',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recordsToShow.length,
          itemBuilder: (context, index) {
            final record = recordsToShow[index];
            final date = record['date'] as DateTime;
            final status = record['status'] as String;
            final color = record['color'] as Color;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Icon(
                    status == 'Present' ? Icons.check_circle :
                    status == 'Absent' ? Icons.cancel :
                    Icons.access_time,
                    color: color,
                  ),
                ),
                title: Text(DateFormat('EEEE, MMMM d, yyyy').format(date)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: status == 'Absent' ? () => _showAbsenceJustificationDialog(context, date) : null,
              ),
            );
          },
        ),
        if (recordsToShow.any((record) => record['status'] == 'Absent'))
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Tap on an absence to provide justification',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic
              ),
            ),
          ),
      ],
    );
  }
  
  void _showAbsenceJustificationDialog(BuildContext context, DateTime date) {
    final TextEditingController _reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Justify Absence'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date: ${DateFormat('EEEE, MMMM d, yyyy').format(date)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Please provide reason for absence:'),
              SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'E.g. Medical appointment, illness, etc.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please provide a reason for absence')),
                  );
                  return;
                }
                
                // Here you would submit the justification to the API
                // For now, just show a success message
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Justification submitted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text('Submit'),
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            ),
          ],
        );
      },
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
