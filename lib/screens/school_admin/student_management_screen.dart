import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../services/student_service.dart';
import '../../services/class_services.dart';
import '../../utils/constants.dart';
import '../../services/grading_service.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _StudentManagementScreenState createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String overallPercentage="";


  late StudentService _studentService;
  late ClassService _classService;
  late GradingService _gradingService;

  // List to store available classes
  List<Map<String, dynamic>> _availableClasses = [];
  bool _loadingClasses = false;
  bool _classesPreloaded = false;

  // Cache timestamp to know when classes were last loaded
  DateTime? _lastClassesLoadTime;

  final _searchController = TextEditingController();
  String _selectedFilter = 'All';

  // Theme colors
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;

  @override
  void initState() {
    super.initState();
    _loadThemeColors();
    _studentService = StudentService(baseUrl: Constants.apiBaseUrl);
    _classService = ClassService(baseUrl: Constants.apiBaseUrl);
    _gradingService = GradingService(baseUrl: Constants.apiBaseUrl);
    _loadStudents();
    _preloadClasses();
  }

  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _tertiaryColor = AppTheme.getTertiaryColor(AppTheme.defaultTheme);
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final students = await _studentService.getAllStudents();
      final formattedStudents = students.map((student) {
        final className = student['classId'] is Map
            ? 'Class ${student['classId']['grade']}${student['classId']['section']}'
            : 'Unknown Class';

        // Extract parent info
        final parents =
            student['parents'] is List ? student['parents'] as List : [];
        final parentName = parents.isNotEmpty && parents[0] is Map
            ? parents[0]['name']
            : 'Unknown';
        final parentContact =
            parents.isNotEmpty && parents[0] is Map ? parents[0]['phone'] : '';

        // Format date of birth
        final dob =
            student['dob'] != null ? _formatDate(student['dob']) : 'Unknown';

        // Extract academic record
        final academicReport =
            student['academicReport'] is Map ? student['academicReport'] : {};
        final attendance = academicReport['attendancePct'] != null
            ? '${academicReport['attendancePct']}%'
            : 'N/A';

        final grades = academicReport['grades'] is List
            ? (academicReport['grades'] as List)
                .map((grade) => {
                      'subject': grade['subject'] ?? 'Unknown',
                      'grade': grade['grade'] ?? 'N/A',
                    })
                .toList()
            : [];

        return {
          'id': student['studentId'] ?? '',
          'name': student['name'] ?? 'Unknown',
          'grade': student['classId'] is Map ? student['classId']['grade'] : '',
          'class': className,
          'gender': student['gender'] ?? 'Unknown',
          'dob': dob,
          'address': student['address'] ?? 'N/A',
          'contact': student['phone'] ?? 'N/A',
          'email': student['email'] ?? 'N/A',
          'parent': parentName,
          'parentContact': parentContact,
          'attendance': attendance,
          'academicRecord': grades,
          'feePaid': student['feePaid'] ?? false,
          '_id': student['_id'] ?? '',
        };
      }).toList();

      setState(() {
        _students = formattedStudents;
        _filteredStudents = List.from(_students);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load students: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadStudents,
            textColor: Colors.white,
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _refreshStudents() async {
    await _loadStudents();
    _filterStudents(_searchController.text);
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students
            .where((student) =>
                student['name']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                student['id']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                student['class']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _applyGradeFilter(String grade) {
    setState(() {
      _selectedFilter = grade;
      if (grade == 'All') {
        _filteredStudents = List.from(_students);
      } else {
        _filteredStudents =
            _students.where((student) => student['grade'] == grade).toList();
      }
    });
  }

  Future<void> _preloadClasses() async {
    if (_loadingClasses) return;

    setState(() {
      _loadingClasses = true;
    });

    try {
      final classes = await _classService.getAllClasses();

      setState(() {
        _availableClasses = classes.map((classData) {
          final String grade = classData['grade'] ?? '';
          final String section = classData['section'] ?? '';
          final String name = classData['name'] ?? 'Class $grade$section';
          final String id = classData['_id'] ?? '';

          return {
            'id': id,
            'name': name,
            'grade': grade,
            'section': section,
          };
        }).toList();

        _loadingClasses = false;
        _classesPreloaded = true;
        _lastClassesLoadTime = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _loadingClasses = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to preload classes: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _preloadClasses,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAvailableClasses({bool forceRefresh = false}) async {
    // Skip if already loading
    if (_loadingClasses) {
      print('🔍 Classes already loading, skipping duplicate request');
      return;
    }
    if (_classesPreloaded && !forceRefresh && _lastClassesLoadTime != null) {
      final timeSinceLastLoad =
          DateTime.now().difference(_lastClassesLoadTime!);

      // Use cached data if loaded less than 30 seconds ago
      if (timeSinceLastLoad.inSeconds < 30) {
        print(
            '🔍 Using cached class data (${timeSinceLastLoad.inSeconds}s old)');
        return;
      }
    }
    setState(() {
      _loadingClasses = true;
    });

    try {
      final classes = await _classService.getAllClasses();
      print('🔍 Classes loaded successfully! Count: ${classes.length}');

      // Format classes for display
      setState(() {
        _availableClasses = classes.map((classData) {
          final String grade = classData['grade'] ?? '';
          final String section = classData['section'] ?? '';
          final String name = classData['name'] ?? 'Class $grade$section';
          final String id = classData['_id'] ?? '';

          return {
            'id': id,
            'name': name,
            'grade': grade,
            'section': section,
          };
        }).toList();

        _loadingClasses = false;
        _classesPreloaded = true;
        _lastClassesLoadTime = DateTime.now();
      });
    } catch (e) {
      print('❌ Error loading classes: $e');
      setState(() {
        _loadingClasses = false;
      });

      // Show error message if not in initialization
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load classes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Management',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: _primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStudents,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : _hasError
              ? _buildErrorView()
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey.shade100],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search students...',
                              prefixIcon:
                                  Icon(Icons.search, color: _accentColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 0.0),
                              fillColor: Colors.grey.shade50,
                              filled: true,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(color: _accentColor),
                              ),
                            ),
                            onChanged: _filterStudents,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _primaryColor,
                                      _primaryColor.withValues(alpha: 0.8)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedFilter == 'All'
                                          ? 'All Students'
                                          : 'Grade $_selectedFilter Students',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_filteredStudents.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                icon: Icon(Icons.filter_list,
                                    color: _accentColor),
                                label: Text('Filter',
                                    style: TextStyle(color: _accentColor)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: _accentColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: _showFilterOptions,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 8,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: _students.isEmpty
                            ? _buildEmptyView()
                            : _filteredStudents.isEmpty
                                ? _buildNoMatchView()
                                : ListView.builder(
                                    padding: const EdgeInsets.only(
                                        top: 20,
                                        left: 8,
                                        right: 8,
                                        bottom: 100), // Added bottom padding
                                    itemCount: _filteredStudents.length,
                                    itemBuilder: (context, index) {
                                      final student = _filteredStudents[index];
                                      // Create gradient colors based on index
                                      final List<Color> gradientColors;
                                      switch (index % 4) {
                                        case 0:
                                          gradientColors = [
                                            const Color(0xFF90CAF9),
                                            const Color(0xFFBBDEFB),
                                          ];
                                          break;
                                        case 1:
                                          gradientColors = [
                                            const Color(0xFF80CBC4),
                                            const Color(0xFFB2DFDB),
                                          ];
                                          break;
                                        case 2:
                                          gradientColors = [
                                            const Color(0xFFFFD54F),
                                            const Color(0xFFFFE082),
                                          ];
                                          break;
                                        case 3:
                                          gradientColors = [
                                            const Color(0xFFCE93D8),
                                            const Color(0xFFE1BEE7),
                                          ];
                                          break;
                                        default:
                                          gradientColors = [
                                            const Color(0xFF90CAF9),
                                            const Color(0xFFBBDEFB),
                                          ];
                                      }

                                      return Card(
                                        elevation: 3,
                                        shadowColor:
                                            gradientColors[0].withValues(alpha: 0.3),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 8.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          onTap: () =>
                                              _showStudentDetails(student),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Header section with gradient
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: gradientColors,
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(18),
                                                    topRight:
                                                        Radius.circular(18),
                                                  ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 16.0),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color:
                                                                gradientColors[
                                                                        0]
                                                                    .withValues(alpha: 
                                                                        0.3),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                    0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        student['name']
                                                            .toString()
                                                            .substring(0, 1),
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 18,
                                                          color:
                                                              gradientColors[0],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            student['name']
                                                                as String,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 18,
                                                              color:
                                                                  Colors.white,
                                                              shadows: [
                                                                Shadow(
                                                                  offset:
                                                                      Offset(
                                                                          0, 1),
                                                                  blurRadius: 2,
                                                                  color: Color(
                                                                      0x50000000),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            'ID: ${student['id']} | Grade: ${student['grade']}',
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 14,
                                                              shadows: [
                                                                Shadow(
                                                                  offset:
                                                                      Offset(
                                                                          0, 1),
                                                                  blurRadius: 2,
                                                                  color: Color(
                                                                      0x50000000),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Footer with essential info and actions
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    bottomLeft:
                                                        Radius.circular(18),
                                                    bottomRight:
                                                        Radius.circular(18),
                                                  ),
                                                  border: Border(
                                                    top: BorderSide(
                                                      color: gradientColors[0]
                                                          .withValues(alpha: 0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 12.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.school,
                                                            size: 16,
                                                            color:
                                                                gradientColors[
                                                                    0]),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                          student['class']
                                                              as String,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors.grey
                                                                  .shade800),
                                                        ),
                                                        const Spacer(),
                                                        // Row(
                                                        //   children: [
                                                        //     Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                                                        //     const SizedBox(width: 4),
                                                        //     Text(
                                                        //       student['attendance'] as String,
                                                        //       style: TextStyle(
                                                        //         fontSize: 13,
                                                        //         fontWeight: FontWeight.w500,
                                                        //         color: Colors.blue.shade700
                                                        //       ),
                                                        //     ),
                                                        //   ],
                                                        // ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Row(
                                                            // children: [
                                                            //   Icon(Icons.badge,
                                                            //       size: 16,
                                                            //       color: Colors
                                                            //           .orange
                                                            //           .shade700),
                                                            //   const SizedBox(
                                                            //       width: 4),
                                                            //   // Text(
                                                            //   //   'Avg: ${_getAverageGrade(student['academicRecord'] as List)}',
                                                            //   //   style: TextStyle(
                                                            //   //     fontSize: 13,
                                                            //   //     fontWeight: FontWeight.w500,
                                                            //   //     color: Colors.orange.shade700
                                                            //   //   ),
                                                            //   // ),
                                                            // ],
                                                          ),
                                                        ),
                                                        TextButton.icon(
                                                          icon: Icon(
                                                              Icons.visibility,
                                                              size: 16,
                                                              color:
                                                                  gradientColors[
                                                                      0]),
                                                          label: Text(
                                                            'View Profile',
                                                            style: TextStyle(
                                                                color:
                                                                    gradientColors[
                                                                        0],
                                                                fontSize: 13),
                                                          ),
                                                          onPressed: () =>
                                                              _showStudentDetails(
                                                                  student),
                                                          style: ButtonStyle(
                                                            tapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                            padding: MaterialStateProperty.all(
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4)),
                                                          ),
                                                        ),
                                                        PopupMenuButton(
                                                          icon: Icon(
                                                            Icons.more_vert,
                                                            color: Colors
                                                                .grey.shade600,
                                                            size: 20,
                                                          ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          position:
                                                              PopupMenuPosition
                                                                  .under,
                                                          itemBuilder:
                                                              (context) => [
                                                            const PopupMenuItem(
                                                              value: 'edit',
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .edit,
                                                                      color: Colors
                                                                          .blue,
                                                                      size: 18),
                                                                  SizedBox(
                                                                      width: 8),
                                                                  Text('Edit',
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              14)),
                                                                ],
                                                              ),
                                                            ),
                                                            // const PopupMenuItem(
                                                            //   value: 'academic',
                                                            //   child: Row(
                                                            //     children: [
                                                            //       Icon(Icons.book, color: Colors.green, size: 18),
                                                            //       SizedBox(width: 8),
                                                            //       Text('Academic Record', style: TextStyle(fontSize: 14)),
                                                            //     ],
                                                            //   ),
                                                            // ),
                                                            // const PopupMenuItem(
                                                            //   value: 'message',
                                                            //   child: Row(
                                                            //     children: [
                                                            //       Icon(Icons.message, color: Colors.orange, size: 18),
                                                            //       SizedBox(width: 8),
                                                            //       Text('Message Parent', style: TextStyle(fontSize: 14)),
                                                            //     ],
                                                            //   ),
                                                            // ),
                                                            const PopupMenuItem(
                                                              value: 'delete',
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .delete,
                                                                      color: Colors
                                                                          .red,
                                                                      size: 18),
                                                                  SizedBox(
                                                                      width: 8),
                                                                  Text(
                                                                      'Remove Student',
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              14)),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                          // onSelected: (value) {
                                                          //   _handleMenuAction(value, student);
                                                          // },
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
                      ),
                    ),
                  ],
                ),
      backgroundColor: Colors.white,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accentColor, _accentColor.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddStudentDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text("Enroll New Student",
              style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  // Build error view for API failures
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load students',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStudents,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Build empty view when no students are available
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Students Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get started by enrolling your first student',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddStudentDialog,
            icon: const Icon(Icons.add),
            label: const Text('Enroll New Student'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Build view for when no students match filter criteria
  Widget _buildNoMatchView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No students match your filter',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing your search criteria',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear Filters'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedFilter = 'All';
                _filteredStudents = List.from(_students);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding:
            const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentColor, _accentColor.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Filter Students',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter by grade
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade50,
                    Colors.blue.shade100.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Filter by Grade',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'All',
                      '9',
                      '10',
                      '11',
                      '12',
                    ]
                        .map((grade) => _buildFilterChip(
                              label: grade,
                              selected: _selectedFilter == grade,
                              onSelected: (selected) {
                                Navigator.pop(context);
                                _applyGradeFilter(grade);
                              },
                              color: Colors.blue,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

            // Actions
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear All'),
                    onPressed: () {
                      setState(() {
                        _filteredStudents = List.from(_students);
                        _selectedFilter = 'All';
                      });
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      elevation: 2,
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

  // Helper method to create consistent filter chips
  Widget _buildFilterChip(
      {required String label,
      required bool selected,
      required Function(bool) onSelected,
      required Color color}) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: color.withValues(alpha: 0.15),
      checkmarkColor: color.withValues(alpha: 0.8),
      labelStyle: TextStyle(
        color: selected ? color : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: selected ? color : Colors.grey.shade300),
      elevation: 1,
      shadowColor: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    // Get MongoDB ID for API request
    final String studentId = student['_id'] as String;

    // Show bottom sheet with FutureBuilder
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _studentService.getStudentById(studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingStudentDetails();
              } else if (snapshot.hasError) {
                return _buildErrorStudentDetails(
                  snapshot.error.toString(),
                  () {
                    // Close current sheet and reopen to retry
                    Navigator.pop(context);
                    _showStudentDetails(student);
                  },
                );
              } else if (snapshot.hasData) {
                return _buildStudentDetailsContent(
                    snapshot.data!, scrollController);
              } else {
                return _buildErrorStudentDetails(
                  'No data available',
                  () {
                    Navigator.pop(context);
                    _showStudentDetails(student);
                  },
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // Loading view for student details
  Widget _buildLoadingStudentDetails() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _accentColor),
          const SizedBox(height: 24),
          Text(
            'Loading student details...',
            style: TextStyle(
              color: _accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Error view for student details
  Widget _buildErrorStudentDetails(
      String errorMessage, VoidCallback retryFunction) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 80,
          color: Colors.red.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          'Failed to load student details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: retryFunction,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Content view for student details
  Widget _buildStudentDetailsContent(
      Map<String, dynamic> student, ScrollController scrollController) {
    // Extract data from the student details API response
    final studentName = student['name']?.toString() ?? 'Unknown';
    final studentId = student['studentId']?.toString() ?? 'Unknown';
    final String mongoId = student['_id']?.toString() ?? '';

    // Process class info - handle both Map and String cases
    String className = "Unknown Class";
    String grade = "Unknown";
    String section = "";
    if (student['classId'] is Map) {
      final classData = student['classId'] as Map<String, dynamic>;
      grade = classData['grade']?.toString() ?? 'Unknown';
      section = classData['section']?.toString() ?? '';
      className = classData['name']?.toString() ?? 'Class $grade$section';
    } else if (student['classId'] is String) {
      // Handle case where classId is just a string ID
      className = "Class ID: ${student['classId']}";
    }

    // Format date of birth
    String dob = "Unknown";
    if (student['dob'] != null) {
      try {
        final DateTime dobDate = DateTime.parse(student['dob'].toString());
        dob =
            '${dobDate.year}-${dobDate.month.toString().padLeft(2, '0')}-${dobDate.day.toString().padLeft(2, '0')}';
      } catch (e) {
        dob = student['dob'].toString();
      }
    }

    // Extract parent info safely
    final List<dynamic> parents = student['parents'] ?? [];
    String parentName = "Unknown";
    String parentContact = "Unknown";
    String parentEmail = "Unknown";

    if (parents.isNotEmpty && parents[0] is Map) {
      final parent = parents[0] as Map<String, dynamic>;
      parentName = parent['name']?.toString() ?? 'Unknown';
      parentContact = parent['phone']?.toString() ?? 'Unknown';
      parentEmail = parent['email']?.toString() ?? 'Unknown';
    }

    // Extract other student info safely
    final gender = student['gender']?.toString() ?? 'Unknown';
    final address = student['address']?.toString() ?? 'Unknown';
    final phone = student['phone']?.toString() ?? 'Unknown';
    final email = student['email']?.toString() ?? 'Unknown';
    final schoolName = student['schoolId'] is Map
        ? student['schoolId']['name']?.toString() ?? 'Unknown School'
        : 'Unknown School';

    return FutureBuilder<Map<String, dynamic>>(
        future: _gradingService.getStudentGradesByStudentId(mongoId),
        builder: (context, gradeSnapshot) {
          int attendancePercentage = 0;
          Map<String, dynamic> gradeData = {
            'grades': [],
            'studentName': '',
            'studentId': studentId,
          };
          print('📚 FutureBuilder state: ${gradeSnapshot.connectionState}');
          // Process grade data if available
          if (gradeSnapshot.connectionState == ConnectionState.done &&
              gradeSnapshot.hasData &&
              !gradeSnapshot.hasError) {
            print('📚 Error in FutureBuilder: ${gradeSnapshot.error}');
            print('📚 Stack trace: ${gradeSnapshot.stackTrace}');
            final academicData = gradeSnapshot.data!;
            print('📚 Raw academicData: $academicData');
            print('📚 Type of academicData: ${academicData.runtimeType}');
            print(
                '📚 Type of grades: ${academicData.containsKey('grades') ? academicData['grades'].runtimeType : 'missing'}');

            if (academicData.containsKey('attendance')) {
              attendancePercentage = academicData['attendance'] ?? 0;
            }

            gradeData = academicData;

            if (!gradeData.containsKey('grades') ||
                gradeData['grades'] == null) {
              gradeData['grades'] = [];
              print('📚 Grades key missing or null, set to empty list');
            } else {
              try {
                gradeData['grades'] =
                    List<dynamic>.from(gradeData['grades'] as Iterable);
                print('📚 Grades: ${gradeData['grades']}');
              } catch (e) {
                print('📚 Error casting grades to List: $e');
                gradeData['grades'] = [];
              }
            }
          }

          return Column(
            children: [
              // Colorful header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentColor, _accentColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Text(
                            studentName.isNotEmpty
                                ? studentName.substring(0, 1).toUpperCase()
                                : "?",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Grade $grade$section | $className',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ID: $studentId',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content area with details
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic information
                      _buildInfoSection(
                        'Basic Information',
                        Icons.person,
                        [
                          _buildDetailRow('Date of Birth', dob),
                          _buildDetailRow('Gender', gender),
                          _buildDetailRow('School Name', schoolName),
                        ],
                        _primaryColor,
                      ),

                      const SizedBox(height: 24),

                      // Contact information
                      _buildInfoSection(
                        'Contact Information',
                        Icons.contact_mail,
                        [
                          _buildDetailRow('Address', address),
                          _buildDetailRow('Contact', phone),
                          _buildDetailRow('Email', email),
                        ],
                        _tertiaryColor,
                      ),

                      const SizedBox(height: 24),

                      // Parent information
                      _buildInfoSection(
                        'Parent Information',
                        Icons.family_restroom,
                        [
                          _buildDetailRow('Parent Name', parentName),
                          _buildDetailRow('Parent Contact', parentContact),
                          _buildDetailRow('Parent Email', parentEmail),
                        ],
                        Colors.orange,
                      ),

                      const SizedBox(height: 24),

                      // Academic information with grades from GradingService
                      _buildInfoSection(
                        'Academic Information',
                        Icons.school,
                        [
                          _buildDetailRow(
                              'Attendance', '$attendancePercentage%'),
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Subject Grades',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (gradeSnapshot.connectionState ==
                                    ConnectionState.waiting)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _accentColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Loading grades...',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: _accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (gradeSnapshot.hasError)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Error loading grades: ${gradeSnapshot.error.toString()}',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.red.shade500,
                                      ),
                                    ),
                                  )
                                else if (!gradeData.containsKey('grades') ||
                                    gradeData['grades'] == null)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'No grades recorded yet',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    children: gradeData['grades']
                                        .map<Widget>((grade) {
                                      final subject =
                                          grade['subject']?.toString() ??
                                              'Unknown Subject';
                                      final gradeValue =
                                          grade['percentage'] ?? 0;
                                      return ListTile(
                                        title: Text('Subject: $subject'),
                                        trailing:
                                            Text('Percentage: $gradeValue%'),
                                      );
                                    }).toList(),
                                  )
                              ],
                            ),
                          ),
                        ],
                        _accentColor,
                      ),

                      const SizedBox(height: 24),

                      // Registration info
                      _buildInfoSection(
                        'Registration Details',
                        Icons.event_note,
                        [
                          _buildDetailRow('Created At',
                              _formatAPIDate(student['createdAt'])),
                          _buildDetailRow('Last Updated',
                              _formatAPIDate(student['updatedAt'])),
                        ],
                        Colors.grey.shade700,
                      ),

                      const SizedBox(height: 32),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profile'),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditStudentDialog(student);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        });
  }

  // Helper to format API dates
  String _formatAPIDate(dynamic dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final DateTime date = DateTime.parse(dateStr.toString());
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  Widget _buildInfoSection(
      String title, IconData icon, List<Widget> children, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    // Student info controllers
    final nameController = TextEditingController();
    final idController = TextEditingController(
        text: 'ST${(100000 + _students.length).toString().substring(1)}');
    final dobController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    // Parent controllers - Support for up to 2 parents
    final parent1NameController = TextEditingController();
    final parent1PhoneController = TextEditingController();
    final parent1EmailController = TextEditingController();

    final parent2NameController = TextEditingController();
    final parent2PhoneController = TextEditingController();
    final parent2EmailController = TextEditingController();

    // Form state variables
    String selectedGender = 'Male';
    bool feePaid = false;
    bool includeSecondParent = false;

    String? selectedClassId =
        _availableClasses.isNotEmpty ? _availableClasses[0]['id'] : null;

    bool isSubmitting = false;
    bool isRefreshingClasses = false;

    if (!_classesPreloaded) {
      Future.microtask(() {
        _loadAvailableClasses(forceRefresh: true).then((_) {});
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: _primaryColor),
              const SizedBox(width: 8),
              const Text('Enroll New Student'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student Information',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            hintText: 'Enter student\'s full name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: idController,
                          decoration: const InputDecoration(
                            labelText: 'Student ID *',
                            hintText: 'Enter student ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email *',
                            hintText: 'Enter student email for login',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            // If no classes are loaded yet, show loading or error
                            if (_availableClasses.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isRefreshingClasses
                                      ? Colors.blue.shade50
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isRefreshingClasses
                                          ? Colors.blue.shade200
                                          : Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    isRefreshingClasses
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.blue.shade700,
                                            ),
                                          )
                                        : Icon(Icons.error_outline,
                                            color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isRefreshingClasses
                                            ? 'Loading available classes...'
                                            : 'No classes available. Please create classes first.',
                                        style: TextStyle(
                                            color: isRefreshingClasses
                                                ? Colors.blue.shade700
                                                : Colors.red.shade700),
                                      ),
                                    ),
                                    if (!isRefreshingClasses)
                                      IconButton(
                                        icon: Icon(Icons.refresh,
                                            color: Colors.red.shade700),
                                        onPressed: () {
                                          setDialogState(() {
                                            isRefreshingClasses = true;
                                          });

                                          _loadAvailableClasses(
                                                  forceRefresh: true)
                                              .then((_) {
                                            if (mounted) {
                                              setDialogState(() {
                                                isRefreshingClasses = false;
                                                selectedClassId =
                                                    _availableClasses.isNotEmpty
                                                        ? _availableClasses[0]
                                                            ['id']
                                                        : null;
                                              });
                                            }
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }

                            // Make sure we have a valid selection
                            if (selectedClassId == null ||
                                !_availableClasses
                                    .any((c) => c['id'] == selectedClassId)) {
                              selectedClassId = _availableClasses[0]['id'];
                            }

                            return DropdownButtonFormField<String>(
                              value: selectedClassId,
                              decoration: const InputDecoration(
                                labelText: 'Class *',
                                border: OutlineInputBorder(),
                              ),
                              items: _availableClasses.map((classItem) {
                                return DropdownMenuItem<String>(
                                  value: classItem['id'],
                                  child: Text(
                                      '${classItem['name']} (Grade ${classItem['grade']}${classItem['section']})'),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                setDialogState(() {
                                  selectedClassId = value;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: dobController,
                          decoration: InputDecoration(
                            labelText: 'Date of Birth *',
                            hintText: 'YYYY-MM-DD',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now()
                                      .subtract(const Duration(days: 365 * 10)),
                                  firstDate: DateTime.now()
                                      .subtract(const Duration(days: 365 * 18)),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    dobController.text =
                                        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Gender: *', style: TextStyle(fontSize: 16)),
                        Row(
                          children: [
                            Radio(
                              value: 'Male',
                              groupValue: selectedGender,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedGender = value.toString();
                                });
                              },
                            ),
                            const Text('Male'),
                            const SizedBox(width: 12),
                            Radio(
                              value: 'Female',
                              groupValue: selectedGender,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedGender = value.toString();
                                });
                              },
                            ),
                            const Text('Female'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Information section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address *',
                            hintText: 'Enter complete address',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Number *',
                            hintText: 'Enter phone number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Parent Information section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Parent/Guardian Information',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),

                        // Primary Parent
                        const Text(
                          'Primary Parent/Guardian *',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: parent1NameController,
                          decoration: const InputDecoration(
                            labelText: 'Parent Name *',
                            hintText: 'Enter parent\'s full name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: parent1PhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Parent Contact *',
                            hintText: 'Enter parent\'s phone number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: parent1EmailController,
                          decoration: const InputDecoration(
                            labelText: 'Parent Email *',
                            hintText: 'Enter parent\'s email for login access',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 16),

                        // Option to add second parent
                        CheckboxListTile(
                          title: const Text("Add Second Parent/Guardian"),
                          subtitle: const Text(
                              "Optional - for guardians with dual custody"),
                          value: includeSecondParent,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              includeSecondParent = value ?? false;
                              if (!includeSecondParent) {
                                // Clear second parent fields if unchecked
                                parent2NameController.clear();
                                parent2PhoneController.clear();
                                parent2EmailController.clear();
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),

                        // Second Parent (conditional)
                        if (includeSecondParent) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Second Parent/Guardian',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: parent2NameController,
                            decoration: const InputDecoration(
                              labelText: 'Second Parent Name',
                              hintText: 'Enter second parent\'s full name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: parent2PhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Second Parent Contact',
                              hintText: 'Enter second parent\'s phone number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: parent2EmailController,
                            decoration: const InputDecoration(
                              labelText: 'Second Parent Email',
                              hintText: 'Enter second parent\'s email',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  const SizedBox(height: 8),
                  const Text(
                    '* Required fields',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Text(
                      'Note: Student and parent login credentials will use the school secret key as password. They can change it later.',
                      style:
                          TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              child: const Text('Cancel'),
            ),
            _availableClasses.isEmpty
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload Classes'),
                    onPressed: () async {
                      setDialogState(() {
                        isRefreshingClasses = true;
                      });

                      await _loadAvailableClasses(forceRefresh: true);

                      setDialogState(() {
                        isRefreshingClasses = false;
                        selectedClassId = _availableClasses.isNotEmpty
                            ? _availableClasses[0]['id']
                            : null;
                      });
                    },
                  )
                : ElevatedButton.icon(
                    icon: isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.school),
                    label:
                        Text(isSubmitting ? 'Enrolling...' : 'Enroll Student'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            // Check if there are available classes
                            if (_availableClasses.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Cannot enroll student: No classes available'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Validate required fields
                            if (nameController.text.isEmpty ||
                                idController.text.isEmpty ||
                                emailController.text.isEmpty ||
                                selectedClassId == null ||
                                dobController.text.isEmpty ||
                                addressController.text.isEmpty ||
                                phoneController.text.isEmpty ||
                                parent1NameController.text.isEmpty ||
                                parent1PhoneController.text.isEmpty ||
                                parent1EmailController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Please fill all required fields'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Validate second parent if included
                            if (includeSecondParent &&
                                (parent2NameController.text.isEmpty ||
                                    parent2PhoneController.text.isEmpty ||
                                    parent2EmailController.text.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please fill all second parent fields or uncheck the option'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            try {
                              // Show loading indicator inside dialog
                              setDialogState(() {
                                isSubmitting = true;
                              });

                              // Show progress message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Text(
                                          'Creating student and parent accounts...'),
                                    ],
                                  ),
                                  backgroundColor: _primaryColor,
                                  duration: const Duration(seconds: 5),
                                ),
                              );

                              final List<Map<String, dynamic>> parentData = [
                                {
                                  'name': parent1NameController.text,
                                  'email': parent1EmailController.text,
                                  'phone': parent1PhoneController.text,
                                }
                              ];
                              if (includeSecondParent &&
                                  parent2NameController.text.isNotEmpty) {
                                parentData.add({
                                  'name': parent2NameController.text,
                                  'email': parent2EmailController.text,
                                  'phone': parent2PhoneController.text,
                                  // Password will be added by createStudent method using schoolSecretKey
                                });
                              }

                              final result =
                                  await _studentService.createStudent(
                                studentId: idController.text,
                                name: nameController.text,
                                classId: selectedClassId!,
                                dob: dobController.text,
                                gender: selectedGender,
                                address: addressController.text,
                                phone: phoneController.text,
                                email: emailController.text,
                                feePaid: feePaid,
                                parents: parentData,
                              );

                              print(
                                  '✅ Student created successfully: ${result['_id']}');

                              Navigator.pop(context);

                              await _refreshStudents();

                              // Hide progress message and show success message
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Student and parent accounts created successfully! They can login with their email and the school secret key.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 6),
                                ),
                              );
                            } catch (e) {
                              // Stop loading but keep dialog open
                              setDialogState(() {
                                isSubmitting = false;
                              });

                              print('❌ Error creating student: $e');

                              // Hide progress message
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();

                              String errorMessage = e.toString();
                              if (errorMessage
                                  .contains('School secret key not found')) {
                                errorMessage =
                                    'School secret key not found. Please contact administrator.';
                              } else if (errorMessage
                                  .contains('Email already exists')) {
                                errorMessage =
                                    'A user with this email already exists.';
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Failed to enroll student: $errorMessage'),
                                  backgroundColor: Colors.red,
                                  action: SnackBarAction(
                                    label: 'Retry',
                                    onPressed: () {
                                      // Retry by calling the same function again
                                    },
                                    textColor: Colors.white,
                                  ),
                                  duration: const Duration(seconds: 8),
                                ),
                              );
                            }
                          },
                  ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    final nameController =
        TextEditingController(text: student['name'] as String);
    final dobController = TextEditingController(text: student['dob'] as String);
    final addressController =
        TextEditingController(text: student['address'] as String);
    final contactController =
        TextEditingController(text: student['contact'] as String);
    final emailController =
        TextEditingController(text: student['email'] as String);

    String selectedGender = student['gender'] as String;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dobController,
                  decoration: const InputDecoration(labelText: 'Date of Birth'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Gender: '),
                    Radio(
                      value: 'Male',
                      groupValue: selectedGender,
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value.toString();
                        });
                      },
                    ),
                    const Text('Male'),
                    Radio(
                      value: 'Female',
                      groupValue: selectedGender,
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value.toString();
                        });
                      },
                    ),
                    const Text('Female'),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contactController,
                  decoration:
                      const InputDecoration(labelText: 'Contact Number'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all required fields')),
                  );
                  return;
                }

                try {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);

                  final studentIdToUpdate =
                      student['_id'].toString(); // Use MongoDB _id

                  await _studentService.updateStudent(
                    studentId: studentIdToUpdate,
                    name: nameController.text,
                    gender: selectedGender,
                    dob: dobController.text,
                    address: addressController.text,
                    phone: contactController.text,
                    email: emailController.text,
                  );

                  await _refreshStudents();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Student updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Failed to update student: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
            'Are you sure you want to remove ${student['name']} from the school? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final studentIdToDelete =
                    student['_id'].toString(); // Use MongoDB _id

                // Show loading state but don't close dialog yet
                setState(() {
                  // Local loading indicator
                });

                // Perform the deletion
                await _studentService.deleteStudent(studentIdToDelete);

                // Only close the dialog after successful deletion
                Navigator.pop(context);

                // Update UI
                setState(() => _isLoading = true);
                await _refreshStudents();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student removed successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // Keep dialog open, reset loading state
                setState(() {
                  // Reset local loading indicator
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to remove student: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
