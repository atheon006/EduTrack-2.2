import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/grading_service.dart';
import '../../services/class_services.dart';
import '../../services/teacher_service.dart';
import '../../services/schedule_service.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class TeacherGradingScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? selectedClass;

  const TeacherGradingScreen({
    super.key, 
    required this.user, 
    this.selectedClass,
  });

  @override
  // ignore: library_private_types_in_public_api
  _TeacherGradingScreenState createState() => _TeacherGradingScreenState();
}

class _TeacherGradingScreenState extends State<TeacherGradingScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  // Remove tab controller as we don't need tabs anymore
  
  // Services
  late GradingService _gradingService;
  late ClassService _classService;
  late TeacherService _teacherService;
  late ScheduleService _scheduleService;
  
  final List<Map<String, dynamic>> _students = [];
  final List<Map<String, dynamic>> _grades = [];
  final List<Map<String, dynamic>> _classes = [];
  final List<String> _subjects = [];
  
  // Store the required IDs for API requests
  Map<String, dynamic>? _selectedClass;
  String? _selectedSubject;
  bool _isBulkSubmitting = false;

  // Light theme colors to match attendance screen
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

  final Map<String, TextEditingController> _bulkGradeControllers = {};
  
  // Add temporary grade storage
  final Map<String, double> _tempGrades = {};
  bool _hasUnsavedGrades = false;
  
  // Add editing state for individual students
  final Set<String> _editingStudents = {};

  @override
  void initState() {
    super.initState();
    // Remove tab controller initialization
    
    // Initialize services
    const baseUrl = Constants.apiBaseUrl; // Use the constant for base URL
    _gradingService = GradingService(baseUrl: baseUrl);
    _classService = ClassService(baseUrl: baseUrl);
    _teacherService = TeacherService(baseUrl: baseUrl);
    _scheduleService = ScheduleService(baseUrl: baseUrl);
    
    // Step 1: Load classes like teacher class screen does
    _loadTeacherClasses();
  }
  
  @override
  void dispose() {
    _bulkGradeControllers.forEach((_, controller) => controller.dispose());
    // Remove tab controller disposal
    super.dispose();
  }

  // Step 1: Load classes like teacher class screen does
  Future<void> _loadTeacherClasses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the teacher data with populated classes (same as teacher class screen)
      final teacherData = await _teacherService.getTeacherById(widget.user.id);
      
      setState(() {
        _classes.clear();
        final classes = teacherData['classes'] as List<dynamic>? ?? [];
        
        for (int i = 0; i < classes.length; i++) {
          final classData = classes[i] as Map<String, dynamic>;
          _classes.add({
            '_id': classData['_id'] ?? classData['id'] ?? '',
            'name': classData['name'] ?? '${classData['grade'] ?? 'Unknown'} ${classData['section'] ?? ''}',
            'grade': classData['grade'] ?? 'Unknown',
            'section': classData['section'] ?? '',
            'year': classData['year']?.toString() ?? DateTime.now().year.toString(),
            'color': _classColors[i % _classColors.length],
          });
        }
      });
    } catch (e) {
      print('Error loading teacher classes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: $e')),
      );
      setState(() {
        _classes.clear();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Step 2: Select subject using schedule service and match teacher id with class id
  Future<void> _loadSubjectsForSelectedClass(String classId) async {
    setState(() {
      _isLoading = true;
      _subjects.clear();
      _selectedSubject = null;
    });
    
    try {
      print('📚 Loading subjects for class: $classId and teacher: ${widget.user.id}');
      
      // Get schedules for the selected class
      final schedules = await _scheduleService.getSchedulesByClassId(classId);
      
      Set<String> teacherSubjectsForClass = {};
      
      print('📚 Found ${schedules.length} schedules for class $classId');
      
      // Process each schedule to find subjects taught by this teacher
      for (var schedule in schedules) {
        final periods = schedule['periods'] as List<dynamic>? ?? [];
        
        for (var period in periods) {
          // Get teacher ID from period
          String periodTeacherId = '';
          
          if (period['teacherId'] is String) {
            periodTeacherId = period['teacherId'];
          } else if (period['teacherId'] is Map<String, dynamic>) {
            periodTeacherId = period['teacherId']['_id'] ?? '';
          }
          
          print('📚 Period: ${period['subject']}, TeacherId: $periodTeacherId, Current Teacher: ${widget.user.id}');
          
          // Match teacher id with class id selected to see the subject
          if (periodTeacherId == widget.user.id && 
              period['subject'] != null && 
              period['subject'].toString().trim().isNotEmpty) {
            teacherSubjectsForClass.add(period['subject']);
            print('📚 Added subject: ${period['subject']}');
          }
        }
      }
      
      print('📚 Final subjects found for class $classId: $teacherSubjectsForClass');
      
      setState(() {
        _subjects.addAll(teacherSubjectsForClass.toList());
        _isLoading = false;
      });
      
      if (_subjects.isEmpty) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subjects found for this class in your schedule')),
        );
      }
      
    } catch (e) {
      setState(() {
        _subjects.clear();
        _isLoading = false;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading subjects: $e')),
      );
    }
  }
  
  // Step 3: Load all students of that class (don't load grades here)
  Future<void> _loadStudentsForClassAndSubject(String classId, String subject) async {
    setState(() {
      _students.clear();
      _grades.clear();
      _isLoading = true;
      _selectedSubject = subject;
    });
    
    try {
      
      // Load all students of that class first
      final classStudents = await _classService.getClassStudents(classId);
      
      
      // Then load existing grades for this subject after students are loaded
      await _loadGradesForClassAndSubject(classId, subject);
      
      
      setState(() {
        _students.clear();
        _students.addAll(classStudents);
        
        // Initialize controllers for bulk grading
        _bulkGradeControllers.clear();
        for (var student in _students) {
          final studentId = student['_id'];
          if (studentId != null) {
            final grade = _findLatestGradeForStudent(studentId);
            _bulkGradeControllers[studentId] = TextEditingController(
              text: grade != null ? grade['percentage'].toStringAsFixed(1) : '',
            );
          }
        }
        
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    }
  }

  Future<void> _loadGradesForClassAndSubject(String classId, String subject) async {
    try {
      print('📊 Loading grades for class $classId and subject $subject (called after subject selection)');
      
      // Get grades for this class and subject
      final grades = await _gradingService.getGradesForClassAndSubject(classId, subject);
      
      print('📊 Loaded ${grades.length} grades');
      
      setState(() {
        _grades.clear();
        _grades.addAll(grades);
      });
    } catch (e) {
      // Don't show error for grades loading as it's not critical
      setState(() {
        _grades.clear();
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
        title: Text(_getAppBarTitle()),
        // Remove the bottom TabBar
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryColor))
        : _buildCurrentScreen(),
    );
  }
  
  String _getAppBarTitle() {
    if (_selectedClass == null) {
      return 'Grading - Select Class';
    } else if (_selectedSubject == null) {
      return 'Grading - ${_selectedClass!['name']} - Select Subject';
    } else {
      return 'Grading - ${_selectedClass!['name']} - $_selectedSubject';
    }
  }
  
  Widget _buildCurrentScreen() {
    if (_selectedClass == null) {
      return _buildClassSelectionScreen();
    } else if (_selectedSubject == null) {
      return _buildSubjectSelectionScreen();
    } else {
      // Directly show students screen without tabs
      return _buildStudentsScreen();
    }
  }
  
  Widget _buildClassSelectionScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Select a Class to Manage Grades',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimaryColor,
            ),
          ),
        ),
        Expanded(
          child: _classes.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.class_, size: 64, color: _textSecondaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'No classes assigned',
                      style: TextStyle(
                        fontSize: 18,
                        color: _textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
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
                          classData['grade']?.toString() ?? classData['name']?.substring(0, 2) ?? 'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        classData['name'] ?? 'Unknown Class',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimaryColor,
                        ),
                      ),
                      subtitle: Text(
                        'Grade ${classData['grade']} - Section ${classData['section']}',
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
                        _loadSubjectsForSelectedClass(classData['_id']);
                      },
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
  
  Widget _buildSubjectSelectionScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Subject',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Class: ${_selectedClass!['name']}',
                style: TextStyle(
                  fontSize: 16,
                  color: _textSecondaryColor,
                ),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading subjects from schedule...',
                      style: TextStyle(
                        color: _textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _subjects.isEmpty && !_isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.subject, size: 64, color: _textSecondaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'No subjects found',
                      style: TextStyle(
                        fontSize: 18,
                        color: _textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No subjects found in your schedule for this class',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _selectClass(),
                      child: const Text('Go Back to Classes'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  final subject = _subjects[index];
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
                        backgroundColor: _primaryColor,
                        radius: 25,
                        child: Text(
                          subject.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        subject,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimaryColor,
                        ),
                      ),
                      subtitle: Text(
                        'Tap to view students and grades',
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
                          _selectedSubject = subject;
                        });
                        _loadStudentsForClassAndSubject(_selectedClass!['_id'], subject);
                      },
                    ),
                  );
                },
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: OutlinedButton.icon(
            onPressed: () => _selectClass(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Classes'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              side: BorderSide(color: _primaryColor),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStudentsScreen() {
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedClass!['name']} - $_selectedSubject',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_students.length} students • ${_grades.length} grades recorded',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _selectClass(),
                    icon: const Icon(Icons.class_, size: 18),
                    label: const Text('Change'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: BorderSide(color: _primaryColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _students.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: _textSecondaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'No students found',
                      style: TextStyle(
                        fontSize: 18,
                        color: _textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Students will appear here once enrolled',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return _buildStudentGradeCard(student, classColor);
                },
              ),
        ),
        // Submit grades button at bottom
        if (_hasUnsavedGrades)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.1),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${_tempGrades.length} unsaved grade(s)',
                  style: TextStyle(
                    color: _textSecondaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearTempGrades,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Clear All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isBulkSubmitting ? null : _submitAllGrades,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        child: _isBulkSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Submitting...', style: TextStyle(color: Colors.white)),
                                ],
                              )
                            : const Text(
                                'Submit All Grades',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStudentGradeCard(Map<String, dynamic> student, Color classColor) {
    final studentId = student['_id'] ?? '';
    final currentGrade = _findLatestGradeForStudent(studentId);
    final isEditing = _editingStudents.contains(studentId);
    final hasExistingGrade = currentGrade != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Student info on the left
            CircleAvatar(
              backgroundColor: classColor,
              radius: 24,
              child: Text(
                (student['name'] ?? 'N').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['name'] ?? 'Unknown Student',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${student['studentId'] ?? student['_id'] ?? 'N/A'}',
                    style: TextStyle(
                      color: _textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                  if (hasExistingGrade && !isEditing) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _getGradeColor(currentGrade['percentage']).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getGradeColor(currentGrade['percentage']).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Current: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondaryColor,
                            ),
                          ),
                          Text(
                            '${currentGrade['percentage'].toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _getGradeColor(currentGrade['percentage']),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Grade input/action on the right
            SizedBox(
              width: 120,
              child: hasExistingGrade && !isEditing
                  ? OutlinedButton(
                      onPressed: () => _startEditing(studentId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: BorderSide(color: _primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Edit Grade'),
                    )
                  : _buildGradeInputField(student),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeInputField(Map<String, dynamic> student) {
    final studentId = student['_id'] ?? '';
    final currentGrade = _findLatestGradeForStudent(studentId);
    final hasExistingGrade = currentGrade != null;
    
    return Column(
      children: [
        TextFormField(
          decoration: InputDecoration(
            labelText: hasExistingGrade ? 'New Score' : 'Score',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            isDense: true,
            suffixText: '%',
          ),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          initialValue: _tempGrades.containsKey(studentId) 
              ? _tempGrades[studentId]!.toStringAsFixed(0)
              : '',
          onChanged: (value) {
            final percentage = double.tryParse(value);
            setState(() {
              if (percentage != null && percentage >= 0 && percentage <= 100) {
                _tempGrades[studentId] = percentage;
                _hasUnsavedGrades = true;
              } else if (value.isEmpty) {
                _tempGrades.remove(studentId);
                _hasUnsavedGrades = _tempGrades.isNotEmpty;
              }
            });
          },
        ),
        if (hasExistingGrade && _editingStudents.contains(studentId)) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _cancelEditing(studentId),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondaryColor,
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }

  void _startEditing(String studentId) {
    setState(() {
      _editingStudents.add(studentId);
    });
  }

  void _cancelEditing(String studentId) {
    setState(() {
      _editingStudents.remove(studentId);
      _tempGrades.remove(studentId);
      _hasUnsavedGrades = _tempGrades.isNotEmpty;
    });
  }

  Map<String, dynamic>? _findLatestGradeForStudent(String studentId) {
    final studentGrades = _grades.where((g) => g['studentId'] == studentId).toList();
    if (studentGrades.isEmpty) return null;
    
    // Sort by createdAt and return the latest
    studentGrades.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
    
    return studentGrades.first;
  }

  void _clearTempGrades() {
    setState(() {
      _tempGrades.clear();
      _hasUnsavedGrades = false;
    });
  }

  Future<void> _submitAllGrades() async {
    if (_tempGrades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No grades to submit')),
      );
      return;
    }

    setState(() {
      _isBulkSubmitting = true;
    });

    try {
      // Prepare entries for bulk submission
      final entries = _tempGrades.entries.map((entry) => {
        'studentId': entry.key,
        'percentage': entry.value,
      }).toList();

      print('📊 Submitting ${entries.length} grades for class ${_selectedClass!['_id']} and subject $_selectedSubject');

      await _gradingService.submitBulkGrades(
        classId: _selectedClass!['_id'],
        subjectId: _selectedSubject!,
        teacherId: widget.user.id,
        entries: entries,
      );

      // Clear temporary grades after successful submission
      setState(() {
        _tempGrades.clear();
        _hasUnsavedGrades = false;
      });

      // Reload grades to show updated data
      await _loadGradesForClassAndSubject(_selectedClass!['_id'], _selectedSubject!);

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entries.length} grades submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error submitting grades: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting grades: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isBulkSubmitting = false;
      });
    }
  }

  void _selectClass() {
    setState(() {
      _selectedClass = null;
      _selectedSubject = null;
      _subjects.clear();
      _students.clear();
      _grades.clear();
      _tempGrades.clear();
      _hasUnsavedGrades = false;
    });
  }
  
  Color _getGradeColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }


}

  



  
  


