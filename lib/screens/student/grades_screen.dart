import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../services/grading_service.dart';
// ignore: unused_import
import '../../services/student_service.dart';
import '../../utils/constants.dart'; // Import constants for base URL 

class GradesScreen extends StatefulWidget {
  final User user;

  const GradesScreen({super.key, required this.user});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _grades = [];
  late GradingService _gradingService;
  
  // Theme colors
  late Color _accentColor;
  late List<Color> _gradientColors;

  // Subject colors mapping
  final Map<String, Color> _subjectColors = {
    'Mathematics': Colors.blue,
    'Math': Colors.blue,
    'Science': Colors.green,
    'Physics': Colors.indigo,
    'Chemistry': Colors.teal,
    'Biology': Colors.lightGreen,
    'English Literature': Colors.purple,
    'English': Colors.purple,
    'History': Colors.orange,
    'Computer Science': Colors.cyan,
    'Programming': Colors.cyan,
    'Art': Colors.pink,
    'Geography': Colors.brown,
    'Economics': Colors.deepOrange,
    'default': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _gradingService = GradingService(baseUrl: Constants.apiBaseUrl); // Use Constants for base URL
    _loadThemeColors();
    _loadGradeData();
  }
  
  void _loadThemeColors() {
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _gradientColors = AppTheme.getGradientColors(AppTheme.defaultTheme);
  }
  
  Future<void> _loadGradeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use the user's database ID directly for the API call
      // The API expects the student's database _id, not the studentId field
      final grades = await _gradingService.getStudentGrades(widget.user.id);
      
      // Transform the data to include additional UI properties
      final transformedGrades = grades.map((grade) {
        final subject = grade['subject'] as String;
        final percentage = grade['percentage'] as double;
        
        return {
          ...grade,
          'grade': _getGradeLetter(percentage),
          'color': _getSubjectColor(subject),
          'feedback': _generateFeedback(subject, percentage),
          'teacher': grade['teacherName'],
          'date': DateTime.now(), // Using current date since API doesn't provide assessment date
        };
      }).toList();

      setState(() {
        _grades = transformedGrades;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error loading grades: $e');
    }
  }

  Color _getSubjectColor(String subject) {
    return _subjectColors[subject] ?? _subjectColors['default']!;
  }

  String _generateFeedback(String subject, double percentage) {
    if (percentage >= 95) {
      return 'Outstanding performance! Keep up the excellent work in $subject.';
    } else if (percentage >= 85) {
      return 'Very good work in $subject. Continue to strengthen your understanding.';
    } else if (percentage >= 75) {
      return 'Good progress in $subject. Focus on areas that need improvement.';
    } else if (percentage >= 65) {
      return 'Satisfactory performance in $subject. Additional practice recommended.';
    } else {
      return 'This subject needs more attention. Consider seeking additional help.';
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(AppTheme.defaultTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grades & Progress', style: TextStyle(fontWeight: FontWeight.bold)),
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
            tabs: const [
              Tab(text: 'Current Grades'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadGradeData,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _accentColor),
            const SizedBox(height: 16),
            const Text('Loading your grades...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load grades',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGradeData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_grades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No grades available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Your grades will appear here once they are entered by your teachers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildGradesTab(),
      ],
    );
  }

  Widget _buildGradesTab() {
    // Calculate overall percentage (average of all grade percentages)
    double overallPercentage = 0;
    for (var grade in _grades) {
      overallPercentage += grade['percentage'] as double;
    }
    overallPercentage = overallPercentage / _grades.length;
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    overallPercentage.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Percentage',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${overallPercentage.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _getGradeLetterContainer(_getGradeLetter(overallPercentage)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _grades.length,
            itemBuilder: (context, index) {
              final grade = _grades[index];
              return _buildGradeCard(grade);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildGradeCard(Map<String, dynamic> grade) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (grade['color'] as Color).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.book, color: grade['color'] as Color),
        ),
        title: Text(
          grade['subject'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class: ${grade['className']} (Grade ${grade['classGrade']}-${grade['classSection']})',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Teacher: ${grade['teacher']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${(grade['percentage'] as double).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            _getGradeLetterContainer(grade['grade'] as String),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Feedback:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    grade['feedback'] as String,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  

  
  
  
  
  Widget _getGradeLetterContainer(String grade) {
    Color color;
    switch (grade[0]) {
      case 'A':
        color = Colors.green;
        break;
      case 'B':
        color = Colors.blue;
        break;
      case 'C':
        color = Colors.orange;
        break;
      case 'D':
        color = Colors.deepOrange;
        break;
      default:
        color = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        grade,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
  
  String _getGradeLetter(double percentage) {
    if (percentage >= 90) {
      return 'A';
    } else if (percentage >= 80) {
      return 'B';
    } else if (percentage >= 70) {
      return 'C';
    } else if (percentage >= 60) {
      return 'D';
    } else {
      return 'F';
    }
  }
}
