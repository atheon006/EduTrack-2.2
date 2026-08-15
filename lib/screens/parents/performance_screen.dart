import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../services/student_service.dart';
import '../../services/grading_service.dart';
import '../../utils/constants.dart';

class ParentPerformanceScreen extends StatefulWidget {
  final User user;

  const ParentPerformanceScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ParentPerformanceScreenState createState() => _ParentPerformanceScreenState();
}

class _ParentPerformanceScreenState extends State<ParentPerformanceScreen> {
  bool _isLoading = true;
  late Color _primaryColor;
  late Color _accentColor;
  
  // Services
  late StudentService _studentService;
  late GradingService _gradingService;
  
  // Student data for the children of the parent
  List<Map<String, dynamic>> _studentsData = [];
  
  // Selected student for viewing detailed performance
  Map<String, dynamic>? _selectedStudent;
  
  // Map to store grade data for each student
  Map<String, List<Map<String, dynamic>>> _studentGradesMap = {};
  
  @override
  void initState() {
    super.initState();
    _loadThemeColors();
    
    // Initialize services
    const baseUrl =  Constants.apiBaseUrl;
    _studentService = StudentService(baseUrl: baseUrl);
    _gradingService = GradingService(baseUrl: baseUrl);
    
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
      
      print('👨‍👩‍👧‍👦 Loading students for parent: ${widget.user.id}');
      final response = await _studentService.getStudentsByParentId(widget.user.id);
      print('👨‍👩‍👧‍👦 Found ${response.length} children for parent');
      
      // Transform student data to the format expected by the UI
      final transformedStudents = await Future.wait(
        response.map((student) async {
          // Get grade data for this student
          final gradeData = await _getStudentGrades(student['_id']);
          
          // Store the grade data in the map for later use
          _studentGradesMap[student['_id']] = await _fetchStudentGradeData(student['_id']);
          
          // Extract class info from the response
          Map<String, dynamic> classInfo;
          if (student['classId'] is Map<String, dynamic>) {
            final classData = student['classId'] as Map<String, dynamic>;
            classInfo = {
              'grade': classData['grade'] ?? 'Unknown',
              'section': classData['section'] ?? 'A',
              'name': classData['name'] ?? 'Unknown Class',
            };
          } else {
            classInfo = {
              'grade': 'Unknown Grade',
              'section': 'A',
              'name': 'Unknown Class',
            };
          }
          
          return {
            '_id': student['_id'] ?? '',
            'name': student['name'] ?? 'Unknown Student',
            'grade': classInfo['grade'] ?? 'Unknown Grade',
            'section': classInfo['section'] ?? 'A',
            'rollNumber': student['studentId'] ?? '',
            'image': _getStudentImage(student),
            'average': gradeData['average'],
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
  
  // Get real grade data for a student
  Future<Map<String, dynamic>> _getStudentGrades(String studentId) async {
    try {
      final grades = await _gradingService.getStudentGrades(studentId);
      
      if (grades.isEmpty) {
        return {'average': '0.0', 'averageValue': 0.0};
      }
      
      final average = GradingService.calculateOverallAverage(grades);
      
      return {
        'average': average.toStringAsFixed(1),
        'averageValue': average,
      };
    } catch (e) {
      print('📊 Error getting grades for student $studentId: $e');
      return {'average': 'N/A', 'averageValue': 0.0};
    }
  }
  
  // Method to fetch real student grade data from the API
  Future<List<Map<String, dynamic>>> _fetchStudentGradeData(String studentId) async {
    try {
      print('📊 Fetching real grade data for student: $studentId');
      final grades = await _gradingService.getStudentGrades(studentId);
      
      if (grades.isEmpty) {
        print('📊 No grades found for student: $studentId');
        return [];
      }
      
      print('📊 Received ${grades.length} grade entries');
      
      // Transform the grade data into the format needed for the UI
      final List<Map<String, dynamic>> subjectGrades = [];
      
      // Generate a consistent color for each subject
      final subjectColors = {
        'Mathematics': Colors.blue,
        'Physics': Colors.green,
        'Chemistry': Colors.purple,
        'Biology': Colors.orange,
        'English': Colors.indigo,
        'History': Colors.teal,
        'Geography': Colors.amber,
        'Computer Science': Colors.deepPurple,
      };
      
      for (var grade in grades) {
        final subjectName = grade['subject'] ?? 'Unknown Subject';
        final percentage = (grade['percentage'] ?? 0).toDouble();
        
        // Determine the letter grade based on percentage
        String letterGrade;
        if (percentage >= 90) letterGrade = 'A+';
        else if (percentage >= 85) letterGrade = 'A';
        else if (percentage >= 80) letterGrade = 'A-';
        else if (percentage >= 75) letterGrade = 'B+';
        else if (percentage >= 70) letterGrade = 'B';
        else if (percentage >= 65) letterGrade = 'B-';
        else if (percentage >= 60) letterGrade = 'C+';
        else if (percentage >= 55) letterGrade = 'C';
        else if (percentage >= 50) letterGrade = 'C-';
        else if (percentage >= 45) letterGrade = 'D+';
        else if (percentage >= 40) letterGrade = 'D';
        else letterGrade = 'F';
        
        // Assign a color based on the subject, defaulting to a random color if not in our predefined list
        final color = subjectColors[subjectName] ?? 
            Colors.primaries[subjectName.hashCode % Colors.primaries.length];
        
        subjectGrades.add({
          'name': subjectName,
          'grade': letterGrade,
          'score': percentage.toInt(),
          'color': color,
          'teacherName': grade['teacherName'] ?? 'Unknown Teacher',
          'className': grade['className'] ?? 'Unknown Class',
        });
      }
      
      print('📊 Processed subjects: ${subjectGrades.map((g) => g['name']).join(', ')}');
      return subjectGrades;
    } catch (e) {
      print('📊 Error fetching grade data: $e');
      return [];
    }
  }
  
  String _getStudentImage(Map<String, dynamic> student) {
    // Return a default student image or use profile picture if available
    final profilePicture = student['profilePicture'];
    if (profilePicture != null && profilePicture.toString().isNotEmpty) {
      return profilePicture.toString();
    }
    
    // Generate a consistent random image based on student ID
    final studentId = student['_id'] ?? student['studentId'] ?? '';
    final imageIndex = studentId.hashCode.abs() % 10 + 1;
    return 'https://randomuser.me/api/portraits/children/$imageIndex.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(AppTheme.defaultTheme),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.grade, color: Colors.white),
              const SizedBox(width: 10),
              const Text('Performance Reports', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : Column(
              children: [
                _buildStudentSelector(),
                Expanded(
                  child: _selectedStudent != null
                    ? _buildPerformanceDetails()
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.family_restroom, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No Students Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No students are associated with your account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
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
                        Text(
                          student['grade'],
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? _primaryColor.withValues(alpha: 0.8) : Colors.grey[600],
                          ),
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
  
  Widget _buildPerformanceDetails() {
    if (_selectedStudent == null) return Container();
    
    final student = _selectedStudent!;
    final studentId = student['_id'] as String;
    
    // Get the grade data for this student from the map
    final subjects = _studentGradesMap[studentId] ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Average Card
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
                      "${student['average']}%",
                      style: TextStyle(
                        fontSize: 18,
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
                          'Average Percentage',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subjects.isEmpty ? 'No Grades Recorded' : 'Academic Performance',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subjects.isEmpty 
                              ? 'Grades will appear here once recorded' 
                              : '${student['name']} has grades in ${subjects.length} subject(s)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh Grades',
                    onPressed: () async {
                      // Refresh grades for this student
                      setState(() {
                        _isLoading = true;
                      });
                      _studentGradesMap[studentId] = await _fetchStudentGradeData(studentId);
                      setState(() {
                        _isLoading = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          if (subjects.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Grades Available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Grades will appear here once teachers submit them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh),
                    label: Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      // Refresh grades for this student
                      setState(() {
                        _isLoading = true;
                      });
                      _studentGradesMap[studentId] = await _fetchStudentGradeData(studentId);
                      setState(() {
                        _isLoading = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            // Subject Grades
            const SizedBox(height: 24),
            _buildSectionHeader('Subject Grades'),
            const SizedBox(height: 16),
            
            for (var subject in subjects)
              _buildSubjectCard(subject),
              
            // Academic Progress
            const SizedBox(height: 24),
            _buildSectionHeader('Grade Distribution'),
            const SizedBox(height: 16),
            _buildGradeDistribution(subjects),
            
            // Teacher's Remarks
            const SizedBox(height: 24),
            _buildSectionHeader('Performance Overview'),
            const SizedBox(height: 16),
            _buildPerformanceOverview(subjects),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  Widget _buildGradeDistribution(List<Map<String, dynamic>> subjects) {
    // Create a map to count grades by letter grade
    final Map<String, int> gradeCounts = {};
    final Map<String, Color> gradeColors = {
      'A+': Colors.green.shade800,
      'A': Colors.green.shade700,
      'A-': Colors.green.shade600,
      'B+': Colors.blue.shade700,
      'B': Colors.blue.shade600,
      'B-': Colors.blue.shade500,
      'C+': Colors.orange.shade700,
      'C': Colors.orange.shade600,
      'C-': Colors.orange.shade500,
      'D+': Colors.red.shade600,
      'D': Colors.red.shade500,
      'F': Colors.red.shade700,
    };
    
    // Count occurrences of each grade
    for (var subject in subjects) {
      final grade = subject['grade'] as String;
      gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;
    }
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grade Distribution',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: gradeCounts.entries.map((entry) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: gradeColors[entry.key] ?? Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          entry.value.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: gradeColors[entry.key],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceOverview(List<Map<String, dynamic>> subjects) {
    // Calculate average score
    double totalScore = 0;
    for (var subject in subjects) {
      totalScore += subject['score'] as int;
    }
    final averageScore = subjects.isNotEmpty ? totalScore / subjects.length : 0;
    
    // Find highest and lowest scoring subjects
    subjects.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final highestSubject = subjects.isNotEmpty ? subjects.first : null;
    final lowestSubject = subjects.isNotEmpty ? subjects.last : null;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Overview',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Average Score',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${averageScore.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (highestSubject != null) ...[
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Strongest Subject',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (highestSubject['color'] as Color).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.arrow_upward, 
                                color: highestSubject['color'] as Color,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    highestSubject['name'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${highestSubject['score']}% (${highestSubject['grade']})',
                                    style: TextStyle(
                                      color: highestSubject['color'] as Color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 32),
            if (lowestSubject != null && subjects.length > 1) ...[
              Text(
                'Area for Improvement',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.info_outline, 
                      color: Colors.orange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lowestSubject['name'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${lowestSubject['score']}% (${lowestSubject['grade']})',
                          style: TextStyle(
                            color: lowestSubject['color'] as Color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Would navigate to a detailed view or tutoring options
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Get Help'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final subjectName = subject['name'] as String;
    final subjectGrade = subject['grade'] as String;
    final subjectScore = subject['score'] as int;
    final subjectColor = subject['color'] as Color;
    final teacherName = subject['teacherName'] as String;
    final className = subject['className'] as String;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        className,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
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
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: subjectScore / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: subjectColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Score: $subjectScore%',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Teacher: $teacherName',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
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
}

