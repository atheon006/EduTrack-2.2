import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/teacher_service.dart';
import '../../services/class_services.dart';
import 'teacher_assignments_screen.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_grading_screen.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class TeacherClassesScreen extends StatefulWidget {
  final User user;

  const TeacherClassesScreen({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _TeacherClassesScreenState createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  bool _isLoading = true;
  final List<Map<String, dynamic>> _classes = [];
  late TeacherService _teacherService;
  late ClassService _classService;
  String _errorMessage = '';

  // Light theme colors matching assignment screen
  final Color _primaryColor = const Color(0xFF5E63B6);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _cardColor = Colors.white;
  final Color _textPrimaryColor = const Color(0xFF333333);
  final Color _textSecondaryColor = const Color(0xFF717171);

  // Class colors for light theme
  final List<Color> _classColors = [
    const Color(0xFF5E63B6),
    const Color(0xFF43A047),
    const Color(0xFFFF9800),
    const Color(0xFF2196F3),
    const Color(0xFFE53935),
  ];

  @override
  void initState() {
    super.initState();
    _teacherService = TeacherService(baseUrl: Constants.apiBaseUrl);
    _classService = ClassService(baseUrl: Constants.apiBaseUrl);
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      print('🎓 Loading classes for teacher ID: ${widget.user.id}');
      
      // Get the teacher data with populated classes using the simple GET request
      final teacherData = await _teacherService.getTeacherById(widget.user.id);
      
      print('🎓 Teacher data response: $teacherData');

      // Clear existing classes
      _classes.clear();

      // Extract classes from the teacher data
      final classes = teacherData['classes'] as List<dynamic>? ?? [];
      
      print('🎓 Found ${classes.length} classes in teacher data');

      // Process each class
      for (int i = 0; i < classes.length; i++) {
        final classData = classes[i] as Map<String, dynamic>;
        
        // Get subjects from teacher's teachingSubs
        final teachingSubs = teacherData['teachingSubs'] as List<dynamic>? ?? [];
        final subjects = teachingSubs.join(', ').isNotEmpty ? teachingSubs.join(', ') : 'No subjects';

        // Format the class data for display
        final formattedClass = {
          'id': classData['_id'] ?? classData['id'] ?? '',
          'name': classData['name'] ?? '${classData['grade'] ?? 'Unknown'} ${classData['section'] ?? ''}',
          'subject': subjects,
          'students': 0, // Will be populated when we get actual student count
          'schedule': _generateSchedule(classData),
          'room': classData['room'] ?? 'TBD',
          'nextClass': _getNextClass(),
          'color': _classColors[i % _classColors.length],
          'grade': classData['grade'] ?? 'Unknown',
          'section': classData['section'] ?? '',
          'year': classData['year']?.toString() ?? DateTime.now().year.toString(),
        };

        // Try to get students count for the class
        try {
          final students = await _classService.getClassStudents(classData['_id'] ?? '');
          formattedClass['students'] = students.length;
        } catch (e) {
          print('🎓 Could not get students count for ${classData['_id']}: $e');
          formattedClass['students'] = 0;
        }

        _classes.add(formattedClass);
      }

      print('🎓 Processed ${_classes.length} classes');
      
    } catch (e) {
      print('🎓 Error loading classes: $e');
      setState(() {
        _errorMessage = 'Failed to load classes: ${e.toString()}';
      });
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading classes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateSchedule(Map<String, dynamic> classData) {
    // Generate a mock schedule - in a real app, this would come from the API
    final days = ['Mon, Wed, Fri', 'Tue, Thu', 'Mon, Wed', 'Tue, Thu, Fri'];
    final times = ['9:00 AM', '10:00 AM', '11:00 AM', '1:00 PM', '2:00 PM'];
    
    final dayIndex = (classData['_id']?.hashCode ?? 0) % days.length;
    final timeIndex = (classData['_id']?.hashCode ?? 0) % times.length;
    
    return '${days[dayIndex]} ${times[timeIndex]}';
  }

  String _getNextClass() {
    // Generate a mock next class time - in a real app, this would be calculated
    final nextClasses = ['Today, 11:00 AM', 'Tomorrow, 9:00 AM', 'Tomorrow, 10:00 AM', 'Thursday, 1:00 PM'];
    return nextClasses[DateTime.now().millisecond % nextClasses.length];
  }

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Classes', 
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          )
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadClasses,
          ),
        ],
      ),
      backgroundColor: _backgroundColor,
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryColor))
        : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : _classes.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadClasses,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) => _buildClassCard(_classes[index]),
                ),
              ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Classes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 16,
              color: _textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadClasses,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.class_outlined,
            size: 80,
            color: _textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Classes Assigned Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your assigned classes will appear here',
            style: TextStyle(
              fontSize: 16,
              color: _textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    final Color classColor = classData['color'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () {
          _showClassDetails(classData);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: classColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classData['name'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          classData['subject'],
                          style: TextStyle(
                            fontSize: 14,
                            color: _textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: classColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${classData['students']} students',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: classColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: _textSecondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Schedule: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _textSecondaryColor,
                        ),
                      ),
                      Text(
                        classData['schedule'],
                        style: TextStyle(
                          color: _textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.room, size: 16, color: _textSecondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Classroom: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _textSecondaryColor,
                        ),
                      ),
                      Text(
                        classData['room'],
                        style: TextStyle(
                          color: _textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.event, size: 16, color: _textSecondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Next Class: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _textSecondaryColor,
                        ),
                      ),
                      Text(
                        classData['nextClass'],
                        style: TextStyle(
                          color: _textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeacherAssignmentsScreen(
                          user: widget.user,
                          selectedClass: classData,
                        ),
                      ),
                    ),
                    icon: Icon(Icons.assignment, color: _primaryColor),
                    label: Text('HomeWork', style: TextStyle(color: _primaryColor)),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeacherAttendanceScreen(
                          user: widget.user,
                          selectedClass: classData,
                        ),
                      ),
                    ),
                    icon: Icon(Icons.people, color: _primaryColor),
                    label: Text('Attendance', style: TextStyle(color: _primaryColor)),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryColor,
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

  void _showClassDetails(Map<String, dynamic> classData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            title: Text(classData['name']),
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pop(context);
                  // Edit class functionality
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  elevation: 1,
                  color: _cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classData['name'],
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.subject, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Subject: ${classData['subject']}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.people, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Students: ${classData['students']}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.schedule, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Schedule: ${classData['schedule']}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.room, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Classroom: ${classData['room']}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.event, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Next Class: ${classData['nextClass']}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeacherAssignmentsScreen(
                            user: widget.user,
                            selectedClass: classData,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.assignment),
                      label: const Text('Homwework'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeacherAttendanceScreen(
                            user: widget.user,
                            selectedClass: classData,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.people),
                      label: const Text('Attendance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeacherGradingScreen(
                            user: widget.user,
                            selectedClass: classData,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.grade),
                      label: const Text('Grades'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  void _showAddClassDialog() {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final roomController = TextEditingController();
    final scheduleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Add New Class',
            style: TextStyle(color: _textPrimaryColor),
          ),
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Class Name',
                    hintText: 'e.g., Class 10A',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelStyle: TextStyle(color: _textSecondaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    hintText: 'e.g., Mathematics',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelStyle: TextStyle(color: _textSecondaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: roomController,
                  decoration: InputDecoration(
                    labelText: 'Room',
                    hintText: 'e.g., Room 101',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelStyle: TextStyle(color: _textSecondaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: scheduleController,
                  decoration: InputDecoration(
                    labelText: 'Schedule',
                    hintText: 'e.g., Mon, Wed, Fri 9:00 AM',
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelStyle: TextStyle(color: _textSecondaryColor),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: _textSecondaryColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                if (titleController.text.isEmpty || 
                    subjectController.text.isEmpty ||
                    roomController.text.isEmpty ||
                    scheduleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }
                
                // Add the new class
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Class added successfully'),
                    backgroundColor: _primaryColor,
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
