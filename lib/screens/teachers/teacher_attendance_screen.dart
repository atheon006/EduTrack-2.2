import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/class_services.dart';
import '../../services/attendance_service.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class TeacherAttendanceScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? selectedClass;

  const TeacherAttendanceScreen({
    Key? key, 
    required this.user, 
    this.selectedClass,
  }) : super(key: key);

  @override
  _TeacherAttendanceScreenState createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  bool _isLoading = true;
  final List<Map<String, dynamic>> _students = [];
  final List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;
  bool _hasExistingAttendance = false;
  String? _existingAttendanceId;
  
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  
  // Light theme colors to match assignment screen
  final Color _primaryColor = const Color(0xFF5E63B6);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _cardColor = Colors.white;
  final Color _textPrimaryColor = const Color(0xFF333333);
  final Color _textSecondaryColor = const Color(0xFF717171);
  
  // Class colors
  final List<Color> _classColors = [
    const Color(0xFF5E63B6),
    const Color(0xFF43A047),
    const Color(0xFFFF9800),
    const Color(0xFF2196F3),
    const Color(0xFFE53935),
  ];

  late ClassService _classService;
  late AttendanceService _attendanceService;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.selectedClass;
    _classService = ClassService(baseUrl: Constants.apiBaseUrl); // Use the constant for base URL
    _attendanceService = AttendanceService(baseUrl: Constants.apiBaseUrl); // Use the constant for base URL
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Load classes from API
      if (_classes.isEmpty) {
        final classesData = await _classService.getAllClasses();
        setState(() {
          _classes.clear();
          for (int i = 0; i < classesData.length; i++) {
            final classData = classesData[i];
            _classes.add({
              'id': classData['_id'] ?? '',
              'name': '${classData['grade'] ?? 'N/A'} ${classData['section'] ?? 'N/A'}',
              'subject': classData['subjects']?.isNotEmpty == true 
                  ? classData['subjects'][0] 
                  : 'General',
              'color': _classColors[i % _classColors.length],
              'fullData': classData,
            });
          }
        });
      }
      
      if (_selectedClass != null) {
        await _loadStudentsForClass(_selectedClass!['id']);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadStudentsForClass(String classId) async {
    setState(() {
      _students.clear();
      _isLoading = true;
      _errorMessage = null;
      _hasExistingAttendance = false;
      _existingAttendanceId = null;
    });
    
    try {
      // First, get all students for the selected class
      final studentsData = await _classService.getClassStudents(classId);
      
      // Populate students list with default values (not marked present initially)
      setState(() {
        _students.clear();
        for (final studentData in studentsData) {
          _students.add({
            'id': studentData['studentId'] ?? studentData['_id'] ?? '',
            '_id': studentData['_id'] ?? '', // Store the actual _id from API
            'name': studentData['name'] ?? 'Unknown Student',
            'present': false, // Default to not marked (absent)
            'fullData': studentData,
          });
        }
      });

      // Now check if attendance exists for this class and date
      await _checkExistingAttendance(classId);
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading students: ${e.toString()}';
      });
      print('Error loading students: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkExistingAttendance(String classId) async {
    try {
      // Format the date for the API call
      final formattedDate = AttendanceService.formatDate(_selectedDate);
      
      print('📋 Checking attendance for class: $classId, date: $formattedDate');
      
      // Call attendance API to check if attendance exists for this class and date
      final attendanceRecords = await _attendanceService.getClassAttendance(
        classId: classId,
        date: formattedDate,
      );
      
      if (attendanceRecords.isNotEmpty) {
        // Found existing attendance record
        final existingAttendance = attendanceRecords.first;
        
        setState(() {
          _hasExistingAttendance = true;
          _existingAttendanceId = existingAttendance['_id'];
          
          // Create a map of student attendance status from existing data
          final attendanceMap = <String, bool>{};
          if (existingAttendance['entries'] != null) {
            for (final entry in existingAttendance['entries']) {
              // Check both _id and studentId fields for matching
              final entryStudentId = entry['studentId'];
              attendanceMap[entryStudentId] = entry['status'] == 'present';
            }
          }
          
          // Update students with their attendance status from the record
          for (int i = 0; i < _students.length; i++) {
            final studentId = _students[i]['_id']; // Use _id for matching
            final altStudentId = _students[i]['id']; // Also check alternative ID
            
            if (attendanceMap.containsKey(studentId)) {
              _students[i]['present'] = attendanceMap[studentId]!;
            } else if (attendanceMap.containsKey(altStudentId)) {
              _students[i]['present'] = attendanceMap[altStudentId]!;
            }
            // If student not found in attendance record, keep as false (absent)
          }
        });
        
        print('📋 Found existing attendance with ${existingAttendance['entries']?.length ?? 0} entries');
      } else {
        // No existing attendance found for this date
        setState(() {
          _hasExistingAttendance = false;
          _existingAttendanceId = null;
          // Keep all students as false (not marked)
        });
        
        print('📋 No existing attendance found for this date');
      }
    } catch (e) {
      print('📋 Error checking existing attendance: $e');
      // Don't throw error here, just log it and continue with no existing attendance
      setState(() {
        _hasExistingAttendance = false;
        _existingAttendanceId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(_selectedClass == null 
            ? 'Attendance' 
            : 'Attendance - ${_selectedClass!['name']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
           
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    return _selectedClass == null 
        ? _buildClassSelectionScreen()
        : _buildAttendanceScreen();
  }
  
  Widget _buildClassSelectionScreen() {
    if (_classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.class_,
              size: 64,
              color: _textSecondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Classes Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                color: _textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Select a Class to Take Attendance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimaryColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: _classes.length,
            itemBuilder: (context, index) {
              final classData = _classes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                color: _cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: classData['color'],
                    radius: 25,
                    child: Text(
                      classData['name'].split(' ').first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    classData['name'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    classData['subject'],
                    style: TextStyle(
                      color: _textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: _primaryColor,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedClass = classData;
                    });
                    _loadStudentsForClass(classData['id']);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildAttendanceScreen() {
    Color classColor = _selectedClass!['color'] ?? _primaryColor;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: classColor.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: _textSecondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _dateFormat.format(_selectedDate),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimaryColor,
                        ),
                      ),
                      if (_hasExistingAttendance) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Recorded',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _selectClass(),
                    icon: const Icon(Icons.class_),
                    label: const Text('Class'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: BorderSide(color: _primaryColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Students: ${_students.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: _textSecondaryColor,
                    ),
                  ),
                  if (_students.isNotEmpty) ...[
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _markAllPresent(true),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('All Present'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _markAllPresent(false),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('All Absent'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _students.isEmpty 
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_off,
                      size: 80,
                      color: _textSecondaryColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Students Found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This class has no enrolled students',
                      style: TextStyle(
                        color: _textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: student['present'] 
                      ? Colors.green.withValues(alpha: 0.1) 
                      : Colors.red.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: student['present'] 
                          ? Colors.green.withValues(alpha: 0.3) 
                          : Colors.red.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor: student['present'] ? Colors.green : Colors.red,
                        child: Text(
                          student['name'].substring(0, 1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        student['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _textPrimaryColor,
                        ),
                      ),
                      subtitle: Text(
                        'ID: ${student['id']}',
                        style: TextStyle(
                          color: _textSecondaryColor,
                        ),
                      ),
                      trailing: Switch(
                        value: student['present'],
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: (bool value) {
                          setState(() {
                            _students[index]['present'] = value;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
        ),
        if (_students.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: _cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Present: ${_students.where((s) => s['present']).length}/${_students.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Absent: ${_students.where((s) => !s['present']).length}/${_students.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _saveAttendance,
                  icon: Icon(_hasExistingAttendance ? Icons.edit : Icons.save),
                  label: Text(_hasExistingAttendance ? 'Update Attendance' : 'Save Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // When date changes, check attendance for the new date
      if (_selectedClass != null) {
        await _checkExistingAttendance(_selectedClass!['id']);
      }
    }
  }
  
  void _selectClass() {
    setState(() {
      _selectedClass = null;
      _students.clear();
    });
  }

  void _saveAttendance() async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students to save attendance for')),
      );
      return;
    }

    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No class selected')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );

      // Format attendance data for API
      final attendanceData = AttendanceService.formatAttendanceData(_students);
      final formattedDate = AttendanceService.formatDate(_selectedDate);

      if (_hasExistingAttendance && _existingAttendanceId != null) {
        // Update existing attendance record
        await _attendanceService.updateAttendance(
          attendanceId: _existingAttendanceId!,
          attendanceData: attendanceData,
        );
      } else {
        // Create new attendance record
        await _attendanceService.markAttendance(
          classId: _selectedClass!['id'],
          date: formattedDate,
          attendanceData: attendanceData,
        );
      }

      // Hide loading indicator
      Navigator.of(context).pop();

      final presentCount = _students.where((s) => s['present']).length;
      final totalCount = _students.length;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hasExistingAttendance 
            ? 'Attendance updated successfully ($presentCount/$totalCount present)'
            : 'Attendance recorded successfully ($presentCount/$totalCount present)'),
          backgroundColor: _primaryColor,
        ),
      );

      // Refresh the data to show updated status
      _loadStudentsForClass(_selectedClass!['id']);
    } catch (e) {
      // Hide loading indicator
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hasExistingAttendance 
            ? 'Failed to update attendance: ${e.toString()}'
            : 'Failed to save attendance: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _markAllPresent(bool present) {
    setState(() {
      for (var student in _students) {
        student['present'] = present;
      }
    });
  }
}
